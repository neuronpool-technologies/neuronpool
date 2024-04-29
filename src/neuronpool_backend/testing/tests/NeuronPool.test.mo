import {test; expect; suite} "mo:test/async";
import NeuronPool "../../NeuronPool";
import Debug "mo:base/Debug";

var neuronpool = await NeuronPool.NeuronPool();

suite("test initiate_icp_stake_transfer flow", func() : async () {
    // Step 1: approve the canister

    // Step 2: call the transfer_from
    await test("assert anonymous caller fails", func() : async () {
        let res = await neuronpool.initiate_icp_stake_transfer();
        Debug.print("hello " # debug_show res)
    });

});