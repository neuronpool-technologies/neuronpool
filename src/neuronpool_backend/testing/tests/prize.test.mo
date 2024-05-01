import { test; expect; suite } "mo:test/async";
import T "../../types";
import Vector "mo:vector";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Operations "../../operations";
import Iter "mo:base/Iter";
import Prize "../../prize";
import Stats "../../stats";

await suite("test generating a random threshold", func() : async() {

    let mockPrincipal : Principal = Principal.fromText("un4fu-tqaaa-aaaab-qadjq-cai");
    let mockAmount : Nat64 = 100_000_000;

    await test("random threshold is not null", func() : async() {

        let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

        // add 100 ICP
        for(i in Iter.range(0, 99)){
            ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
                staker = mockPrincipal;
                amount_e8s = mockAmount;
            }));
        };

        let randomThreshold = await Prize.generateRandomThreshold(Stats.getTotalStakeAmount(_mockOperationHistory));

        expect.option(randomThreshold, Nat64.toText, Nat64.equal).isSome();
    });

    await test("random threshold is within range (10 ICP)", func() : async() {
        let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

        // add 10 ICP
        for(i in Iter.range(0, 9)){
            ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
                staker = mockPrincipal;
                amount_e8s = mockAmount;
            }));
        };

        let ?randomThreshold = await Prize.generateRandomThreshold(Stats.getTotalStakeAmount(_mockOperationHistory)) else {
            return ()
        };

        expect.nat64(randomThreshold).lessOrEqual(10_00_000_000);
        Debug.print(debug_show (randomThreshold / 1_00_000_000) # " ICP");
    });

    await test("random threshold is within range (1,000 ICP)", func() : async() {
        let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

        // add 1000 ICP
        for(i in Iter.range(0, 999)){
            ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
                staker = mockPrincipal;
                amount_e8s = mockAmount;
            }));
        };

        let ?randomThreshold = await Prize.generateRandomThreshold(Stats.getTotalStakeAmount(_mockOperationHistory)) else {
            return ()
        };

        expect.nat64(randomThreshold).lessOrEqual(1000_00_000_000);
        Debug.print(debug_show (randomThreshold / 1_00_000_000) # " ICP");
    });

    await test("random threshold is within range (100,000 ICP)", func() : async() {
        let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

        // add 100,000 ICP
        for(i in Iter.range(0, 99999)){
            ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
                staker = mockPrincipal;
                amount_e8s = mockAmount;
            }));
        };

        let ?randomThreshold = await Prize.generateRandomThreshold(Stats.getTotalStakeAmount(_mockOperationHistory)) else {
            return ()
        };

        expect.nat64(randomThreshold).lessOrEqual(100_000_00_000_000);
        Debug.print(debug_show (randomThreshold / 1_00_000_000) # " ICP");
    });
});

await suite("test weighted selection algorithm", func() : async() {
    
    let mockPrincipalsAndAmounts : [(Text, Nat64)] = [
        ("r6gcn-ysbbb-cccac-zlekr-hai", 100_000_000),
        ("2jcrw-waddd-ddded-vmpft-oai", 100_000_000),
        ("q4tvz-2zeaa-aaafg-fnjqr-nai", 100_000_000),
        ("l5p4m-l2ggg-hhhbh-slrjq-pai", 100_000_000),
        ("mdi57-tdhhh-iiiic-gdpkq-wai", 100_000_000),
        ("yy6u5-sbejj-jjjjd-bwclq-lai", 100_000_000),
        ("kobwd-kkkkk-kkkke-xzfjq-zai", 100_000_000),
        ("hps3k-y7uuu-llllf-nhmrq-gai", 100_000_000),
        ("7ttao-7gvvv-mmmmg-rbnpq-bai", 100_000_000),
        ("f43vs-djwww-wnnnh-tjqkq-yai", 100_000_000),
    ];

    await test("weighted selection chooses the correct winner (10 ICP)", func() : async() {
        let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

        for((mockPrincipal, mockAmount) in mockPrincipalsAndAmounts.vals()){
            ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
                staker = Principal.fromText(mockPrincipal);
                amount_e8s = mockAmount;
            }));
        };

        let ?randomThreshold = await Prize.generateRandomThreshold(Stats.getTotalStakeAmount(_mockOperationHistory)) else {
            return ()
        };

        let winner = Prize.weightedSelection(_mockOperationHistory, randomThreshold);
        expect.option(winner, Principal.toText, Principal.equal).isSome();

        // expect the winner picked to be correct
        var runningSum : Nat64 = 0;
        label lo for((mockPrincipal, mockAmount) in mockPrincipalsAndAmounts.vals()){
            runningSum += mockAmount;

            if (runningSum >= randomThreshold) {
                expect.option(winner, Principal.toText, Principal.equal).equal(?Principal.fromText(mockPrincipal));
                break lo;
            };
        };
    });

    await test("weighted selection chooses the correct winner (100,000 ICP)", func() : async() {
        let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

        // add 100,000 ICP
        for(i in Iter.range(0, 9999)){
            for((mockPrincipal, mockAmount) in mockPrincipalsAndAmounts.vals()){
                ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
                    staker = Principal.fromText(mockPrincipal);
                    amount_e8s = mockAmount;
                }));
            };
        };

        let ?randomThreshold = await Prize.generateRandomThreshold(Stats.getTotalStakeAmount(_mockOperationHistory)) else {
            return ()
        };

        let winner = Prize.weightedSelection(_mockOperationHistory, randomThreshold);
        expect.option(winner, Principal.toText, Principal.equal).isSome();

        // expect the winner picked to be correct
        var runningSum : Nat64 = 0;
        label lo for((mockPrincipal, mockAmount) in Stats.getCurrentStakers(_mockOperationHistory).vals()){
            runningSum += mockAmount;

            if (runningSum >= randomThreshold) {
                Debug.print("Random threshold: " # debug_show (randomThreshold / 1_00_000_000) # " ICP");
                Debug.print("Winner: " # debug_show mockPrincipal);
                expect.option(winner, Principal.toText, Principal.equal).equal(?mockPrincipal);
                break lo;
            };
        };
    });
});