#!/usr/bin/env bash
# Simple script to run distributed tests with proper settings

# Check if Erlang is available
if ! command -v erl &> /dev/null
then
    echo "Error: Erlang is not installed or not in the PATH"
    exit 1
fi

# Check if Elixir is available
if ! command -v elixir &> /dev/null
then
    echo "Error: Elixir is not installed or not in the PATH"
    exit 1
fi

# Ensure epmd is running
epmd -daemon

# Set environment variable to enable distributed tests
export ENABLE_DISTRIBUTED_TESTS=true

# Set cookie for distributed Erlang
export ERL_DIST_COOKIE=automata_test

# Set name for the Elixir node
export NODE_NAME=automata_primary@127.0.0.1

# Run the tests with distributed flag
echo "Running distributed tests..."
echo "----------------------------"
elixir --name $NODE_NAME --cookie $ERL_DIST_COOKIE -S mix test --include distributed "$@"