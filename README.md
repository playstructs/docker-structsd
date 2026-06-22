# docker-structsd

[Docker](https://www.docker.com) container for running the [Structs Consensus Engine](https://github.com/playstructs/structsd/). 

Docker Hub: [https://hub.docker.com/r/structs/structsd/](https://hub.docker.com/r/structs/structsd/)

## Structs
In the distant future the species of the galaxy are embroiled in a race for Alpha Matter, the rare and dangerous substance that fuels galactic civilization. Players take command of Structs, a race of sentient machines, and must forge alliances, conquer enemies and expand their influence to control Alpha Matter and the fate of the galaxy.

# How to Build

```
git clone git@github.com:playstructs/docker-structsd.git
cd docker-structsd
docker build .
```

# How to Use this Image

## Quickstart

The following will run the latest Structs consensus server.

```
docker run -d --restart unless-stopped -p 26656:26656 --name=structsd structs/structsd:latest
```

`--restart unless-stopped` is recommended so the container auto-recovers if cosmovisor itself ever crashes. The chain binary swap at the upgrade height does **not** stop the container (see "Cosmovisor and chain upgrades" below), but a host reboot or cosmovisor crash would.

## Interactive

A good way to run for development and for continual monitoring is to attach to the terminal:

```
docker run -it --rm -p 26656:26656 --name=structsd structs/structsd:latest
```

# Cosmovisor and chain upgrades

This image runs `structsd` under [cosmovisor](https://docs.cosmos.network/main/build/tooling/cosmovisor) so that on-chain `x/upgrade` software-upgrade plans swap the binary automatically without operator intervention and without restarting the container.

Three binaries are baked into the image:

- **Genesis binary** — built from the `structsd` `111b` branch with Ignite. Cosmovisor runs this from block 0 until the first upgrade fires.
- **Upgrade binary `v0.16.0`** — the official `structsd-0.16.0-linux-amd64.tar.gz` from the [v0.16.0 GitHub release](https://github.com/playstructs/structsd/releases/tag/v0.16.0), verified against the sha256 from the on-chain proposal. Cosmovisor switches to this at height **385730**.
- **Upgrade binary `v0.17.0`** — the official `structsd-0.17.0-linux-amd64.tar.gz` from the [v0.17.0 GitHub release](https://github.com/playstructs/structsd/releases/tag/v0.17.0), verified against the sha256 from governance proposal 2. Cosmovisor switches to this at height **867678**.

At container start, `scripts/start.sh` syncs all binaries into `$STRUCTS_PATH/cosmovisor/` (idempotent), runs `scripts/reconcile-cosmovisor-current.sh` to fix any drift in the `cosmovisor/current` symlink, registers batch upgrades for catch-up syncs, then `exec`s `cosmovisor run start --home $STRUCTS_PATH`. Because cosmovisor is PID 1 and `DAEMON_RESTART_AFTER_UPGRADE=true`, each upgrade swap is handled in-place: the daemon child exits, cosmovisor updates `cosmovisor/current`, and starts the new binary as a fresh child. The container itself stays running.

The reconciler treats `data/upgrade-info.json` (written by `x/upgrade` at the upgrade height) as the authoritative signal for which binary should be running. This closes the rare window where a Docker restart during an in-process upgrade swap would otherwise leave `cosmovisor/current` pointing at the old binary and trigger a permanent restart loop.

Roll out a new image **before** the next on-chain upgrade height. Consider publishing a versioned tag (e.g. `structs/structsd:v0.17.0`) alongside `:latest` so operators can pin the exact image containing the upgrade binary.

## Cosmovisor environment knobs

| Variable | Default | Notes |
| --- | --- | --- |
| `DAEMON_NAME` | `structsd` | Must match the binary file name under `cosmovisor/*/bin/`. |
| `DAEMON_HOME` | `/root/.structs` | Same as `STRUCTS_PATH`; cosmovisor looks for `cosmovisor/` under this path. |
| `DAEMON_RESTART_AFTER_UPGRADE` | `true` | Required so the container does not exit after the upgrade swap. |
| `DAEMON_ALLOW_DOWNLOAD_BINARIES` | `false` | Image is hermetic; the upgrade binary is baked in. |
| `UNSAFE_SKIP_BACKUP` | `true` | Skips tarballing `data/` before upgrade. Set to `false` for an extra safety net (slow on a long-lived chain). Take a manual volume snapshot before upgrade heights regardless. |

## Adding a future upgrade

The repo has one source of truth for known upgrades — [`scripts/upgrades.conf.sh`](scripts/upgrades.conf.sh) — and one place that downloads the binary at build time (`Dockerfile`). When a governance proposal lands:

1. Add one line to [`scripts/upgrades.conf.sh`](scripts/upgrades.conf.sh):
   ```bash
   UPGRADES=(
     "v0.16.0:385730"
     "v0.17.0:867678"
     "v0.18.0:1173255"
     "v0.19.0:NEW_HEIGHT"
   )
   ```
2. Add one line to the upgrade `RUN` in the [`Dockerfile`](Dockerfile), using the sha256 from the governance proposal:
   ```
   # Normal case (release tag == on-chain plan name):
   /root/scripts/install-upgrade-binary.sh v0.20.0 0.20.0 <sha256>

   # When the plan-name binary ships under a different release tag (e.g. a hotfix),
   # pass the release tag as an optional 4th arg. Here the v0.19.0 plan binary
   # lives in the v0.19.1 GitHub release:
   /root/scripts/install-upgrade-binary.sh v0.19.0 0.19.1 <sha256> v0.19.1
   ```
   The first arg is the on-chain plan name (and the `cosmovisor/upgrades/<dir>`), the second is the version in the release filename, the third is the tarball sha256, and the optional fourth overrides the GitHub release tag (defaults to the plan name).
3. Rebuild and roll before the upgrade height. Cosmovisor picks the right binary based on chain state.

`scripts/start.sh` and `scripts/reconcile-cosmovisor-current.sh` both source `upgrades.conf.sh`, so the batch-upgrade list, pre-flight checks, and drift correction all derive automatically. **No compose changes are needed for chain upgrades** — operators never touch their compose files for this.

The genesis binary stays `111b` so fresh syncs from block 0 still work through all historical upgrade heights.

## Stuck after an upgrade?

If a container is restart-looping with `UPGRADE "vX.Y.Z" NEEDED at height: N` after the chain crossed the upgrade height, `cosmovisor/current` is pointing at the old binary. The reconciler in this image self-heals on every start, so the **permanent fix is to rebuild and redeploy with the latest image**.

For an immediate fix without rebuilding (or for nodes still on a pre-reconciler image), repoint the symlink manually:

```bash
# Universal: works on any host (replace v0.17.0 with the target upgrade name).
docker exec <structsd-container> bash -c '
  ln -sfn upgrades/v0.17.0 /root/.structs/cosmovisor/current &&
  cp /root/.structs/data/upgrade-info.json \
     /root/.structs/cosmovisor/upgrades/v0.17.0/upgrade-info.json
'
docker restart <structsd-container>
```

Notes:

- `STRUCTS_UPGRADE_NAME` is **not** used by this image. Do not add it to compose; older docs that reference it are out of date.
- `priv_validator_state.json` height only advances for validators that signed blocks. Full nodes rely on `data/upgrade-info.json` for upgrade detection (which is sufficient — `x/upgrade` writes that file at every upgrade height regardless of node role).

# Learn more

- [Structs](https://playstructs.com)
- [Project Wiki](https://watt.wiki)
- [@PlayStructs Twitter](https://twitter.com/playstructs)


# License

Copyright 2021 [Slow Ninja Inc](https://slow.ninja).

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.