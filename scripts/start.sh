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

# Single source of truth for known upgrades. Adding a new upgrade is a one-line
# edit to upgrades.conf.sh plus an install-upgrade-binary.sh line in Dockerfile.
CONF_FILE="/root/scripts/upgrades.conf.sh"
if [ ! -f "$CONF_FILE" ]; then
  echo "FATAL: $CONF_FILE missing — image is stale or built without the upgrades config. Rebuild the image." >&2
  exit 1
fi
# shellcheck disable=SC1091
source "$CONF_FILE"

# Derived arrays.
KNOWN_UPGRADES=()
for entry in "${UPGRADES[@]}"; do
  KNOWN_UPGRADES+=("${entry%%:*}")
done

GENESIS_SRC="/opt/structs/cosmovisor/genesis/bin/structsd"
GENESIS_DST_DIR="$STRUCTS_PATH/cosmovisor/genesis/bin"
CURRENT_LINK="$STRUCTS_PATH/cosmovisor/current"
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

# Reconcile cosmovisor/current against authoritative chain state. Closes the
# restart-during-upgrade-swap window that otherwise leaves the symlink stale.
bash /root/scripts/reconcile-cosmovisor-current.sh

# Point utility scripts at the active binary (fallback to genesis pre-upgrade).
if [ -L "$CURRENT_LINK" ] && [ -x "$CURRENT_LINK/bin/structsd" ]; then
  ln -sf "$CURRENT_LINK/bin/structsd" /usr/bin/structsd
else
  ln -sf "$GENESIS_DST_DIR/structsd" /usr/bin/structsd
fi

# Pre-declare upgrade heights for catch-up syncs from genesis. Built from UPGRADES.
export DAEMON_NAME DAEMON_HOME DAEMON_ALLOW_DOWNLOAD_BINARIES

if [ ! -f "$BATCH_FILE" ]; then
  batch_list=""
  for entry in "${UPGRADES[@]}"; do
    name="${entry%%:*}"
    height="${entry##*:}"
    bin_path="${STRUCTS_PATH}/cosmovisor/upgrades/${name}/bin/structsd"
    [ -n "$batch_list" ] && batch_list+=","
    batch_list+="${name}:${bin_path}:${height}"
  done
  echo "Registering batch upgrades: $batch_list"
  cosmovisor add-batch-upgrade --upgrade-list "$batch_list"
fi

export DAEMON_RESTART_AFTER_UPGRADE UNSAFE_SKIP_BACKUP

echo "Launching cosmovisor (DAEMON_NAME=$DAEMON_NAME DAEMON_HOME=$DAEMON_HOME)"
# exec so cosmovisor is PID 1: signals from `docker stop` reach the daemon
# and the container stays alive across the binary swap (cosmovisor restarts
# the daemon child after the upgrade).
exec cosmovisor run start --home "$STRUCTS_PATH" ${STRUCTSD_ARGUMENTS}
