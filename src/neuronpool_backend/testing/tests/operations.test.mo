import { test; expect; suite } "mo:test";
import T "../../types";
import Vector "mo:vector";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Operations "../../operations";

suite("test logging operations", func() {
    
    let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

    let mockPrincipal : Principal = Principal.fromText("un4fu-tqaaa-aaaab-qadjq-cai");
    let mockAmount : Nat64 = 100_000_000;
    let mockNeuronId : Nat64 = 4829694856491667492;

    test("log an operation", func() {
        expect.nat(Vector.size(_mockOperationHistory)).equal(0);

        ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
            staker = mockPrincipal;
            amount_e8s = mockAmount
        }));

        expect.nat(Vector.size(_mockOperationHistory)).equal(1);
    });

    test("log 100 operations", func() {
        for(i in Iter.range(0, 99)){
            if (i % 2 == 0) {
                ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
                    staker = mockPrincipal;
                    amount_e8s = mockAmount;
                }));
            } else {
                ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({
                    staker = mockPrincipal;
                    amount_e8s = mockAmount;
                    neuron_id = mockNeuronId;
                }));
            }
        };

        expect.nat(Vector.size(_mockOperationHistory)).equal(101); // +1 from previous test
    });

});

suite("test stake and withdrawal flow", func() {
    
    let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

    let mockPrincipal : Principal = Principal.fromText("un4fu-tqaaa-aaaab-qadjq-cai");
    let mockAmount : Nat64 = 100_000_000;
    let mockNeuronId : T.NeuronId = 4829694856491667492;

    test("balance is accurate after transferring", func() {
        ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
            staker = mockPrincipal;
            amount_e8s = mockAmount
        }));

        expect.nat64(Operations.stakerBalance(_mockOperationHistory, mockPrincipal)).equal(mockAmount)
    });

    test("balance is accurate after withdrawing", func() {
        ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({
            staker = mockPrincipal;
            amount_e8s = mockAmount;
            neuron_id = mockNeuronId;
        }));

        expect.nat64(Operations.stakerBalance(_mockOperationHistory, mockPrincipal)).equal(0)
    });

    test("balance is accurate after multiple transfers and withdrawals", func() {
        for(i in Iter.range(0, 9)){
            if (i % 2 == 0) {
                ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
                    staker = mockPrincipal;
                    amount_e8s = mockAmount;
                }));
            } else {
                ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({
                    staker = mockPrincipal;
                    amount_e8s = mockAmount;
                    neuron_id = mockNeuronId;
                }));
            }
        };

        expect.nat64(Operations.stakerBalance(_mockOperationHistory, mockPrincipal)).equal(0);

        for(i in Iter.range(0, 9)){
            ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
                staker = mockPrincipal;
                amount_e8s = mockAmount;
            }));
        };

        expect.nat64(Operations.stakerBalance(_mockOperationHistory, mockPrincipal)).equal(1_000_000_000);

        for(i in Iter.range(0, 9)){
            ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({
                staker = mockPrincipal;
                amount_e8s = 10_000_000;
                neuron_id = mockNeuronId;
            }));
        };

        expect.nat64(Operations.stakerBalance(_mockOperationHistory, mockPrincipal)).equal(900_000_000);
    });

    test("correct withdrawal neurons and balance", func() {
        let newUser : Principal = Principal.fromText("kobwd-kkkkk-kkkke-xzfjq-zai");
        let newUserAmount : Nat64 = 350_000_000;
        let newWithdrawalNeuron1 : T.NeuronId = 1234567812345678123;
        let newWithdrawalNeuron2 : T.NeuronId = 4673826543985643694;
        let newWithdrawalNeuron3 : T.NeuronId = 7854390654365430646;

        ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
            staker = newUser;
            amount_e8s = newUserAmount;
        }));

        ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({
            staker = newUser;
            amount_e8s = 100_000_000;
            neuron_id = newWithdrawalNeuron1;
        }));

        ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({
            staker = newUser;
            amount_e8s = 100_000_000;
            neuron_id = newWithdrawalNeuron2;
        }));

        ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({
            staker = newUser;
            amount_e8s = 100_000_000;
            neuron_id = newWithdrawalNeuron3;
        }));

        expect.bool(Operations.assertCallerOwnsNeuron(_mockOperationHistory, newUser, newWithdrawalNeuron1)).isTrue();
        expect.bool(Operations.assertCallerOwnsNeuron(_mockOperationHistory, newUser, newWithdrawalNeuron2)).isTrue();
        expect.bool(Operations.assertCallerOwnsNeuron(_mockOperationHistory, newUser, newWithdrawalNeuron3)).isTrue();
        expect.bool(Operations.assertCallerOwnsNeuron(_mockOperationHistory, newUser, mockNeuronId)).isFalse();
        expect.nat(Operations.getStakerWithdrawalNeurons(_mockOperationHistory, newUser).size()).equal(3);
        expect.nat64(Operations.stakerBalance(_mockOperationHistory, newUser)).equal(50_000_000);
    });

});

suite("test multiple users performing many actions", func() {

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

    test("high usage and payload (>100,000 operations)", func() {
        // simulate main neuron gets staked
        ignore Operations.logOperation(_mockOperationHistory, #CreateNeuron({
            neuron_id = mockNeuronId
        }));

        // simulate over a 100,000 entries (range * array size)
        for(i in Iter.range(0, 9999)){
            if (i % 2 == 0) {
                // simulate 10 users transferring in ICP
                for((mockPrincipal, mockAmount) in mockPrincipalsAndAmounts.vals()){
                    ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({
                        staker = Principal.fromText(mockPrincipal);
                        amount_e8s = mockAmount;
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
                    }));
                };

                // simulate an error being logged
                ignore Operations.logOperation(_mockOperationHistory, #Error({
                    function="Testing()";
                    message="Testing an error";
                }));
            };
        };
        
        expect.nat(Vector.size(_mockOperationHistory)).greater(100_000);

        // balances are 0 (from the successful withdrawals)
        for((mockPrincipal, mockAmount) in mockPrincipalsAndAmounts.vals()){
            expect.nat64(Operations.stakerBalance(_mockOperationHistory, Principal.fromText(mockPrincipal))).equal(0)
        };
        // main neuron id is still found
        expect.option(Operations.mainNeuronId(_mockOperationHistory), Nat64.toText, Nat64.equal).isSome();
    });

});