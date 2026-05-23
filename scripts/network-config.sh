#!/usr/bin/env bash

echo "Checking Chain Configuration"

mkdir -p "$STRUCTS_PATH/status"

# structsd init/start may create config/ before this script runs; do not rely on
# "config directory missing" as the seed signal (see apply-docker-config.sh).
bash /root/scripts/apply-docker-config.sh

STRUCTS_PREVIOUS_CHAIN_ID=""
if [ -f "$STRUCTS_PATH/status/network" ]; then
  STRUCTS_PREVIOUS_CHAIN_ID=$(cat "$STRUCTS_PATH/status/network")
fi

if [ "$STRUCTS_PREVIOUS_CHAIN_ID" != "$STRUCTS_CHAIN_ID" ]; then
  echo "Current Chain: ${STRUCTS_CHAIN_ID}"
  echo "Previous Chain: ${STRUCTS_PREVIOUS_CHAIN_ID}"

  # Re-apply docker templates after a chain migration.
  rm -f "$STRUCTS_PATH/status/docker-config-v1"
  bash /root/scripts/apply-docker-config.sh

  echo "Cloning network details from branch ${STRUCTS_NETWORK_VERSION}"
  git clone --depth 1 --branch "$STRUCTS_NETWORK_VERSION" https://github.com/playstructs/structs-networks.git
  cp structs-networks/genesis.json "$STRUCTS_PATH/config/genesis.json"
  cp structs-networks/addrbook.json "$STRUCTS_PATH/config/addrbook.json"

  echo "Updating client.toml with the correct Chain ID ${STRUCTS_CHAIN_ID}"
  sed -i 's/chain-id.*.$/chain-id = "'"$STRUCTS_CHAIN_ID"'"/' "$STRUCTS_PATH/config/client.toml"

  #scorched universe
  echo "Deleting all old data since the chain completely chainged"
  rm -rf "$STRUCTS_PATH/data"

  # TODO Fix this sledge hammer
  # Just get the system working again.
  #echo "Snapshot for 0.16.0 loading"
  #structsd snapshots load /root/snapshots/392500-3.tar.gz --home $STRUCTS_PATH
  #echo "Snapshot for 0.16.0 restoring"
  #structsd snapshots restore 392500 3 --home $STRUCTS_PATH

  echo "$STRUCTS_CHAIN_ID" > "$STRUCTS_PATH/status/network"
else
  echo "Things already look great. Nothing to do. Go Structs!"
fi

echo "Network Configuration Process Completed Successfully"
exit 0
