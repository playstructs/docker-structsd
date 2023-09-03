#!/usr/bin/env bash
# Prepare to launc chain


# Check for the ready file marker
# if it exists, don't do it again 
if [ ! -f /var/chain/ready ]
then
	read -p "What is the network number? " network

	ignite network chain prepare $network --home /var/structs/chain  --keyring-dir /var/structs/accounts

	touch /var/chain/ready 
	
fi

