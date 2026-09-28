# Docker

The repository comes with a `Dockerfile` for a witness node image and a `compose.yml`
to run it.

## Running a node

    docker compose up -d
    docker compose logs -f

or without compose:

    docker run -d --name graphene --stop-timeout 300 \
        -v graphene-data:/var/lib/graphene \
        -p 1776:1776 -p 127.0.0.1:8090:8090 \
        ghcr.io/graphene-blockchain/graphene-core:latest

Things to keep in mind:

* **Stop timeout.** The node writes its object database to disk only when it exits
  cleanly on SIGINT, which takes a while. `docker stop` waits 10 seconds by default and
  then kills the process; the database is left unusable and the next start replays the
  whole chain. `compose.yml` sets `stop_grace_period: 5m`, with `docker run` use
  `--stop-timeout 300`.
* **Data directory.** `/var/lib/graphene` holds the blockchain, `config.ini` and the
  logs. Mount a named volume or a host directory there; the image declares no volume, so
  without a mount the data is lost with the container.
* **User.** The node runs as uid/gid 10001 (`graphene`). The container starts as root
  only to fix up permissions and then drops to it: a data directory whose top level
  belongs to someone else (a fresh host directory) is chowned to 10001, and a file passed
  to `witness_node` that 10001 cannot read, such as a bind-mounted `api-access.json` with
  mode 600 owned by root on the host, is copied to `/run/graphene` and the option is
  pointed to the copy. Started with `--user`, the container does none of this. Commands
  run with `docker exec` start as root: add `-u graphene`, or files the wallet writes to
  the data directory end up owned by root.
* **RPC.** The examples publish the websocket RPC port 8090 on localhost only.

On the first start the node writes a default `config.ini` and `logging.ini` to the data
directory. Edit them there and restart the container.

Arguments after the image name are passed to `witness_node`:

    docker run --rm IMAGE --version
    docker run ... IMAGE --replay-blockchain

An argument that does not start with `-` is run as a command instead, e.g. the wallet
against a running node:

    docker exec -it -u graphene graphene cli_wallet -s ws://127.0.0.1:8090
    docker run --rm IMAGE get_dev_key <prefix> <seed>

## Windows (Docker Desktop)

The simplest way is PowerShell: the container then shows up in Docker Desktop and can be managed there.

    docker run -d --name graphene --stop-timeout 300 `
      -v graphene-data:/var/lib/graphene `
      -p 1776:1776 -p 127.0.0.1:8090:8090 `
      grapheneblockchain/graphene-core:latest

The stop timeout is stored with the container, so the Stop button of Docker Desktop also waits up to 5 minutes.

To set the node up in the Docker Desktop window instead:

1. **Volumes → Create**, name `graphene-data`.
2. **Images → `grapheneblockchain/graphene-core:latest` → Run → Optional settings**:
   * Container name: `graphene`;
   * Ports: host port `1776` for container port `1776` (P2P) and, if the RPC is needed, `8090` for `8090`;
   * Volumes: host path `graphene-data`, container path `/var/lib/graphene`;
   * Environment variables, optional: e.g. `GRAPHENED_PLUGINS` (see below).

The Run window has no stop timeout setting: its Stop button kills the node after 10 seconds, which may leave the
database unwritten and force a full replay on the next start. It also publishes the RPC port on all interfaces, not
only on localhost. Prefer the PowerShell command above for a node that keeps running.

The wallet, from PowerShell:

    docker exec -it -u graphene graphene cli_wallet -s ws://127.0.0.1:8090

## Environment variables

The entry point translates these variables into `witness_node` options. Options on the
command line take precedence over `config.ini`.

| variable | option |
|---|---|
| `GRAPHENED_P2P_ENDPOINT` | `--p2p-endpoint`, default `0.0.0.0:1776` |
| `GRAPHENED_RPC_ENDPOINT` | `--rpc-endpoint`, default `0.0.0.0:8090` |
| `GRAPHENED_SEED_NODES` | `--seed-node`, space-separated list |
| `GRAPHENED_PLUGINS` | `--plugins`, space-separated list |
| `GRAPHENED_WITNESS_ID` | `--witness-id` |
| `GRAPHENED_PRIVATE_KEY` | `--private-key` |
| `GRAPHENED_TRACK_ACCOUNTS` | `--track-account`, space-separated list |
| `GRAPHENED_PARTIAL_OPERATIONS` | `--partial-operations` |
| `GRAPHENED_MAX_OPS_PER_ACCOUNT` | `--max-ops-per-account` |
| `GRAPHENED_ES_NODE_URL` | `--elasticsearch-node-url` |
| `GRAPHENED_ES_START_AFTER_BLOCK` | `--elasticsearch-start-es-after-block` |
| `GRAPHENED_TRUSTED_NODE` | `--trusted-node` |
| `GRAPHENED_REPLAY` | `--replay-blockchain`, if set |
| `GRAPHENED_RESYNC` | `--resync-blockchain`, if set |
| `GRAPHENED_ARGS` | extra options, split on whitespace |

## Building the image

    docker build -t graphene-core .

The build compiles the node inside the image on Ubuntu 26.04, the toolchain the code is
tested with, and the final image contains only the stripped binaries (`witness_node`,
`cli_wallet`, `get_dev_key`) and their runtime libraries. Compilation needs 1.5-2 GB of
memory per job; on a small machine limit the jobs with `--build-arg JOBS=2`.

The build context includes `.git`: the version string (`witness_node --version`) carries
the commit hash. Clone with `--recursive` so that the submodules are present.

The debug symbols of the binaries are kept in a separate build target. They are needed
to decode addresses of a stack trace from the stripped binaries with `addr2line`:

    docker build --target debug-symbols --output type=local,dest=debug-symbols .

## Published images

The GitHub workflow `.github/workflows/docker.yml` builds the image on every push. A
release tag `graphene-X.Y.Z` publishes it as `X.Y.Z` and `latest` to
`ghcr.io/graphene-blockchain/graphene-core` and `grapheneblockchain/graphene-core` on Docker Hub; the debug
symbols are attached to the GitHub release of the tag as
`graphene-core-X.Y.Z-debug-symbols-linux-x86_64.tar.xz` (a draft release is created if
the tag has none yet) and to every workflow run as an artifact. A pre-release tag `graphene-X.Y.Z-rcN`
is published as `X.Y.Z-rcN` only, without `latest`.
