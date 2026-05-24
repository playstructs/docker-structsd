# Base image
FROM ubuntu:24.04

# Information
LABEL maintainer="Slow Ninja <info@slow.ninja>"

# Variables
ENV DEBIAN_FRONTEND=noninteractive \
    STRUCTS_PATH="/root/.structs" \
    STRUCTS_REACTOR_SHARE="/root/reactor_share" \
    STRUCTS_REACTOR_BACKUP="/root/reactor_backup" \
    STRUCTS_CHAIN_ID="structstestnet-111" \
    STRUCTS_NETWORK_VERSION="112b" \
    STRUCTS_MONIKER="UnknownGuild" \
    STRUCTSD_HOST="structsd" \
    STRUCTS_VALIDATOR_INITIAL_STAKING_AMOUNT="50000000" \
    STRUCTS_VALIDATOR_IDENTITY="UnknownDroid" \
    STRUCTS_GUILD_WEBSITE="https://playstructs.com" \
    STRUCTS_GUILD_CONTACT="UnknownDroidLeader" \
    STRUCTS_VALIDATOR_COMMISSION_RATE="0.1" \
    STRUCTS_VALIDATOR_MAX_RATE="0.2" \
    STRUCTS_VALIDATOR_MAX_CHANGE_RATE="0.01" \
    STRUCTS_VALIDATOR_MIN_SELF_DELEGATION="1" \
    STRUCTS_INDEXER_PG_CONNECTION="" \
    STRUCTSD_ARGUMENTS="--log_level info --minimum-gas-prices 0ualpha" \
    # Cosmovisor / upgrade settings
    STRUCTS_GENESIS_BRANCH="111b" \
    COSMOVISOR_VERSION="v1.7.0" \
    DAEMON_NAME="structsd" \
    DAEMON_HOME="/root/.structs" \
    DAEMON_RESTART_AFTER_UPGRADE="true" \
    DAEMON_ALLOW_DOWNLOAD_BINARIES="false" \
    UNSAFE_SKIP_BACKUP="true"

# Install packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        git \
        curl \
        ca-certificates \
        postgresql-client \
        jq \
        nano \
        && \
    rm -rf /var/lib/apt/lists/*

# Install Go 1.24.1
RUN curl -LO https://go.dev/dl/go1.24.1.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.24.1.linux-amd64.tar.gz && \
    rm go1.24.1.linux-amd64.tar.gz

ENV PATH="/usr/local/go/bin:/root/go/bin:${PATH}"

# Put this file into place so that the ignite command does not
# get stuck waiting for input
RUN mkdir /root/.ignite
COPY config/anon_identity.json /root/.ignite/anon_identity.json

# Install ignite
RUN curl -L -o ignite.tar.gz https://github.com/ignite/cli/releases/download/v28.8.2/ignite_28.8.2_linux_amd64.tar.gz && \
    tar -xzvf ignite.tar.gz && \
    mv ignite /usr/bin/

# Install cosmovisor (pinned to a release line that supports cosmos-sdk v0.53.x)
RUN go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@${COSMOVISOR_VERSION} && \
    install -m 0755 /root/go/bin/cosmovisor /usr/local/bin/cosmovisor && \
    cosmovisor version || true

# Expose ports
EXPOSE 26656
EXPOSE 26657
EXPOSE 1317

# Build the genesis (pre-upgrade) binary from the requested branch.
# Cosmovisor runs this until height 385730 (v0.16.0), then 867678 (v0.17.0).
RUN mkdir -p /opt/structs/cosmovisor/genesis/bin && \
    git clone https://github.com/playstructs/structsd.git -b ${STRUCTS_GENESIS_BRANCH} && \
    cd structsd && \
    ignite chain build && \
    install -m 0755 /root/go/bin/structsd /opt/structs/cosmovisor/genesis/bin/structsd && \
    /opt/structs/cosmovisor/genesis/bin/structsd version || true

# Keep a stable `structsd` on PATH for utility scripts (reactor-create.sh,
# indexer-insert-genesis.sh, ad-hoc CLI calls). It points at the genesis
# binary; cosmovisor manages the live daemon separately.
RUN ln -sf /opt/structs/cosmovisor/genesis/bin/structsd /usr/bin/structsd

RUN mkdir -p $STRUCTS_PATH && \
    mkdir -p $STRUCTS_REACTOR_SHARE && \
    mkdir -p $STRUCTS_REACTOR_BACKUP && \
    mkdir -p /root/scripts && \
    mkdir -p /root/config

COPY scripts/ /root/scripts/
RUN chmod a+x /root/scripts/*

# Stage official upgrade binaries. SHA256s match the on-chain governance proposals.
RUN /root/scripts/install-upgrade-binary.sh v0.16.0 0.16.0 14a251a01fe51b76afd0896befdacff43873337a5e12c8673d6a30014a2a385f && \
    /root/scripts/install-upgrade-binary.sh v0.17.0 0.17.0 09208557818f4c4a646435472f35f33390fa91c807f4678f853cc804809d91a7

COPY config/ /root/config/

# Run Structs (cosmovisor handles upgrades at heights 385730 and 867678)
CMD [ "bash", "/root/scripts/start.sh" ]
