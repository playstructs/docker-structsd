# Base image
FROM ubuntu:23.10

# Information
LABEL maintainer="Slow Ninja <info@slow.ninja>"

# Variables
ENV DEBIAN_FRONTEND=noninteractive \
      MONIKER="UnknownGuild" \
      NETWORK_VERSION="99b" \
      NETWORK_TYPE="testnet" \
      NETWORK_CHAIN_ID="structstestnet-99" \
      NODE_TYPE='NONVALIDATING' \
      NODE_INDEXER="kv" \
      NODE_INDEXER_PG_CONNECTION="" \
      LAUNCH_METHOD="AUTOMATIC"

# Install packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        git \
        curl \
        wget \
        golang \
        &&  \
    rm -rf /var/lib/apt/lists/*

ENV PATH=$PATH:/usr/local/go/bin

# Put this file into place so that the ignite command does not
# get stuck waiting for input
RUN mkdir /root/.ignite
COPY config/anon_identity.json /root/.ignite/anon_identity.json

# Install ignite 
RUN curl https://get.ignite.com/cli! | bash

# Add the user and groups appropriately
RUN addgroup --system structs && \
    adduser --system --home /src/structs --shell /bin/bash --group structs


# Setup the scripts
WORKDIR /src
RUN chown -R structs /src/structs
COPY scripts/* /src/structs/
RUN chmod a+x /src/structs/*

RUN mkdir /var/structs && \
    mkdir /var/structs/bin && \
    mkdir /var/structs/chain && \
    mkdir /var/structs/accounts

COPY config/app.toml /var/structs/chain/config/app.toml

ENV PATH="$PATH:/var/structs/bin"

# Expose ports
EXPOSE 26656
EXPOSE 26657
EXPOSE 1317


# Persistence volume
# VOLUME [ "/var/structs" ]

# Building latest structsd
RUN git clone https://github.com/playstructs/structsd.git && \
    cd structsd && \
    ignite chain build

# Run Structs
CMD [ "/src/structs/start_structsd.sh" ]
