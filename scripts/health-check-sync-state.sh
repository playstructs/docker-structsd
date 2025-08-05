#!/usr/bin/env bash

STRUCTS_NODE_STATUS=$(structsd status | jq -r ".sync_info.catching_up")
if $STRUCTS_NODE_STATUS; then
  exit 1
fi

exit 0