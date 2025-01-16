import T "./types";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Vector "mo:vector";
import Map "mo:map/Map";
import VectorClass "mo:vector/Class";
import Debug "mo:base/Debug";

module {

    public func logOperation(history : T.OperationHistory, action : T.Action) : T.OperationIndex {
        Vector.add(
            history,
            {
                action = action;
                timestamp_nanos = getNowNanos();
            },
        );

        return Vector.size(history);
    };

    public func getNowNanos() : Nat64 {
        return Time.now() |> Int.abs(_) |> Nat64.fromNat(_);
    };

    public func mainNeuronId(history : T.OperationHistory) : T.NeuronId {
        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#CreateNeuron { neuron_id }) {
                    return neuron_id;
                };
                case _ {};
            };
        };

        Debug.trap("Main neuron ID not found");
    };

    public func assertMainNeuronStaked(history : T.OperationHistory) : Bool {
        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#CreateNeuron { neuron_id }) {
                    return true;
                };
                case _ {};
            };
        };

        return false;
    };

    public func stakerBalance(history : T.OperationHistory, caller : Principal) : Nat64 {
        var sum : Nat64 = 0;
        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#StakeTransfer(args)) {
                    if (Principal.equal(caller, args.staker)) {
                        sum += args.amount_e8s;
                    };
                };
                case (#StakeWithdrawal(args)) {
                    if (Principal.equal(caller, args.staker)) {
                        sum -= args.amount_e8s + args.blockchain_fee;
                    };
                };
                case _ { /* do nothing */ };
            };
        };

        return sum;
    };

    public func getStakerWithdrawalNeurons(history : T.OperationHistory, caller : Principal) : [T.NeuronId] {
        let filtered = VectorClass.Vector<T.NeuronId>();

        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#StakeWithdrawal(args)) {
                    if (Principal.equal(caller, args.staker)) {
                        filtered.add(args.neuron_id);
                    };
                };
                case _ { /* do nothing */ };
            };
        };

        return VectorClass.toArray(filtered);
    };

    public func getStakerPrizeNeurons(history : T.OperationHistory, caller : Principal) : [T.NeuronId] {
        let filtered = VectorClass.Vector<T.NeuronId>();

        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#SpawnReward(args)) {
                    if (Principal.equal(caller, args.winner)) {
                        filtered.add(args.neuron_id);
                    };
                };
                case _ { /* do nothing */ };
            };
        };

        return VectorClass.toArray(filtered);
    };

    public func getStakerClaimedPrizeNeurons(history : T.OperationHistory, caller : Principal) : [T.DisburseReward] {
        let filtered = VectorClass.Vector<T.DisburseReward>();

        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#DisburseReward(args)) {
                    if (Principal.equal(caller, args.winner)) {
                        filtered.add(args);
                    };
                };
                case _ { /* do nothing */ };
            };
        };

        return VectorClass.toArray(filtered);
    };

    public func assertCallerOwnsNeuron(history : T.OperationHistory, caller : Principal, neuronId : T.NeuronId) : Bool {
        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#StakeWithdrawal(args)) {
                    if (Principal.equal(caller, args.staker) and Nat64.equal(neuronId, args.neuron_id)) {
                        return true;
                    };
                };
                case _ { /* do nothing */ };
            };
        };

        return false;
    };

    public func assertCallerWonPrize(history : T.OperationHistory, caller : Principal, neuronId : T.NeuronId) : Bool {
        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#SpawnReward(args)) {
                    if (Principal.equal(caller, args.winner) and Nat64.equal(neuronId, args.neuron_id)) {
                        return true;
                    };
                };
                case _ { /* do nothing */ };
            };
        };

        return false;
    };

    public func getOperationHistory(history : T.OperationHistory, start : Nat, length : Nat) : T.HistoryResult {
        let total = Vector.size(history);
        // if less entries available than requested length use that
        let realLength = Nat.min(length, if (start > total) 0 else total - start);

        let operations = Array.tabulate<?T.Operation>(
            realLength,
            func(i) {
                let index = start + i;
                return Vector.getOpt(history, index);
            },
        );

        return #ok({ total; operations });
    };

    public func getLatestRewardTimer(history : T.OperationHistory) : ?T.RewardTimer {
        for (op in Vector.valsRev(history)) {
            switch (op.action) {
                case (#RewardTimer(args)) {
                    return ?args;
                };
                case _ { /* do nothing */ };
            };
        };

        return null;
    };

    // This function calculates the total stake amount of users who transferred in to the neuron.
    // It is used to determine the total deposits, which is necessary for selecting a winner for the reward.
    public func getTotalStakeDeposits(history : T.OperationHistory) : Nat64 {
        var sum : Nat64 = 0;
        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#StakeTransfer(args)) {
                    sum += args.amount_e8s;
                };
                case (#StakeWithdrawal(args)) {
                    sum -= args.amount_e8s + args.blockchain_fee;
                };
                case _ { /* do nothing */ };
            };
        };

        return sum;
    };

    // This function calculates the real total stake amount of all the ICP in the neuron.
    // It takes into account the amount used to stake the initial neuron and any other donation amounts added.
    public func getTotalNeuronStake(history : T.OperationHistory) : Nat64 {
        var sum : Nat64 = 0;
        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#StakeTransfer(args)) {
                    sum += args.amount_e8s;
                };
                case (#StakeWithdrawal(args)) {
                    sum -= args.amount_e8s + args.blockchain_fee;
                };
                case (#CreateNeuron(args)) {
                    sum += args.amount_e8s;
                };
                case (#StakeDonation(args)) {
                    sum += args.amount_e8s;
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
                        func(_k : Principal, v : ?Nat64) : ?Nat64 {
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
                        func(_k : Principal, v : ?Nat64) : ?Nat64 {
                            // if no previous value make no changes
                            let ?previousValue = v else return null;
                            // if an existing previous value, decrement
                            return ?(previousValue - (args.amount_e8s + args.blockchain_fee));
                        },
                    );
                };
                case _ { /* do nothing */ };
            };
        };

        return Map.filter(stakers, Map.phash, func(_k : Principal, v : Nat64) : Bool { return v > 0 }) |> Map.toArray(_);
    };

    public func getTotalProtocolFees(history : T.OperationHistory) : Nat64 {
        var sum : Nat64 = 0;
        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#DisburseReward(args)) {
                    sum += args.protocol_fee;
                };
                case _ { /* do nothing */ };
            };
        };

        return sum;
    };

    public func getRewardDistributions(history : T.OperationHistory) : [T.Operation] {
        let filtered = VectorClass.Vector<T.Operation>();

        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#SpawnReward _) {
                    filtered.add(op); // we want the time stamp too
                };
                case _ { /* do nothing */ };
            };
        };

        return VectorClass.toArray(filtered);
    };

    public func getStakerHistory(history : T.OperationHistory, caller : Principal) : [T.Operation] {
        let filtered = VectorClass.Vector<T.Operation>();

        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#StakeTransfer(args)) {
                    if (Principal.equal(caller, args.staker)) {
                        filtered.add(op); // we want the time stamp too
                    };
                };
                case (#StakeWithdrawal(args)) {
                    if (Principal.equal(caller, args.staker)) {
                        filtered.add(op);
                    };
                };
                case (#SpawnReward(args)) {
                    if (Principal.equal(caller, args.winner)) {
                        filtered.add(op);
                    };
                };
                case (#DisburseReward(args)) {
                    if (Principal.equal(caller, args.winner)) {
                        filtered.add(op);
                    };
                };
                case _ { /* do nothing */ };
            };
        };

        return VectorClass.toArray(filtered);
    };

};
