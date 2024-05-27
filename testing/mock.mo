import T "../src/types";
import Prim "mo:⛔";
import Vector "mo:vector";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Operations "../src/operations";

module {

    // In these mock tests, we are not concerned with the correct logic of the canister.
    // These tests are designed to assess the performance of the canister under heavy load
    // to help us determine how much data we can safely store.

    public type HeapData = {
        operation_entries : Nat;
        heap_bytes : Nat;
        heap_mb : Nat;
        mem_bytes : Nat;
        mem_mb : Nat;
    };

    public func addMockData(history : T.OperationHistory) : () {
        for (i in Iter.range(0, 99)) {
            logMockTransfer(history);
            logMockWithdrawal(history);
            logMockSpawn(history);
            logMockDisburse(history);
            logMockCreateNeuron(history);
            logMockRewardTimer(history);
        };
    };

    let mockPrincipal : Text = "un4fu-tqaaa-aaaab-qadjq-cai";
    let mockAmount : Nat64 = 100_000_000;
    let mockFee : Nat64 = 10_000;
    let mockNeuronId : Nat64 = 4829694856491667492;
    let mockTimerId : Nat = 1;
    let mockTimerDuration : Nat64 = 10_000_000_000_000;

    public func logMockTransfer(history : T.OperationHistory) : () {
        ignore Operations.logOperation(
            history,
            #StakeTransfer({
                staker = Principal.fromText(mockPrincipal);
                amount_e8s = mockAmount;
                blockchain_fee = mockFee;
            }),
        );
    };

    public func logMockWithdrawal(history : T.OperationHistory) : () {
        ignore Operations.logOperation(
            history,
            #StakeWithdrawal({
                staker = Principal.fromText(mockPrincipal);
                amount_e8s = mockAmount;
                neuron_id = mockNeuronId;
                blockchain_fee = mockFee;
            }),
        );
    };

    public func logMockSpawn(history : T.OperationHistory) : () {
        ignore Operations.logOperation(history, #SpawnReward({ winner = Principal.fromText(mockPrincipal); neuron_id = mockNeuronId }));
    };

    public func logMockDisburse(history : T.OperationHistory) : () {
        ignore Operations.logOperation(
            history,
            #DisburseReward({
                winner = Principal.fromText(mockPrincipal);
                neuron_id = mockNeuronId;
                amount = mockAmount;
                protocol_fee = mockFee;
            }),
        )

    };

    public func logMockCreateNeuron(history : T.OperationHistory) : () {
        ignore Operations.logOperation(history, #CreateNeuron({ neuron_id = mockNeuronId; token = "ICP" }));
    };

    public func logMockRewardTimer(history : T.OperationHistory) : () {
        ignore Operations.logOperation(history, #RewardTimer({ timer_id = mockTimerId; timer_duration_nanos = mockTimerDuration }));
    };

    public func getCanisterHeapData(history : T.OperationHistory) : HeapData {
        let heap = Prim.rts_heap_size();
        let heap_kb = heap / 1024;
        let heap_mb = heap_kb / 1024;

        let mem = Prim.rts_memory_size();
        let mem_kb = mem / 1024;
        let mem_mb = mem_kb / 1024;
        return {
            operation_entries = Vector.size(history);
            heap_bytes = heap;
            heap_mb = heap_mb;
            mem_bytes = mem;
            mem_mb = mem_mb;
        };
    };
};
