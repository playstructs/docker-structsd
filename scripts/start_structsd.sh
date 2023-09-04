#!/usr/bin/env bash

# launch the Structs blockchain


# Check for the Ready file
FILE=/var/chain/ready
while [ ! -f /var/chain/ready ]
do
	echo "Waiting for chain to the ready..."
	sleep 60
done

structsd start --home /var/structs/chain


