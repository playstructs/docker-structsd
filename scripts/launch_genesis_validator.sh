#!/usr/bin/env bash
# Prepare to launch chain


# Check for the ready file marker
# if it exists, don't do it again 
if [ ! -f /var/structs/ready ]
then
	read -p "What is the network number? " network

	ignite network chain prepare $network --home /var/structs/chain  --keyring-dir /var/structs/accounts

	echo "There was probably a big error above, but it's probably fine"


  echo "Configuring structsd Chain"

  echo "Building latest structsd"
  git clone https://github.com/playstructs/structsd.git
  cd structsd
  ignite chain build

  cd ..
  git clone --depth 1 --branch $NETWORK_VERSION https://github.com/playstructs/structs-networks.git
  cp structs-networks/genesis.json /var/structs/chain/config/genesis.json
  cp structs-networks/addrbook.json /var/structs/chain/config/addrbook.json

  cat /var/structs/chain/config/client.toml
  echo "Updating client.toml"
  sed -i 's/chain-id.*.$/chain-id = "'$NETWORK_CHAIN_ID'"/' /var/structs/chain/config/client.toml

  # Setup Indexer
  /src/structs/configure_indexer.sh

	touch /var/structs/ready

fi


