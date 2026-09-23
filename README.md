Graphene Core
==============

[Build Status](https://travis-ci.org/graphene-blockchain/graphene-core/branches):

`master` | `develop` | `hardfork` | `testnet` | `bitshares-fc` 
 --- | --- | --- | --- | ---
 [![](https://travis-ci.org/graphene-blockchain/graphene-core.svg?branch=master)](https://travis-ci.org/graphene-blockchain/graphene-core) | [![](https://travis-ci.org/bitshares/bitshares-core.svg?branch=develop)](https://travis-ci.org/bitshares/bitshares-core) | [![](https://travis-ci.org/bitshares/bitshares-core.svg?branch=hardfork)](https://travis-ci.org/bitshares/bitshares-core) | [![](https://travis-ci.org/bitshares/bitshares-core.svg?branch=testnet)](https://travis-ci.org/bitshares/bitshares-core) | [![](https://travis-ci.org/bitshares/bitshares-fc.svg?branch=master)](https://travis-ci.org/bitshares/bitshares-fc) 


* [Getting Started](#getting-started)
* [Support](#support)
* [Using the API](#using-the-api)
* [Accessing restricted API's](#accessing-restricted-apis)
* [FAQ](#faq)
* [License](#license)

Graphene Core is the Graphene blockchain implementation and command-line interface.
The web wallet is [Graphene UI](https://github.com/graphene-blockchain/graphene-ui).

Visit [gph.ai](https://gph.ai/) to learn about Graphene and join the community at [forum.gph.ai](https://forum.gph.ai/).

Information for developers can be found in the [Graphene Developer Portal](https://developers.gph.ai/). Users interested in how bitshares works can go to the [Graphene Documentation](https://docs.gph.ai/) site.


Getting Started
---------------
Version 1.1 builds on a current toolchain: Ubuntu 26.04 LTS with GCC 15, CMake 4, Boost 1.90 and OpenSSL 3.5.
Version 1.0 built only on Ubuntu 18.04–20.04. See [RELEASE_NOTES_1.1.md](RELEASE_NOTES_1.1.md) for the full list of
changes and bug fixes.

We recommend building on Ubuntu 26.04 LTS (64-bit). This is the only system 1.1 has been built and tested on.

**Build Dependencies**:

    sudo apt-get update
    sudo apt-get install build-essential cmake git autoconf automake libtool pkg-config libboost-all-dev libssl-dev libreadline-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libzstd-dev libncurses-dev libicu-dev liblzma-dev doxygen

`libicu-dev` and `liblzma-dev` are required to link against the static Boost libraries.

**Build Script, option 1, debug build** (`witness_node` 366 MB, `cli_wallet` 426 MB): same optimisation as Release
plus full debug information, for running the node under a debugger or reading its stack traces line by line. Sync
speed is unaffected (1 h 56 min against 1 h 59 min for the Release build).

    git clone --recurse-submodules -b graphene https://github.com/graphene-blockchain/graphene-core.git
    cd graphene-core && mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_CXX_FLAGS_RELWITHDEBINFO="-O3 -g -DNDEBUG"
    make -j2 witness_node cli_wallet

A plain `-DCMAKE_BUILD_TYPE=Debug` builds with `-O0` and produces a noticeably slower binary; that build is not
tested for this release.

**Build Script, option 2, slim build** (`witness_node` 27 MB, 20 MB after `strip`; `cli_wallet` 33 MB before
`strip`): the build to run in production, on a small VPS or in a container image. The two `strip` lines are
optional. After `strip` the stack traces print bare addresses instead of function names, so skip them on a node you
may need to diagnose.

    git clone --recurse-submodules -b graphene https://github.com/graphene-blockchain/graphene-core.git
    cd graphene-core && mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release
    make -j2 witness_node cli_wallet
    strip programs/witness_node/witness_node
    strip programs/cli_wallet/cli_wallet

Run `make` without targets to build all programs and tests.

**Build with Docker**: the only requirement on the host is Docker 23 or newer; the compiler and all libraries stay
inside the build. The image is compiled on Ubuntu 26.04 whatever the host system is, and contains the stripped
`witness_node`, `cli_wallet` and `get_dev_key`.

    git clone --recurse-submodules -b graphene https://github.com/graphene-blockchain/graphene-core.git
    cd graphene-core
    docker build -t graphene-core .

Every compiler process needs 1.5-2 GB of memory and the build runs one per CPU; on a machine with little memory add
`--build-arg JOBS=2`. Running the node from the image, the environment variables of the entry point and the debug
symbols of the stripped binaries are described in [README-docker.md](README-docker.md).

**Upgrade Script** (run in an existing clone if you built a prior release):

    git remote set-url origin https://github.com/graphene-blockchain/graphene-core.git
    git fetch origin
    git checkout graphene
    git pull
    git submodule sync --recursive
    git submodule update --init --recursive

The `libraries/fc`, `fc/vendor/websocketpp` and `fc/vendor/editline` submodules now point to the `graphene-blockchain`
forks, so `git submodule sync --recursive` is required after upgrading.

**NOTE:** Graphene 1.1 is tested with [Boost](http://www.boost.org/) 1.90 and OpenSSL 3.5. It requires CMake 3.5 or
newer. Older Boost releases are not tested with this version. If your system came pre-installed with a version of
Boost that you do not wish to use, you may manually build your preferred version and use it with Graphene by
specifying it on the CMake command line.

Example: ``cmake .. -DBOOST_ROOT=/path/to/boost``

**NOTE:** Graphene requires a 64-bit operating system to build, and will not build on a 32-bit OS.

**NOTE:** The compiler needs about 2–4 GB of memory per build job. On machines with less memory, add swap or build
with fewer jobs (`make -j1`).

**NOTE:** Binaries link against the system OpenSSL 3 and libcurl libraries, so a build made on Ubuntu 26.04 does not
run on Ubuntu 18.04–20.04. Build on the system you run the node on.

**After Building**, the `witness_node` can be launched with:

    ./programs/witness_node/witness_node

The node will automatically create a data directory including a config file. A full sync from scratch took about
2 hours on a machine with 2 vCPUs and 3.8 GB of RAM (default plugins); the time depends on your hardware and peers.
After syncing, you can exit the node using Ctrl+C and setup the command-line wallet by editing
`witness_node_data_dir/config.ini` as follows:

    rpc-endpoint = 127.0.0.1:8090

**IMPORTANT:** By default the witness node will start in reduced memory mode by using some of the commands detailed in [Memory reduction for nodes](https://github.com/bitshares/bitshares-core/wiki/Memory-reduction-for-nodes).
In order to run a full node with all the account history you need to remove `partial-operations` and `max-ops-per-account` from your config file. Please note that currently(2018-10-17) a full node will need more than 160GB of RAM to operate and required memory is growing fast. Consider the following table as minimal requirements before running a node:

| Default | Full | Minimal  | ElasticSearch 
| --- | --- | --- | ---
| 40G HDD, 8G RAM | 80G SSD, 16G RAM * | 40G HDD, 8G RAM | 100G SSD, 16G RAM

\* For this setup, allocate at least 500GB of SSD as swap.

After starting the witness node again, in a separate terminal you can run:

    ./programs/cli_wallet/cli_wallet

Set your inital password:

    >>> set_password <PASSWORD>
    >>> unlock <PASSWORD>

To import your initial balance:

    >>> import_balance <ACCOUNT NAME> [<WIF_KEY>] true

If you send private keys over this connection, `rpc-endpoint` should be bound to localhost for security.

Use `help` to see all available wallet commands. Source definition and listing of all commands is available
[here](https://github.com/bitshares/bitshares-core/blob/master/libraries/wallet/include/graphene/wallet/wallet.hpp).

Support
-------
Technical support is available in the [Graphene Forum technical support subforum](https://forum.gph.ai).

Graphene Core bugs can be reported directly to the [issue tracker](https://github.com/graphene-blockchain/graphene-core/issues).

Graphene UI bugs should be reported to the [UI issue tracker](https://github.com/graphene-blockchain/graphene-ui/issues)

Using the API
-------------

We provide several different API's.  Each API has its own ID.
When running `witness_node`, initially two API's are available:
API 0 provides read-only access to the database, while API 1 is
used to login and gain access to additional, restricted API's.

Here is an example using `wscat` package from `npm` for websockets:

    $ npm install -g wscat
    $ wscat -c ws://127.0.0.1:8090
    > {"id":1, "method":"call", "params":[0,"get_accounts",[["1.2.0"]]]}
    < {"id":1,"result":[{"id":"1.2.0","annotations":[],"membership_expiration_date":"1969-12-31T23:59:59","registrar":"1.2.0","referrer":"1.2.0","lifetime_referrer":"1.2.0","network_fee_percentage":2000,"lifetime_referrer_fee_percentage":8000,"referrer_rewards_percentage":0,"name":"committee-account","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[],"address_auths":[]},"active":{"weight_threshold":6,"account_auths":[["1.2.5",1],["1.2.6",1],["1.2.7",1],["1.2.8",1],["1.2.9",1],["1.2.10",1],["1.2.11",1],["1.2.12",1],["1.2.13",1],["1.2.14",1]],"key_auths":[],"address_auths":[]},"options":{"memo_key":"GPH1111111111111111111111111111111114T1Anm","voting_account":"1.2.0","num_witness":0,"num_committee":0,"votes":[],"extensions":[]},"statistics":"2.7.0","whitelisting_accounts":[],"blacklisting_accounts":[]}]}

We can do the same thing using an HTTP client such as `curl` for API's which do not require login or other session state:

    $ curl --data '{"jsonrpc": "2.0", "method": "call", "params": [0, "get_accounts", [["1.2.0"]]], "id": 1}' http://127.0.0.1:8090/rpc
    {"id":1,"result":[{"id":"1.2.0","annotations":[],"membership_expiration_date":"1969-12-31T23:59:59","registrar":"1.2.0","referrer":"1.2.0","lifetime_referrer":"1.2.0","network_fee_percentage":2000,"lifetime_referrer_fee_percentage":8000,"referrer_rewards_percentage":0,"name":"committee-account","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[],"address_auths":[]},"active":{"weight_threshold":6,"account_auths":[["1.2.5",1],["1.2.6",1],["1.2.7",1],["1.2.8",1],["1.2.9",1],["1.2.10",1],["1.2.11",1],["1.2.12",1],["1.2.13",1],["1.2.14",1]],"key_auths":[],"address_auths":[]},"options":{"memo_key":"GPH1111111111111111111111111111111114T1Anm","voting_account":"1.2.0","num_witness":0,"num_committee":0,"votes":[],"extensions":[]},"statistics":"2.7.0","whitelisting_accounts":[],"blacklisting_accounts":[]}]}

API 0 is accessible using regular JSON-RPC:

    $ curl --data '{"jsonrpc": "2.0", "method": "get_accounts", "params": [["1.2.0"]], "id": 1}' http://127.0.0.1:8090/rpc

Accessing restricted API's
--------------------------

You can restrict API's to particular users by specifying an `api-access` file in `config.ini` or by using the `--api-access /full/path/to/api-access.json` startup node command.  Here is an example `api-access` file which allows
user `bytemaster` with password `supersecret` to access four different API's, while allowing any other user to access the three public API's
necessary to use the wallet:

    {
       "permission_map" :
       [
          [
             "bytemaster",
             {
                "password_hash_b64" : "9e9GF7ooXVb9k4BoSfNIPTelXeGOZ5DrgOYMj94elaY=",
                "password_salt_b64" : "INDdM6iCi/8=",
                "allowed_apis" : ["database_api", "network_broadcast_api", "history_api", "network_node_api"]
             }
          ],
          [
             "*",
             {
                "password_hash_b64" : "*",
                "password_salt_b64" : "*",
                "allowed_apis" : ["database_api", "network_broadcast_api", "history_api"]
             }
          ]
       ]
    }

Passwords are stored in `base64` as salted `sha256` hashes.  A simple Python script, `saltpass.py` is avaliable to obtain hash and salt values from a password.
A single asterisk `"*"` may be specified as username or password hash to accept any value.

With the above configuration, here is an example of how to call `add_node` from the `network_node` API:

    {"id":1, "method":"call", "params":[1,"login",["bytemaster", "supersecret"]]}
    {"id":2, "method":"call", "params":[1,"network_node",[]]}
    {"id":3, "method":"call", "params":[2,"add_node",["127.0.0.1:9090"]]}

Note, the call to `network_node` is necessary to obtain the correct API identifier for the network API.  It is not guaranteed that the network API identifier will always be `2`.

Since the `network_node` API requires login, it is only accessible over the websocket RPC.  Our `doxygen` documentation contains the most up-to-date information
about API's for the [witness node](https://bitshares.github.io/doxygen/namespacegraphene_1_1app.html) and the
[wallet](https://bitshares.github.io/doxygen/classgraphene_1_1wallet_1_1wallet__api.html).
If you want information which is not available from an API, it might be available
from the [database](https://bitshares.github.io/doxygen/classgraphene_1_1chain_1_1database.html);
it is fairly simple to write API methods to expose database methods.

FAQ
---

- Is there a way to generate help with parameter names and method descriptions?

    Yes. Documentation of the code base, including APIs, can be generated using Doxygen. Simply run `doxygen` in this directory.

    If both Doxygen and perl are available in your build environment, the CLI wallet's `help` and `gethelp`
    commands will display help generated from the doxygen documentation.

    If your CLI wallet's `help` command displays descriptions without parameter names like
        `signed_transaction transfer(string, string, string, string, string, bool)`
    it means CMake was unable to find Doxygen or perl during configuration.  If found, the
    output should look like this:
        `signed_transaction transfer(string from, string to, string amount, string asset_symbol, string memo, bool broadcast)`

- Is there a way to allow external program to drive `cli_wallet` via websocket, JSONRPC, or HTTP?

    Yes. External programs may connect to the CLI wallet and make its calls over a websockets API. To do this, run the wallet in
    server mode, i.e. `cli_wallet -s "127.0.0.1:9999"` and then have the external program connect to it over the specified port
    (in this example, port 9999).

- Is there a way to access methods which require login over HTTP?

    No.  Login is inherently a stateful process (logging in changes what the server will do for certain requests, that's kind
    of the point of having it).  If you need to track state across HTTP RPC calls, you must maintain a session across multiple
    connections.  This is a famous source of security vulnerabilities for HTTP applications.  Additionally, HTTP is not really
    designed for "server push" notifications, and we would have to figure out a way to queue notifications for a polling client.

    Websockets solves all these problems.  If you need to access Graphene's stateful methods, you need to use Websockets.

- What is the meaning of `a.b.c` numbers?

    The first number specifies the *space*.  Space 1 is for protocol objects, 2 is for implementation objects.
    Protocol space objects can appear on the wire, for example in the binary form of transactions.
    Implementation space objects cannot appear on the wire and solely exist for implementation
    purposes, such as optimization or internal bookkeeping.

    The second number specifies the *type*.  The type of the object determines what fields it has.  For a
    complete list of type ID's, see `enum object_type` and `enum impl_object_type` in
    bitshares/libraries/chain/include/graphene/chain/protocol/types.hpp

    The third number specifies the *instance*.  The instance of the object is different for each individual
    object.

- The answer to the previous question was really confusing.  Can you make it clearer?

    All account ID's are of the form `1.2.x`.  If you were the 9735th account to be registered,
    your account's ID will be `1.2.9735`.  Account `0` is special (it's the "committee account,"
    which is controlled by the committee members and has a few abilities and restrictions other accounts
    do not).

    All asset ID's are of the form `1.3.x`.  If you were the 29th asset to be registered,
    your asset's ID will be `1.3.29`.  Asset `0` is special (it's BTS, which is considered the "core asset").

    The first and second number together identify the kind of thing you're talking about (`1.2` for accounts,
    `1.3` for assets).  The third number identifies the particular thing.

- How do I get the `network_add_nodes` command to work?  Why is it so complicated?

    You need to follow the instructions in the "Accessing restricted API's" section to
    allow a username/password access to the `network_node` API.  Then you need
    to pass the username/password to the `cli_wallet` on the command line or in a config file.

    It's set up this way so that the default configuration is secure even if the RPC port is
    publicly accessible.  It's fine if your `witness_node` allows the general public to query
    the database or broadcast transactions (in fact, this is how the hosted web UI works).  It's
    less fine if your `witness_node` allows the general public to control which p2p nodes it's
    connecting to.  Therefore the API to add p2p connections needs to be set up with proper access
    controls.
 
License
-------
Graphene Core is under the MIT license. See [LICENSE](https://github.com/graphene-blockchain/graphene-core/blob/master/LICENSE.txt)
for more information.
