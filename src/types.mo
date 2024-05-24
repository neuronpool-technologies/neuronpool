import Result "mo:base/Result";
import Vector "mo:vector";
import NeuroTypes "mo:neuro/types";

module {

    public type Result<X, Y> = Result.Result<X, Y>;

    public type CanisterAccountsResult = Result<CanisterAccounts, ()>;

    public type OperationResponse = Result<OperationIndex, Text>;

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
        #CreateNeuron : CreateNeuron;
        #RewardTimer : RewardTimer;
        #Error : Error;
    };

    public type StakeTransfer = {
        staker : Principal;
        amount_e8s : Nat64;
        blockchain_fee : Nat64;
        // royalty_fee : ?RoyaltyFee;
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
        protocol_maturity_fee_e8s : Nat64;
    };

    public type RewardTimer = {
        timer_id : Nat;
        timer_duration_nanos : Nat64;
    };

    public type Error = {
        function : Text;
        message : Text;
    };

    // public type RoyaltyFee = {
    //     address : Text;
    //     fee_e8s : Nat64;
    // };

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
        operations : [?Operation]
    };

};
