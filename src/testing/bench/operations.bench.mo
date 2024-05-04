import Bench "mo:bench";
import Nat "mo:base/Nat";
import T "../../types";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Vector "mo:vector";
import Operations "../../operations";

module {
    public func init() : Bench.Bench {
        let bench = Bench.Bench();

        bench.name("Operation history performance");
        bench.description("Testing the performance of the operation history vector");

        bench.rows(["Operation history"]);
        bench.cols(["10", "10000", "100000"]);

        bench.runner(
            func(row, col) {
                let _mockOperationHistory : T.OperationHistory = Vector.new<T.Operation>();
                let mockPrincipal : Principal = Principal.fromText("un4fu-tqaaa-aaaab-qadjq-cai");
                let mockAmount : Nat64 = 100_000_000;
                let mockNeuronId : Nat64 = 4829694856491667492;

                let ?n = Nat.fromText(col);

                if (row == "Operation history") {
                    for (i in Iter.range(1, n)) {
                        if (i % 2 == 0) {
                            ignore Operations.logOperation(_mockOperationHistory, #StakeTransfer({ staker = mockPrincipal; amount_e8s = mockAmount }));
                        } else {
                            ignore Operations.logOperation(_mockOperationHistory, #StakeWithdrawal({ staker = mockPrincipal; amount_e8s = mockAmount; neuron_id = mockNeuronId }));
                        };
                    };
                };
            }
        );

        bench;
    };
};
