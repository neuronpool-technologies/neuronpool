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
                    ignore Map.update(
                        stakers,
                        Map.phash,
                        args.staker,
                        func(k : Principal, v : ?Nat64) : ?Nat64 {
                            let ?previousValue = v else return ?args.amount_e8s;
                            // if an existing previous value, increment
                            return ?(previousValue + args.amount_e8s);
                        },
                    );
                };
                case (#StakeWithdrawal(args)) {
                    ignore Map.update(
                        stakers,
                        Map.phash,
                        args.staker,
                        func(k : Principal, v : ?Nat64) : ?Nat64 {
                            // if no previous value make no changes
                            let ?previousValue = v else return null;
                            // if an existing previous value, decrement
                            return ?(previousValue - args.amount_e8s);
                        },
                    );
                };
                case _ { /* do nothing */ };
            };
        };

        return Map.filter(stakers, Map.phash, func(k : Principal, v : Nat64) : Bool { return v > 0 }) |> Map.toArray(_);
    };
};
