#!/usr/bin/env bash
# Configure chain data and docker-specific node settings (idempotent).
set -euo pipefail

: "${STRUCTS_PATH:=/root/.structs}"
: "${STRUCTS_MIN_GAS_PRICES:=0ualpha}"
: "${STRUCTS_API_ADDRESS:=tcp://0.0.0.0:1317}"

DEFAULTS_DIR="/root/config/default"
CONFIG_DIR="$STRUCTS_PATH/config"
DOCKER_CONFIG_MARKER="$STRUCTS_PATH/status/docker-config-v1"

apply_docker_config() {
  if [ -d "$DEFAULTS_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    if [ ! -f "$CONFIG_DIR/app.toml" ] || [ ! -f "$DOCKER_CONFIG_MARKER" ]; then
      if [ -f "$CONFIG_DIR/app.toml" ]; then
        echo "Replacing structsd-init app.toml with docker template"
      else
        echo "Seeding config from image defaults"
      fi
      cp -f "$DEFAULTS_DIR/app.toml" "$CONFIG_DIR/app.toml"
      if [ ! -f "$CONFIG_DIR/client.toml" ]; then
        cp -f "$DEFAULTS_DIR/client.toml" "$CONFIG_DIR/client.toml"
      fi
    fi
  else
    echo "No $DEFAULTS_DIR; skipping app.toml template overlay"
  fi

  if [ -f "$CONFIG_DIR/app.toml" ]; then
    sed -i 's/^minimum-gas-prices = .*/minimum-gas-prices = "'"${STRUCTS_MIN_GAS_PRICES}"'"/' \
      "$CONFIG_DIR/app.toml"
    sed -i '/^\[api\]/,/^\[/ s|^address = .*|address = "'"${STRUCTS_API_ADDRESS}"'"|' \
      "$CONFIG_DIR/app.toml"
    sed -i '/^\[api\]/,/^\[/ s/^enable = .*/enable = true/' "$CONFIG_DIR/app.toml"
  fi

  if [ -f "$CONFIG_DIR/config.toml" ]; then
    sed -i '/^\[rpc\]/,/^\[/ s|^laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|' \
      "$CONFIG_DIR/config.toml"
  fi

  touch "$DOCKER_CONFIG_MARKER"
}

echo "Checking Chain Configuration"
mkdir -p "$STRUCTS_PATH/status"
apply_docker_config

STRUCTS_PREVIOUS_CHAIN_ID=""
if [ -f "$STRUCTS_PATH/status/network" ]; then
  STRUCTS_PREVIOUS_CHAIN_ID=$(cat "$STRUCTS_PATH/status/network")
fi

if [ "$STRUCTS_PREVIOUS_CHAIN_ID" != "$STRUCTS_CHAIN_ID" ]; then
  echo "Current Chain: ${STRUCTS_CHAIN_ID}"
  echo "Previous Chain: ${STRUCTS_PREVIOUS_CHAIN_ID}"

  rm -f "$DOCKER_CONFIG_MARKER"
  apply_docker_config

  echo "Cloning network details from branch ${STRUCTS_NETWORK_VERSION}"
  git clone --depth 1 --branch "$STRUCTS_NETWORK_VERSION" https://github.com/playstructs/structs-networks.git
  cp structs-networks/genesis.json "$STRUCTS_PATH/config/genesis.json"
  cp structs-networks/addrbook.json "$STRUCTS_PATH/config/addrbook.json"

  echo "Updating client.toml with the correct Chain ID ${STRUCTS_CHAIN_ID}"
  sed -i 's/chain-id.*.$/chain-id = "'"$STRUCTS_CHAIN_ID"'"/' "$STRUCTS_PATH/config/client.toml"

  echo "Deleting all old data since the chain completely changed"
  rm -rf "$STRUCTS_PATH/data"

  echo "$STRUCTS_CHAIN_ID" > "$STRUCTS_PATH/status/network"
else
  echo "Chain unchanged; docker config applied"
fi

echo "Network Configuration Process Completed Successfully"
exit 0
