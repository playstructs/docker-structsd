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
sed -i 's#psql-conn.*.$#psql-conn = "'$STRUCTS_INDEXER_PG_CONNECTION'"#' $STRUCTS_PATH/config/config.toml

echo "Node successfully configured for indexing"

echo "Resetting Database State"
psql ${STRUCTS_INDEXER_PG_CONNECTION} --set=sslmode=require -f /root/scripts/indexer-chain-reset.sql

echo "Checking to see if meta should be reset too.."
INDEXER_PREVIOUS_CHAIN_ID=$(cat $STRUCTS_PATH/status/network_indexer)
if [ "$INDEXER_PREVIOUS_CHAIN_ID" != "$STRUCTS_CHAIN_ID" ]; then
  echo "New network chain id detected, resetting meta tables"
  psql ${STRUCTS_INDEXER_PG_CONNECTION} --set=sslmode=require -f /root/scripts/indexer-meta-reset.sql
fi

echo $STRUCTS_CHAIN_ID > $STRUCTS_PATH/status/network_indexer

bash /root/scripts/indexer-insert-genesis.sh

echo "Done!"

exit 0