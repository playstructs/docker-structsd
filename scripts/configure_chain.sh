#!/usr/bin/env bash
# Prepare to launch chain


# Check for the ready file marker
# if it exists, don't do it again
if [ ! -f /var/structs/ready ]
then
  echo "Configuring structsd Chain"
  if [ ! -f /var/structs/chain/config/config.toml ]
  then

    echo "Building latest structsd"
    git clone https://github.com/playstructs/structsd.git
    cd structsd
    ignite build

    echo "Putting genesis into place"


    echo "Initializing chain because nothing's there"
    /root/go/bin/structsd init --home /var/structs/chain
  fi

  echo "Updating config.toml to point to postgres"
  echo $NODE_INDEXER_PG_CONNECTION
  sed -i 's/indexer = "kv"/indexer = "pg"/' /var/structs/chain/config/config.toml
  sed -i "s/psql-conn = \"\"/psql-conn = \"$NODE_INDEXER_PG_CONNECTION\"/" /var/structs/chain/config/config.toml

	touch /var/structs/ready

fi
