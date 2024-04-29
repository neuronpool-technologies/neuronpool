import Result "mo:base/Result";
import Vector "mo:vector";
import IcpGovernanceInterface "interfaces/governance_interface";

module {

    public type Result<X, Y> = Result.Result<X, Y>;

    public type CanisterAccountsResult = Result<CanisterAccounts, ()>;

    public type MainNeuronInfoResult = Result<IcpGovernanceInterface.NeuronInfo, Text>;

    public type MainNeuronResult = Result<IcpGovernanceInterface.Neuron, Text>;

    public type OperationResponse = Result<OperationIndex, Text>;

    public type ConfigurationResponse = Result<(), Text>;

    public type NeuronId = Nat64;

    public type OperationIndex = Nat;

    public type OperationHistory = Vector.Vector<Operation>;

    public type Operation = {
        action : Action;
        timestamp : Nat64;
    };

    public type Action = {
        #StakeTransfer : StakeTransfer;
        #StakeWithdrawal : StakeWithdrawal;
        #SpawnReward : SpawnReward;
        #CreateNeuron : CreateNeuron;
        #Error : Error;
    };

    public type StakeTransfer = {
        staker : Principal;
        amount_e8s : Nat64;
    };

    public type StakeWithdrawal = {
        staker : Principal;
        amount_e8s : Nat64;
        neuron_id : NeuronId;
    };

    public type SpawnReward = {
        winner : Principal;
        neuron_id : NeuronId;
    };

    public type Error = {
        function : Text;
        message : Text;
    };

    public type CreateNeuron = {
        neuron_id : Nat64;
    };

    public type CanisterAccounts = {
        account_identifier : Text;
        icrc1_identifier : Text;
        balance : Nat;
    };

};
