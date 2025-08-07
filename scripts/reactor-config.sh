#!/usr/bin/env bash

if ! [ -f $STRUCTS_PATH/status/network ]; then
  echo "Network needs to be configured first"
  exit 1
fi

if [ -f $STRUCTS_PATH/status/reactor ]; then
  echo "Reactor already initialized"
  exit 0
else
  STRUCTS_PREVIOUS_CHAIN_ID=$(cat $STRUCTS_PATH/status/network)
  if [ "$STRUCTS_PREVIOUS_CHAIN_ID" != "$STRUCTS_CHAIN_ID" ]; then
    echo "Network needs to be configured first"
    exit 1
  else

    mv /root/.structs/config/genesis.json /root/genesis.json.tmp

    echo "Initialing the Reactor Files"
    structsd init "$STRUCTS_MONIKER"

    mv /root/genesis.json.tmp /root/.structs/config/genesis.json

    echo "Updating config.toml to accept outside connections"
    sed -i 's#tcp://127.0.0.1:26657#tcp://0.0.0.0:26657#' $STRUCTS_PATH/config/config.toml

    structsd comet show-validator > $STRUCTS_REACTOR_SHARE/reactor_pub_key.json
    structsd comet show-address > $STRUCTS_REACTOR_SHARE/reactor_address

    cp $STRUCTS_PATH/config/priv_validator_key.json $STRUCTS_REACTOR_BACKUP/priv_validator_key.json

    touch $STRUCTS_PATH/status/reactor

  fi
fi

exit 0