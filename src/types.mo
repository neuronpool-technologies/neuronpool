import Result "mo:base/Result";
import Vector "mo:vector";
import NeuroTypes "mo:neuro/types";

module {

    public type Result<X, Y> = Result.Result<X, Y>;

    public type ProtocolInformationResult = Result<ProtocolInformation, ()>;

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

    public type History = {
        total : Nat;
        operations : [?Operation];
    };

    public type ProtocolInformation = {
        account_identifier : Text;
        icrc_identifier : Text;
        minimum_stake : Nat64;
        minimum_withdrawal : Nat64;
        protocol_fee_percentage : Nat64;
        reward_timer_duration_nanos : Nat64;
        default_neuron_followee : NeuronId;
        main_neuron_dissolve_seconds : Nat32;
        total_protocol_fees : Nat64;
        total_stake_amount : Nat64;
        total_stakers : Nat;
    };

    public type StakerPrizeNeurons = {
        claimed : [DisburseReward];
        all_prize_neurons : [NeuronId];
    };
};
