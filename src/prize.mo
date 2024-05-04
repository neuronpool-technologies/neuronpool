import Random "mo:base/Random";
import Nat64 "mo:base/Nat64";
import Stats "./stats";
import T "./types";

module {

    public func weightedSelection(history : T.OperationHistory, randomThreshold : Nat64) : ?Principal {
        let currentStakers = Stats.getCurrentStakers(history);

        var runningSum : Nat64 = 0;
        for ((staker, amount) in currentStakers.vals()) {
            runningSum += amount;

            if (runningSum >= randomThreshold) {
                return ?staker;
            };
        };

        return null;
    };

    public func generateRandomThreshold(totalStakeAmount : Nat64) : async ?Nat64 {
        let random = Random.Finite(await Random.blob());

        // We find the minimum p needed for range
        var p : Nat8 = 0;
        var value : Nat64 = 1;
        label p_loop loop {
            if (value > totalStakeAmount) break p_loop;
            value *= 2; // Double the value, effectively increasing the power of 2.
            p += 1; // Increment the exponent 'p' by 1.
        };

        // We find the random threshold using the p
        label range_loop loop {
            // if p = 17 (over 100,000 ICP staked):
            // each call is roughly 3 bytes. So, we have 32 (our blob) which gives 9 or 10 chances to find a number
            // chances decrease as total stake amount grows
            let ?randomNumber = random.range(p) else break range_loop;

            if (Nat64.fromNat(randomNumber) <= totalStakeAmount) {
                return ?Nat64.fromNat(randomNumber);
            };
        };

        // Insufficient entropy to generate a random winning number.
        return null;
    };

};
