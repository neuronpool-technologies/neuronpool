import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat64 "mo:base/Nat64";
import Timer "mo:base/Timer";
import Prize "./prize";
import Operations "./operations";
import T "./types";
import Hex "mo:encoding/Hex";
import Vector "mo:vector";
import AccountIdentifier "mo:account-identifier";
import IcpLedgerInterface "mo:neuro/interfaces/icp_ledger_interface";
import IcpGovernanceInterface "mo:neuro/interfaces/nns_interface";
import NeuroTypes "mo:neuro/types";
import { NNS } "mo:neuro";

shared ({ caller = owner }) actor class NeuronPool() = thisCanister {

    /////////////////
    /// Constants ///
    /////////////////

    // ICP ledger canister
    let IcpLedger = actor "ryjl3-tyaaa-aaaaa-aaaba-cai" : IcpLedgerInterface.Self;

    // ICP governance canister
    let IcpGovernance = actor "rrkah-fqaaa-aaaaa-aaaaq-cai" : IcpGovernanceInterface.Self;

    // The standard ICP transaction fee
    let ICP_PROTOCOL_FEE : Nat64 = 10_000;

    // 1 ICP in e8s
    let ONE_ICP : Nat64 = 100_000_000;

    // 0.1 ICP in e8s
    let MINIMUM_STAKE : Nat64 = 10_000_000;

    // 1.06 ICP in e8s
    let MINIMUM_SPAWN : Nat64 = 106_000_000;

    // The refresh rate of checking if rewards are ready to spawn
    let SPAWN_REWARD_TIMER_DURATION_NANOS : Nat64 = (24 * 60 * 60 * 1_000_000_000); // 24 hours

    // The canister controlled neuron will follow this neuron on all votes
    let DEFAULT_NEURON_FOLLOWEE : T.NeuronId = 6914974521667616512; // Rakeoff.io named neuron

    // The dissolve delay for the main. Also inherited by all split neurons
    let NEURON_DISSOLVE_DELAY_SECONDS : Nat32 = 15897600; // 184 days

    // If this limit is reached we don't allow any more stakeTransfers
    // All other operations are allowed to continue
    let OPERATION_HISTORY_LIMIT : Nat = 100_000;

    // The fee paid to the smart contract (held as maturity)
    let PROTOCOL_FEE_PERCENTAGE : Nat64 = 3;

    //////////////////////
    /// Canister State ///
    //////////////////////

    stable let _operationHistory : T.OperationHistory = Vector.new<T.Operation>();

    /////////////////////////////
    /// User Public Functions ///
    /////////////////////////////

    public shared ({ caller }) func initiate_icp_stake_transfer() : async T.OperationResponse {
        assert (Principal.isAnonymous(caller) == false);
        return await initiateIcpStakeTransfer(caller);
    };

    public shared ({ caller }) func initiate_icp_stake_withdrawal({
        amount_e8s : Nat64;
    }) : async T.OperationResponse {
        assert (Principal.isAnonymous(caller) == false);
        return await initiateIcpStakeWithdrawal(caller, amount_e8s);
    };

    public shared ({ caller }) func process_icp_stake_dissolve({
        neuronId : T.NeuronId;
    }) : async NeuroTypes.ConfigureResult {
        assert (Principal.isAnonymous(caller) == false);
        return await processIcpStakeDissolve(caller, neuronId);
    };

    public shared ({ caller }) func process_icp_stake_disburse({
        neuronId : T.NeuronId;
    }) : async NeuroTypes.ConfigureResult {
        assert (Principal.isAnonymous(caller) == false);
        return await processIcpStakeDisburse(caller, neuronId);
    };

    public shared query ({ caller }) func get_staker_balance() : async Nat64 {
        assert (Principal.isAnonymous(caller) == false);
        return Operations.stakerBalance(_operationHistory, caller);
    };

    public shared query ({ caller }) func get_staker_withdrawal_neurons() : async [T.NeuronId] {
        assert (Principal.isAnonymous(caller) == false);
        return Operations.getStakerWithdrawalNeurons(_operationHistory, caller);
    };

    ///////////////////////////////////
    /// Controller Public Functions ///
    ///////////////////////////////////

    public shared ({ caller }) func controller_stake_main_neuron({
        amount_e8s : Nat64;
    }) : async T.OperationResponse {
        assert (caller == owner);
        return await stakeMainNeuron(amount_e8s);
    };

    public shared ({ caller }) func controller_set_main_neuron_dissolve_delay() : async NeuroTypes.ConfigureResult {
        assert (caller == owner);
        return await setMainNeuronDissolveDelay();
    };

    public shared ({ caller }) func controller_set_main_neuron_following({
        topic : Int32;
    }) : async NeuroTypes.ConfigureResult {
        assert (caller == owner);
        return await setMainNeuronFollowing(topic);
    };

    public shared ({ caller }) func controller_set_spawn_reward_timer() : async T.OperationResponse {
        assert (caller == owner);
        return setSpawnRewardTimer<system>();
    };

    ////////////////////////////////////
    /// Information Public Functions ///
    ////////////////////////////////////

    public func get_canister_accounts() : async T.CanisterAccountsResult {
        return await getCanisterAccounts();
    };

    public query func get_operation_history({ start : Nat; length : Nat }) : async T.HistoryResult {
        return Operations.getOperationHistory(_operationHistory, start, length);
    };

    public query func get_minimum_stake() : async Nat64 {
        return MINIMUM_STAKE + ICP_PROTOCOL_FEE;
    };

    public query func get_minimum_withdrawal() : async Nat64 {
        return ONE_ICP + ICP_PROTOCOL_FEE;
    };

    public func get_main_neuron() : async NeuroTypes.NnsInformationResult {
        return await getMainNeuron();
    };

    //////////////////////////////
    /// User Private Functions ///
    //////////////////////////////

    private func initiateIcpStakeTransfer(caller : Principal) : async T.OperationResponse {
        if (Vector.size(_operationHistory) >= OPERATION_HISTORY_LIMIT) {
            return #err("The operation history has reached its limit of " # debug_show OPERATION_HISTORY_LIMIT # " No additional stake transfers can be processed at this time.");
        };

        let { allowance } = await IcpLedger.icrc2_allowance({
            account = { owner = caller; subaccount = null };
            spender = {
                owner = Principal.fromActor(thisCanister);
                subaccount = null;
            };
        });

        if (Nat64.fromNat(allowance) < MINIMUM_STAKE + ICP_PROTOCOL_FEE) return #err("A minimum of 0.1001 ICP is needed");

        let amountToStake = Nat64.fromNat(allowance) - ICP_PROTOCOL_FEE; // allowance >= amount + fee

        switch (await getMainNeuron()) {
            case (#ok { account }) {
                // TODO may need to refresh neuron
                let transferResult = await IcpLedger.icrc2_transfer_from({
                    to = {
                        owner = Principal.fromActor(IcpGovernance); // NNS canister
                        subaccount = ?Blob.fromArray(account); // neuron account
                    };
                    from = { owner = caller; subaccount = null };
                    spender_subaccount = null;
                    fee = null;
                    memo = null;
                    created_at_time = null;
                    amount = Nat64.toNat(amountToStake);
                });

                switch (transferResult) {
                    case (#Ok _) {
                        return #ok(
                            Operations.logOperation(
                                _operationHistory,
                                #StakeTransfer({
                                    staker = caller;
                                    amount_e8s = amountToStake;
                                    blockchain_fee = ICP_PROTOCOL_FEE;
                                }),
                            )
                        );
                    };
                    case (#Err error) {
                        return #err(debug_show error);
                    };
                };
            };
            case (#err error) {
                return #err(debug_show error);
            };
        };
    };

    private func initiateIcpStakeWithdrawal(caller : Principal, amount_e8s : Nat64) : async T.OperationResponse {
        if (amount_e8s < ONE_ICP + ICP_PROTOCOL_FEE) return #err("Insufficient amount to withdraw: " # debug_show amount_e8s # ". A minimum of 1.0001 ICP is needed.");

        let balance = Operations.stakerBalance(_operationHistory, caller);

        if (balance >= amount_e8s) {
            let neuron = NNS.Neuron({
                nns_canister_id = Principal.fromActor(IcpGovernance);
                neuron_id = Operations.mainNeuronId(_operationHistory);
            });

            switch (await neuron.split({ amount_e8s = amount_e8s })) {
                case (#ok createdNeuronId) {
                    return #ok(
                        Operations.logOperation(
                            _operationHistory,
                            #StakeWithdrawal({
                                staker = caller;
                                amount_e8s = amount_e8s;
                                neuron_id = createdNeuronId;
                                blockchain_fee = ICP_PROTOCOL_FEE;
                            }),
                        )
                    );
                };
                case (#err error) {
                    return #err("Failed to split new neuron. " # debug_show error);
                };
            };
        } else {
            return #err("Insufficient balance for caller: " # debug_show caller # ". Balance: " # debug_show balance);
        };
    };

    private func processIcpStakeDissolve(caller : Principal, neuronId : T.NeuronId) : async NeuroTypes.ConfigureResult {
        if (Operations.assertCallerOwnsNeuron(_operationHistory, caller, neuronId) == false) return #err("Failed to find neuron Id for caller: " # debug_show neuronId);

        let neuron = NNS.Neuron({
            nns_canister_id = Principal.fromActor(IcpGovernance);
            neuron_id = neuronId;
        });

        return await neuron.startDissolving();
    };

    private func processIcpStakeDisburse(caller : Principal, neuronId : T.NeuronId) : async NeuroTypes.ConfigureResult {
        if (Operations.assertCallerOwnsNeuron(_operationHistory, caller, neuronId) == false) return #err("Failed to find neuron Id for caller: " # debug_show neuronId);

        let neuron = NNS.Neuron({
            nns_canister_id = Principal.fromActor(IcpGovernance);
            neuron_id = neuronId;
        });

        return await neuron.disburse({
            to_account = AccountIdentifier.accountIdentifier(caller, AccountIdentifier.defaultSubaccount()) |> Blob.toArray(_);
        });
    };

    ////////////////////////////////////
    /// Controller Private Functions ///
    ////////////////////////////////////

    private func stakeMainNeuron(amount_e8s : Nat64) : async T.OperationResponse {
        if (Operations.mainNeuronId(_operationHistory) > 0) return #err("Main neuron has already been staked");

        let nns = NNS.Governance({
            canister_id = Principal.fromActor(thisCanister);
            nns_canister_id = Principal.fromActor(IcpGovernance);
            icp_ledger_canister_id = Principal.fromActor(IcpLedger);
        });

        switch (await nns.stake({ amount_e8s = amount_e8s })) {
            case (#ok neuronId) {
                // store the staked neuron in the log
                return #ok(Operations.logOperation(_operationHistory, #CreateNeuron({ neuron_id = neuronId; token = "ICP" })));
            };
            case (#err error) {
                return #err(error);
            };
        };
    };

    private func setMainNeuronDissolveDelay() : async NeuroTypes.ConfigureResult {
        switch (await getMainNeuron()) {
            case (#ok { dissolve_delay_seconds }) {
                if (dissolve_delay_seconds > 0) return #err("Dissolve delay already set");

                let neuron = NNS.Neuron({
                    nns_canister_id = Principal.fromActor(IcpGovernance);
                    neuron_id = Operations.mainNeuronId(_operationHistory);
                });

                return await neuron.increaseDissolveDelay({
                    additional_dissolve_delay_seconds = NEURON_DISSOLVE_DELAY_SECONDS;
                });
            };
            case (#err error) {
                return #err(debug_show error);
            };
        };
    };

    private func setMainNeuronFollowing(topic : Int32) : async NeuroTypes.ConfigureResult {
        let neuron = NNS.Neuron({
            nns_canister_id = Principal.fromActor(IcpGovernance);
            neuron_id = Operations.mainNeuronId(_operationHistory);
        });

        return await neuron.follow({
            topic = topic;
            followee = DEFAULT_NEURON_FOLLOWEE;
        });
    };

    //////////////////////////////////
    /// Canister Private Functions ///
    //////////////////////////////////

    private func getMainNeuron() : async NeuroTypes.NnsInformationResult {
        let neuron = NNS.Neuron({
            nns_canister_id = Principal.fromActor(IcpGovernance);
            neuron_id = Operations.mainNeuronId(_operationHistory);
        });

        return await neuron.getInformation();
    };

    // TODO Check over the flow here and calculations
    // some helper functions may be needed to seperate logic
    private func spawnPrizeReward() : async () {
        let { total_maturity; available_maturity; protocol_fee } = await checkAvailableMaturity();

        if (available_maturity < MINIMUM_SPAWN) {
            return ignore Operations.logOperation(_operationHistory, #Error({ function = "spawnRandomReward()"; message = "Insufficient available maturity to spawn reward" }));
        };

        // Calculate total stake amount for generating random threshold
        let totalAmount = Operations.getTotalStakeAmount(_operationHistory);

        let ?randomNumber = await Prize.generateRandomThreshold(totalAmount) else {
            return ignore Operations.logOperation(_operationHistory, #Error({ function = "spawnRandomReward()"; message = "Failed to generate random threshold" }));
        };

        let ?winner = Prize.weightedSelection(_operationHistory, randomNumber) else {
            return ignore Operations.logOperation(_operationHistory, #Error({ function = "spawnRandomReward()"; message = "Failed to find a winner" }));
        };

        // the neuron is controlled by the winner
        // so it won't appear as part of the canister controlled neurons
        let neuron = NNS.Neuron({
            nns_canister_id = Principal.fromActor(IcpGovernance);
            neuron_id = Operations.mainNeuronId(_operationHistory);
        });

        switch (await neuron.spawn({ new_controller = ?winner; percentage_to_spawn = ?Nat64.toNat32((available_maturity * 100) / total_maturity) })) {
            case (#ok createdNeuronId) {
                // store the staked neuron in the log
                return ignore Operations.logOperation(_operationHistory, #SpawnReward({ winner = winner; neuron_id = createdNeuronId; protocol_maturity_fee_e8s = protocol_fee }));
            };
            case (#err error) {
                return ignore Operations.logOperation(_operationHistory, #Error({ function = "spawnRandomReward()"; message = "Failed to spawn. " # debug_show error }));
            };
        };
    };

    private func checkAvailableMaturity() : async {
        total_maturity : Nat64;
        available_maturity : Nat64;
        protocol_fee : Nat64;
    } {
        switch (await getMainNeuron()) {
            case (#ok { maturity_e8s_equivalent }) {
                let nonFeeMaturity = maturity_e8s_equivalent - Operations.getTotalProtocolFees(_operationHistory);

                let thisRoundsFee = (nonFeeMaturity * PROTOCOL_FEE_PERCENTAGE) / 100;

                return {
                    total_maturity = maturity_e8s_equivalent;
                    available_maturity = nonFeeMaturity - thisRoundsFee; // this needs to be greater than 1.06 to spawn
                    protocol_fee = thisRoundsFee;
                };
            };
            case (#err _) {
                return {
                    total_maturity = 0;
                    available_maturity = 0;
                    protocol_fee = 0;
                };
            };
        };
    };

    private func setSpawnRewardTimer<system>() : T.OperationResponse {
        let oldTimer = Operations.getLatestRewardTimer(_operationHistory);

        // safety cancel
        switch (oldTimer) {
            case (?{ timer_id }) { Timer.cancelTimer(timer_id) };
            case _ {};
        };

        let newTimerId = Timer.recurringTimer<system>(
            #nanoseconds(Nat64.toNat(SPAWN_REWARD_TIMER_DURATION_NANOS)),
            spawnPrizeReward,
        );

        return #ok(Operations.logOperation(_operationHistory, #RewardTimer({ timer_id = newTimerId; timer_duration_nanos = SPAWN_REWARD_TIMER_DURATION_NANOS })));
    };

    //////////////////////////////////////////////
    /// Protocol Information Private Functions ///
    //////////////////////////////////////////////

    private func getCanisterAccounts() : async T.CanisterAccountsResult {
        return #ok({
            account_identifier = Principal.fromActor(thisCanister) |> AccountIdentifier.accountIdentifier(_, AccountIdentifier.defaultSubaccount()) |> Blob.toArray(_) |> Hex.encode(_);
            icrc1_identifier = Principal.fromActor(thisCanister) |> Principal.toText(_);
            balance = await IcpLedger.icrc1_balance_of({
                owner = Principal.fromActor(thisCanister);
                subaccount = null;
            });
        });
    };

};
