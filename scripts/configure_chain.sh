#!/usr/bin/env bash
# Prepare to launch chain

echo "Checking Chain Configuration"
# Check for the ready file marker
# if it exists, don't do it again
if [ ! -f /var/structs/ready ]
then
  echo "Configuring structsd Chain"
  if [ ! -f /var/structs/chain/config/config.toml ]
  then

    echo "Building latest structsd"
    git clone https://github.com/playstructs/structsd.git
    cd structsd
    ignite chain build


    echo "Initializing chain because nothing's there"
    /root/go/bin/structsd init --home /var/structs/chain

    cd ..
    git clone --depth 1 --branch $NETWORK_VERSION https://github.com/playstructs/structs-networks.git
    cp structs-network/genesis.json /var/structs/chain/config/genesis.json
    cp structs-network/addrbook.json /var/structs/chain/config/addrbook.json


  fi

  echo "Updating config.toml to point to postgres"
  echo $NODE_INDEXER_PG_CONNECTION
  sed -i 's/indexer = "kv"/indexer = "pg"/' /var/structs/chain/config/config.toml
  sed -i "s/psql-conn = \"\"/psql-conn = \"$NODE_INDEXER_PG_CONNECTION\"/" /var/structs/chain/config/config.toml

	touch /var/structs/ready

fi
