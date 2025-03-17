#!/usr/bin/env bash
# Prepare to launch chain


# Check for the ready file marker
# if it exists, don't do it again 
if [ ! -f /var/structs/chain/ready ]
then
	touch /var/structs/chain/ready
fi

