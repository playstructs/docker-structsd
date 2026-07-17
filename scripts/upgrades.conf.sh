# Single source of truth for chain upgrades known to this image.
# Format: NAME:HEIGHT (NAME must match the on-chain x/upgrade plan name exactly).
#
# When a governance proposal lands:
#   1) Add a line below.
#   2) Add an install-upgrade-binary.sh line to the Dockerfile with the SHA256
#      from the proposal so the binary is baked into the image.
#
# Build-time SHA256s stay in the Dockerfile so they remain human-reviewable
# against governance, separate from this runtime config.
#
# This file is sourced by:
#   - scripts/start.sh (derives KNOWN_UPGRADES, builds add-batch-upgrade list)
#   - scripts/reconcile-cosmovisor-current.sh (drift correction at start)
UPGRADES=(
  "v0.16.0:385730"
  "v0.17.0:867678"
  "v0.18.0:1173255"
  "v0.19.0:1335904"
  "v0.20.0:1732284"
)
