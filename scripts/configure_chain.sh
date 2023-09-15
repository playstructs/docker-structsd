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
    /root/go/bin/structsd init $MONIKER --home /var/structs/chain

    cd ..
    git clone --depth 1 --branch 73 https://github.com/playstructs/structs-networks.git
    cp structs-networks/genesis.json /var/structs/chain/config/genesis.json
    cp structs-networks/addrbook.json /var/structs/chain/config/addrbook.json

    echo "Updating client.toml"
    sed -i 's/chain-id.*.$/chain-id = "'$NETWORK_CHAIN_ID'"/' /var/structs/chain/config/client.toml

  fi

	touch /var/structs/ready

fi
