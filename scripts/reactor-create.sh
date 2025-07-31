#!/usr/bin/env bash

if ! [ -f $STRUCTS_PATH/status/network ]; then
  echo "Network needs to be configured first"
  exit 1
fi

if [ -f $STRUCTS_PATH/status/reactor ]; then
  echo "Reactor needs to be initialized"
  exit 1
fi

STRUCTS_PREVIOUS_CHAIN_ID=$(cat $STRUCTS_PATH/status/network)
if [ "$STRUCTS_PREVIOUS_CHAIN_ID" != "$STRUCTS_CHAIN_ID" ]; then
  echo "Network needs to be reconfigured first"
  exit 1
else

  # TODO Move a special client.toml into play

  echo "$STRUCTS_GUILD_MNEMONIC" | structsd keys add guild_admin --recover

  echo "Creating the Reactor on-chain"

  # TODO setup validator.json
  # TODO Update this with the file
  structsd tx staking create-validator --from guild_admin

  touch $STRUCTS_PATH/status/reactor

fi


exit 0