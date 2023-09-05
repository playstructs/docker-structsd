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

# Install packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        git \
        curl \
        wget \
        && \
    rm -rf /var/lib/apt/lists/*


ARG GOLANG_VERSION=1.21.0

#we need the go version installed from apk to bootstrap the custom version built from source
RUN apk update && apk add go gcc bash musl-dev openssl-dev ca-certificates && update-ca-certificates

RUN wget https://dl.google.com/go/go$GOLANG_VERSION.src.tar.gz && tar -C /usr/local -xzf go$GOLANG_VERSION.src.tar.gz

RUN cd /usr/local/go/src && ./make.bash

ENV PATH=$PATH:/usr/local/go/bin

RUN rm go$GOLANG_VERSION.src.tar.gz

#we delete the apk installed version to avoid conflict
RUN apk del go

RUN go version



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
