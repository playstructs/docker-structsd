# Base image
FROM ubuntu:22.04

# Information
LABEL maintainer="Slow Ninja <info@slow.ninja>"

# Variables
ENV DEBIAN_FRONTEND=noninteractive \
  PGDATABASE=structs \
  PGPORT=5432 \
  PGHOST=localhost \
  PGUSER=structs

ENV SNAPCRAFT_SETUP_CORE=1

# Install packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        git \
        curl \
        wget \
        snapd \
        squashfuse \
        fuse \
        && \
    rm -rf /var/lib/apt/lists/*

RUN systemctl enable snapd
RUN snap install go --classic

ENV PATH="$PATH:/usr/local/go/bin"


# Install ignite 
RUN curl https://get.ignite.com/cli! | bash
RUN ignite plugin add -g github.com/ignite/cli-plugin-network@v0.1.0

# Add the user and groups appropriately
RUN addgroup --system structs && \
    adduser --system --home /src/structs --shell /bin/bash --group structs



# Setup the scripts
WORKDIR /src
RUN chown -R structs /src/structs
#COPY conf/sqitch.conf /src/structs/
COPY scripts/* /src/structs/
RUN chmod a+x /src/structs/*

RUN mkdir /var/structs && \
    mkdir /var/structs/bin && \
    mkdir /var/structs/chain && \
    mkdir /var/structs/accounts

ENV PATH="$PATH:/var/structs/bin"

# Expose ports
EXPOSE 26656
EXPOSE 26657
EXPOSE 1317


# Persistence volume
VOLUME [ "/var/structs" ]

# Run Structs
CMD [ "/src/structs/start_structsd.sh" ]
