#!/usr/bin/env bash
# Idempotent reconciler for $STRUCTS_PATH/cosmovisor/current.
#
# Cosmovisor swaps the `current` symlink in-process when an x/upgrade plan fires.
# If the container restarts during that window, `current` can be left pointing at
# the old binary even though the chain has already crossed the upgrade height.
# That state causes a permanent restart loop (old binary panics on WAL replay
# with "UPGRADE NEEDED" and exits, repeating forever).
#
# This script runs on every container start, after binaries are staged and
# before `cosmovisor run`. It treats $STRUCTS_PATH/data/upgrade-info.json as the
# authoritative signal (it's written by x/upgrade BeginBlocker at the upgrade
# height) and corrects `cosmovisor/current` to match. Validator height is a
# defense-in-depth fallback.
#
# Intentionally does NOT read cosmovisor/current/upgrade-info.json — that was
# the source of the priority bug this script replaces.
set -euo pipefail

: "${STRUCTS_PATH:=/root/.structs}"

CONF_FILE="$(dirname "$0")/upgrades.conf.sh"
if [ ! -f "$CONF_FILE" ]; then
  echo "FATAL: missing $CONF_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$CONF_FILE"

DATA_INFO="$STRUCTS_PATH/data/upgrade-info.json"
VALIDATOR_STATE="$STRUCTS_PATH/data/priv_validator_state.json"
CURRENT_LINK="$STRUCTS_PATH/cosmovisor/current"

# Build derived arrays from UPGRADES.
KNOWN_UPGRADES=()
for entry in "${UPGRADES[@]}"; do
  KNOWN_UPGRADES+=("${entry%%:*}")
done

is_known_upgrade() {
  local name="$1" known
  for known in "${KNOWN_UPGRADES[@]}"; do
    [ "$known" = "$name" ] && return 0
  done
  return 1
}

# Returns the highest-named upgrade whose height is <= the given chain height.
# Empty if no upgrade fits.
upgrade_for_height() {
  local height="$1"
  local picked="" entry height_at name
  for entry in "${UPGRADES[@]}"; do
    height_at="${entry##*:}"
    name="${entry%%:*}"
    if [ "$height" -ge "$height_at" ]; then
      picked="$name"
    fi
  done
  echo "$picked"
}

# Returns whichever of $1, $2 appears later in UPGRADES (ordering = upgrade order).
newer_upgrade() {
  local a="$1" b="$2"
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

# Resolve required upgrade name from authoritative + defense sources.
required=""
source_used=""

# Priority 1: data/upgrade-info.json (authoritative).
if [ -f "$DATA_INFO" ]; then
  data_name="$(jq -r '.name // empty' "$DATA_INFO" 2>/dev/null || true)"
  if [ -z "$data_name" ]; then
    echo "WARN: $DATA_INFO is not valid JSON or missing .name; treating as absent" >&2
  elif is_known_upgrade "$data_name"; then
    required="$data_name"
    source_used="data/upgrade-info.json"
  else
    echo "WARN: $DATA_INFO names unknown upgrade '$data_name'; this image is missing the binary. Chain will halt unless image is updated." >&2
  fi
fi

# Priority 2: validator height (defense in depth; non-validators have height=0).
if [ -f "$VALIDATOR_STATE" ]; then
  height="$(jq -r '.height // 0' "$VALIDATOR_STATE" 2>/dev/null || echo 0)"
  if [ "$height" -gt 0 ] 2>/dev/null; then
    height_upgrade="$(upgrade_for_height "$height")"
    if [ -n "$height_upgrade" ]; then
      merged="$(newer_upgrade "$required" "$height_upgrade")"
      if [ "$merged" != "$required" ]; then
        required="$merged"
        source_used="${source_used:+${source_used}+}priv_validator_state.json(height=${height})"
      fi
    fi
  fi
fi

# Nothing to do if no signal — leave current alone (genesis path is fine).
if [ -z "$required" ]; then
  exit 0
fi

# Verify the binary we plan to point at actually exists in the volume.
required_bin="$STRUCTS_PATH/cosmovisor/upgrades/${required}/bin/structsd"
if [ ! -x "$required_bin" ]; then
  echo "WARN: required upgrade '$required' resolved but binary missing at $required_bin; leaving cosmovisor/current alone" >&2
  exit 0
fi

# Read current target if any.
current_target=""
if [ -L "$CURRENT_LINK" ]; then
  current_target="$(readlink "$CURRENT_LINK")"
fi

expected="upgrades/${required}"

if [ "$current_target" = "$expected" ]; then
  # Already correct; no-op.
  exit 0
fi

# Drift detected — repoint the symlink.
echo "Reconciled cosmovisor/current -> ${expected} (was: ${current_target:-none}, source: ${source_used})"
if ! ln -sfn "${expected}" "$CURRENT_LINK"; then
  echo "FATAL: failed to update $CURRENT_LINK -> $expected" >&2
  exit 1
fi

# Sync metadata only when we actually changed the symlink AND destination is
# missing or stale relative to data/upgrade-info.json. Cosmovisor compares
# current/upgrade-info.json against data/upgrade-info.json to decide whether
# an upgrade is pending; we want them aligned with the binary we just selected.
dest_info="$STRUCTS_PATH/cosmovisor/upgrades/${required}/upgrade-info.json"
if [ -f "$DATA_INFO" ]; then
  dest_name=""
  if [ -f "$dest_info" ]; then
    dest_name="$(jq -r '.name // empty' "$dest_info" 2>/dev/null || true)"
  fi
  if [ "$dest_name" != "$required" ]; then
    cp "$DATA_INFO" "$dest_info"
    echo "Synced $dest_info from $DATA_INFO"
  fi
fi
