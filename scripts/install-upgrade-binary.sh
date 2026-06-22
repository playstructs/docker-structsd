#!/usr/bin/env bash
# Download, verify, and install an official structsd upgrade binary for cosmovisor.
# Usage: install-upgrade-binary.sh <plan-name> <version> <sha256> [release-tag]
#
# <plan-name>   on-chain x/upgrade plan name; also the cosmovisor upgrades/<dir>.
# <version>     version string in the release filename (structsd-<version>-...).
# <sha256>      linux/amd64 tarball sha256 from the governance proposal.
# [release-tag] GitHub release tag to download from. Defaults to <plan-name>.
#               Override when the plan-name binary ships under a different
#               release tag, e.g. a hotfix: plan v0.19.0 binary lives in the
#               v0.19.1 release -> install-upgrade-binary.sh v0.19.0 0.19.1 <sha> v0.19.1
set -euo pipefail

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo "Usage: $0 <plan-name> <version> <sha256> [release-tag]" >&2
  exit 1
fi

UPGRADE_NAME="$1"
UPGRADE_VERSION="$2"
UPGRADE_SHA256="$3"
RELEASE_TAG="${4:-$UPGRADE_NAME}"
DEST="/opt/structs/cosmovisor/upgrades/${UPGRADE_NAME}/bin/structsd"

mkdir -p "$(dirname "$DEST")" /tmp/upgrade
curl -fsSL -o /tmp/upgrade/structsd.tar.gz \
  "https://github.com/playstructs/structsd/releases/download/${RELEASE_TAG}/structsd-${UPGRADE_VERSION}-linux-amd64.tar.gz"
echo "${UPGRADE_SHA256}  /tmp/upgrade/structsd.tar.gz" | sha256sum -c -
tar -xzf /tmp/upgrade/structsd.tar.gz -C /tmp/upgrade
UPGRADE_BIN="$(find /tmp/upgrade -type f -name structsd ! -path '*.tar.gz' | head -n1)"
test -n "${UPGRADE_BIN}"
install -m 0755 "${UPGRADE_BIN}" "$DEST"
"${DEST}" version || true
rm -rf /tmp/upgrade
