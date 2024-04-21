import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Option "mo:base/Option";
import Random "mo:base/Random";
import Text "mo:base/Text";
import Sha256 "mo:sha2/Sha256";
import Hex "mo:encoding/Hex";
import Binary "mo:encoding/Binary";
import Account "mo:account";
import AccountIdentifier "mo:account-identifier";
import IcpLedgerInterface "./ledger_interface";
import IcpGovernanceInterface "./governance_interface";

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

  /////////////
  /// Types ///
  /////////////

  public type CanisterAccountsResult = {
    account_identifier : Text;
    icrc1_identifier : Text;
    balance : Nat;
  };

  public type CanisterLegacyTransferResult = {
    #Ok : Nat64;
    #Err : IcpLedgerInterface.TransferError_1;
  };

  public type CanisterIcrc1TransferResult = {
    #Ok : Nat;
    #Err : IcpLedgerInterface.TransferError;
  };

  //////////////////////
  /// Canister State ///
  //////////////////////

  private stable var _mainNeuronId : ?Nat64 = null;

  ////////////////////////
  /// public Functions ///
  ////////////////////////

  public shared ({ caller }) func controller_get_canister_accounts() : async CanisterAccountsResult {
    assert (caller == owner);
    return await getCanisterAccounts();
  };

  public shared ({ caller }) func controller_canister_legacy_transfer(to : Text, amount : Nat64) : async CanisterLegacyTransferResult {
    assert (caller == owner);
    return await canisterLegacyTransfer(to, amount, null);
  };

  public shared ({ caller }) func controller_canister_icrc1_transfer(to : Text, amount : Nat) : async CanisterIcrc1TransferResult {
    assert (caller == owner);
    return await canisterIcrc1Transfer(to, amount);
  };

  public shared ({ caller }) func controller_stake_neuron(amount : Nat64) : async Nat64 {
    assert (caller == owner);
    return await stakeNeuron(amount);
  };

  ////////////////////////////////
  /// Canister Stake Functions ///
  ////////////////////////////////

  // WON'T WORK UNTIL CANISTERS CAN STAKE NEURONS
  private func stakeNeuron(amount : Nat64) : async Nat64 {
    if (Option.isSome(_mainNeuronId) or amount < ONE_ICP + ICP_PROTOCOL_FEE) {
      Debug.trap("Failed to proceed with staking a new neuron");
    };

    // generate a random nonce that fits into Nat64
    // let-else option binding
    let ?nonce = Random.Finite(await Random.blob()).range(64) else Debug.trap("Failed to generate nonce");

    // controller is the canister
    let neuronController : Principal = Principal.fromActor(thisCanister);

    // neurons subaccounts contain random nonces so one controller can have many neurons
    let newSubaccount : Blob = computeNeuronStakingSubaccountBytes(neuronController, Nat64.fromNat(nonce));

    // the neuron account ID is a sub account of the governance canister
    let newNeuronAccount : Text = Principal.fromActor(IcpGovernance) |> AccountIdentifier.accountIdentifier(_, newSubaccount) |> Blob.toArray(_) |> Hex.encode(_); // pipe operators

    switch (await canisterLegacyTransfer(newNeuronAccount, amount, ?Nat64.fromNat(nonce))) {
      case (#Ok result) {
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

        let ?commandList = command else {
          return Debug.trap("Failed to stake. Nonce: " # debug_show nonce # " command result: " # debug_show command);
        };

        switch (commandList) {
          case (#ClaimOrRefresh { refreshed_neuron_id }) {

            let ?{ id } = refreshed_neuron_id else Debug.trap("Failed to retrieve new neuron Id. Nonce: " # debug_show nonce);
            // store the staked neuron locally
            _mainNeuronId := ?id;

            return id;
          };
          case _ {
            return Debug.trap("Failed to stake. Nonce: " # debug_show nonce # " command result: " # debug_show commandList);
          };
        };
      };
      case (#Err result) {
        return Debug.trap("Failed to transfer ICP: " # debug_show result);
      };
    };
  };

  // motoko version of this: https://github.com/dfinity/ic/blob/0f7973af4283f3244a08b87ea909b6f605d65989/rs/nervous_system/common/src/ledger.rs#L210
  private func computeNeuronStakingSubaccountBytes(controller : Principal, nonce : Nat64) : Blob {
    let hash = Sha256.Digest(#sha256);
    hash.writeArray([0x0c]);
    hash.writeArray(Blob.toArray(Text.encodeUtf8("neuron-stake")));
    hash.writeArray(Blob.toArray(Principal.toBlob(controller)));
    hash.writeArray(Binary.BigEndian.fromNat64(nonce)); // needs to be big endian bytes
    return hash.sum();
  };

  /////////////////////////////////
  /// Canister Wallet Functions ///
  /////////////////////////////////

  private func getCanisterAccountIdentifier() : [Nat8] {
    return Blob.toArray(
      AccountIdentifier.accountIdentifier(
        Principal.fromActor(thisCanister),
        AccountIdentifier.defaultSubaccount(),
      )
    );
  };

  private func getCanisterIcrcAccount() : IcpLedgerInterface.Account {
    return { owner = Principal.fromActor(thisCanister); subaccount = null };
  };

  private func getCanisterBalance() : async Nat {
    return await IcpLedger.icrc1_balance_of(getCanisterIcrcAccount());
  };

  private func canisterLegacyTransfer(to : Text, amount : Nat64, memo : ?Nat64) : async CanisterLegacyTransferResult {
    switch (Hex.decode(to)) {
      case (#ok address_decoded) {
        return await IcpLedger.transfer({
          memo = Option.get<Nat64>(memo, 0);
          from_subaccount = ?AccountIdentifier.defaultSubaccount();
          to = Blob.fromArray(address_decoded);
          amount = { e8s = amount - ICP_PROTOCOL_FEE };
          fee = { e8s = ICP_PROTOCOL_FEE };
          created_at_time = null;
        })

      };
      case (#err address_decoded) {
        Debug.trap("Address failed to decode");
      };
    };
  };

  private func canisterIcrc1Transfer(to : Text, amount : Nat) : async CanisterIcrc1TransferResult {
    switch (Account.fromText((to))) {
      case (#ok account_decoded) {
        return await IcpLedger.icrc1_transfer({
          to = account_decoded;
          fee = null; // default
          memo = null;
          from_subaccount = null;
          created_at_time = null;
          amount = amount - Nat64.toNat(ICP_PROTOCOL_FEE);
        });
      };
      case (#err address_decoded) {
        Debug.trap("Account failed to decode");
      };
    };
  };

  private func getCanisterAccounts() : async CanisterAccountsResult {
    return {
      account_identifier = Hex.encode(getCanisterAccountIdentifier());
      icrc1_identifier = Account.toText(getCanisterIcrcAccount());
      balance = await getCanisterBalance();
    };
  };

};
