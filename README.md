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

Two binaries are baked into the image:

- **Genesis binary** — built from the `structsd` `111b` branch with Ignite. Cosmovisor runs this from block 0 until the first upgrade fires.
- **Upgrade binary `v0.16.0`** — the official `structsd-0.16.0-linux-amd64.tar.gz` from the [v0.16.0 GitHub release](https://github.com/playstructs/structsd/releases/tag/v0.16.0), verified against the sha256 from the on-chain proposal. Cosmovisor switches to this when the chain announces the `v0.16.0` plan at height **385730**.

At container start, `scripts/start.sh` syncs both binaries into `$STRUCTS_PATH/cosmovisor/{genesis,upgrades/v0.16.0}/bin/structsd` (idempotent), then `exec`s `cosmovisor run start --home $STRUCTS_PATH`. Because cosmovisor is PID 1 and `DAEMON_RESTART_AFTER_UPGRADE=true`, the upgrade swap is handled in-place: the daemon child exits, cosmovisor updates the `cosmovisor/current` symlink, and starts the new binary as a fresh child. The container itself stays running.

## Cosmovisor environment knobs

| Variable | Default | Notes |
| --- | --- | --- |
| `DAEMON_NAME` | `structsd` | Must match the binary file name under `cosmovisor/*/bin/`. |
| `DAEMON_HOME` | `/root/.structs` | Same as `STRUCTS_PATH`; cosmovisor looks for `cosmovisor/` under this path. |
| `DAEMON_RESTART_AFTER_UPGRADE` | `true` | Required so the container does not exit after the upgrade swap. |
| `DAEMON_ALLOW_DOWNLOAD_BINARIES` | `false` | Image is hermetic; the upgrade binary is baked in. |
| `UNSAFE_SKIP_BACKUP` | `true` | Skips tarballing `data/` before upgrade. Set to `false` for an extra safety net (slow on a long-lived chain). |
| `STRUCTS_UPGRADE_NAME` | `v0.16.0` | Must match the on-chain plan name exactly (case-sensitive). |

## Adding a future upgrade

When the next on-chain upgrade lands (e.g. `v0.17.0`), bake a third binary into the image alongside the existing two:

1. Add a `RUN` block in the `Dockerfile` that fetches the release tarball, verifies its sha256 from the governance proposal, and installs it to `/opt/structs/cosmovisor/upgrades/v0.17.0/bin/structsd`.
2. Add a corresponding `install -m 0755 ...` line in `scripts/start.sh` so the binary is staged into the volume on next start.
3. Rebuild and roll. Cosmovisor will pick the right binary based on the active plan in chain state.

The `v0.16.0` swap continues to work for fresh syncs because the genesis binary is still `111b`.

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