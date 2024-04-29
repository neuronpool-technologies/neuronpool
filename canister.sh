# 
# Deploy canisters:
# 

# dfx deploy --network ic neuronpool
# dfx deploy --network ic neuronpool_frontend
# dfx canister --network ic install --mode reinstall neuronpool
# dfx canister --network ic status neuronpool

# 
# canister test functions:
# 

# dfx canister --network ic call neuronpool get_canister_accounts