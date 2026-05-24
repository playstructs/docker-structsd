#!/usr/bin/env bash
set -euo pipefail

# Idempotent chain + docker config (also used by the network-config compose service).
bash /root/scripts/network-config.sh

if ! [ -f "$STRUCTS_PATH/status/network" ]; then
  echo "Network configuration failed"
  exit 1
fi

# Defaults (also set in the Dockerfile ENV; re-asserted here so this script
# is safe to run standalone or with overridden envs).
: "${DAEMON_NAME:=structsd}"
: "${DAEMON_HOME:=$STRUCTS_PATH}"
: "${DAEMON_RESTART_AFTER_UPGRADE:=true}"
: "${DAEMON_ALLOW_DOWNLOAD_BINARIES:=false}"
: "${UNSAFE_SKIP_BACKUP:=true}"

KNOWN_UPGRADES=(v0.16.0 v0.17.0)

GENESIS_SRC="/opt/structs/cosmovisor/genesis/bin/structsd"
GENESIS_DST_DIR="$STRUCTS_PATH/cosmovisor/genesis/bin"
CURRENT_LINK="$STRUCTS_PATH/cosmovisor/current"
UPGRADE_INFO="$STRUCTS_PATH/data/upgrade-info.json"
BATCH_FILE="$STRUCTS_PATH/data/upgrade-info.json.batch"

echo "Staging cosmovisor binaries into $STRUCTS_PATH/cosmovisor"
mkdir -p "$GENESIS_DST_DIR"

# Cosmovisor v1.7+ refuses to start unless $DAEMON_HOME/data already exists.
# The daemon itself populates this directory on first block; we just need it
# to exist (network-config.sh deletes it on chain-id changes).
mkdir -p "$STRUCTS_PATH/data"

# Idempotent install: keep image-baked binaries authoritative so an image
# bump propagates into existing volumes on next start.
install -m 0755 "$GENESIS_SRC" "$GENESIS_DST_DIR/structsd"

for upgrade_name in "${KNOWN_UPGRADES[@]}"; do
  src="/opt/structs/cosmovisor/upgrades/${upgrade_name}/bin/structsd"
  dst_dir="$STRUCTS_PATH/cosmovisor/upgrades/${upgrade_name}/bin"
  mkdir -p "$dst_dir"
  install -m 0755 "$src" "$dst_dir/structsd"
done

# Pre-flight: fail fast if any binary is missing before cosmovisor starts.
if [ ! -x "$GENESIS_DST_DIR/structsd" ]; then
  echo "FATAL: missing genesis binary at $GENESIS_DST_DIR/structsd" >&2
  exit 1
fi
for upgrade_name in "${KNOWN_UPGRADES[@]}"; do
  bin="$STRUCTS_PATH/cosmovisor/upgrades/${upgrade_name}/bin/structsd"
  if [ ! -x "$bin" ]; then
    echo "FATAL: missing upgrade binary for ${upgrade_name} at $bin" >&2
    exit 1
  fi
done

# Migration safety: bootstrap cosmovisor/current only when absent (e.g. volume
# copied from a manually-upgraded node, or pre-cosmovisor adoption).
CURRENT_INFO="$CURRENT_LINK/upgrade-info.json"
detected_name=""
if [ -f "$CURRENT_INFO" ]; then
  detected_name="$(jq -r '.name // empty' "$CURRENT_INFO")"
elif [ -f "$UPGRADE_INFO" ]; then
  detected_name="$(jq -r '.name // empty' "$UPGRADE_INFO")"
fi

if [ -n "$detected_name" ] && [ ! -L "$CURRENT_LINK" ]; then
  if [ -f "$STRUCTS_PATH/cosmovisor/upgrades/${detected_name}/bin/structsd" ]; then
    echo "Bootstrapping cosmovisor/current -> upgrades/${detected_name}"
    ln -sfn "upgrades/${detected_name}" "$CURRENT_LINK"
  fi
fi

# Point utility scripts at the active binary (fallback to genesis pre-upgrade).
if [ -L "$CURRENT_LINK" ] && [ -x "$CURRENT_LINK/bin/structsd" ]; then
  ln -sf "$CURRENT_LINK/bin/structsd" /usr/bin/structsd
else
  ln -sf "$GENESIS_DST_DIR/structsd" /usr/bin/structsd
fi

# Pre-declare upgrade heights for catch-up syncs from genesis.
export DAEMON_NAME DAEMON_HOME DAEMON_ALLOW_DOWNLOAD_BINARIES

if [ ! -f "$BATCH_FILE" ]; then
  echo "Registering batch upgrades for heights 385730 (v0.16.0) and 867678 (v0.17.0)"
  cosmovisor add-batch-upgrade --upgrade-list \
    "v0.16.0:${STRUCTS_PATH}/cosmovisor/upgrades/v0.16.0/bin/structsd:385730,v0.17.0:${STRUCTS_PATH}/cosmovisor/upgrades/v0.17.0/bin/structsd:867678"
fi

export DAEMON_RESTART_AFTER_UPGRADE UNSAFE_SKIP_BACKUP

echo "Launching cosmovisor (DAEMON_NAME=$DAEMON_NAME DAEMON_HOME=$DAEMON_HOME)"
# exec so cosmovisor is PID 1: signals from `docker stop` reach the daemon
# and the container stays alive across the binary swap (cosmovisor restarts
# the daemon child after the upgrade).
exec cosmovisor run start --home "$STRUCTS_PATH" ${STRUCTSD_ARGUMENTS}
