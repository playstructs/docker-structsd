#!/usr/bin/env bash

# launch the Structs blockchain

# Check for the Ready file
while [ ! -f /var/structs/ready ]
do
	echo "Waiting for chain to the ready..."
	sleep 60
done

/root/go/bin/structsd start --home /var/structs/chain


