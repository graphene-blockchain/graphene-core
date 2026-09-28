# graphene-core 1.2.0

**Date:** September 2026
**Branch:** `graphene` ([graphene-blockchain/graphene-core](https://github.com/graphene-blockchain/graphene-core/tree/graphene))
**Tag:** `graphene-1.2.0`
**Previous version:** 1.1 — tag `graphene-1.1` (September 15, 2026), [release notes](RELEASE_NOTES_1.1.md)

## Summary

graphene-core 1.2.0 fixes the four defects found after the 1.1 release: the peer database erased on every shutdown,
a BitShares version string in `--version`, `cli_wallet` unable to connect over `wss://`, and unmasked websocket frames
from clients. Two more were found and fixed along the way: a startup race that delayed `--seed-node` connections by
30 seconds, and the intermittent `app_test/two_node_network`.

1.2.0 is also the first release with a working Docker image. It is built on Ubuntu 26.04 and published to Docker Hub
and the GitHub Container Registry by a GitHub Actions workflow.

All submodules now come from the `graphene-blockchain` forks; `secp256k1-zkp` moved there from `bitshares` in 1.2.0.

The built-in seed node list has been refreshed.

Consensus rules, block format and serialization are unchanged.

## Getting the node

The five ways to get a node, from Docker images to source builds, are described in [README.md](README.md#getting-started);
running the node in a container is described in [README-docker.md](README-docker.md).

```
docker pull grapheneblockchain/graphene-core:1.2.0
docker pull ghcr.io/graphene-blockchain/graphene-core:1.2.0
```

Release candidates are published only under their own tags, e.g. `1.3.0-rc1`; `latest` points to the newest release.

The toolchain is the same as in 1.1: Ubuntu 26.04 with GCC 15, CMake 4, Boost 1.90 and OpenSSL 3.5. In an existing
clone, run `git submodule sync --recursive && git submodule update --init --recursive` after updating: the
`secp256k1-zkp` submodule points to a new repository (see below).

## Repositories

All submodules are built from the `graphene-blockchain` forks:

- [graphene-fc](https://github.com/graphene-blockchain/graphene-fc) (`libraries/fc`) carries the 1.2.0 fixes: TLS 1.2+,
  masked client frames and the git hash;
- [websocketpp](https://github.com/graphene-blockchain/websocketpp) and [editline](https://github.com/graphene-blockchain/editline)
  (`fc/vendor/`) are unchanged since 1.1;
- [secp256k1-zkp](https://github.com/graphene-blockchain/secp256k1-zkp) (`fc/vendor/secp256k1-zkp`) is new in 1.2.0.
  1.1 took the library directly from `bitshares/secp256k1-zkp`; the fork is on the same commit, `bd06794`, so the code is
  unchanged, and every dependency of the node is now built from a repository of the organization.

## Bug fixes

### Peer database erased on every shutdown
The P2P node was closed three times during one shutdown: in `application::shutdown()`, in `~application()` and in
`~node_impl()`. `peer_database_impl::close()` saved the peers to `p2p/peers.json` and cleared them, so the second and
third calls wrote `[]` over the file. The node always started from the built-in seed nodes.

- `peer_database_impl::close()` writes the file only on the first call after `open()`.

Verified with two local nodes: after `SIGINT` the old binary leaves `[]` in `peers.json`, the new one keeps the peer.
The new test `tests/tests/peer_database_tests.cpp` fails on the old code and passes on the new.
Commit: graphene-core `d103612e`.

### `--version` showed a BitShares tag
The version came from `git describe --tags`, and the history still contains the BitShares release tags. The result
was `2.0.171025-minor-fix-1-…`, or `unknown` in a clone without tags.

- The release number is set in the code: `set( GRAPHENE_VERSION "1.2.0" )` in the root `CMakeLists.txt`. It changes
  together with the `graphene-<version>` tag and is also used as the CPack package version.
- The build string is the version plus 8 characters of the commit hash, e.g. `1.2.0-8bbc9c44`; without git (a
  source archive), just `1.2.0`. A new commit is picked up by `make`, without re-running `cmake`.
- `witness_node --version` and `cli_wallet --version` print an aligned table; `about()` in the wallet reports the same
  build string as `client_version`.

```
Version:     1.2.0
Build:       1.2.0-8bbc9c44
SHA:         8bbc9c44798c2ee071256df67931b5a4bf887498
Timestamp:   …
SSL:         OpenSSL 3.5.5 27 Jan 2026
Boost:       1.90
Websocket++: 0.7.0
```

Fixed along the way:
- `get_git_head_revision()` in fc returned the branch name instead of the hash when refs were packed (`git gc`,
  `git pack-refs`). The hash now comes from `git rev-parse HEAD`, which fixes both `graphene_revision` and
  `fc_revision`.
- The P2P user agent is `Graphene Reference Implementation` instead of `BitShares Reference Implementation`.

Commits: graphene-core `4f7738c9`, `98f6d662`; graphene-fc `51b844d`.

### `cli_wallet` could not connect over `wss://`
fc created its TLS contexts as `ssl::context::tlsv1`, which fixes both the minimum and the maximum version to TLS 1.0.
OpenSSL 3.5 forbids TLS 1.0 at its default security level, so the client sent a `protocol_version` alert instead of a
ClientHello. The node's TLS RPC server could not accept a single connection either.

SNI was not broken, contrary to the 1.1 release notes: websocketpp sets it from the endpoint role.

- Contexts are created with `tls_client` / `tls_server`; TLS 1.2 and 1.3 are supported, and a connection uses the
  newest version both sides know. TLS 1.0 and 1.1 are disabled.

Verified end to end: `cli_wallet` → `witness_node` over `wss` connects with TLS 1.3 and SNI. A certificate for another
host name, an unknown CA and a TLS 1.0-only server are rejected.
Commit: graphene-fc `a090fad`.

### Websocket client frames were sent with a zero mask
fc's client endpoints were built on the server configs `asio` / `asio_tls`. Their base `config::core` uses
`random::none` as the random number generator, which always returns zero, so every client frame carried the masking
key `00 00 00 00`. RFC 6455 requires a random key, and strict intermediaries drop such frames.

- Client endpoints have their own configs based on `asio_client` / `asio_tls_client`, with `random_device` as the
  generator. Logging, the handshake timeout and permessage-deflate are unchanged.

Verified with a probe that prints the masking key of each client frame: `00000000` with the old `cli_wallet`, random
keys with the new one, over both `ws` and `wss`.
Commit: graphene-fc `a090fad` (a separate change from the TLS fix, in the same commit).

### `--seed-node` connections delayed by 30 seconds
The node connected to its `--seed-node` peers before `connect_to_p2p_network()`. Until the connection loop is running,
`is_accepting_new_connections()` returns false, so the seed's early hello was rejected with "not accepting any more
incoming connections", and the next attempt came only after
`GRAPHENE_NET_DEFAULT_PEER_CONNECTION_RETRY_TIME` (30 seconds).

- Connections to seed nodes are opened after `connect_to_p2p_network()` and `sync_from()`.

Commit: graphene-core `dc124416`.

### Intermittent `app_test/two_node_network`
The test failed in about half of the runs on a 2-core machine. There were four causes:

- the two nodes could get different genesis files, and so different chain ids, when a 3-second boundary fell between
  the two `create_genesis_file()` calls; both nodes now share one file;
- the second node's port stayed in `TIME-WAIT` for about a minute after a run; it now listens on a random port;
- the `--seed-node` startup race above;
- a transaction broadcast while the peer was still syncing was dropped; the test now repeats the broadcast every
  500 ms until the transaction arrives.

Fixed `usleep` calls were replaced with `wait_for()`, which polls a condition for up to 10 seconds.
Verified: 100 / 100 single runs, 10 / 10 full `app_test` runs, 20 / 20 with both cores under load.
Commit: graphene-core `af54f065`.

## Seed nodes

The built-in list of seed nodes in `libraries/egenesis/seed-nodes.txt` has been updated to the nodes that currently
accept P2P connections.

Commit: graphene-core [`c08d0142`](https://github.com/graphene-blockchain/graphene-core/commit/c08d014217041bc440607dc37a3e74162c30c296).

## Docker image

The `Dockerfile` inherited from BitShares was based on `phusion/baseimage:0.11` (Ubuntu 18.04) and no longer built.
It has been rewritten.

- **Multi-stage build.** The `builder` stage compiles `witness_node`, `cli_wallet` and `get_dev_key` on Ubuntu 26.04
  as `RelWithDebInfo` (`-O3 -g`), linking with mold and caching with ccache.
- **Final image:** Ubuntu 26.04 with the stripped binaries and their runtime libraries, 254 MB on disk and 67 MB
  compressed.
- **Debug symbols** are split off with `objcopy` into a separate `debug-symbols` target. The workflow attaches them to
  the GitHub release of the tag as `graphene-core-X.Y.Z-debug-symbols-linux-x86_64.tar.xz`.
- **Version.** The build context includes `.git`, so `--version` in the container shows the commit hash.
- **Submodule check.** A clone without `--recurse-submodules` fails at the start of the build with a clear message.
- **Data.** Blockchain, `config.ini` and logs live in `/var/lib/graphene`. The image declares no `VOLUME`; mount a
  named volume or a host directory there.
- **Shutdown.** `STOPSIGNAL SIGINT`; `compose.yml` sets `stop_grace_period: 5m`, with `docker run` use
  `--stop-timeout 300`. The default of 10 seconds can kill the node before it writes its database, and the next start
  replays the whole chain.
- **Entry point.**
  - The node writes its default `config.ini` into the data directory on the first start. The old entry point replaced
    the user's `config.ini` with a symlink on every start.
  - Default endpoints: P2P `0.0.0.0:1776`, RPC `0.0.0.0:8090`.
  - Arguments after the image name go to `witness_node`; an argument that does not start with `-` is run as a command,
    e.g. `cli_wallet` or `get_dev_key`.
  - The `GRAPHENED_*` environment variables are kept.
- **Permissions.** The node runs as uid/gid 10001 (`graphene`). The container starts as root, fixes permissions and
  drops to 10001 with `setpriv`:
  - a data directory whose top level belongs to someone else is chowned to 10001;
  - a file passed to `witness_node` that 10001 cannot read, such as a bind-mounted `api-access.json` with mode 600
    owned by root, is copied to `/run/graphene` and the option is pointed to the copy;
  - `witness_node` stays PID 1 and receives `SIGINT` from `docker stop` directly.

  Started with `--user`, the container does none of this. Commands run with `docker exec` start as root: add
  `-u graphene`.
- `docker/default_config.ini` with BitShares settings has been removed.

### Publishing

The workflow `.github/workflows/docker.yml` builds the image on every push and pull request.

- Push or pull request: build and smoke test, nothing is published; the debug symbols are kept as a workflow artifact.
- Tag `graphene-X.Y.Z`: `X.Y.Z` and `latest` to Docker Hub and GHCR; a draft release with the debug symbols.
- Tag `graphene-X.Y.Z-rcN`: only `X.Y.Z-rcN`; a draft pre-release with the debug symbols.

The compiler cache is kept between runs: a warm build takes about 9 minutes, a cold one about 30.

## Tests

Full suite on Ubuntu 26.04:

- fc `all_tests`: 65 / 65;
- `chain_test`: 305 / 305, including the new `peer_database_tests`;
- `cli_test`: 15 / 15;
- `app_test`: 10 / 10 runs, see the `two_node_network` fix above.

Docker image: the workflow's smoke test runs `witness_node --version` and `cli_wallet --version` on every build. Key
generation with `get_dev_key`, uid 10001, ownership of the data volume and reading a root-owned `api-access.json` were
checked by hand.

## Performance

Full sync from scratch in a Docker image built from the same sources (`1.2.0-rc1`, published from a contributor fork before the organization registries existed), on a VPS with 2 vCPU, running next to a
production node on the same machine, with the plugins `account_history market_history grouped_orders
api_helper_indexes`:

- 7 h 16 min to block 55,849,207; a native 1.1 node on the same VPS took about 11 h;
- about 2,000 blocks/s, steady from the first hour to the last;
- 9.07 GB of data;
- `docker stop` on the full database: 4.1 s, clean exit; the restart took 2 s and replayed 7 reversible blocks,
  without a full replay.

## Compatibility

- No protocol changes and no hardforks.
- The P2P user agent string changed from `BitShares Reference Implementation` to `Graphene Reference Implementation`.
- TLS 1.0 and 1.1 are no longer accepted by `cli_wallet` or by the node's TLS RPC server.
- Docker: the image runs the node as uid 10001, reads its configuration from the data directory and no longer ships
  `docker/default_config.ini`. A data directory created by the old image is chowned to 10001 on the first start.

## Known limitations

- `cmake -DENABLE_INSTALLER=ON` fails: CPack looks for a missing `LICENSE.md`. This predates 1.2.0.
- In fc `all_tests`, the three `fc_stacktrace` tests fail on a build without `-g`: there is nothing to symbolize.

## Components

| Repository | Branch | Commit |
|---|---|---|
| [graphene-blockchain/graphene-core](https://github.com/graphene-blockchain/graphene-core/tree/graphene) | `graphene` | `graphene-1.2.0` |
| [graphene-blockchain/graphene-fc](https://github.com/graphene-blockchain/graphene-fc/tree/graphene) | `graphene` | `0a5fcbe` |
| [graphene-blockchain/websocketpp](https://github.com/graphene-blockchain/websocketpp/tree/fc) | `fc` | `571a7b0` |
| [graphene-blockchain/editline](https://github.com/graphene-blockchain/editline/tree/graphene) | `graphene` | `224e256` |
| [graphene-blockchain/secp256k1-zkp](https://github.com/graphene-blockchain/secp256k1-zkp/tree/graphene) | `graphene` | `bd06794` |

websocketpp, editline and secp256k1-zkp are on the same commits as in 1.1.

## Commits

**graphene-core** ([#6](https://github.com/graphene-blockchain/graphene-core/pull/6), [#7](https://github.com/graphene-blockchain/graphene-core/pull/7) and this documentation)
- [`d103612e`](https://github.com/graphene-blockchain/graphene-core/commit/d103612e) net: keep peers.json when the peer database is closed twice
- [`98f6d662`](https://github.com/graphene-blockchain/graphene-core/commit/98f6d662) app: announce the P2P node as Graphene, not BitShares
- [`4f7738c9`](https://github.com/graphene-blockchain/graphene-core/commit/4f7738c9) version: print 1.2.0 and a version-hash build string
- [`80ebf3c3`](https://github.com/graphene-blockchain/graphene-core/commit/80ebf3c3) fc: bump to graphene-fc 0a5fcbe (TLS 1.2+, masked client frames, git hash fix)
- [`dc124416`](https://github.com/graphene-blockchain/graphene-core/commit/dc124416) app: connect to --seed-node peers after the P2P node is running
- [`af54f065`](https://github.com/graphene-blockchain/graphene-core/commit/af54f065) tests: make app_test two_node_network deterministic
- [`c08d0142`](https://github.com/graphene-blockchain/graphene-core/commit/c08d0142) egenesis: drop the dead seed nodes, add three live ones
- [`3749b4da`](https://github.com/graphene-blockchain/graphene-core/commit/3749b4da) docker: rebuild the image on Ubuntu 26.04
- [`3a527787`](https://github.com/graphene-blockchain/graphene-core/commit/3a527787) ci: build the Docker image and publish it on release tags
- [`12629321`](https://github.com/graphene-blockchain/graphene-core/commit/12629321) ci: move the workflow actions to their Node 24 releases
- [`6391cf03`](https://github.com/graphene-blockchain/graphene-core/commit/6391cf03) ci: keep the compiler cache between workflow runs
- [`0f7579c8`](https://github.com/graphene-blockchain/graphene-core/commit/0f7579c8) ci: do not tag pre-releases as latest
- [`8bbc9c44`](https://github.com/graphene-blockchain/graphene-core/commit/8bbc9c44) docker: start as root, fix permissions, drop to uid 10001

**graphene-fc** ([graphene-fc#2](https://github.com/graphene-blockchain/graphene-fc/pull/2))
- [`a090fad`](https://github.com/graphene-blockchain/graphene-fc/commit/a090fad) websocket: TLS 1.2+ and masked client frames
- [`51b844d`](https://github.com/graphene-blockchain/graphene-fc/commit/51b844d) cmake: take the HEAD hash from git rev-parse
- [`c340d6b`](https://github.com/graphene-blockchain/graphene-fc/commit/c340d6b) build: point secp256k1-zkp at the graphene-blockchain fork
