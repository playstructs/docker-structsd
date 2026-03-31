#!/usr/bin/env bash

echo "Inserting Genesis Data into Structs DB"

echo "Deleting old genesis entries"
psql ${STRUCTS_INDEXER_PG_CONNECTION} --set=sslmode=require -c "DELETE FROM structs.ledger WHERE action = 'genesis';"

GENESIS_FILE="$STRUCTS_PATH/config/genesis.json"

ALL_GENESIS_TIME=$(jq -r '.genesis_time' "$GENESIS_FILE")
echo "Genesis time: ${ALL_GENESIS_TIME}"

SQL="BEGIN;\n"

# ---------------------------------------------------------------------------
# 1. Bank Balances
# ---------------------------------------------------------------------------
echo "Processing bank balances..."

BANK_SQL=$(jq -r --arg gt "$ALL_GENESIS_TIME" '
  .app_state.bank.balances[] |
  .address as $addr |
  .coins[] |
  "INSERT INTO structs.ledger(address, amount_p, block_height, time, action, direction, denom) VALUES(\u0027" + $addr + "\u0027,\u0027" + .amount + "\u0027, 0, \u0027" + $gt + "\u0027, \u0027genesis\u0027, \u0027credit\u0027, \u0027" + .denom + "\u0027);"
' "$GENESIS_FILE")

SQL+="${BANK_SQL}\n"

BANK_COUNT=$(echo "$BANK_SQL" | grep -c "^INSERT")
echo "  ${BANK_COUNT} bank balance entries"

# ---------------------------------------------------------------------------
# 2. Staking Delegations
# ---------------------------------------------------------------------------
echo "Processing staking delegations..."

DELEGATION_SQL=$(jq -r --arg gt "$ALL_GENESIS_TIME" '
  (.app_state.staking.validators | map({key: .operator_address, value: {tokens: (.tokens | tonumber), shares: (.delegator_shares | tonumber)}}) | from_entries) as $validators |

  .app_state.staking.delegations[] |
  .delegator_address as $delegator |
  .validator_address as $validator |
  (.shares | tonumber) as $shares |

  ($validators[$validator].tokens // 0) as $vtokens |
  ($validators[$validator].shares // 1) as $vshares |
  (if $vshares > 0 then (($shares * $vtokens / $vshares) | floor | tostring) else "0" end) as $amount |

  "INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom) VALUES(\u0027" + $delegator + "\u0027, \u0027" + $validator + "\u0027, \u0027" + $amount + "\u0027, 0, \u0027" + $gt + "\u0027, \u0027genesis\u0027, \u0027credit\u0027, \u0027ualpha.infused\u0027);",

  "INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom) VALUES(\u0027" + $validator + "\u0027, \u0027" + $delegator + "\u0027, \u0027" + $amount + "\u0027, 0, \u0027" + $gt + "\u0027, \u0027genesis\u0027, \u0027credit\u0027, \u0027ualpha.infused\u0027);"
' "$GENESIS_FILE")

SQL+="${DELEGATION_SQL}\n"

DELEGATION_COUNT=$(echo "$DELEGATION_SQL" | grep -c "^INSERT")
echo "  ${DELEGATION_COUNT} delegation entries (from $(( DELEGATION_COUNT / 2 )) delegations)"

# ---------------------------------------------------------------------------
# 3. Unbonding Delegations
# ---------------------------------------------------------------------------
echo "Processing unbonding delegations..."

UNBONDING_SQL=$(jq -r --arg gt "$ALL_GENESIS_TIME" '
  .app_state.staking.unbonding_delegations[] |
  .delegator_address as $delegator |
  .validator_address as $validator |
  .entries[] |
  .balance as $amount |

  "INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom) VALUES(\u0027" + $delegator + "\u0027, \u0027" + $validator + "\u0027, \u0027" + $amount + "\u0027, 0, \u0027" + $gt + "\u0027, \u0027genesis\u0027, \u0027credit\u0027, \u0027ualpha.defusing\u0027);",

  "INSERT INTO structs.ledger(address, counterparty, amount_p, block_height, time, action, direction, denom) VALUES(\u0027" + $validator + "\u0027, \u0027" + $delegator + "\u0027, \u0027" + $amount + "\u0027, 0, \u0027" + $gt + "\u0027, \u0027genesis\u0027, \u0027credit\u0027, \u0027ualpha.defusing\u0027);"
' "$GENESIS_FILE")

SQL+="${UNBONDING_SQL}\n"

UNBONDING_COUNT=$(echo "$UNBONDING_SQL" | grep -c "^INSERT")
echo "  ${UNBONDING_COUNT} unbonding entries (from $(( UNBONDING_COUNT / 2 )) unbonding delegations)"

# ---------------------------------------------------------------------------
# 4. Player Ore Balances (from gridList, attribute type 0 on object type 1)
# ---------------------------------------------------------------------------
echo "Processing player ore balances..."

ORE_SQL=$(jq -r --arg gt "$ALL_GENESIS_TIME" '
  (.app_state.structs.playerList | map({key: .index, value: .primaryAddress}) | from_entries) as $players |

  [.app_state.structs.gridList[] | select(.attributeId | startswith("0-1-")) | select(.value != "0")] |
  .[] |
  (.attributeId | split("-") | .[2]) as $playerIndex |
  ($players[$playerIndex] // "") as $addr |

  select($addr != "") |

  "INSERT INTO structs.ledger(address, amount_p, block_height, time, action, direction, denom) VALUES(\u0027" + $addr + "\u0027, \u0027" + .value + "\u0027, 0, \u0027" + $gt + "\u0027, \u0027genesis\u0027, \u0027credit\u0027, \u0027ore\u0027);"
' "$GENESIS_FILE")

SQL+="${ORE_SQL}\n"

ORE_COUNT=$(echo "$ORE_SQL" | grep -c "^INSERT")
echo "  ${ORE_COUNT} player ore entries"

# ---------------------------------------------------------------------------
# Execute all SQL in a single transaction
# ---------------------------------------------------------------------------
SQL+="COMMIT;\n"

TOTAL_COUNT=$(echo -e "$SQL" | grep -c "^INSERT")
echo ""
echo "Executing ${TOTAL_COUNT} total INSERT statements in a single transaction..."

echo -e "$SQL" | psql ${STRUCTS_INDEXER_PG_CONNECTION} --set=sslmode=require

echo "Genesis insert complete!"
