# 
# Deploy canisters:
# 

# dfx deploy --network ic neuronpool
# dfx canister --network ic install --mode reinstall neuronpool
# dfx canister --network ic status neuronpool

# 
# useful canister commands:
# 

# dfx canister --network ic call neuronpool get_protocol_information
# dfx canister --network ic call neuronpool get_operation_history
# dfx canister --network ic call neuronpool get_neuron_information
# dfx canister --network ic call neuronpool get_main_neuron

# dfx canister --network ic call neuronpool controller_get_canister_memory