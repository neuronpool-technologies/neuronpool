# Number of times to run the command
num_iterations=1000

# Loop to run the command multiple times
for ((i=1; i<=num_iterations; i++))
do
  echo "Running iteration $i/$num_iterations"
  dfx canister --network ic call neuronpool controller_add_mock_data
  if [ $? -ne 0 ]; then
    echo "Error encountered during iteration $i. Exiting."
    exit 1
  fi
done

echo "All iterations completed successfully."
echo "Canister heap data result:"
dfx canister --network ic call neuronpool controller_get_canister_heap_data
