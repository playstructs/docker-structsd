#!/usr/bin/env bash
# Idempotent docker-specific config overlay. Safe to run on every container start.
# structsd init/start creates config/ with localhost bindings before network-config
# can copy image defaults; this script enforces the docker template values.

set -euo pipefail

: "${STRUCTS_PATH:=/root/.structs}"
: "${STRUCTS_MIN_GAS_PRICES:=0ualpha}"
: "${STRUCTS_API_ADDRESS:=tcp://0.0.0.0:1317}"

DEFAULTS_DIR="/root/config/default"
CONFIG_DIR="$STRUCTS_PATH/config"
MARKER="$STRUCTS_PATH/status/docker-config-v1"

overlay_defaults() {
  if [ ! -d "$DEFAULTS_DIR" ]; then
    echo "apply-docker-config: no $DEFAULTS_DIR, skipping template overlay"
    return
  fi

  mkdir -p "$CONFIG_DIR"
  echo "apply-docker-config: overlaying app.toml from image defaults"
  cp -f "$DEFAULTS_DIR/app.toml" "$CONFIG_DIR/app.toml"
  if [ ! -f "$CONFIG_DIR/client.toml" ]; then
    cp -f "$DEFAULTS_DIR/client.toml" "$CONFIG_DIR/client.toml"
  fi
}

apply_app_toml() {
  local app_toml="$CONFIG_DIR/app.toml"
  [ -f "$app_toml" ] || return 0

  if grep -qE '^minimum-gas-prices[[:space:]]*=' "$app_toml"; then
    sed -i 's/^minimum-gas-prices = .*/minimum-gas-prices = "'"${STRUCTS_MIN_GAS_PRICES}"'"/' "$app_toml"
  fi

  if grep -qE '^address[[:space:]]*=' "$app_toml"; then
    sed -i '/^\[api\]/,/^\[/ s|^address = .*|address = "'"${STRUCTS_API_ADDRESS}"'"|' "$app_toml"
  fi

  sed -i '/^\[api\]/,/^\[/ s/^enable = .*/enable = true/' "$app_toml"
}

apply_comet_config() {
  local config_toml="$CONFIG_DIR/config.toml"
  [ -f "$config_toml" ] || return 0

  sed -i '/^\[rpc\]/,/^\[/ s|^laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|' "$config_toml"
}

mkdir -p "$STRUCTS_PATH/status"

if [ ! -f "$CONFIG_DIR/app.toml" ]; then
  overlay_defaults
elif [ ! -f "$MARKER" ]; then
  echo "apply-docker-config: existing config detected (likely structsd init); applying docker templates"
  overlay_defaults
fi

apply_app_toml
apply_comet_config
touch "$MARKER"
