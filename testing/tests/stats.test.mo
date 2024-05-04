import { test; expect; suite } "mo:test";
import T "../../src/types";
import Vector "mo:vector";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Operations "../../src/operations";
import Stats "../../src/stats";

suite("test computing stats under high usage", func() {

    let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

    let mockPrincipalsAndAmounts : [(Text, Nat64)] = [
        ("r6gcn-ysbbb-cccac-zlekr-hai", 100_000_000),
        ("2jcrw-waddd-ddded-vmpft-oai", 100_000_000),
        ("q4tvz-2zeaa-aaafg-fnjqr-nai", 100_000_000),
        ("l5p4m-l2ggg-hhhbh-slrjq-pai", 100_000_000),
        ("mdi57-tdhhh-iiiic-gdpkq-wai", 100_000_000),
        ("yy6u5-sbejj-jjjjd-bwclq-lai", 100_000_000),
        ("kobwd-kkkkk-kkkke-xzfjq-zai", 100_000_000),
        ("hps3k-y7uuu-llllf-nhmrq-gai", 100_000_000),
        ("7ttao-7gvvv-mmmmg-rbnpq-bai", 100_000_000),
        ("f43vs-djwww-wnnnh-tjqkq-yai", 100_000_000),
    ];
    let mockPrincipal : Principal = Principal.fromText("un4fu-tqaaa-aaaab-qadjq-cai");
    let mockNeuronId : Nat64 = 4829694856491667492;
    let mockBlockchainFee : Nat64 = 10_000;

    test("accurate total stake amount with many actions", func() {

        // simulate over a 100,000 entries (range * array size)
        for(i in Iter.range(0, 9999)){
            if (i % 2 == 0) {
                // simulate 10 users transferring in ICP
                for((mockPrincipal, mockAmount) in mockPrincipalsAndAmounts.vals()){
                    ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
                        staker = Principal.fromText(mockPrincipal);
                        amount_e8s = mockAmount;
                        blockchain_fee = mockBlockchainFee;
                    }));
                };

                // simulate a reward being spawned
                ignore Operations.logOperation(_mockOperationHistory, #SpawnReward({
                    winner = mockPrincipal;
                    neuron_id = mockNeuronId
                }));
            } else {
                // simulate 10 users withdrawing
                for((mockPrincipal, mockAmount) in mockPrincipalsAndAmounts.vals()){
                    ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({
                        staker = Principal.fromText(mockPrincipal);
                        amount_e8s = mockAmount;
                        neuron_id = mockNeuronId;
                        blockchain_fee = mockBlockchainFee;
                    }));
                };

                // simulate an error being logged
                ignore Operations.logOperation(_mockOperationHistory, #Error({
                    function="Testing()";
                    message="Testing an error";
                }));
            };
        };

        expect.nat64(Stats.getTotalStakeAmount(_mockOperationHistory)).equal(0)
    });

    test("accurate total stake amount with many transfers", func() {

        // simulate over a 100,000 entries (range * array size)
        for(i in Iter.range(0, 9999)){
            // simulate 10 users transferring in ICP
            for((mockPrincipal, mockAmount) in mockPrincipalsAndAmounts.vals()){
                ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
                    staker = Principal.fromText(mockPrincipal);
                    amount_e8s = mockAmount;
                    blockchain_fee = mockBlockchainFee;
                }));
            };
        };

        // 100,000 ICP
        expect.nat64(Stats.getTotalStakeAmount(_mockOperationHistory)).equal(100_000_00_000_000)
    });
});

suite("test computing current stakers under high usage", func() {

    let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

    let mockPrincipalsAndAmounts : [(Text, Nat64)] = [
        ("r6gcn-ysbbb-cccac-zlekr-hai", 100_000_000),
        ("2jcrw-waddd-ddded-vmpft-oai", 100_000_000),
        ("q4tvz-2zeaa-aaafg-fnjqr-nai", 100_000_000),
        ("l5p4m-l2ggg-hhhbh-slrjq-pai", 100_000_000),
        ("mdi57-tdhhh-iiiic-gdpkq-wai", 100_000_000),
        ("yy6u5-sbejj-jjjjd-bwclq-lai", 100_000_000),
        ("kobwd-kkkkk-kkkke-xzfjq-zai", 100_000_000),
        ("hps3k-y7uuu-llllf-nhmrq-gai", 100_000_000),
        ("7ttao-7gvvv-mmmmg-rbnpq-bai", 100_000_000),
        ("f43vs-djwww-wnnnh-tjqkq-yai", 100_000_000),
    ];
    let mockPrincipal : Principal = Principal.fromText("un4fu-tqaaa-aaaab-qadjq-cai");
    let mockNeuronId : Nat64 = 4829694856491667492;
    let mockBlockchainFee : Nat64 = 10_000;

    test("accurate current stakers with many actions", func() {
        // simulate over a 100,000 entries (range * array size)
        for(i in Iter.range(0, 999)){
            if (i % 2 == 0) {
                // simulate 10 users transferring in ICP
                for((mockPrincipal, mockAmount) in mockPrincipalsAndAmounts.vals()){
                    ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
                        staker = Principal.fromText(mockPrincipal);
                        amount_e8s = mockAmount;
                        blockchain_fee = mockBlockchainFee;
                    }));
                };

                // simulate a reward being spawned
                ignore Operations.logOperation(_mockOperationHistory, #SpawnReward({
                    winner = mockPrincipal;
                    neuron_id = mockNeuronId
                }));
            } else {
                // simulate 10 users withdrawing
                for((mockPrincipal, mockAmount) in mockPrincipalsAndAmounts.vals()){
                    ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({
                        staker = Principal.fromText(mockPrincipal);
                        amount_e8s = mockAmount;
                        neuron_id = mockNeuronId;
                        blockchain_fee = mockBlockchainFee;
                    }));
                };

                // simulate an error being logged
                ignore Operations.logOperation(_mockOperationHistory, #Error({
                    function="Testing()";
                    message="Testing an error";
                }));
            };
        };

        expect.nat(Stats.getCurrentStakers(_mockOperationHistory).size()).equal(0)
    });

});