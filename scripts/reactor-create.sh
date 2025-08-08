#!/usr/bin/env bash

if ! [ -f $STRUCTS_REACTOR_SHARE/reactor_pub_key.json ]; then
  echo "Reactor needs to be initialized"
  exit 1
fi

mkdir $STRUCTS_PATH/config
cp /root/config/client/client.toml $STRUCTS_PATH/config/

echo "Updating client.toml with the correct Chain ID ${STRUCTS_CHAIN_ID}"
sed -i 's/chain-id.*.$/chain-id = "'$STRUCTS_CHAIN_ID'"/' $STRUCTS_PATH/config/client.toml

echo "Updating client.toml with the correct host ${STRUCTSD_HOST}"
sed -i 's#node = "tcp://localhost:26657"$#node = "tcp://'$STRUCTSD_HOST':26657"#' $STRUCTS_PATH/config/client.toml

STRUCTS_NODE_STATUS=$(structsd status | jq -r ".sync_info.catching_up")
while $STRUCTS_NODE_STATUS; do
  echo "Node is not ready, still syncing"
  sleep 30
  STRUCTS_NODE_STATUS=$(structsd status | jq -r ".sync_info.catching_up")
done

STRUCTS_VALIDATOR_ADDRESS=$(cat $STRUCTS_REACTOR_SHARE/reactor_address)
STRUCTS_VALIDATOR_COUNT=$(structsd query staking validator $STRUCTS_VALIDATOR_ADDRESS --output json 2>/dev/null | jq length | awk 'NF || $0 == "" { print ($0 == "" ? 0 : $0) } END { if (NR == 0) print 0 }')

STRUCTS_VALIDATOR_PUB_KEY_DETAILS=$(cat $STRUCTS_REACTOR_SHARE/reactor_pub_key.json)

if [ "$STRUCTS_VALIDATOR_COUNT" -eq 0 ]; then
  echo "The Reactor is not found onchain, creating..."

  echo "Setup Guild Admin Key"
  echo "$STRUCTS_GUILD_MNEMONIC" | structsd keys add guild_admin --recover
  STRUCTS_GUILD_ADMIN_ADDRESS=$(structsd keys show guild_admin -a )

  echo "Confirming wallet has enough funds ${STRUCTS_GUILD_ADMIN_ADDRESS}"
  STRUCTS_GUILD_ADMIN_BALANCE=$(structsd query bank balance $STRUCTS_GUILD_ADMIN_ADDRESS ualpha --output json | jq -r .balance.amount)
  if [ "$STRUCTS_GUILD_ADMIN_BALANCE" -lt "$STRUCTS_VALIDATOR_INITIAL_STAKING_AMOUNT" ]; then
    echo "The Mnemonic provided ${STRUCTS_GUILD_ADMIN_ADDRESS} does not have a large enough balance for the initial staking (${STRUCTS_GUILD_ADMIN_BALANCE}ualpha < ${STRUCTS_VALIDATOR_INITIAL_STAKING_AMOUNT}ualpha)"
    exit 1
  fi

  echo "Preparing the reactor.json file"
  cat /root/config/reactor-create/reactor.template.json > $STRUCTS_REACTOR_SHARE/reactor.json
  echo "####### reactor.json ############"
  cat $STRUCTS_REACTOR_SHARE/reactor.json
  echo "####### reactor.json ############"


  echo "Pub Key Details: ${STRUCTS_VALIDATOR_PUB_KEY_DETAILS}"
  sed -i "s#VALIDATOR_PUB_KEY_DETAILS#${STRUCTS_VALIDATOR_PUB_KEY_DETAILS}#" $STRUCTS_REACTOR_SHARE/reactor.json
  echo "Initial Staking Amount: ${STRUCTS_VALIDATOR_INITIAL_STAKING_AMOUNT}ualpha"
  sed -i "s#VALIDATOR_INITIAL_STAKING_AMOUNT#${STRUCTS_VALIDATOR_INITIAL_STAKING_AMOUNT}ualpha#" $STRUCTS_REACTOR_SHARE/reactor.json

  echo "Moniker: ${STRUCTS_MONIKER}"
  sed -i "s#VALIDATOR_MONIKER#${STRUCTS_MONIKER}#" $STRUCTS_REACTOR_SHARE/reactor.json

  echo "Identity: ${STRUCTS_VALIDATOR_IDENTITY}"
  sed -i "s#VALIDATOR_IDENTITY#${STRUCTS_VALIDATOR_IDENTITY}#" $STRUCTS_REACTOR_SHARE/reactor.json

  echo "Website: ${STRUCTS_GUILD_WEBSITE}"
  sed -i "s#VALIDATOR_WEBSITE#${STRUCTS_GUILD_WEBSITE}#" $STRUCTS_REACTOR_SHARE/reactor.json

  echo "Security Contact: ${STRUCTS_GUILD_CONTACT}"
  sed -i "s#VALIDATOR_SECURITY_CONTACT#${STRUCTS_GUILD_CONTACT}#" $STRUCTS_REACTOR_SHARE/reactor.json

  # Description is used later, should not be set to anything special at this stage.
  sed -i "s#VALIDATOR_DESCRIPTION##" $STRUCTS_REACTOR_SHARE/reactor.json

  echo "Commission Rate: ${STRUCTS_VALIDATOR_COMMISSION_RATE}"
  sed -i "s#VALIDATOR_COMMISSION_RATE#${STRUCTS_VALIDATOR_COMMISSION_RATE}#" $STRUCTS_REACTOR_SHARE/reactor.json

  echo "Max Rate: ${STRUCTS_VALIDATOR_MAX_RATE}"
  sed -i "s#VALIDATOR_MAX_RATE#${STRUCTS_VALIDATOR_MAX_RATE}#" $STRUCTS_REACTOR_SHARE/reactor.json

  echo "Max Change Rate: ${STRUCTS_VALIDATOR_MAX_CHANGE_RATE}"
  sed -i "s#VALIDATOR_MAX_CHANGE_RATE#${STRUCTS_VALIDATOR_MAX_CHANGE_RATE}#" $STRUCTS_REACTOR_SHARE/reactor.json

  echo "Min Self Delegation: ${STRUCTS_VALIDATOR_MIN_SELF_DELEGATION}"
  sed -i "s#VALIDATOR_MIN_SELF_DELEGATION#${STRUCTS_VALIDATOR_MIN_SELF_DELEGATION}#" $STRUCTS_REACTOR_SHARE/reactor.json

  echo "Final reactor.json"
  echo "####### reactor.json ############"
  cat $STRUCTS_REACTOR_SHARE/reactor.json
  echo "####### reactor.json ############"

  echo "Reactor Creation transaction"
  structsd tx staking create-validator "${STRUCTS_REACTOR_SHARE}/reactor.json" --from guild_admin --gas auto --yes

  sleep 10
  echo "Checking for confirmation..."

  STRUCTS_VALIDATOR_COUNT=$(structsd query staking validator $STRUCTS_VALIDATOR_ADDRESS --output json 2>/dev/null | jq length | awk 'NF || $0 == "" { print ($0 == "" ? 0 : $0) } END { if (NR == 0) print 0 }')
  if [ "$STRUCTS_VALIDATOR_COUNT" -eq 0 ]; then
    echo "Validator creation seems to have failed"
    cat $STRUCTS_REACTOR_SHARE/reactor.json
    exit 1
  fi

else
  echo "Reactor is already onchain"
fi

exit 0