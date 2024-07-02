import { test; expect; suite } "mo:test";
import T "../../src/types";
import Vector "mo:vector";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Operations "../../src/operations";

suite(
    "test stake and withdrawal flow",
    func() {

        let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

        let mockPrincipal : Principal = Principal.fromText("un4fu-tqaaa-aaaab-qadjq-cai");
        let mockAmount : Nat64 = 100_000_000;
        let mockNeuronId : T.NeuronId = 4829694856491667492;
        let mockBlockchainFee : Nat64 = 10_000;

        test(
            "balance is accurate after transferring",
            func() {
                ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({ staker = mockPrincipal; amount_e8s = mockAmount; blockchain_fee = mockBlockchainFee }));

                expect.nat64(Operations.stakerBalance(_mockOperationHistory, mockPrincipal)).equal(mockAmount);
            },
        );

        test(
            "balance is accurate after withdrawing",
            func() {
                // there is a withdrawal transaction fee so minus it from the amount
                let amountToWithdraw = mockAmount - mockBlockchainFee;

                ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({ staker = mockPrincipal; amount_e8s = amountToWithdraw; neuron_id = mockNeuronId; blockchain_fee = mockBlockchainFee }));

                expect.nat64(Operations.stakerBalance(_mockOperationHistory, mockPrincipal)).equal(0);
            },
        );

        test(
            "balance is accurate after multiple transfers and withdrawals",
            func() {
                for (i in Iter.range(0, 9)) {
                    if (i % 2 == 0) {
                        ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({ staker = mockPrincipal; amount_e8s = mockAmount; blockchain_fee = mockBlockchainFee }));
                    } else {
                        let amountToWithdraw = mockAmount - mockBlockchainFee;

                        ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({ staker = mockPrincipal; amount_e8s = amountToWithdraw; neuron_id = mockNeuronId; blockchain_fee = mockBlockchainFee }));
                    };
                };

                expect.nat64(Operations.stakerBalance(_mockOperationHistory, mockPrincipal)).equal(0);

                for (i in Iter.range(0, 9)) {
                    ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({ staker = mockPrincipal; amount_e8s = mockAmount; blockchain_fee = mockBlockchainFee }));
                };

                expect.nat64(Operations.stakerBalance(_mockOperationHistory, mockPrincipal)).equal(1_000_000_000);

                for (i in Iter.range(0, 9)) {
                    ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({ staker = mockPrincipal; amount_e8s = 10_000_000; neuron_id = mockNeuronId; blockchain_fee = mockBlockchainFee }));
                };

                expect.nat64(Operations.stakerBalance(_mockOperationHistory, mockPrincipal)).equal(900_000_000 - (mockBlockchainFee * 10));
            },
        );

        test(
            "correct withdrawal neurons and balance",
            func() {
                let newUser : Principal = Principal.fromText("kobwd-kkkkk-kkkke-xzfjq-zai");
                let newUserAmount : Nat64 = 350_000_000;
                let newWithdrawalNeuron1 : T.NeuronId = 1234567812345678123;
                let newWithdrawalNeuron2 : T.NeuronId = 4673826543985643694;
                let newWithdrawalNeuron3 : T.NeuronId = 7854390654365430646;

                ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({ staker = newUser; amount_e8s = newUserAmount; blockchain_fee = mockBlockchainFee }));

                ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({ staker = newUser; amount_e8s = 100_000_000; neuron_id = newWithdrawalNeuron1; blockchain_fee = mockBlockchainFee }));

                ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({ staker = newUser; amount_e8s = 100_000_000; neuron_id = newWithdrawalNeuron2; blockchain_fee = mockBlockchainFee }));

                ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({ staker = newUser; amount_e8s = 100_000_000; neuron_id = newWithdrawalNeuron3; blockchain_fee = mockBlockchainFee }));

                expect.bool(Operations.assertCallerOwnsNeuron(_mockOperationHistory, newUser, newWithdrawalNeuron1)).isTrue();
                expect.bool(Operations.assertCallerOwnsNeuron(_mockOperationHistory, newUser, newWithdrawalNeuron2)).isTrue();
                expect.bool(Operations.assertCallerOwnsNeuron(_mockOperationHistory, newUser, newWithdrawalNeuron3)).isTrue();
                expect.bool(Operations.assertCallerOwnsNeuron(_mockOperationHistory, newUser, mockNeuronId)).isFalse();
                expect.nat(Operations.getStakerWithdrawalNeurons(_mockOperationHistory, newUser).size()).equal(3);
                expect.nat64(Operations.stakerBalance(_mockOperationHistory, newUser)).equal(50_000_000 - (mockBlockchainFee * 3));
            },
        );

    },
);

suite(
    "test multiple users performing many actions",
    func() {

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

        test(
            "high usage and payload (>100,000 operations)",
            func() {
                // simulate main neuron gets staked
                ignore Operations.logOperation(_mockOperationHistory, #CreateNeuron({ neuron_id = mockNeuronId; token = "ICP"; amount_e8s = 100_000_000 }));

                // simulate over a 100,000 entries (range * array size)
                for (i in Iter.range(0, 9999)) {
                    if (i % 2 == 0) {
                        // simulate 10 users transferring in ICP
                        for ((mockPrincipal, mockAmount) in mockPrincipalsAndAmounts.vals()) {
                            ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({ staker = Principal.fromText(mockPrincipal); amount_e8s = mockAmount; blockchain_fee = mockBlockchainFee }));
                        };

                        // simulate a reward being spawned
                        ignore Operations.logOperation(_mockOperationHistory, #SpawnReward({ winner = mockPrincipal; neuron_id = mockNeuronId; maturity_e8s = 100_000_000 }));
                    } else {
                        // simulate 10 users withdrawing
                        for ((mockPrincipal, mockAmount) in mockPrincipalsAndAmounts.vals()) {
                            let amountToWithdraw = mockAmount - mockBlockchainFee;

                            ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({ staker = Principal.fromText(mockPrincipal); amount_e8s = amountToWithdraw; neuron_id = mockNeuronId; blockchain_fee = mockBlockchainFee }));
                        };
                    };
                };

                expect.nat(Vector.size(_mockOperationHistory)).greater(100_000);

                // balances are 0 (from the successful withdrawals)
                for ((mockPrincipal, mockAmount) in mockPrincipalsAndAmounts.vals()) {
                    expect.nat64(Operations.stakerBalance(_mockOperationHistory, Principal.fromText(mockPrincipal))).equal(0);
                };
                // main neuron id is still found
                expect.nat64(Operations.mainNeuronId(_mockOperationHistory)).greater(0);
            },
        );

    },
);

suite(
    "test getting operation history",
    func() {

        let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

        let mockPrincipal : Principal = Principal.fromText("un4fu-tqaaa-aaaab-qadjq-cai");
        let mockAmount : Nat64 = 100_000_000;
        let mockNeuronId : Nat64 = 4829694856491667492;
        let mockBlockchainFee : Nat64 = 10_000;

        // log 100 operations
        for (i in Iter.range(0, 99)) {
            if (i % 2 == 0) {
                ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({ staker = mockPrincipal; amount_e8s = mockAmount; blockchain_fee = mockBlockchainFee }));
            } else {
                ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({ staker = mockPrincipal; amount_e8s = mockAmount; neuron_id = mockNeuronId; blockchain_fee = mockBlockchainFee }));
            };
        };

        let #ok({ total; operations }) = Operations.getOperationHistory(_mockOperationHistory, 0, 10) else return assert (false);

        test(
            "fetches correct amount of operations",
            func() {
                expect.nat(operations.size()).equal(10);
            },
        );

        test(
            "operations are not null",
            func() {
                for (op in operations.vals()) {
                    expect.bool(op == null).isFalse();
                };
            },
        );

        test(
            "correct calculation of real length",
            func() {
                switch (Operations.getOperationHistory(_mockOperationHistory, total - 5, 10)) {
                    case (#ok({ total; operations })) {
                        expect.nat(operations.size()).equal(5);
                    };
                    case _ { return assert (false) };
                };
            },
        );

        test(
            "returns empty if less entries available than requested length",
            func() {
                switch (Operations.getOperationHistory(_mockOperationHistory, total, 10)) {
                    case (#ok({ total; operations })) {
                        expect.nat(operations.size()).equal(0);
                    };
                    case _ { return assert (false) };
                };
            },
        );

        test(
            "returns all entries",
            func() {
                switch (Operations.getOperationHistory(_mockOperationHistory, 0, total)) {
                    case (#ok({ total; operations })) {
                        expect.nat(operations.size()).equal(total);
                    };
                    case _ { return assert (false) };
                };
            },
        );

    },
);

suite(
    "test getting latest reward timer",
    func() {

        let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

        let SPAWN_REWARD_TIMER_DURATION_NANOS : Nat64 = (24 * 60 * 60 * 1_000_000_000); // 24 hours

        test(
            "returns null timer",
            func() {
                let timer = Operations.getLatestRewardTimer(_mockOperationHistory);

                expect.bool(timer == null).isTrue();
            },
        );

        test(
            "returns latest timer",
            func() {
                // log 10 timer
                for (i in Iter.range(1, 10)) {
                    ignore Operations.logOperation(_mockOperationHistory, #RewardTimer({ timer_id = i; timer_duration_nanos = SPAWN_REWARD_TIMER_DURATION_NANOS }));
                };

                let ?{ timer_id } = Operations.getLatestRewardTimer(_mockOperationHistory) else return;

                expect.option(?timer_id, Nat.toText, Nat.equal).equal(?10);
            },
        );

    },
);

suite(
    "test getting prize neurons",
    func() {

        let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

        let mockPrincipal : Principal = Principal.fromText("un4fu-tqaaa-aaaab-qadjq-cai");
        let mockAmount : Nat64 = 100_000_000;
        let mockNeuronId : Nat64 = 4829694856491667492;
        let mockProtocolFee : Nat64 = 10_000;

        ignore Operations.logOperation(_mockOperationHistory, #SpawnReward({ neuron_id = mockNeuronId; winner = mockPrincipal; maturity_e8s = 100_000_000 }));

        test(
            "correct prize neurons",
            func() {
                // all prize neurons should be 1:
                let allNeurons = Operations.getStakerPrizeNeurons(_mockOperationHistory, mockPrincipal);
                expect.nat(allNeurons.size()).equal(1);

                // there should be no claimed neurons:
                let claimedNeuronsBefore = Operations.getStakerClaimedPrizeNeurons(_mockOperationHistory, mockPrincipal);
                expect.nat(claimedNeuronsBefore.size()).equal(0);

                // disburse a prize
                ignore Operations.logOperation(_mockOperationHistory, #DisburseReward({ neuron_id = mockNeuronId; winner = mockPrincipal; amount = mockAmount; protocol_fee = mockProtocolFee }));

                // claimed neurons should now be 1:
                let claimedNeuronsAfter = Operations.getStakerClaimedPrizeNeurons(_mockOperationHistory, mockPrincipal);
                expect.nat(claimedNeuronsAfter.size()).equal(1);

                // neurons should have the corret owners:
                expect.bool(Operations.assertCallerWonPrize(_mockOperationHistory, mockPrincipal, mockNeuronId)).isTrue();
                expect.bool(Operations.assertCallerWonPrize(_mockOperationHistory, Principal.fromText("x5xyv-ziqqq-aaaab-qadjq-cai"), mockNeuronId)).isFalse();
            },
        );
    },
);

suite(
    "test getting current stakers",
    func() {

        let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

        let mockPrincipalsAndAmounts : [(Text, Nat64)] = [
            ("r6gcn-ysbbb-cccac-zlekr-hai", 10_000_000_000), // 10 ICP
            ("2jcrw-waddd-ddded-vmpft-oai", 64_000_000_000), // 64 ICP
            ("q4tvz-2zeaa-aaafg-fnjqr-nai", 5_000_000_000), // 5 ICP
            ("l5p4m-l2ggg-hhhbh-slrjq-pai", 20_000_000_000), // 20 ICP
            ("mdi57-tdhhh-iiiic-gdpkq-wai", 32_000_000_000), // 32 ICP
            ("yy6u5-sbejj-jjjjd-bwclq-lai", 50_000_000_000), // 50 ICP
            ("kobwd-kkkkk-kkkke-xzfjq-zai", 1_000_000_000), // 1 ICP
            ("hps3k-y7uuu-llllf-nhmrq-gai", 8_000_000_000), // 8 ICP
            ("7ttao-7gvvv-mmmmg-rbnpq-bai", 100_000_000_000), // 100 ICP
            ("f43vs-djwww-wnnnh-tjqkq-yai", 16_000_000_000), // 16 ICP
        ];
        let mockBlockchainFee : Nat64 = 10_000;
        let mockNeuronId : Nat64 = 4829694856491667492;

        test(
            "correct current stakers",
            func() {
                for ((mockUser, mockAmount) in mockPrincipalsAndAmounts.vals()) {
                    ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({ staker = Principal.fromText(mockUser); amount_e8s = mockAmount; blockchain_fee = mockBlockchainFee }));
                };

                // there should be 10 current stakers:
                expect.nat(Operations.getCurrentStakers(_mockOperationHistory).size()).equal(10);

                // make withdrawals
                for ((mockUser, mockAmount) in mockPrincipalsAndAmounts.vals()) {
                    ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({ staker = Principal.fromText(mockUser); neuron_id = mockNeuronId; amount_e8s = mockAmount - mockBlockchainFee; blockchain_fee = mockBlockchainFee }));
                };

                // there should be 0 current stakers:
                expect.nat(Operations.getCurrentStakers(_mockOperationHistory).size()).equal(0);
            },
        );

    },
);
