#!/usr/bin/env bash

# launch the Structs blockchain

# Setup Chain
/src/structs/configure_chain.sh

# Setup Indexer
/src/structs/configure_indexer.sh

# Check for the Ready file
while [ ! -f /var/structs/ready ]
do
	echo "Waiting for chain to the ready..."
	sleep 60
done
echo "Launching Chain..."
/root/go/bin/structsd start --home /var/structs/chain --chain-id $NETWORK_CHAIN_ID


