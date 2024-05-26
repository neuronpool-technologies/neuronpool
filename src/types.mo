import Result "mo:base/Result";
import Vector "mo:vector";
import NeuroTypes "mo:neuro/types";

module {

    public type Result<X, Y> = Result.Result<X, Y>;

    public type CanisterAccountsResult = Result<CanisterAccounts, ()>;

    public type OperationResponse = Result<OperationIndex, Text>;

    public type ConfigureResponse = NeuroTypes.ConfigureResult;
    
    public type HistoryResult = Result<History, ()>;

    public type NeuronId = NeuroTypes.NnsNeuronId;

    public type OperationIndex = Nat;

    public type OperationHistory = Vector.Vector<Operation>;

    public type Operation = {
        action : Action;
        timestamp_nanos : Nat64;
    };

    public type Action = {
        #StakeTransfer : StakeTransfer;
        #StakeWithdrawal : StakeWithdrawal;
        #SpawnReward : SpawnReward;
        #DisburseReward : DisburseReward;
        #CreateNeuron : CreateNeuron;
        #RewardTimer : RewardTimer;
    };

    public type StakeTransfer = {
        staker : Principal;
        amount_e8s : Nat64;
        blockchain_fee : Nat64;
    };

    public type StakeWithdrawal = {
        staker : Principal;
        amount_e8s : Nat64;
        neuron_id : NeuronId;
        blockchain_fee : Nat64;
    };

    public type SpawnReward = {
        winner : Principal;
        neuron_id : NeuronId;
    };

    public type DisburseReward = {
        winner : Principal;
        neuron_id : NeuronId;
        amount : Nat64;
        protocol_fee : Nat64;
    };

    public type RewardTimer = {
        timer_id : Nat;
        timer_duration_nanos : Nat64;
    };

    public type CreateNeuron = {
        neuron_id : Nat64;
        token : Text;
    };

    public type CanisterAccounts = {
        account_identifier : Text;
        icrc1_identifier : Text;
        balance : Nat;
    };

    public type History = {
        total : Nat;
        operations : [?Operation];
    };

};
