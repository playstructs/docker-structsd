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
# plan-name:block-height — used to pick the correct binary when chain data is past an upgrade.
UPGRADE_HEIGHTS=(385730:v0.16.0 867678:v0.17.0)

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

upgrade_for_height() {
  local height="$1"
  local picked=""
  local entry height_at name
  for entry in "${UPGRADE_HEIGHTS[@]}"; do
    height_at="${entry%%:*}"
    name="${entry##*:}"
    if [ "$height" -ge "$height_at" ]; then
      picked="$name"
    fi
  done
  echo "$picked"
}

newer_upgrade() {
  local a="$1"
  local b="$2"
  if [ -z "$a" ]; then echo "$b"; return; fi
  if [ -z "$b" ]; then echo "$a"; return; fi
  local idx_a=-1 idx_b=-1 i=0 name
  for name in "${KNOWN_UPGRADES[@]}"; do
    if [ "$name" = "$a" ]; then idx_a=$i; fi
    if [ "$name" = "$b" ]; then idx_b=$i; fi
    i=$((i + 1))
  done
  if [ "$idx_a" -ge "$idx_b" ]; then echo "$a"; else echo "$b"; fi
}

ensure_current_points_to() {
  local upgrade_name="$1"
  local expected="upgrades/${upgrade_name}"
  local current_target=""

  if [ -L "$CURRENT_LINK" ]; then
    current_target="$(readlink "$CURRENT_LINK")"
  fi

  if [ "$current_target" != "$expected" ] && [ -x "$STRUCTS_PATH/cosmovisor/${expected}/bin/structsd" ]; then
    echo "Pointing cosmovisor/current -> ${expected} (was: ${current_target:-none})"
    ln -sfn "${expected}" "$CURRENT_LINK"
  fi
}

# Ensure cosmovisor/current matches chain state. Too-conservative bootstrap was
# leaving current on genesis after a failed replay past height 385730, causing
# a restart loop even once data/upgrade-info.json recorded the upgrade.
CURRENT_INFO="$CURRENT_LINK/upgrade-info.json"
active_upgrade=""
if [ -f "$CURRENT_INFO" ]; then
  active_upgrade="$(jq -r '.name // empty' "$CURRENT_INFO")"
elif [ -f "$UPGRADE_INFO" ]; then
  active_upgrade="$(jq -r '.name // empty' "$UPGRADE_INFO")"
fi

VALIDATOR_STATE="$STRUCTS_PATH/data/priv_validator_state.json"
if [ -f "$VALIDATOR_STATE" ]; then
  chain_height="$(jq -r '.height // 0' "$VALIDATOR_STATE")"
  height_upgrade="$(upgrade_for_height "$chain_height")"
  if [ -n "$height_upgrade" ]; then
    active_upgrade="$(newer_upgrade "$active_upgrade" "$height_upgrade")"
  fi
fi

if [ -n "$active_upgrade" ]; then
  ensure_current_points_to "$active_upgrade"
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
