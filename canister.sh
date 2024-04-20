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

# dfx canister --network ic call NeuronPool controller_get_canister_accounts
# dfx canister --network ic call NeuronPool controller_canister_transfer_legacy '("<address>", <amount>)'
# dfx canister --network ic call NeuronPool controller_canister_icrc1_transfer '("<ICRC-1 Account>", <amount>)'