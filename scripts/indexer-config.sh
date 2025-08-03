#!/usr/bin/env bash

echo "Configuring node for use as a postgres indexer"

if ! [ -f $STRUCTS_PATH/status/network ]; then
  echo "Network needs to be configured first"
  exit 1
fi

# Check that postgres works
#
# pg_isready returns... (https://www.postgresql.org/docs/current/app-pg-isready.html)
#   0 if the server is accepting connections normally,
#   1 if the server is rejecting connections (for example during startup),
#   2 if there was no response to the connection attempt, and
#   3 if no attempt was made (for example due to invalid parameters).
POSTGRES_STATUS=$(pg_isready -q -d $STRUCTS_INDEXER_PG_CONNECTION)
case "$POSTGRES_STATUS" in
  0)
    echo "Connecting to Postgres was mostly successful"
    ;;
  1)
    echo "Postgres is rejecting connections (for example during startup)"
    echo $STRUCTS_INDEXER_PG_CONNECTION
    exit 1
    ;;
  2)
    echo "Postgres gave no response to the connection attempt"
    echo $STRUCTS_INDEXER_PG_CONNECTION
    exit 1
    ;;
  3)
    echo "Could not attempt to connect to Postgres (invalid parameters)"
    echo $STRUCTS_INDEXER_PG_CONNECTION
    exit 1
    ;;
  *)
    echo "Connecting to Postgres failed in some other unique undocumented way, how exciting!"
    echo $STRUCTS_INDEXER_PG_CONNECTION
    exit 1
    ;;
esac

# TODO Deploy a testnet specific schema?

echo "Moving Indexer specific configuration files into place"
cp ~/config/indexer/* $STRUCTS_PATH/config/

echo "Updating config.toml to point to postgres"
echo $STRUCTS_INDEXER_PG_CONNECTION
sed -i 's#psql-conn.*.$#psql-conn = "'$STRUCTS_INDEXER_PG_CONNECTION'"#' /var/structs/chain/config/config.toml

echo "Node successfully configured for indexing"

exit 0