import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Random "mo:base/Random";
import Timer "mo:base/Timer";
import Text "mo:base/Text";
import Prize "./prize";
import Stats "./stats";
import Operations "./operations";
import T "./types";
import Sha256 "mo:sha2/Sha256";
import Hex "mo:encoding/Hex";
import Binary "mo:encoding/Binary";
import Account "mo:account";
import Vector "mo:vector";
import AccountIdentifier "mo:account-identifier";
import IcpLedgerInterface "interfaces/ledger_interface";
import IcpGovernanceInterface "interfaces/governance_interface";

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

  // The refresh rate of checking if rewards are ready to spawn
  let SPAWN_REWARD_TIMER_DURATION_NANOS : Nat64 = (24 * 60 * 60 * 1_000_000_000); // 24 hours

  // 0.1 ICP in e8s
  let MINIMUM_STAKE : Nat64 = 10_000_000;

  // The canister controlled neuron will follow this neuron on all votes
  let DEFAULT_NEURON_FOLLOWEE : T.NeuronId = 6914974521667616512; // Rakeoff.io named neuron

  // The dissolve delay for the main. Also inherited by all split neurons
  let NEURON_DISSOLVE_DELAY_SECONDS : Nat32 = 15897600; // 184 days

  // If this limit is reached we don't allow any more stakeTransfers
  // All other operations are allowed to continue
  let OPERATION_HISTORY_LIMIT : Nat = 100_000;

  //////////////////////
  /// Canister State ///
  //////////////////////

  stable let _operationHistory : T.OperationHistory = Vector.new<T.Operation>();

  ////////////////////////
  /// Public Functions ///
  ////////////////////////

  public shared ({ caller }) func initiate_icp_stake_transfer() : async T.OperationResponse {
    assert (Principal.isAnonymous(caller) == false);
    return await initiateIcpStakeTransfer(caller);
  };

  public shared ({ caller }) func initiate_icp_stake_withdrawal({
    amount : Nat64;
  }) : async T.OperationResponse {
    assert (Principal.isAnonymous(caller) == false);
    return await initiateIcpStakeWithdrawal(caller, amount);
  };

  public shared ({ caller }) func process_icp_stake_dissolve({
    neuronId : T.NeuronId;
  }) : async T.ConfigurationResponse {
    assert (Principal.isAnonymous(caller) == false);
    return await processIcpStakeDissolve(caller, neuronId);
  };

  public shared ({ caller }) func process_icp_stake_disburse({
    neuronId : T.NeuronId;
  }) : async T.ConfigurationResponse {
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

  public query func get_operation_history({ start : Nat; length : Nat }) : async T.HistoryResult {
    return Operations.getOperationHistory(_operationHistory, start, length);
  };

  public func get_canister_accounts() : async T.CanisterAccountsResult {
    return await getCanisterAccounts();
  };

  public func get_main_neuron() : async T.FullNeuronResult {
    return await getMainNeuron();
  };

  public shared ({ caller }) func controller_stake_neuron({ amount : Nat64 }) : async T.OperationResponse {
    assert (caller == owner);
    return await stakeNeuron(amount);
  };

  public shared ({ caller }) func controller_set_neuron_dissolve_delay() : async T.ConfigurationResponse {
    assert (caller == owner);
    return await setNeuronDissolveDelay();
  };

  public shared ({ caller }) func controller_set_governance_following({
    topic : Int32;
    followee : ?T.NeuronId;
  }) : async T.ConfigurationResponse {
    assert (caller == owner);
    return await setGovernanceFollowing(topic, followee);
  };

  public shared ({ caller }) func controller_set_spawn_reward_timer() : async T.OperationResponse {
    assert (caller == owner);
    return setSpawnRewardTimer<system>();
  };

  /////////////////////////
  /// Private Functions ///
  /////////////////////////

  private func initiateIcpStakeTransfer(caller : Principal) : async T.OperationResponse {
    let ?mainNeuron = Operations.mainNeuronId(_operationHistory) else return #err("Main neuron ID not found");

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

    switch (await IcpGovernance.get_full_neuron(mainNeuron)) {
      case (#Ok { account }) {
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
                }),
              )
            );
          };
          case (#Err error) {
            return #err(debug_show error);
          };
        };
      };
      case (#Err error) {
        return #err(debug_show error);
      };
    };
  };

  private func initiateIcpStakeWithdrawal(caller : Principal, amount : Nat64) : async T.OperationResponse {
    let ?mainNeuron = Operations.mainNeuronId(_operationHistory) else return #err("Main neuron ID not found");

    if (amount < ONE_ICP + ICP_PROTOCOL_FEE) return #err("Insufficient amount to withdraw: " # debug_show amount # ". A minimum of 1.0001 ICP is needed.");

    let balance = Operations.stakerBalance(_operationHistory, caller);

    if (balance >= amount) {
      // neuron pays the fee, so minus it from user amount
      let { command } = await IcpGovernance.manage_neuron({
        id = ?{ id = mainNeuron };
        neuron_id_or_subaccount = null;
        command = ? #Split({ amount_e8s = amount - ICP_PROTOCOL_FEE });
      });

      let ?commandList = command else return #err("Failed to split new neuron");

      switch (commandList) {
        case (#Split { created_neuron_id }) {

          let ?{ id } = created_neuron_id else return #err("Failed to retrieve new neuron Id");

          return #ok(
            Operations.logOperation(
              _operationHistory,
              #StakeWithdrawal({
                staker = caller;
                amount_e8s = amount;
                neuron_id = id; // neuron balance will be amount - protocol fee
              }),
            )
          );
        };
        case _ {
          return #err("Failed to stake. " # debug_show commandList);
        };
      };
    } else {
      return #err("Insufficient balance for caller: " # debug_show caller # ". Balance: " # debug_show balance);
    };
  };

  private func processIcpStakeDissolve(caller : Principal, neuronId : T.NeuronId) : async T.ConfigurationResponse {
    if (Operations.assertCallerOwnsNeuron(_operationHistory, caller, neuronId) == false) return #err("Failed to find neuron Id for caller: " # debug_show neuronId);

    let { command } = await IcpGovernance.manage_neuron({
      id = ?{ id = neuronId };
      neuron_id_or_subaccount = null;
      command = ? #Configure({ operation = ? #StartDissolving({}) });
    });

    let ?commandList = command else return #err("Failed to start dissolving neuron");

    switch (commandList) {
      case (#Configure _) { return #ok() };
      case _ {
        return #err("Failed to start dissolving neuron. " # debug_show commandList);
      };
    };
  };

  private func processIcpStakeDisburse(caller : Principal, neuronId : T.NeuronId) : async T.ConfigurationResponse {
    if (Operations.assertCallerOwnsNeuron(_operationHistory, caller, neuronId) == false) return #err("Failed to find neuron Id for caller: " # debug_show neuronId);

    let { command } = await IcpGovernance.manage_neuron({
      id = ?{ id = neuronId };
      neuron_id_or_subaccount = null;
      command = ? #Disburse({
        to_account = ?{
          hash = AccountIdentifier.accountIdentifier(caller, AccountIdentifier.defaultSubaccount()) |> Blob.toArray(_);
        };
        amount = null; // defaults to 100%
      });
    });

    let ?commandList = command else return #err("Failed to disburse neuron");

    switch (commandList) {
      case (#Disburse _) { return #ok() };
      case _ {
        return #err("Failed to start dissolving neuron. " # debug_show commandList);
      };
    };
  };

  // WON'T WORK UNTIL CANISTERS CAN STAKE NEURONS
  private func stakeNeuron(amount : Nat64) : async T.OperationResponse {
    // guard clauses
    if (Option.isSome(Operations.mainNeuronId(_operationHistory))) return #err("Main neuron has already been staked");
    if (amount < ONE_ICP + ICP_PROTOCOL_FEE) return #err("A minimum of 1.0001 ICP is needed to stake");

    // generate a random nonce that fits into Nat64
    let ?nonce = Random.Finite(await Random.blob()).range(64) else return #err("Failed to generate nonce");

    // controller is the canister
    let neuronController : Principal = Principal.fromActor(thisCanister);

    // motoko version of this: https://github.com/dfinity/ic/blob/0f7973af4283f3244a08b87ea909b6f605d65989/rs/nervous_system/common/src/ledger.rs#L210
    func computeNeuronStakingSubaccountBytes(controller : Principal, nonce : Nat64) : Blob {
      let hash = Sha256.Digest(#sha256);
      hash.writeArray([0x0c]);
      hash.writeArray(Blob.toArray(Text.encodeUtf8("neuron-stake")));
      hash.writeArray(Blob.toArray(Principal.toBlob(controller)));
      hash.writeArray(Binary.BigEndian.fromNat64(nonce)); // needs to be big endian bytes
      return hash.sum();
    };

    // neurons subaccounts contain random nonces so one controller can have many neurons
    let newSubaccount : Blob = computeNeuronStakingSubaccountBytes(neuronController, Nat64.fromNat(nonce));

    // the neuron account ID is a sub account of the governance canister
    let newNeuronAccount : Blob = AccountIdentifier.accountIdentifier(Principal.fromActor(IcpGovernance), newSubaccount);

    switch (await IcpLedger.transfer({ memo = Nat64.fromNat(nonce); from_subaccount = null; to = newNeuronAccount; amount = { e8s = amount - ICP_PROTOCOL_FEE }; fee = { e8s = ICP_PROTOCOL_FEE }; created_at_time = null })) {
      case (#Ok _) {
        // ClaimOrRefresh: finds the neuron by subaccount and checks if the memo matches the nonce
        let { command } = await IcpGovernance.manage_neuron({
          id = null;
          neuron_id_or_subaccount = null;
          command = ? #ClaimOrRefresh({
            by = ? #MemoAndController({
              controller = ?neuronController;
              memo = Nat64.fromNat(nonce);
            });
          });
        });

        let ?commandList = command else return #err("Failed to claim new neuron");

        switch (commandList) {
          case (#ClaimOrRefresh { refreshed_neuron_id }) {

            let ?{ id } = refreshed_neuron_id else return #err("Failed to retrieve new neuron Id");

            // store the staked neuron in the log
            return #ok(Operations.logOperation(_operationHistory, #CreateNeuron({ neuron_id = id })));
          };
          case _ {
            return #err("Failed to stake. " # debug_show commandList);
          };
        };
      };
      case (#Err error) {
        return #err("Failed to transfer ICP: " # debug_show error);
      };
    };
  };

  private func setNeuronDissolveDelay() : async T.ConfigurationResponse {
    let ?mainNeuron = Operations.mainNeuronId(_operationHistory) else return #err("Main neuron ID not found");

    switch (await IcpGovernance.get_neuron_info(mainNeuron)) {
      case (#Ok { dissolve_delay_seconds }) {
        if (dissolve_delay_seconds > 0) return #err("Dissolve delay already set");

        let { command } = await IcpGovernance.manage_neuron({
          id = ?{ id = mainNeuron };
          neuron_id_or_subaccount = null;
          command = ? #Configure({
            operation = ? #IncreaseDissolveDelay({
              additional_dissolve_delay_seconds = NEURON_DISSOLVE_DELAY_SECONDS;
            });
          });
        });

        let ?commandList = command else return #err("Failed to set neuron dissolve delay");

        switch (commandList) {
          case (#Configure _) { return #ok() };
          case _ {
            return #err("Failed to set neuron dissolve delay. " # debug_show commandList);
          };
        };
      };
      case (#Err error) {
        return #err(debug_show error);
      };
    };
  };

  private func setGovernanceFollowing(topic : Int32, followee : ?T.NeuronId) : async T.ConfigurationResponse {
    let ?mainNeuron = Operations.mainNeuronId(_operationHistory) else return #err("Main neuron ID not found");

    // if null is passed use the default followee
    let followNeuron = Option.get(followee, DEFAULT_NEURON_FOLLOWEE);

    let { command } = await IcpGovernance.manage_neuron({
      id = ?{ id = mainNeuron };
      neuron_id_or_subaccount = null;
      command = ? #Follow({ topic = topic; followees = [{ id = followNeuron }] });
    });

    let ?commandList = command else return #err("Failed to set followee");

    switch (commandList) {
      case (#Follow _) { return #ok() };
      case _ {
        return #err("Failed to set followee. " # debug_show commandList);
      };
    };

  };

  // Timer function
  // TODO only call this when maturity is above 1 ICP
  private func spawnRandomReward() : async () {
    let ?mainNeuron = Operations.mainNeuronId(_operationHistory) else {
      return ignore Operations.logOperation(_operationHistory, #Error({ function = "spawnRandomReward()"; message = "Main neuron ID not found" }));
    };

    // Calculate total stake amount for generating random threshold
    let totalAmount = Stats.getTotalStakeAmount(_operationHistory);

    let ?randomNumber = await Prize.generateRandomThreshold(totalAmount) else {
      return ignore Operations.logOperation(_operationHistory, #Error({ function = "spawnRandomReward()"; message = "Failed to generate random threshold" }));
    };

    let ?winner = Prize.weightedSelection(_operationHistory, randomNumber) else {
      return ignore Operations.logOperation(_operationHistory, #Error({ function = "spawnRandomReward()"; message = "Failed to find a winner" }));
    };

    // the neuron is controlled by the winner
    // so it won't appear as part of the canister controlled neurons
    let { command } = await IcpGovernance.manage_neuron({
      id = ?{ id = mainNeuron };
      neuron_id_or_subaccount = null;
      command = ? #Spawn({
        percentage_to_spawn = null;
        new_controller = ?winner;
        nonce = null;
      });
    });

    let ?commandList = command else {
      return ignore Operations.logOperation(_operationHistory, #Error({ function = "spawnRandomReward()"; message = "Failed to spawn new neuron" }));
    };

    switch (commandList) {
      case (#Spawn { created_neuron_id }) {

        let ?{ id } = created_neuron_id else {
          return ignore Operations.logOperation(_operationHistory, #Error({ function = "spawnRandomReward()"; message = "Failed to retrieve new neuron Id" }));
        };

        // store the staked neuron in the log
        return ignore Operations.logOperation(_operationHistory, #SpawnReward({ winner = winner; neuron_id = id }));
      };
      case _ {
        return ignore Operations.logOperation(_operationHistory, #Error({ function = "spawnRandomReward()"; message = "Failed to spawn. " # debug_show commandList }));
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
      spawnRandomReward,
    );

    return #ok(Operations.logOperation(_operationHistory, #RewardTimer({ timer_id = newTimerId; timer_duration_nanos = SPAWN_REWARD_TIMER_DURATION_NANOS })));
  };

  private func getMainNeuron() : async T.FullNeuronResult {
    let ?mainNeuron = Operations.mainNeuronId(_operationHistory) else return #err("Main neuron ID not found");

    switch (await IcpGovernance.get_neuron_info(mainNeuron), await IcpGovernance.get_full_neuron(mainNeuron)) {
      case (#Ok neuronInfo, #Ok neuron) {
        return #ok({
          age_seconds = neuronInfo.age_seconds;
          created_timestamp_seconds = neuronInfo.created_timestamp_seconds;
          dissolve_delay_seconds = neuronInfo.dissolve_delay_seconds;
          joined_community_fund_timestamp_seconds = neuronInfo.joined_community_fund_timestamp_seconds;
          known_neuron_data = neuronInfo.known_neuron_data;
          recent_ballots = neuronInfo.recent_ballots;
          retrieved_at_timestamp_seconds = neuronInfo.retrieved_at_timestamp_seconds;
          stake_e8s = neuronInfo.stake_e8s;
          state = neuronInfo.state;
          voting_power = neuronInfo.voting_power;
          account = neuron.account;
          aging_since_timestamp_seconds = neuron.aging_since_timestamp_seconds;
          cached_neuron_stake_e8s = neuron.cached_neuron_stake_e8s;
          controller = neuron.controller;
          dissolve_state = neuron.dissolve_state;
          followees = neuron.followees;
          hot_keys = neuron.hot_keys;
          id = neuron.id;
          kyc_verified = neuron.kyc_verified;
          maturity_e8s_equivalent = neuron.maturity_e8s_equivalent;
          neuron_fees_e8s = neuron.neuron_fees_e8s;
          not_for_profit = neuron.not_for_profit;
          spawn_at_timestamp_seconds = neuron.spawn_at_timestamp_seconds;
          transfer = neuron.transfer;
        });
      };
      case _ {
        return #err("Failed to fetch main neuron information");
      };
    };
  };

  private func getCanisterAccounts() : async T.CanisterAccountsResult {
    return #ok({
      account_identifier = Principal.fromActor(thisCanister) |> AccountIdentifier.accountIdentifier(_, AccountIdentifier.defaultSubaccount()) |> Blob.toArray(_) |> Hex.encode(_);
      icrc1_identifier = Account.toText({
        owner = Principal.fromActor(thisCanister);
        subaccount = null;
      });
      balance = await IcpLedger.icrc1_balance_of({
        owner = Principal.fromActor(thisCanister);
        subaccount = null;
      });
    });
  };

};
