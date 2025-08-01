# Base image
FROM ubuntu:24.04

# Information
LABEL maintainer="Slow Ninja <info@slow.ninja>"

# Variables
ENV DEBIAN_FRONTEND=noninteractive \
    STRUCTS_PATH="~/.structs" \
    STRUCTS_REACTOR_SHARE="~/reactor_share" \
    STRUCTS_REACTOR_BACKUP="~/reactor_backup" \
    STRUCTS_CHAIN_ID="structstestnet-102" \
    STRUCTS_NETWORK_VERSION="102b" \
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
    STRUCTS_INDEXER_PG_CONNECTION=""




# Install packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        git \
        curl \
        wget \
        golang \
        bc \
        jq \
        vim \
        &&  \
    rm -rf /var/lib/apt/lists/*

# Put this file into place so that the ignite command does not
# get stuck waiting for input
RUN mkdir /root/.ignite
COPY config/anon_identity.json /root/.ignite/anon_identity.json

# Install ignite
RUN curl -L -o ignite.tar.gz https://github.com/ignite/cli/releases/download/v28.8.2/ignite_28.8.2_linux_amd64.tar.gz && \
    tar -xzvf ignite.tar.gz && \
    mv ignite /usr/bin/

# Expose ports
EXPOSE 26656
EXPOSE 26657
EXPOSE 1317

# Building latest structsd
RUN git clone https://github.com/playstructs/structsd.git && \
    cd structsd && \
    ignite chain build && \
    cp /root/go/bin/structsd /usr/bin/structsd

RUN mkdir $STRUCTS_PATH && \
    mkdir $STRUCTS_REACTOR_SHARE && \
    mkdir ~/scripts && \
    mkdir ~/config

COPY scripts/* ~/scripts/
RUN chmod a+x ~/scripts/*

COPY config/* ~/config/

# Run Structs
CMD [ "structsd", "start" ]
