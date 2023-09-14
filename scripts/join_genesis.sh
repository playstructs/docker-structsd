#!/usr/bin/env bash
# Initialize and Join the Genesis 


# Check for the ready file marker
# if it exists, don't do it again 
if [ ! -f /var/structs/ready ]
then
	read -p "What is the network number? " network

	echo "Initializing chain #$network locally"
	ignite network chain init $network --home /var/structs/chain  --keyring-dir /var/structs/accounts

	echo "Joining chain Genesis..."
	ignite network chain join $network --amount 1000001alpha --home /var/structs/chain  --keyring-dir /var/structs/accounts

	echo "Chain should be ready unless something above failed"
	echo "Wait for instruction to run launch_genesis_validator.sh"
fi





