import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Nat64 "mo:base/Nat64";
import Hex "mo:encoding/Hex";
import Account "mo:account";
import AccountIdentifier "mo:account-identifier";
import IcpLedgerInterface "./ledger_interface";

shared ({ caller = owner }) actor class NeuronPool() = thisCanister {

  /////////////////
  /// Constants ///
  /////////////////

  // ICP ledger canister
  let IcpLedger = actor "ryjl3-tyaaa-aaaaa-aaaba-cai" : IcpLedgerInterface.Self;

  // The standard ICP transaction fee
  let ICP_PROTOCOL_FEE : Nat64 = 10_000;

  /////////////
  /// Types ///
  /////////////

  public type CanisterAccounts = {
    account_identifier : Text;
    icrc1_identifier : Text;
    balance : Nat;
  };

  public type CanisterAccountsResult = Result.Result<CanisterAccounts, ()>;

  public type CanisterTransferLegacyResult = Result.Result<IcpLedgerInterface.Result_5, Text>;

  public type CanisterIcrc1TransferResult = Result.Result<IcpLedgerInterface.Result, Text>;

  //////////////////////
  /// Canister State ///
  //////////////////////

  ////////////////////////
  /// public Functions ///
  ////////////////////////

  public shared ({ caller }) func controller_get_canister_accounts() : async CanisterAccountsResult {
    assert (caller == owner);
    return await getCanisterAccounts();
  };

  public shared ({ caller }) func controller_canister_transfer_legacy(to : Text, amount : Nat64) : async CanisterTransferLegacyResult {
    assert (caller == owner);
    return await canisterTransferLegacy(to, amount);
  };

  public shared ({ caller }) func controller_canister_icrc1_transfer(to : Text, amount : Nat) : async CanisterIcrc1TransferResult {
    assert (caller == owner);
    return await canisterIcrc1Transfer(to, amount);
  };

  /////////////////////////////////
  /// canister Wallet Functions ///
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

  private func canisterTransferLegacy(to : Text, amount : Nat64) : async CanisterTransferLegacyResult {
    switch (Hex.decode(to)) {
      case (#ok address_decoded) {
        return #ok(
          await IcpLedger.transfer({
            memo = 0;
            from_subaccount = ?AccountIdentifier.defaultSubaccount();
            to = Blob.fromArray(address_decoded);
            amount = { e8s = amount - ICP_PROTOCOL_FEE };
            fee = { e8s = ICP_PROTOCOL_FEE };
            created_at_time = null;
          })
        );
      };
      case (#err address_decoded) {
        return #err("Address failed to decode");
      };
    };
  };

  private func canisterIcrc1Transfer(to : Text, amount : Nat) : async CanisterIcrc1TransferResult {
    switch (Account.fromText((to))) {
      case (#ok account_decoded) {
        return #ok(
          await IcpLedger.icrc1_transfer({
            to = account_decoded;
            fee = null; // default
            memo = null;
            from_subaccount = null;
            created_at_time = null;
            amount = amount - Nat64.toNat(ICP_PROTOCOL_FEE);
          })
        );
      };
      case (#err address_decoded) {
        return #err("Account failed to decode");
      };
    };
  };

  private func getCanisterAccounts() : async CanisterAccountsResult {
    return #ok({
      account_identifier = Hex.encode(getCanisterAccountIdentifier());
      icrc1_identifier = Account.toText(getCanisterIcrcAccount());
      balance = await getCanisterBalance();
    });
  };

};
