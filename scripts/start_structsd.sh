#!/usr/bin/env bash

# launch the Structs blockchain
if [[ $LAUNCH_METHOD == "AUTOMATIC" ]];
then
    echo "Launching chain without delay...";

    # Setup Chain
    /src/structs/configure_chain.sh

    # Setup Indexer
    /src/structs/configure_indexer.sh
fi

# Check for the Ready file
while [ ! -f /var/structs/ready ]
do
	echo "Waiting for chain to the ready..."
	sleep 60
done
echo "Launching Chain..."
/root/go/bin/structsd start --home /var/structs/chain --log_level trace


