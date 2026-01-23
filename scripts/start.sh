#!/usr/bin/env bash

if ! [ -f $STRUCTS_PATH/status/network ]; then
  echo "Network needs to be configured first"
  exit 1
fi

structsd start ${STRUCTSD_ARGUMENTS}