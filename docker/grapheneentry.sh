#!/bin/bash
#
# Entry point of the Docker image.
#
# With no arguments, or with arguments starting with "-", runs witness_node on the
# data directory /var/lib/graphene, which should be a mounted volume:
#
#     docker run -v graphene-data:/var/lib/graphene IMAGE [witness_node options]
#
# Any other first argument is run as a command, e.g. `IMAGE cli_wallet -s ws://...`.
#
# Supported environment variables (translated into witness_node options):
#
#   GRAPHENED_P2P_ENDPOINT      --p2p-endpoint (default 0.0.0.0:1776)
#   GRAPHENED_RPC_ENDPOINT      --rpc-endpoint (default 0.0.0.0:8090)
#   GRAPHENED_SEED_NODES        --seed-node, space-separated list
#   GRAPHENED_PLUGINS           --plugins, space-separated list
#   GRAPHENED_WITNESS_ID        --witness-id
#   GRAPHENED_PRIVATE_KEY       --private-key
#   GRAPHENED_TRACK_ACCOUNTS    --track-account, space-separated list
#   GRAPHENED_PARTIAL_OPERATIONS --partial-operations
#   GRAPHENED_MAX_OPS_PER_ACCOUNT --max-ops-per-account
#   GRAPHENED_ES_NODE_URL       --elasticsearch-node-url
#   GRAPHENED_ES_START_AFTER_BLOCK --elasticsearch-start-es-after-block
#   GRAPHENED_TRUSTED_NODE      --trusted-node
#   GRAPHENED_REPLAY            --replay-blockchain, if set to anything
#   GRAPHENED_RESYNC            --resync-blockchain, if set to anything
#   GRAPHENED_ARGS              extra options, split on whitespace
#
# Options given on the command line take precedence over config.ini in the data
# directory, so the endpoint defaults above apply unless the variables are set.

set -e

if [[ $# -gt 0 && "$1" != -* ]]; then
    exec "$@"
fi

DATA_DIR="${GRAPHENED_DATA_DIR:-/var/lib/graphene}"

ARGS=( --data-dir "$DATA_DIR"
       --p2p-endpoint "${GRAPHENED_P2P_ENDPOINT:-0.0.0.0:1776}"
       --rpc-endpoint "${GRAPHENED_RPC_ENDPOINT:-0.0.0.0:8090}" )

for NODE in $GRAPHENED_SEED_NODES; do
    ARGS+=( --seed-node "$NODE" )
done
for ACCOUNT in $GRAPHENED_TRACK_ACCOUNTS; do
    ARGS+=( --track-account "$ACCOUNT" )
done

[[ -n "$GRAPHENED_PLUGINS" ]]             && ARGS+=( --plugins "$GRAPHENED_PLUGINS" )
[[ -n "$GRAPHENED_WITNESS_ID" ]]          && ARGS+=( --witness-id "$GRAPHENED_WITNESS_ID" )
[[ -n "$GRAPHENED_PRIVATE_KEY" ]]         && ARGS+=( --private-key "$GRAPHENED_PRIVATE_KEY" )
[[ -n "$GRAPHENED_PARTIAL_OPERATIONS" ]]  && ARGS+=( --partial-operations "$GRAPHENED_PARTIAL_OPERATIONS" )
[[ -n "$GRAPHENED_MAX_OPS_PER_ACCOUNT" ]] && ARGS+=( --max-ops-per-account "$GRAPHENED_MAX_OPS_PER_ACCOUNT" )
[[ -n "$GRAPHENED_ES_NODE_URL" ]]         && ARGS+=( --elasticsearch-node-url "$GRAPHENED_ES_NODE_URL" )
[[ -n "$GRAPHENED_ES_START_AFTER_BLOCK" ]] && ARGS+=( --elasticsearch-start-es-after-block "$GRAPHENED_ES_START_AFTER_BLOCK" )
[[ -n "$GRAPHENED_TRUSTED_NODE" ]]        && ARGS+=( --trusted-node "$GRAPHENED_TRUSTED_NODE" )
[[ -n "$GRAPHENED_REPLAY" ]]              && ARGS+=( --replay-blockchain )
[[ -n "$GRAPHENED_RESYNC" ]]              && ARGS+=( --resync-blockchain )

# shellcheck disable=SC2206 # GRAPHENED_ARGS is split on whitespace on purpose
ARGS+=( $GRAPHENED_ARGS )

# exec keeps witness_node as PID 1, so it receives the SIGINT from `docker stop`
# directly and can flush the object database before exiting.
exec /usr/local/bin/witness_node "${ARGS[@]}" "$@"
