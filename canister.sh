# 
# Deploy canisters:
# 

# dfx deploy --network ic NeuronPool
# dfx deploy --network ic neuronpool_frontend
# dfx canister --network ic install --mode reinstall NeuronPool
# dfx canister --network ic status NeuronPool

# 
# canister test functions:
# 

# dfx canister --network ic call NeuronPool get_canister_accounts