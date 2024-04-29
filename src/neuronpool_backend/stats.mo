import Operations "./operations";
import Map "mo:map/Map";
import Vector "mo:vector";
import T "./types";

module {

    public func getTotalStakeAmount(history : T.OperationHistory) : Nat64 {
        var sum : Nat64 = 0;
        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#StakeTransfer(args)) {
                    sum += args.amount_e8s;
                };
                case (#StakeWithdrawal(args)) {
                    sum -= args.amount_e8s;
                };
                case _ { /* do nothing */ };
            };
        };

        return sum;
    };

    public func getCurrentStakers(history : T.OperationHistory) : [(Principal, Nat64)] {
        let stakers = Map.new<Principal, Nat64>();

        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#StakeTransfer(args)) {
                    let balance = Operations.stakerBalance(history, args.staker);

                    if (balance > 0) {
                        Map.set(stakers, Map.phash, args.staker, balance);
                    };
                };
                case _ { /* do nothing */ };
            };
        };

        return Map.toArray(stakers);
    };

};
