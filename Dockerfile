# syntax=docker/dockerfile:1
#
# Graphene witness node image.
#
#   docker build -t graphene-core .
#   docker run -d --name graphene --stop-timeout 300 \
#       -v graphene-data:/var/lib/graphene -p 1776:1776 -p 127.0.0.1:8090:8090 graphene-core
#
# The node flushes its object database to disk only on a clean exit. Give it time
# to do so (--stop-timeout / stop_grace_period, see compose.yml): the default ten
# seconds of `docker stop` end in SIGKILL and a full replay on the next start.
#
# The separate debug symbols of the binaries can be exported with
#
#   docker build --target debug-symbols --output type=local,dest=out .
#
# They are needed to decode a stack trace from the stripped binaries (addr2line).

ARG UBUNTU=26.04

FROM ubuntu:${UBUNTU} AS builder

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential cmake git autoconf automake libtool pkg-config ccache mold \
      libboost-all-dev libssl-dev libreadline-dev zlib1g-dev libbz2-dev \
      libcurl4-openssl-dev libzstd-dev libncurses-dev libicu-dev liblzma-dev \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY . /src
WORKDIR /build

# A clone without --recursive (or a source archive from GitHub) lacks the
# submodules; say so instead of letting cmake fail deep inside fc.
RUN for m in libraries/fc libraries/fc/vendor/editline \
             libraries/fc/vendor/secp256k1-zkp libraries/fc/vendor/websocketpp; do \
      if [ -z "$(ls -A /src/$m 2>/dev/null)" ]; then \
        echo "ERROR: submodule $m is missing. Clone with --recursive or run" >&2; \
        echo "       git submodule update --init --recursive" >&2; \
        exit 1; \
      fi; \
    done

# Jobs default to the number of CPUs; lower it on small machines, every compiler
# process of the heavy translation units needs 1.5-2 GB of memory.
ARG JOBS
# The ccache directory is a cache mount; CI carries it between runs (see
# .github/workflows/docker.yml), so a commit rebuilds only what it changed.
ENV CCACHE_DIR=/root/.cache/ccache CCACHE_MAXSIZE=2G
RUN --mount=type=cache,target=/root/.cache/ccache \
    ccache -z && \
    cmake -S /src -B /build \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_CXX_FLAGS_RELWITHDEBINFO="-O3 -g -DNDEBUG" \
      -DCMAKE_C_FLAGS_RELWITHDEBINFO="-O3 -g -DNDEBUG" \
      -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
      -DCMAKE_LINKER_TYPE=MOLD && \
    cmake --build /build --parallel ${JOBS:-$(nproc)} \
      --target witness_node cli_wallet get_dev_key && \
    ccache -s && \
    mkdir -p /out/bin /out/debug && \
    for f in programs/witness_node/witness_node programs/cli_wallet/cli_wallet \
             programs/genesis_util/get_dev_key; do \
      name=$(basename $f) && \
      objcopy --only-keep-debug $f /out/debug/$name.debug && \
      objcopy --strip-all --add-gnu-debuglink=/out/debug/$name.debug $f /out/bin/$name ; \
    done && \
    /out/bin/witness_node --version

FROM scratch AS debug-symbols
COPY --from=builder /out/debug/ /

FROM ubuntu:${UBUNTU}

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends libssl3t64 libcurl4t64 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# A fixed uid for the node. The container starts as root and the entry point drops
# to it after fixing up the owner of the data directory and of unreadable mounted
# files, see docker/grapheneentry.sh.
RUN groupadd --system --gid 10001 graphene && \
    useradd --system --uid 10001 --gid graphene --home-dir /var/lib/graphene \
      --shell /usr/sbin/nologin graphene && \
    install -d -o graphene -g graphene /var/lib/graphene

COPY --from=builder /out/bin/ /usr/local/bin/
COPY docker/grapheneentry.sh /usr/local/bin/grapheneentry.sh

WORKDIR /var/lib/graphene
ENV HOME=/var/lib/graphene

# No VOLUME: an anonymous volume would outlive `docker rm` as nameless garbage of
# many gigabytes. Mount the data directory explicitly.

# P2P
EXPOSE 1776
# websocket RPC
EXPOSE 8090

# witness_node exits cleanly on SIGINT
STOPSIGNAL SIGINT

ENTRYPOINT ["/usr/local/bin/grapheneentry.sh"]
