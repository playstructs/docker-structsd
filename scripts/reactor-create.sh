#!/usr/bin/env bash

if ! [ -f $STRUCTS_REACTOR_PUBLIC_SHARE/reactor_pub_key.json ]; then
  echo "Reactor needs to be initialized"
  exit 1
fi

STRUCTS_PREVIOUS_CHAIN_ID=$(cat $STRUCTS_PATH/status/network)
if [ "$STRUCTS_PREVIOUS_CHAIN_ID" != "$STRUCTS_CHAIN_ID" ]; then
  echo "Network needs to be reconfigured first"
  exit 1
else

  cp ~/config/client/client.toml $STRUCTS_PATH/config/

  echo "Updating client.toml with the correct Chain ID"
  sed -i 's/chain-id.*.$/chain-id = "'$STRUCTS_CHAIN_ID'"/' $STRUCTS_PATH/config/client.toml

  echo "Updating client.toml with the correct host"
  sed -i 's/node = "tcp://localhost:26657"$/node = "tcp://'$STRUCTSD_HOST':26657"/' $STRUCTS_PATH/config/client.toml

  STRUCTS_VALIDATOR_ADDRESS=$(cat $STRUCTS_REACTOR_PUBLIC_SHARE/reactor_address)
  STRUCTS_VALIDATOR_COUNT=$(structsd query staking validator $STRUCTS_VALIDATOR_ADDRESS 2>/dev/null | jq length | awk 'NF || $0 == "" { print ($0 == "" ? 0 : $0) } END { if (NR == 0) print 0 }')

  if [ "$STRUCTS_VALIDATOR_COUNT" -eq 0 ]; then
    echo "The Reactor is not found onchain, creating..."

    echo "Setup Guild Admin Key"
    echo "$STRUCTS_GUILD_MNEMONIC" | structsd keys add guild_admin --recover

    echo "Reactor Creation transaction"

    # TODO setup validator.json
    # TODO Update this with the file
    structsd tx staking create-validator --from guild_admin

    sleep 10
    echo "Checking for confirmation..."

    STRUCTS_VALIDATOR_COUNT=$(structsd query staking validator $STRUCTS_VALIDATOR_ADDRESS 2>/dev/null | jq length | awk 'NF || $0 == "" { print ($0 == "" ? 0 : $0) } END { if (NR == 0) print 0 }')
    if [ "$STRUCTS_VALIDATOR_COUNT" -eq 0 ]; then
      echo "Validator creation seems to have failed"
      exit 1
    fi

  else
    echo "Reactor is already onchain"
  fi
fi


exit 0