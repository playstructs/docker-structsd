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

    echo "Initialing the Reactor Files"
    structsd init "$STRUCTS_MONIKER"

    echo "Updating config.toml to accept outside connections"
    sed -i 's#tcp://127.0.0.1:26657#tcp://0.0.0.0:26657#' $STRUCTS_PATH/config/config.toml

    structsd comet show-validator > $STRUCTS_REACTOR_PUBLIC_SHARE/reactor_pub_key.json

    cp $STRUCTS_PATH/config/priv_validator_key.json $STRUCTS_REACTOR_BACKUP/

    touch $STRUCTS_PATH/status/reactor

  fi
fi

exit 0