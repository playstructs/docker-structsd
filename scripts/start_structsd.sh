#!/usr/bin/env bash

# launch the Structs blockchain
if [[ $LAUNCH_METHOD == "AUTOMATIC" ]];
then
    echo "Launching chain without delay...";

    # Setup Chain
    /src/structs/configure_chain.sh

fi

# Check for the Ready file
while [ ! -f /var/structs/chian/ready ]
do
	echo "Waiting for chain to the ready..."
	sleep 1
done

# Check for the Indexer file
while [ ! -f /var/structs/chain/indexing ]
do
	echo "Waiting for indexer configuration..."
	sleep 1
done

echo "Launching Chain..."
/root/go/bin/structsd start --home /var/structs/chain