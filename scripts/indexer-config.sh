#!/usr/bin/env bash

echo "Configuring node for use as a postgres indexer"

if ! [ -f $STRUCTS_PATH/status/network ]; then
  echo "Network needs to be configured first"
  exit 1
fi

# TODO Deploy a testnet specific schema?

echo "Moving Indexer specific configuration files into place"
cp /root/config/indexer/* $STRUCTS_PATH/config/

echo "Updating config.toml to point to postgres"
echo $STRUCTS_INDEXER_PG_CONNECTION
sed -i 's#psql-conn.*.$#psql-conn = "'$STRUCTS_INDEXER_PG_CONNECTION'"#' /var/structs/chain/config/config.toml

echo "Node successfully configured for indexing"

exit 0