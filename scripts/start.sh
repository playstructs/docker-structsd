#!/usr/bin/env bash
set -euo pipefail

if ! [ -f "$STRUCTS_PATH/status/network" ]; then
  echo "Network needs to be configured first"
  exit 1
fi

# Defaults (also set in the Dockerfile ENV; re-asserted here so this script
# is safe to run standalone or with overridden envs).
: "${DAEMON_NAME:=structsd}"
: "${DAEMON_HOME:=$STRUCTS_PATH}"
: "${DAEMON_RESTART_AFTER_UPGRADE:=true}"
: "${DAEMON_ALLOW_DOWNLOAD_BINARIES:=false}"
: "${UNSAFE_SKIP_BACKUP:=true}"
: "${STRUCTS_UPGRADE_NAME:=v0.16.0}"

GENESIS_SRC="/opt/structs/cosmovisor/genesis/bin/structsd"
UPGRADE_SRC="/opt/structs/cosmovisor/upgrades/${STRUCTS_UPGRADE_NAME}/bin/structsd"

GENESIS_DST_DIR="$STRUCTS_PATH/cosmovisor/genesis/bin"
UPGRADE_DST_DIR="$STRUCTS_PATH/cosmovisor/upgrades/${STRUCTS_UPGRADE_NAME}/bin"

echo "Staging cosmovisor binaries into $STRUCTS_PATH/cosmovisor"
mkdir -p "$GENESIS_DST_DIR" "$UPGRADE_DST_DIR"

# Cosmovisor v1.7+ refuses to start unless $DAEMON_HOME/data already exists.
# The daemon itself populates this directory on first block; we just need it
# to exist (network-config.sh deletes it on chain-id changes).
mkdir -p "$STRUCTS_PATH/data"

# Idempotent install: keep image-baked binaries authoritative so an image
# bump propagates into existing volumes on next start.
install -m 0755 "$GENESIS_SRC" "$GENESIS_DST_DIR/structsd"
install -m 0755 "$UPGRADE_SRC" "$UPGRADE_DST_DIR/structsd"

# Migration safety: if this volume is already past the upgrade height
# (e.g. a prior manual binary swap before we adopted cosmovisor), make sure
# cosmovisor boots the upgrade binary instead of falling back to genesis/bin
# and crashing the 111b binary on unknown post-upgrade state.
UPGRADE_INFO="$STRUCTS_PATH/data/upgrade-info.json"
if [ -f "$UPGRADE_INFO" ] && grep -q "\"name\"[[:space:]]*:[[:space:]]*\"${STRUCTS_UPGRADE_NAME}\"" "$UPGRADE_INFO"; then
  echo "Detected prior ${STRUCTS_UPGRADE_NAME} upgrade in $UPGRADE_INFO; pre-pointing cosmovisor/current"
  ln -sfn "upgrades/${STRUCTS_UPGRADE_NAME}" "$STRUCTS_PATH/cosmovisor/current"
fi

export DAEMON_NAME DAEMON_HOME DAEMON_RESTART_AFTER_UPGRADE DAEMON_ALLOW_DOWNLOAD_BINARIES UNSAFE_SKIP_BACKUP

echo "Launching cosmovisor (DAEMON_NAME=$DAEMON_NAME DAEMON_HOME=$DAEMON_HOME)"
# exec so cosmovisor is PID 1: signals from `docker stop` reach the daemon
# and the container stays alive across the binary swap (cosmovisor restarts
# the daemon child after the upgrade).
exec cosmovisor run start --home "$STRUCTS_PATH" ${STRUCTSD_ARGUMENTS}
