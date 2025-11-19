#!/usr/bin/env bash

if ! [ -f $STRUCTS_PATH/status/network ]; then
  echo "Network needs to be configured first"
  exit 1
fi

if ! [ -f $STRUCTS_PATH/status/network_reactor ]; then
  echo "Performing initial Reactor configuration"

  echo "Moving Reactor specific configuration files into place"
  cp /root/config/reactor/* $STRUCTS_PATH/config/

  touch $STRUCTS_PATH/status/network_reactor
  echo "Node successfully configured for reactor"
fi

if [ -f $STRUCTS_PATH/status/reactor ]; then
  echo "Reactor already initialized"
  exit 0
else
  STRUCTS_PREVIOUS_CHAIN_ID=$(cat $STRUCTS_PATH/status/network)
  if [ "$STRUCTS_PREVIOUS_CHAIN_ID" != "$STRUCTS_CHAIN_ID" ]; then
    echo "Network needs to be configured first"
    echo "Current Chain: ${STRUCTS_CHAIN_ID}"
    echo "Previous Chain: ${STRUCTS_PREVIOUS_CHAIN_ID}"
    exit 1
  else
    if [ -f $STRUCTS_REACTOR_BACKUP/priv_validator_key.json ]; then
      echo "Reactor already configured 😎"
    else
      mv /root/.structs/config/genesis.json /root/genesis.json.tmp

      echo "Initialing the Reactor Files"
      structsd init "$STRUCTS_MONIKER"

      mv /root/genesis.json.tmp /root/.structs/config/genesis.json

      structsd comet show-validator > $STRUCTS_REACTOR_SHARE/reactor_pub_key.json

      cp $STRUCTS_PATH/config/priv_validator_key.json $STRUCTS_REACTOR_BACKUP/priv_validator_key.json
    fi

    touch $STRUCTS_PATH/status/reactor
  fi
fi

echo "Reactor Configuration Process Completed Successfully"

exit 0