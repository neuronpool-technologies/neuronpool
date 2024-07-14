import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat64 "mo:base/Nat64";
import Timer "mo:base/Timer";
import Prize "./prize";
import Operations "./operations";
import T "./types";
import Hex "mo:encoding/Hex";
import Vector "mo:vector";
import Map "mo:map/Map";
import AccountIdentifier "mo:account-identifier";
import IcpLedgerInterface "mo:neuro/interfaces/icp_ledger_interface";
import IcpGovernanceInterface "mo:neuro/interfaces/nns_interface";
import NeuroTypes "mo:neuro/types";
import Mock "../testing/mock";
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

    // // The refresh rate of checking if rewards are ready to spawn
    let SPAWN_REWARD_TIMER_DURATION_NANOS : Nat64 = (14 * 24 * 60 * 60 * 1_000_000_000); // 14 days

    // The canister controlled neuron will follow this neuron on all votes
    let DEFAULT_NEURON_FOLLOWEE : T.NeuronId = 6914974521667616512; // Rakeoff.io named neuron

    // The dissolve delay for the main neuron. Also inherited by all split neurons
    let NEURON_DISSOLVE_DELAY_SECONDS : Nat32 = 15897600; // 184 days

    // Once this limit is reached, no further stake transfers will be allowed,
    // though all other operations can continue without interruption.
    // Testing has shown that the system can handle over 1,000,000 entries without issues.
    // Each 100,000 entries consumes approximately 10MB of heap memory.
    // The heap can theoretically reach up to 1-2 GB without problems, with protocol-level plans to increase this.
    // We chose the 500,000 limit to monitor the system's performance and adjust as necessary.
    // Given typical usage patterns, it may take years to reach 500,000 entries.
    // Scaling solutions include increasing this threshold or adding more canisters.
    let OPERATION_HISTORY_LIMIT : Nat = 500_000;

    // The fee percentage paid to the smart contract
    let PROTOCOL_FEE_PERCENTAGE : Nat64 = 10; // 10%

    //////////////////////
    /// Canister State ///
    //////////////////////

    stable let _operationHistory : T.OperationHistory = Vector.new<T.Operation>();

    stable let _ongoingStakeWithdrawals = Map.new<Principal, Nat64>();

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
    }) : async T.ConfigureResponse {
        assert (Principal.isAnonymous(caller) == false);
        return await processIcpStakeDissolve(caller, neuronId);
    };

    public shared ({ caller }) func process_icp_stake_disburse({
        neuronId : T.NeuronId;
    }) : async T.ConfigureResponse {
        assert (Principal.isAnonymous(caller) == false);
        return await processIcpStakeDisburse(caller, neuronId);
    };

    public shared ({ caller }) func process_icp_prize_disburse({
        neuronId : T.NeuronId;
    }) : async T.OperationResponse {
        assert (Principal.isAnonymous(caller) == false);
        return await processIcpPrizeDisburse(caller, neuronId);
    };

    public shared query ({ caller }) func get_staker_balance() : async Nat64 {
        assert (Principal.isAnonymous(caller) == false);
        return Operations.stakerBalance(_operationHistory, caller);
    };

    public shared query ({ caller }) func get_staker_withdrawal_neurons() : async [T.NeuronId] {
        assert (Principal.isAnonymous(caller) == false);
        return Operations.getStakerWithdrawalNeurons(_operationHistory, caller);
    };

    public shared query ({ caller }) func get_staker_prize_neurons() : async T.StakerPrizeNeurons {
        assert (Principal.isAnonymous(caller) == false);
        return {
            claimed = Operations.getStakerClaimedPrizeNeurons(_operationHistory, caller);
            all_prize_neurons = Operations.getStakerPrizeNeurons(_operationHistory, caller);
        };
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

    public shared ({ caller }) func controller_set_main_neuron_dissolve_delay() : async T.ConfigureResponse {
        assert (caller == owner);
        return await setMainNeuronDissolveDelay();
    };

    public shared ({ caller }) func controller_set_main_neuron_following({
        topic : Int32;
    }) : async T.ConfigureResponse {
        assert (caller == owner);
        return await setMainNeuronFollowing(topic);
    };

    // This function is currently not an ICRC2 transfer_from function.
    // The exposure of the ICP address of the main neuron allows anyone to add ICP to the main neuron, but we would have no way to reflect that in the TVL without this function.
    // Stake donations exist because we may want to boost the APY of the neuron on behalf of all real users.
    // Stake donations and the initial neuron staking amount are ignored when picking a winner to avoid affecting the running sum.
    public shared ({ caller }) func controller_add_stake_donation({
        from : ?Principal;
        amount_e8s : Nat64;
    }) : async T.OperationResponse {
        assert (caller == owner);
        return await addStakeDonation(from, amount_e8s);
    };

    public shared ({ caller }) func controller_set_spawn_reward_timer() : async T.OperationResponse {
        assert (caller == owner);
        return setSpawnRewardTimer<system>();
    };

    public shared query ({ caller }) func controller_get_canister_memory() : async Mock.HeapData {
        assert (caller == owner);
        return Mock.getCanisterHeapData(_operationHistory, _ongoingStakeWithdrawals);
    };

    ////////////////////////////////////
    /// Information Public Functions ///
    ////////////////////////////////////

    public query func get_protocol_information() : async T.ProtocolInformationResult {
        return getProtocolInformation();
    };

    public query func get_operation_history({ start : Nat; length : Nat }) : async T.HistoryResult {
        return Operations.getOperationHistory(_operationHistory, start, length);
    };

    public query func get_reward_distributions() : async [T.Operation] {
        return Operations.getRewardDistributions(_operationHistory);
    };

    public func get_neuron_information(neuronId : T.NeuronId) : async NeuroTypes.NnsInformationResult {
        return await getNeuronInformation(neuronId);
    };

    public func get_main_neuron() : async NeuroTypes.NnsInformationResult {
        return await getNeuronInformation(Operations.mainNeuronId(_operationHistory));
    };

    public func list_neuron_information({
        neuronIds : [T.NeuronId];
        readable : Bool;
    }) : async NeuroTypes.NnsListNeuronsResponse {
        return await listNeuronInformation(neuronIds, readable);
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

        switch (await getNeuronInformation(Operations.mainNeuronId(_operationHistory))) {
            case (#ok { account }) {
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
                        ignore refreshMainNeuron();
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

        if (Map.has(_ongoingStakeWithdrawals, Map.phash, caller)) {
            return #err("Stake withdrawal is already in progress for caller: " # debug_show caller);
        };

        // add the transaction to ongoing withdrawals
        Map.set(_ongoingStakeWithdrawals, Map.phash, caller, amount_e8s);

        let balance = Operations.stakerBalance(_operationHistory, caller);

        if (balance >= amount_e8s) {
            let neuron = NNS.Neuron({
                nns_canister_id = Principal.fromActor(IcpGovernance);
                neuron_id = Operations.mainNeuronId(_operationHistory);
            });

            switch (await neuron.split({ amount_e8s = amount_e8s })) {
                case (#ok createdNeuronId) {
                    ignore refreshMainNeuron();

                    // cleanup ongoing withdrawals
                    Map.delete(_ongoingStakeWithdrawals, Map.phash, caller);

                    return #ok(
                        Operations.logOperation(
                            _operationHistory,
                            #StakeWithdrawal({
                                staker = caller;
                                amount_e8s = amount_e8s - ICP_PROTOCOL_FEE;
                                neuron_id = createdNeuronId;
                                blockchain_fee = ICP_PROTOCOL_FEE;
                            }),
                        )
                    );
                };
                case (#err error) {
                    // cleanup ongoing withdrawals
                    Map.delete(_ongoingStakeWithdrawals, Map.phash, caller);
                    return #err("Failed to split new neuron. " # debug_show error);
                };
            };
        } else {
            // cleanup ongoing withdrawals
            Map.delete(_ongoingStakeWithdrawals, Map.phash, caller);
            return #err("Insufficient balance for caller: " # debug_show caller # ". Balance: " # debug_show balance);
        };
    };

    private func processIcpStakeDissolve(caller : Principal, neuronId : T.NeuronId) : async T.ConfigureResponse {
        if (Operations.assertCallerOwnsNeuron(_operationHistory, caller, neuronId) == false) return #err("Failed to find neuron Id for caller: " # debug_show neuronId);

        let neuron = NNS.Neuron({
            nns_canister_id = Principal.fromActor(IcpGovernance);
            neuron_id = neuronId;
        });

        return await neuron.startDissolving();
    };

    private func processIcpStakeDisburse(caller : Principal, neuronId : T.NeuronId) : async T.ConfigureResponse {
        if (Operations.assertCallerOwnsNeuron(_operationHistory, caller, neuronId) == false) return #err("Failed to find neuron Id for caller: " # debug_show neuronId);

        let neuron = NNS.Neuron({
            nns_canister_id = Principal.fromActor(IcpGovernance);
            neuron_id = neuronId;
        });

        return await neuron.disburse({
            to_account = ?{
                hash = AccountIdentifier.accountIdentifier(caller, AccountIdentifier.defaultSubaccount()) |> Blob.toArray(_);
            };
            amount = null;
        });
    };

    private func processIcpPrizeDisburse(caller : Principal, neuronId : T.NeuronId) : async T.OperationResponse {
        if (Operations.assertCallerWonPrize(_operationHistory, caller, neuronId) == false) return #err("Failed to find prize for caller: " # debug_show neuronId);

        let neuron = NNS.Neuron({
            nns_canister_id = Principal.fromActor(IcpGovernance);
            neuron_id = neuronId;
        });

        switch (await neuron.getInformation()) {
            case (#ok { cached_neuron_stake_e8s }) {
                if (cached_neuron_stake_e8s <= ICP_PROTOCOL_FEE) return #err("Insufficient amount to disburse");

                let protocol_fee : Nat64 = (cached_neuron_stake_e8s * PROTOCOL_FEE_PERCENTAGE) / 100;

                // disburse the protocol fee to the canister
                let disburseFeeResult = await neuron.disburse({
                    to_account = ?{
                        hash = Principal.fromActor(thisCanister) |> AccountIdentifier.accountIdentifier(_, AccountIdentifier.defaultSubaccount()) |> Blob.toArray(_);
                    };
                    amount = ?{ e8s = protocol_fee };
                });

                switch (disburseFeeResult) {
                    case (#ok _) {
                        // disburse the rest of the neuron amount to the winner
                        let disburseWinnerResult = await neuron.disburse({
                            to_account = ?{
                                hash = AccountIdentifier.accountIdentifier(caller, AccountIdentifier.defaultSubaccount()) |> Blob.toArray(_);
                            };
                            amount = null; // defaults to 100% of what's left
                        });

                        switch (disburseWinnerResult) {
                            case (#ok _) {
                                // log the disbursement if successful
                                return #ok(
                                    Operations.logOperation(
                                        _operationHistory,
                                        #DisburseReward({
                                            winner = caller;
                                            neuron_id = neuronId;
                                            amount = cached_neuron_stake_e8s - protocol_fee;
                                            protocol_fee = protocol_fee;
                                        }),
                                    )
                                );
                            };
                            case (#err _) {
                                return #err("Failed to complete neuron disbursement. Please try again");
                            };
                        };
                    };
                    case (#err _) {
                        return #err("Failed to process protocol fee. Please try again");
                    };
                };

            };
            case (#err error) {
                return #err(error);
            };
        };
    };

    ////////////////////////////////////
    /// Controller Private Functions ///
    ////////////////////////////////////

    private func stakeMainNeuron(amount_e8s : Nat64) : async T.OperationResponse {
        if (Operations.assertMainNeuronStaked(_operationHistory)) return #err("Main neuron has already been staked");

        let nns = NNS.Governance({
            canister_id = Principal.fromActor(thisCanister);
            nns_canister_id = Principal.fromActor(IcpGovernance);
            icp_ledger_canister_id = Principal.fromActor(IcpLedger);
        });

        switch (await nns.stake({ amount_e8s = amount_e8s })) {
            case (#ok neuronId) {
                // store the staked neuron in the log
                return #ok(Operations.logOperation(_operationHistory, #CreateNeuron({ neuron_id = neuronId; token = "ICP"; amount_e8s = ONE_ICP })));
            };
            case (#err error) {
                return #err(error);
            };
        };
    };

    private func setMainNeuronDissolveDelay() : async T.ConfigureResponse {
        switch (await getNeuronInformation(Operations.mainNeuronId(_operationHistory))) {
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

    private func setMainNeuronFollowing(topic : Int32) : async T.ConfigureResponse {
        let neuron = NNS.Neuron({
            nns_canister_id = Principal.fromActor(IcpGovernance);
            neuron_id = Operations.mainNeuronId(_operationHistory);
        });

        return await neuron.follow({
            topic = topic;
            followee = DEFAULT_NEURON_FOLLOWEE;
        });
    };

    private func refreshMainNeuron() : async () {
        let neuron = NNS.Neuron({
            nns_canister_id = Principal.fromActor(IcpGovernance);
            neuron_id = Operations.mainNeuronId(_operationHistory);
        });

        ignore await neuron.refresh();
    };

    //////////////////////////////////
    /// Canister Private Functions ///
    //////////////////////////////////

    private func getProtocolInformation() : T.ProtocolInformationResult {
        return #ok({
            account_identifier = Principal.fromActor(thisCanister) |> AccountIdentifier.accountIdentifier(_, AccountIdentifier.defaultSubaccount()) |> Blob.toArray(_) |> Hex.encode(_);
            icrc_identifier = Principal.fromActor(thisCanister) |> Principal.toText(_);
            minimum_stake = MINIMUM_STAKE;
            minimum_withdrawal = ONE_ICP;
            protocol_fee_percentage = PROTOCOL_FEE_PERCENTAGE;
            reward_timer_duration_nanos = SPAWN_REWARD_TIMER_DURATION_NANOS;
            default_neuron_followee = DEFAULT_NEURON_FOLLOWEE;
            main_neuron_id = Operations.mainNeuronId(_operationHistory);
            main_neuron_dissolve_seconds = NEURON_DISSOLVE_DELAY_SECONDS;
            total_protocol_fees = Operations.getTotalProtocolFees(_operationHistory);
            total_stake_amount = Operations.getTotalNeuronStake(_operationHistory);
            total_stake_deposits = Operations.getTotalStakeDeposits(_operationHistory);
            total_stakers = Operations.getCurrentStakers(_operationHistory).size();
        });
    };

    private func getNeuronInformation(neuronId : T.NeuronId) : async NeuroTypes.NnsInformationResult {
        let neuron = NNS.Neuron({
            nns_canister_id = Principal.fromActor(IcpGovernance);
            neuron_id = neuronId;
        });

        return await neuron.getInformation();
    };

    private func listNeuronInformation(neuronIds : [T.NeuronId], readable : Bool) : async NeuroTypes.NnsListNeuronsResponse {
        let nns = NNS.Governance({
            canister_id = Principal.fromActor(thisCanister);
            nns_canister_id = Principal.fromActor(IcpGovernance);
            icp_ledger_canister_id = Principal.fromActor(IcpLedger);
        });

        return await nns.listNeurons({
            neuronIds = neuronIds;
            readable = readable;
        });
    };

    private func addStakeDonation(from : ?Principal, amount_e8s : Nat64) : async T.OperationResponse {
        // Refresh the neuron to show the new balance
        ignore refreshMainNeuron();

        // Log the amount to update the TVL
        return #ok(
            Operations.logOperation(
                _operationHistory,
                #StakeDonation({
                    from = from;
                    amount_e8s = amount_e8s;
                    blockchain_fee = ICP_PROTOCOL_FEE;
                }),
            )
        );
    };

    private func spawnPrizeReward() : async () {
        switch (await getNeuronInformation(Operations.mainNeuronId(_operationHistory))) {
            case (#ok { maturity_e8s_equivalent }) {
                if (maturity_e8s_equivalent < MINIMUM_SPAWN) return;

                // Calculate total stake amount for generating random threshold
                let totalAmount = Operations.getTotalStakeDeposits(_operationHistory);

                let ?randomNumber = await Prize.generateRandomThreshold(totalAmount) else return;

                let ?winner = Prize.weightedSelection(_operationHistory, randomNumber) else return;

                // the neuron is controlled by the canister
                let neuron = NNS.Neuron({
                    nns_canister_id = Principal.fromActor(IcpGovernance);
                    neuron_id = Operations.mainNeuronId(_operationHistory);
                });

                switch (await neuron.spawn({ new_controller = null; percentage_to_spawn = null })) {
                    case (#ok createdNeuronId) {
                        // store the staked neuron in the log
                        return ignore Operations.logOperation(_operationHistory, #SpawnReward({ winner = winner; neuron_id = createdNeuronId; maturity_e8s = maturity_e8s_equivalent }));
                    };
                    case (#err error) { return };
                };

            };
            case (#err error) { return };
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

};
