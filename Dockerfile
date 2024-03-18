# Base image
FROM ubuntu:23.04

# Information
LABEL maintainer="Slow Ninja <info@slow.ninja>"

# Variables
ENV DEBIAN_FRONTEND=noninteractive \
      MONIKER="UnknownGuild" \
      NETWORK_VERSION="74b" \
      NETWORK_TYPE="testnet" \
      NETWORK_CHAIN_ID="structstestnet-74" \
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


# Install ignite 
RUN curl https://get.ignite.com/cli! | bash
RUN ignite app install -g github.com/ignite/cli-plugin-network

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
VOLUME [ "/var/structs" ]

# Run Structs
CMD [ "/src/structs/start_structsd.sh" ]
