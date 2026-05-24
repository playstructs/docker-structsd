#!/usr/bin/env bash
# Download, verify, and install an official structsd upgrade binary for cosmovisor.
# Usage: install-upgrade-binary.sh <plan-name> <version> <sha256>
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <plan-name> <version> <sha256>" >&2
  exit 1
fi

UPGRADE_NAME="$1"
UPGRADE_VERSION="$2"
UPGRADE_SHA256="$3"
DEST="/opt/structs/cosmovisor/upgrades/${UPGRADE_NAME}/bin/structsd"

mkdir -p "$(dirname "$DEST")" /tmp/upgrade
curl -fsSL -o /tmp/upgrade/structsd.tar.gz \
  "https://github.com/playstructs/structsd/releases/download/${UPGRADE_NAME}/structsd-${UPGRADE_VERSION}-linux-amd64.tar.gz"
echo "${UPGRADE_SHA256}  /tmp/upgrade/structsd.tar.gz" | sha256sum -c -
tar -xzf /tmp/upgrade/structsd.tar.gz -C /tmp/upgrade
UPGRADE_BIN="$(find /tmp/upgrade -type f -name structsd ! -path '*.tar.gz' | head -n1)"
test -n "${UPGRADE_BIN}"
install -m 0755 "${UPGRADE_BIN}" "$DEST"
"${DEST}" version || true
rm -rf /tmp/upgrade
