import { test; expect; suite } "mo:test/async";
import T "../../src/types";
import Vector "mo:vector";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Operations "../../src/operations";
import Iter "mo:base/Iter";
import Prize "../../src/prize";

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

let mockBlockchainFee : Nat64 = 10_000; // 0.0001 ICP

await suite(
    "test generating a random threshold",
    func() : async () {

        await test(
            "random threshold is not null",
            func() : async () {

                let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

                for ((mockUser, mockAmount) in mockPrincipalsAndAmounts.vals()) {
                    ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({ staker = Principal.fromText(mockUser); amount_e8s = mockAmount; blockchain_fee = mockBlockchainFee }));
                };

                let totalStakeAmount = Operations.getTotalStakeAmount(_mockOperationHistory);
                Debug.print("Total stake amount e8s: " # debug_show totalStakeAmount);

                let randomThreshold = await Prize.generateRandomThreshold(totalStakeAmount);
                Debug.print("Random threshold e8s: " # debug_show randomThreshold);

                expect.option(randomThreshold, Nat64.toText, Nat64.equal).isSome();
            },
        );

        await test(
            "random threshold is within range (small amount of ICP)",
            func() : async () {

                let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

                for ((mockUser, mockAmount) in mockPrincipalsAndAmounts.vals()) {
                    ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({ staker = Principal.fromText(mockUser); amount_e8s = mockAmount; blockchain_fee = mockBlockchainFee }));
                };

                let totalStakeAmount = Operations.getTotalStakeAmount(_mockOperationHistory);
                Debug.print("Total stake amount e8s: " # debug_show totalStakeAmount);

                let ?randomThreshold = await Prize.generateRandomThreshold(totalStakeAmount) else return;
                Debug.print("Random threshold e8s: " # debug_show randomThreshold);

                expect.nat64(randomThreshold).lessOrEqual(totalStakeAmount);
            },
        );

        await test(
            "random threshold is within range (large amount of ICP)",
            func() : async () {
                let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

                for (i in Iter.range(0, 999)) {
                    for ((mockUser, mockAmount) in mockPrincipalsAndAmounts.vals()) {
                        ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({ staker = Principal.fromText(mockUser); amount_e8s = mockAmount; blockchain_fee = mockBlockchainFee }));
                    };
                };

                let totalStakeAmount = Operations.getTotalStakeAmount(_mockOperationHistory);
                Debug.print("Total stake amount e8s: " # debug_show totalStakeAmount);

                let ?randomThreshold = await Prize.generateRandomThreshold(totalStakeAmount) else return;
                Debug.print("Random threshold e8s: " # debug_show randomThreshold);

                expect.nat64(randomThreshold).lessOrEqual(totalStakeAmount);
            },
        );

        await test(
            "random threshold is within range (extremely large amount of ICP)",
            func() : async () {
                let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

                // add 100,000 ICP
                for (i in Iter.range(0, 9999)) {
                    for ((mockUser, mockAmount) in mockPrincipalsAndAmounts.vals()) {
                        ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({ staker = Principal.fromText(mockUser); amount_e8s = mockAmount; blockchain_fee = mockBlockchainFee }));
                    };
                };

                let totalStakeAmount = Operations.getTotalStakeAmount(_mockOperationHistory);
                Debug.print("Total stake amount e8s: " # debug_show totalStakeAmount);

                let ?randomThreshold = await Prize.generateRandomThreshold(totalStakeAmount) else return;
                Debug.print("Random threshold e8s: " # debug_show randomThreshold);

                expect.nat64(randomThreshold).lessOrEqual(totalStakeAmount);
            },
        );
    },
);

await suite(
    "test weighted selection algorithm",
    func() : async () {

        await test(
            "weighted selection chooses the correct winner (small amount of ICP)",
            func() : async () {
                let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

                for ((mockUser, mockAmount) in mockPrincipalsAndAmounts.vals()) {
                    ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({ staker = Principal.fromText(mockUser); amount_e8s = mockAmount; blockchain_fee = mockBlockchainFee }));
                };

                let totalStakeAmount = Operations.getTotalStakeAmount(_mockOperationHistory);
                Debug.print("Total stake amount e8s: " # debug_show totalStakeAmount);

                let ?randomThreshold = await Prize.generateRandomThreshold(totalStakeAmount) else return;
                Debug.print("Random threshold e8s: " # debug_show randomThreshold);

                let winner = Prize.weightedSelection(_mockOperationHistory, randomThreshold);
                expect.option(winner, Principal.toText, Principal.equal).isSome();

                // expect the winner picked to be correct

                // call the get current stakers function
                let stakers = Operations.getCurrentStakers(_mockOperationHistory);

                var runningSum : Nat64 = 0;
                label lo for ((mockUser, mockAmount) in stakers.vals()) {
                    runningSum += mockAmount;

                    if (runningSum >= randomThreshold) {
                        expect.option(winner, Principal.toText, Principal.equal).equal(?mockUser);
                        break lo;
                    };
                };
            },
        );

        await test(
            "weighted selection chooses the correct winner (large amount of ICP)",
            func() : async () {
                let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();

                for (i in Iter.range(0, 9999)) {
                    for ((mockUser, mockAmount) in mockPrincipalsAndAmounts.vals()) {
                        ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({ staker = Principal.fromText(mockUser); amount_e8s = mockAmount; blockchain_fee = mockBlockchainFee }));
                    };
                };

                let totalStakeAmount = Operations.getTotalStakeAmount(_mockOperationHistory);
                Debug.print("Total stake amount e8s: " # debug_show totalStakeAmount);

                let ?randomThreshold = await Prize.generateRandomThreshold(totalStakeAmount) else return;
                Debug.print("Random threshold e8s: " # debug_show randomThreshold);

                let winner = Prize.weightedSelection(_mockOperationHistory, randomThreshold);
                expect.option(winner, Principal.toText, Principal.equal).isSome();

                // expect the winner picked to be correct

                // call the get current stakers function
                let stakers = Operations.getCurrentStakers(_mockOperationHistory);

                var runningSum : Nat64 = 0;
                label lo for ((mockUser, mockAmount) in stakers.vals()) {
                    runningSum += mockAmount;

                    if (runningSum >= randomThreshold) {
                        expect.option(winner, Principal.toText, Principal.equal).equal(?mockUser);
                        break lo;
                    };
                };
            },
        );
    },
);
