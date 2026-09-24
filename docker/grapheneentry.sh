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
#
# The container starts as root only to fix up permissions, then drops to the user
# graphene (uid/gid 10001) before running anything:
#
#   - the data directory is chowned to graphene if its top level belongs to
#     someone else (a fresh host directory);
#   - a file given to witness_node (--api-access, --genesis-json, ...) that
#     graphene cannot read, e.g. a bind-mounted file with mode 600 owned by root on
#     the host, is copied to /run/graphene with graphene as the owner, and the
#     option points to the copy.
#
# Started with `--user`, the script does none of this and runs as that user.

set -e

DATA_DIR="${GRAPHENED_DATA_DIR:-/var/lib/graphene}"

as_graphene() {
    setpriv --reuid=graphene --regid=graphene --init-groups "$@"
}

run() {
    if [[ $(id -u) -eq 0 ]]; then
        exec setpriv --reuid=graphene --regid=graphene --init-groups "$@"
    fi
    exec "$@"
}

# Prints a path to the contents of $1 that graphene can read: $1 itself or a copy.
COPIES=0
readable_copy() {
    if as_graphene test -r "$1"; then
        echo "$1"
        return
    fi
    local dst
    COPIES=$((COPIES + 1))
    dst="/run/graphene/$COPIES-$(basename "$1")"
    install -d -m 700 -o graphene -g graphene /run/graphene
    install -m 400 -o graphene -g graphene "$1" "$dst"
    echo "grapheneentry: $1 is not readable by uid 10001, using a copy in $dst" >&2
    echo "$dst"
}

if [[ $(id -u) -eq 0 && -d "$DATA_DIR" && "$(stat -c %u:%g "$DATA_DIR")" != 10001:10001 ]]; then
    echo "grapheneentry: $DATA_DIR is not owned by uid 10001, chowning it" >&2
    chown -R graphene:graphene "$DATA_DIR"
fi

if [[ $# -gt 0 && "$1" != -* ]]; then
    run "$@"
fi

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

ARGS+=( "$@" )

if [[ $(id -u) -eq 0 ]]; then
    for i in "${!ARGS[@]}"; do
        arg="${ARGS[$i]}"
        if [[ "$arg" == --*=* && -f "${arg#*=}" ]]; then
            ARGS[i]="${arg%%=*}=$(readable_copy "${arg#*=}")"
        elif [[ -f "$arg" ]]; then
            ARGS[i]="$(readable_copy "$arg")"
        fi
    done
fi

# exec (in run, and in setpriv) keeps witness_node as PID 1, so it receives the
# SIGINT from `docker stop` directly and can flush the object database before
# exiting.
run /usr/local/bin/witness_node "${ARGS[@]}"
