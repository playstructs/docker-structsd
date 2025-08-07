#!/usr/bin/env bash


echo "Checking Chain Configuration"
if [[ ! -d $STRUCTS_PATH/config ]]; then
    echo "No config found, setting defaults"
    mkdir -p $STRUCTS_PATH/config
    cp /root/config/default/* $STRUCTS_PATH/config/
fi

mkdir -p $STRUCTS_PATH/status

STRUCTS_PREVIOUS_CHAIN_ID=$(cat $STRUCTS_PATH/status/network)
if [ "$STRUCTS_PREVIOUS_CHAIN_ID" != "$STRUCTS_CHAIN_ID" ]; then
  echo "Current Chain: ${STRUCTS_CHAIN_ID}"
  echo "Previous Chain: ${STRUCTS_PREVIOUS_CHAIN_ID}"

  echo "Cloning network details from branch ${STRUCTS_NETWORK_VERSION}"
  git clone --depth 1 --branch $STRUCTS_NETWORK_VERSION https://github.com/playstructs/structs-networks.git
  cp structs-networks/genesis.json $STRUCTS_PATH/config/genesis.json
  cp structs-networks/addrbook.json $STRUCTS_PATH/config/addrbook.json

  echo "Updating client.toml with the correct Chain ID ${STRUCTS_CHAIN_ID}"
  sed -i 's/chain-id.*.$/chain-id = "'$STRUCTS_CHAIN_ID'"/' $STRUCTS_PATH/config/client.toml

  #scorched universe
  echo "Deleting all old data since the chain completely chainged"
  rm -rf $STRUCTS_PATH/data

  echo $STRUCTS_CHAIN_ID > $STRUCTS_PATH/status/network
else
  echo "Things already look great. Nothing to do. Go Structs!"
fi

echo "Network Configuration Process Completed Successfully"
exit 0