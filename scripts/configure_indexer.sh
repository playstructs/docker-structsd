#!/usr/bin/env bash
# Prepare to launch chain

echo "Entering the indexer configurator"

# Check for the ready file marker
# if it exists, don't do it again
if [ ! -f /var/structs/chain/indexing ]
then
  if [[ $NODE_INDEXER == "psql" ]];
  then
    echo "Configuring Postgresql Indexer"

    echo "Updating config.toml to point to postgres"
    echo $NODE_INDEXER_PG_CONNECTION
    sed -i 's/indexer = "kv"/indexer = "psql"/' /var/structs/chain/config/config.toml
    sed -i 's#psql-conn.*.$#psql-conn = "'$NODE_INDEXER_PG_CONNECTION'"#' /var/structs/chain/config/config.toml
  fi

  echo "Indexing is READY"
  touch /var/structs/chain/indexing
fi

