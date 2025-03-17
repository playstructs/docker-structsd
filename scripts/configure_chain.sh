#!/usr/bin/env bash
# Prepare to launch chain

echo "Checking Chain Configuration"
# Check for the ready file marker
# if it exists, don't do it again
if [ ! -f /var/structs/chain/ready ]
then
  echo "Configuring structsd Chain"
  if [ ! -f /var/structs/chain/config/config.toml ]
  then

    if [[ $NETWORK_TYPE == "localtestnet" ]];
    then
      echo "Initializing local testnet"
      ignite chain init --home /var/structs/chain
      sleep 30

    else
      echo "Initializing chain because nothing's there"
      /root/go/bin/structsd init $MONIKER --home /var/structs/chain

      cd ..
      echo "Cloning network details"
      echo $NETWORK_VERSION
      git clone --depth 1 --branch $NETWORK_VERSION https://github.com/playstructs/structs-networks.git
      cp structs-networks/genesis.json /var/structs/chain/config/genesis.json
      cp structs-networks/addrbook.json /var/structs/chain/config/addrbook.json


    fi

    echo "Updating client.toml with the correct Chain ID"
    sed -i 's/chain-id.*.$/chain-id = "'$NETWORK_CHAIN_ID'"/' /var/structs/chain/config/client.toml

    echo "Updating config.toml to accept outside connections"
    sed -i 's#tcp://127.0.0.1:26657#tcp://0.0.0.0:26657#' /var/structs/chain/config/config.toml

    # Setup Indexer
    /src/structs/configure_indexer.sh
  fi

  echo "structsd is READY"
	touch /var/structs/chain/ready

fi
