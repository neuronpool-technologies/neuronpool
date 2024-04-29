import T "./types";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Vector "mo:vector";
import VectorClass "mo:vector/Class";

module {

    public func logOperation(history : T.OperationHistory, action : T.Action) : T.OperationIndex {
        Vector.add(
            history,
            {
                action = action;
                timestamp = Time.now() |> Int.abs(_) |> Nat64.fromNat(_);
            },
        );

        return Vector.size(history);
    };

    public func mainNeuronId(history : T.OperationHistory) : ?T.NeuronId {
        for (op in Vector.vals(history)) {
            switch (op.action) {
                case (#CreateNeuron { neuron_id }) {
                    return ?neuron_id;
                };
                case _ {
                    return null;
                };
            };
        };

        return null;
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
                        sum -= args.amount_e8s;
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

    public func assertCallerOwnsNeuron(history : T.OperationHistory,caller : Principal, neuronId : T.NeuronId) : Bool {
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

};
