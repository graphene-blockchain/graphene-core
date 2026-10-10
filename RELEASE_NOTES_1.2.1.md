# graphene-core 1.2.1

**Date:** October 2026
**Branch:** `graphene` ([graphene-blockchain/graphene-core](https://github.com/graphene-blockchain/graphene-core/tree/graphene))
**Tag:** `graphene-1.2.1`
**Previous version:** 1.2.0 — tag `graphene-1.2.0` (September 27, 2026), [release notes](RELEASE_NOTES_1.2.0.md)

## Summary

graphene-core 1.2.1 brings the node to Windows:

- `witness_node.exe`, a single static executable for 64-bit Windows 10 and later, cross-built on Linux with
  MinGW-w64;
- **Graphene Node** (`graphene-node-gui.exe`), a tray app and dashboard that starts, watches and stops the node.

The node now stops cleanly in every way a Windows user ends it: Ctrl+C, closing the console window, the GUI's stop
button, quitting the GUI, and a Windows shutdown, restart or logoff. Each of these used to leave the database dirty and
cost a replay at the next start.

Fixes that apply on every platform:

- a crash on shutdown while the node was syncing;
- a hang in the websocket server's shutdown;
- private keys printed into the log by a malformed `private-key` entry;
- no guard against two nodes on one data directory.

The file log now carries the level of each line.

Consensus rules, block format and serialization are unchanged.

## Changes visible on Linux

Most of 1.2.1 is the Windows node and app; on Linux the node is 1.2.0 with the fixes below. Operators will notice:

- **Lock on the data directory.** The node holds `<data dir>/witness_node.lock` (`flock`) while it runs. A second
  node on the same directory prints the PID of the first and exits with **code 3**; a service manager that restarts
  on failure keeps retrying until the first node stops. See "One node per data directory".
- **Level in log lines.** Lines of the file log carry the level before the `]` (`main info  ] ...`). Tools that parse
  the log by column position need updating; searches for `] message` still match. See "Log format".
- **Version in the P2P user agent.** The node announces itself as `Graphene Reference Implementation <build>`, e.g.
  `... 1.2.1-<commit>`, so peers can tell releases apart. See "P2P user agent with the build string".

Also on Linux, without a change in behaviour to adapt to: the shutdown and websocket fixes, private keys kept out of
the log, and a log line for each shutdown step.

## Getting the node

### Windows

Download `graphene-node-win64-1.2.1.zip` from the GitHub release, unpack it and run `graphene-node-gui.exe`. The zip
holds `witness_node.exe`, `graphene-node-gui.exe` and `WebView2Loader.dll`, which must stay in one folder, and
`LICENSE.txt`.
By default the app uses `witness_node.exe` and `witness_node_data_dir` next to itself. The
WebView2 runtime ships with Windows 10 and 11.

`witness_node.exe` also runs on its own, from `cmd` or PowerShell, like the Linux node.

### Linux and Docker

The node is unchanged from 1.2.0 apart from the fixes below; see [README.md](README.md#getting-started) and
[README-docker.md](README-docker.md).

```
docker pull grapheneblockchain/graphene-core:1.2.1
docker pull ghcr.io/graphene-blockchain/graphene-core:1.2.1
```

## Windows build

`contrib/win64/` cross-builds `witness_node.exe` on a Linux host; see [contrib/win64/README.md](contrib/win64/README.md).

```
apt-get install g++-mingw-w64-x86-64-posix cmake make perl git wine64
contrib/win64/build-deps.sh ~/win64-deps          # Boost 1.90, OpenSSL 3.5, zlib, curl; about 30 min, once
contrib/win64/build.sh ~/win64-deps build-win64   # -> build-win64/programs/witness_node/witness_node.exe
```

- **Compiler:** the `-posix` MinGW-w64 compilers (`std::thread`).
- **Linking:** static, with `-mbig-obj`. The executable needs only DLLs that ship with Windows.
- **Dependencies:** `build-deps.sh` clones them at fixed tags and installs them as static libraries.
- **Build helpers:** the build runs its own helpers (`cat-parts`, `embed_genesis`). Wine runs them as the CMake
  cross-compiling emulator through `wine-run.sh`, which rewrites `/abs/path` arguments to `Z:/abs/path`.
- **fc fixes needed by MinGW** (graphene-fc `cbf1c53`):
  - a missing Boost.PP include in `reflect.hpp`;
  - the reserved size of the Win64 `tcp_socket` implementation (208 bytes with Boost 1.90, 168 reserved);
  - `_WIN32_WINNT` raised to Windows 10, for `WaitOnAddress` in Boost.Atomic.

The GUI is built with Cargo for the `x86_64-pc-windows-gnu` target; see [gui/README.md](gui/README.md).

### CI

The new workflow `.github/workflows/windows.yml` cross-builds the Windows package on `ubuntu-24.04` on every push and
pull request:

- **Build:** `witness_node.exe` with `contrib/win64/`, then `graphene-node-gui.exe` with Cargo; the GUI's tests run
  under Wine.
- **Smoke test:** `witness_node.exe --version` runs under Wine.
- **Package:** `graphene-node-win64-<version>.zip` with `witness_node.exe`, `graphene-node-gui.exe`,
  `WebView2Loader.dll` and `LICENSE.txt`. Every run keeps it as an artifact; a tag `graphene-X.Y.Z` attaches it to the release.
- **Caches:** the dependencies are cached by the hash of `build-deps.sh`, so they are built only once; the node is
  built with ccache.

```
rustup target add x86_64-pc-windows-gnu
cd gui && cargo build --release --target x86_64-pc-windows-gnu
```

## witness_node on Windows

### Clean stop from a GUI: `--shutdown-event`, `--parent-pid`
A GUI that runs the node without a console cannot send it Ctrl+C, and `TerminateProcess` leaves the database dirty.
Two Windows-only options cover this:

- `--shutdown-event <name>` makes the node wait on a named event that the GUI creates and signals;
- `--parent-pid <pid>` makes the node exit when that process exits, so it does not outlive a crashed GUI.

Both take the same exit path as SIGINT. The event and the process are opened before startup, so a wrong name or
PID fails at once instead of leaving a node nobody can stop.
Commit: graphene-core `4dd407e9`.

### Closing the console window
Closing the console window killed the node after the system's grace period, and the next start replayed blocks.
`CTRL_CLOSE_EVENT` and `CTRL_BREAK_EVENT` now take the clean exit path. The handler blocks until the node has shut
down, because Windows ends the process as soon as the handler returns.
Commit: graphene-core `3684598b`.

### The process ends right after "Shutdown: done"
On a real Windows machine, the node logged `Shutdown: done, exiting the process` with the database closed, but the
process stayed. It hung in the runtime's static destructors and thread joins, on network threads with live peers.
Everything that needs a clean close is closed at that point, so on Windows the node now flushes its output and calls
`_exit` there.
Commit: graphene-core `c851cef1`.

### Ended last at a Windows shutdown
The node now asks Windows to end it last: `SetProcessShutdownParameters(0x100)`, the lowest level open to
applications. The GUI asks to be notified first and has time to stop the node (see "Windows shutdown, restart and
logoff" under the GUI below).
Commit: graphene-core `6f425378`.

### Startup errors stay readable after a double-click
Started from Explorer, the node gets a console of its own, which closes with the process. A startup error (data
directory in use, a bad command line, a plugin conflict) flashed by unread. On those exits the node now waits for
Enter, but only when the console belongs to it alone:

- not when started from `cmd` or PowerShell, where the console stays open anyway;
- not when started from the GUI, which shows no console.

Commit: graphene-core `3d0be4e0`.

## Graphene Node (GUI)

A Tauri 2 app, `gui/` in this repository, version 1.0.0. The app has a version of its own: it changes with
the app, while the node's version changes with the node.

### Versions in the file properties
Both executables carry a Windows version resource, shown on the "Details" tab of the file's properties:

| | `witness_node.exe` | `graphene-node-gui.exe` |
|---|---|---|
| File version | 1.2.1 | 1.0.0 |
| Product version | the build string, `1.2.1-<commit>` | 1.0.0 |
| Description | Graphene witness node | Graphene Node |

The node's resource is generated by CMake from `GRAPHENE_VERSION` and the commit, like `--version`. The bottom of
the app's Settings page shows both: "Graphene Node 1.0.0 · witness_node 1.2.1-<commit>".

### The node as its own process
- **Separate from the app.** Closing the app, or the app crashing, leaves the node running. The next start of the app
  finds the node through `graphene-node-gui.lock` in the data folder.
- **Stopping.** The app stops the node through the named event it passed as `--shutdown-event`. If the node has logged
  `Shutdown: done` but its process is still there 10 s later, the app ends it; the database is already closed by then.
- **Watchdog.** A crashed node is restarted after 15 s, then 1 min, then 5 min. After 3 crashes within 10 minutes the
  app stops trying.
- **Data folder in use.** A node refused with exit code 3 (see "One node per data directory" below) is not counted as
  a crash. The status turns red at once with "Data folder in use by another node".
- **Second node.** A second node on the same data folder is detected before the window opens. The app then shows an
  error box with OK and exits.

### Window
- **Dashboard:** status, head and irreversible block, sync progress, blocks per minute and chain ID. The data comes
  from the node's anonymous `database` API over WebSocket and from its log.
- **Journal:** the node's log, coloured by level as in a Linux console, with a filter by level and a "Blocks" view.
  The journal and the blocks table keep the newest 5000 rows.
- **Seeds and Peers:**
  - *Default seeds:* the node's built-in seeds (the same `seed-nodes.txt` the node compiles in) and the
    `seed-node` entries of `config.ini`, with their IP addresses and the node's last attempt to reach each one:
    connected, failed, rejected, handshake failed or not tried yet, with the error. **Add seed** writes
    `seed-node = host:port` into `config.ini` in the data folder, where the node reads it at every start, and
    passes it to a running node at once (`network_node.add_node`); added seeds can be removed again. A
    `seed-nodes` list in `config.ini` replaces the built-in seeds, which are then shown as not used.
  - *Peers:* the connected P2P peers with address, direction, release, build, platform, the peer's block,
    connection time and traffic.

  The data comes from the node's `network_node` API, which anonymous clients cannot use: unless `config.ini`
  sets `api-access`, the app writes `graphene-node-gui-api.json` into the data folder with the node's default
  anonymous access unchanged plus an account for the app (a random password per node start, kept in
  `graphene-node-gui.lock`), and starts the node with `--api-access`.
- **Peer release and build.** From 1.2.1 on, the node's P2P user agent carries its build string (see below).
  Older releases send no version; the app recognises 1.0, 1.1 and 1.2.0, and the 1.1 and 1.2.0 builds of the carbon-witness fork
  (fc `a108c380`, graphene-core `d5a98f9a`)
  by the commit time of the fc library they report and shows the commit of their release tag as the build
  (for the fork's 1.1 build, its fc commit); other builds get a "?".
- **No blocks from the network.** Behind and without a new block for 90 s, the status says so. With no peers it
  points at unreachable seed nodes and a firewall; with peers it shows how many are connected.
- **Actions:** start, stop and restart, as buttons of one width with player glyphs. While stopping, the status shows
  the node's current shutdown step.
- **Settings:**
  - paths to the node and the data folder; an empty path means next to the app, so the folder can be moved;
  - RPC endpoint;
  - language: English or Russian;
  - "Start with Windows".
- **Closing the window** asks: stop the node and quit, or keep running in the tray.

### Tray
- **Icon:** a white circle with a glyph for the node's state:

  | State | Glyph |
  |---|---|
  | Running | Green play |
  | Stopped | Pause |
  | Starting or syncing | Yellow dot |
  | Restarting | Blue-cyan arrow |
  | Failed | Red cross |

  The window shows the same glyph.
- **Menu:** start, stop and restart with the same glyphs, plus "Quit (stop the node)".
- The icon is removed when the app quits.
- The tooltip and the menu are updated only when they change.

### Start with Windows
The app is registered in the per-user `Run` key (`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`, value
`Graphene Node`), so no administrator rights are needed. Started this way, it opens in the tray, without its window.

### Windows shutdown, restart and logoff
Windows ended the node without notice: as a console program that loads `user32.dll`, it gets no console event at
shutdown. The next start replayed the database from block 1.

The app now has a hidden top-level window that receives `WM_QUERYENDSESSION`:

1. The app blocks the shutdown with a reason ("Stopping the Graphene node so that its database stays intact…"), stops the node and only then lets the
   shutdown continue, after 20 s at most.
2. If the shutdown is cancelled, the node is started again.
3. The app asks Windows to notify it first (`SetProcessShutdownParameters(0x3FF)`), and the node asks to be ended
   last.

Each step is written to `%APPDATA%\org.graphene.node-gui\gui.log`.

Verified on Windows 10 with two restarts: the node stopped in 2.4 s and 1.1 s, with `Shutdown: done` in its log.
After each boot it replayed only 6–7 reversible blocks (0.003 s), without a full replay.

### Sync progress of a fresh node
A node without block 1 showed about 90 % synced: the progress was measured from Unix time 0 instead of the first
block. It now shows 0 % until the first block arrives.

### Files
- **Settings:** `%APPDATA%\org.graphene.node-gui\settings.json`; the session-end log `gui.log` sits next to it.
- **Language:** the chosen language is stored in `settings.json`, not in the registry.

## Bug fixes (all platforms)

### Crash on shutdown while syncing
While syncing, the P2P node queues many `handle_block` calls ahead of time. Shutdown yields while it waits for the
plugins, the P2P node and the database, so the queued calls kept pushing blocks into a database that was being rewound
and closed. On Windows this crashed with an access violation right after "Rewinding from N to M", in 4 of 14 stops
during sync.

- From the start of shutdown, `handle_block` and `handle_transaction` refuse new items.
- The plugins and the chain database are shut down only after the items already being applied have finished, waiting
  up to 30 s.

Verified: 0 of 14 crashes with the change.
Commit: graphene-core `2a7ec408`.

### Websocket server shutdown hung or used a destroyed server
Two defects in the websocket server's destructor broke the node's shutdown when clients connected while it stopped:

- **Hang.** The destructor waited without limit for the listener's "closed" callback. websocketpp sends it only if an
  accept is pending at that moment, so right after a connection the node never exited (3 of 4 stops under a
  connection storm). The waits for this callback and for clients to close are now limited to 10 s, with a warning in
  the main log.
- **Use after free.** A connection still opening when the server stopped could call its close or fail handler after
  the server was destroyed (2 of 24 stops crashed). The handlers now hold their own copy of the shutdown state and
  return once the server is gone.

Verified: 16 of 16 stops under a connection storm exited cleanly.
Commit: graphene-fc `10e902f`.

The node also logs each shutdown step (`Shutdown: stopping plugins`, `closing the P2P network`, `closing the chain
database`, …), so a slow stop shows where it waits.
Commit: graphene-core `d47e1193`.

### Private keys in the log
A malformed `private-key` entry put the private key into the exception text, and so into the log, in three cases:

- the "Invalid WIF-format private key" message printed it;
- a WIF given in place of the public key failed in `public_key_type` with the WIF in the message;
- a JSON error carried the whole entry.

Any failure while parsing the entry is now replaced with an error that names at most the public key.
Commit: graphene-core `d54fe838`.

### One node per data directory
Nothing stopped two nodes from opening one data directory and corrupting its database. This could happen with:

- a manual run next to a systemd service;
- two copies of the node;
- the Windows GUI next to a node started by hand.

The node now takes an operating system lock on `<data dir>/witness_node.lock` before it reads its configuration or
opens the database. It uses `LockFileEx` on Windows and `flock` elsewhere. A second node prints which PID holds the
directory and exits with code 3:

```
Another witness_node (PID 4312) is already using the data directory ...
Stop it first: two nodes on one data directory corrupt its database.
```

The lock is released with the process, even after a crash or `kill -9`, so there is never a stale lock file to remove.
Commit: graphene-core `e8a0198e`.

## P2P user agent with the build string

The P2P hello message carries no version, so peers could not tell releases apart. The node's user agent is now
`Graphene Reference Implementation <build>`, e.g. `Graphene Reference Implementation 1.2.1-<commit>`. The hello
message itself is unchanged.

## Log format

File appender lines now carry the level before the `]`:

```
2026-10-03T23:18:54  th_a:?unnamed?   main info  ] Started Graphene node on a chain with 123804 blocks.
```

Searches for `] message` still match.
Commit: graphene-fc `5618f5c`.

## License

`LICENSE.txt` gains a line for the Graphene contributors next to the existing notices of Cryptonomex and the
earlier contributors, which the MIT license requires to stay. The Windows zip now includes it.

## Compatibility

- No protocol changes and no hardforks; the database format is unchanged.
- **Exit code 3** is new: another node holds the data directory. Service managers that restart on failure will retry
  until the other node stops.
- **P2P user agent:** `Graphene Reference Implementation` is followed by the build string.
- **Log format:** lines in the file log have a new level field. Tools that parse the log by column position need
  updating.
- **Lock file:** `witness_node.lock` appears in the data directory. Do not delete it while a node is running. Deleting
  it does not release the lock, but a new node would then create a lock on a different file.
- `--shutdown-event` and `--parent-pid` exist only in Windows builds.

## Known limitations

- **No installer.** The Windows files are shipped as a folder.
- **GUI tests.** The GUI's supervisor tests run under Wine. The window itself (WebView2) was checked by hand on
  Windows 10.
- **Explorer restarts on the test machine** (`explorer.exe`, event 1002) began months before 1.2.1 and continue with
  the app removed from startup. They are not attributed to the node or the GUI.

## Components

| Repository | Branch | Commit |
|---|---|---|
| [graphene-blockchain/graphene-core](https://github.com/graphene-blockchain/graphene-core/tree/graphene) | `graphene` | `graphene-1.2.1` |
| [graphene-blockchain/graphene-fc](https://github.com/graphene-blockchain/graphene-fc/tree/graphene) | `graphene` | `cf2d930` |
| [graphene-blockchain/websocketpp](https://github.com/graphene-blockchain/websocketpp/tree/fc) | `fc` | `571a7b0` |
| [graphene-blockchain/editline](https://github.com/graphene-blockchain/editline/tree/graphene) | `graphene` | `224e256` |
| [graphene-blockchain/secp256k1-zkp](https://github.com/graphene-blockchain/secp256k1-zkp/tree/graphene) | `graphene` | `bd06794` |

websocketpp, editline and secp256k1-zkp are unchanged since 1.2.0.

## Commits

The tag `graphene-1.2.1` is on the merge commit of the documentation PR; the lists below are the commits of each PR.

**graphene-fc** ([#3](https://github.com/graphene-blockchain/graphene-fc/pull/3))
- [`cbf1c53`](https://github.com/graphene-blockchain/graphene-fc/commit/cbf1c53) Build with MinGW-w64 for 64-bit Windows
- [`5618f5c`](https://github.com/graphene-blockchain/graphene-fc/commit/5618f5c) log: write the level into file appender lines
- [`10e902f`](https://github.com/graphene-blockchain/graphene-fc/commit/10e902f) websocket: a server shutdown no longer hangs or touches a destroyed server

**graphene-core: node** ([#11](https://github.com/graphene-blockchain/graphene-core/pull/11))
- [`495f407f`](https://github.com/graphene-blockchain/graphene-core/commit/495f407f) fc: bump to graphene-fc cf2d930 (MinGW-w64 build, file log levels, websocket shutdown fixes)
- [`4dd407e9`](https://github.com/graphene-blockchain/graphene-core/commit/4dd407e9) witness_node: add --shutdown-event and --parent-pid on Windows
- [`3684598b`](https://github.com/graphene-blockchain/graphene-core/commit/3684598b) witness_node: exit cleanly when the console window is closed on Windows
- [`2a7ec408`](https://github.com/graphene-blockchain/graphene-core/commit/2a7ec408) app: refuse P2P blocks during shutdown and let applied ones finish
- [`d54fe838`](https://github.com/graphene-blockchain/graphene-core/commit/d54fe838) witness: keep private keys out of private-key parse errors
- [`d47e1193`](https://github.com/graphene-blockchain/graphene-core/commit/d47e1193) Stop the node quickly from the GUI; log each shutdown step
- [`e8a0198e`](https://github.com/graphene-blockchain/graphene-core/commit/e8a0198e) witness_node: refuse to start on a data directory another node is using
- [`3d0be4e0`](https://github.com/graphene-blockchain/graphene-core/commit/3d0be4e0) witness_node: keep the window open on a startup error after a double-click
- [`c851cef1`](https://github.com/graphene-blockchain/graphene-core/commit/c851cef1) witness_node: end the process right after a clean shutdown on Windows
- [`6f425378`](https://github.com/graphene-blockchain/graphene-core/commit/6f425378) witness_node: ask Windows to end the node last at shutdown
- [`c3efe5c4`](https://github.com/graphene-blockchain/graphene-core/commit/c3efe5c4) version: 1.2.1
- [`1135557d`](https://github.com/graphene-blockchain/graphene-core/commit/1135557d) Show each peer's release: build string in the user agent, Version column
- [`f4d475e7`](https://github.com/graphene-blockchain/graphene-core/commit/f4d475e7) Windows version resources: witness_node 1.2.1, Graphene Node 1.0.0
- [`b3047a3e`](https://github.com/graphene-blockchain/graphene-core/commit/b3047a3e) witness_node: Graphene contributors in the version resource's copyright

**graphene-core: Windows build, app and CI** ([#12](https://github.com/graphene-blockchain/graphene-core/pull/12))
- [`e1ca38d9`](https://github.com/graphene-blockchain/graphene-core/commit/e1ca38d9) contrib/win64: cross-build witness_node.exe with MinGW-w64
- [`04d753b4`](https://github.com/graphene-blockchain/graphene-core/commit/04d753b4) contrib/win64: add the MinGW-w64 toolchain file
- [`50e2b4db`](https://github.com/graphene-blockchain/graphene-core/commit/50e2b4db) contrib/win64: keep the fc fixes as a patch
- [`92165ec0`](https://github.com/graphene-blockchain/graphene-core/commit/92165ec0) fc: build with MinGW-w64 for 64-bit Windows
- [`a04b003e`](https://github.com/graphene-blockchain/graphene-core/commit/a04b003e) gui: tray supervisor and dashboard for witness_node on Windows
- [`6061a9ce`](https://github.com/graphene-blockchain/graphene-core/commit/6061a9ce) gui: languages, Linux-coloured journal, close dialog, second-node guard
- [`db50f514`](https://github.com/graphene-blockchain/graphene-core/commit/db50f514) Stop the node quickly from the GUI; log each shutdown step
- [`21cc6baf`](https://github.com/graphene-blockchain/graphene-core/commit/21cc6baf) gui: node and data paths follow the app's folder
- [`f3614c2f`](https://github.com/graphene-blockchain/graphene-core/commit/f3614c2f) gui: an error box with OK when the node cannot start
- [`5c96ed46`](https://github.com/graphene-blockchain/graphene-core/commit/5c96ed46) gui: check for a conflicting node before the window opens
- [`338f665a`](https://github.com/graphene-blockchain/graphene-core/commit/338f665a) gui: a node refused for a data folder in use is not a crash
- [`eb9924c1`](https://github.com/graphene-blockchain/graphene-core/commit/eb9924c1) gui: graphene-node-gui.exe, player glyphs, start with Windows
- [`b2b2f2c0`](https://github.com/graphene-blockchain/graphene-core/commit/b2b2f2c0) gui: end a node that logged its shutdown but did not exit
- [`8b5f4b01`](https://github.com/graphene-blockchain/graphene-core/commit/8b5f4b01) gui: larger tray glyphs; a plain yellow disc while starting or syncing
- [`81a4b980`](https://github.com/graphene-blockchain/graphene-core/commit/81a4b980) gui: restart glyph during a restart; the window shows the tray's glyph
- [`eee09632`](https://github.com/graphene-blockchain/graphene-core/commit/eee09632) gui: the syncing glyph is a yellow dot inside the white circle
- [`8a6a7923`](https://github.com/graphene-blockchain/graphene-core/commit/8a6a7923) gui: remove the tray icon before the app exits
- [`972292a2`](https://github.com/graphene-blockchain/graphene-core/commit/972292a2) gui: bound the journal's blocks table like the raw feed
- [`962ceb9b`](https://github.com/graphene-blockchain/graphene-core/commit/962ceb9b) gui: stop the node cleanly when Windows shuts down, restarts or logs off
- [`50cef979`](https://github.com/graphene-blockchain/graphene-core/commit/50cef979) gui: stop the node on WM_QUERYENDSESSION; log the session end
- [`c8f2c35c`](https://github.com/graphene-blockchain/graphene-core/commit/c8f2c35c) gui: update the tray tooltip and menu only when they change
- [`5fb8dbf2`](https://github.com/graphene-blockchain/graphene-core/commit/5fb8dbf2) ci: cross-build the Windows package
- [`09e39c0d`](https://github.com/graphene-blockchain/graphene-core/commit/09e39c0d) ci: save the Windows build caches even when a later step fails
- [`c38d6f3c`](https://github.com/graphene-blockchain/graphene-core/commit/c38d6f3c) gui: Peers tab; 0 % for a fresh node; say when no blocks arrive
- [`b66c48dc`](https://github.com/graphene-blockchain/graphene-core/commit/b66c48dc) gui: the peers table is as tall as its rows
- [`6aae5042`](https://github.com/graphene-blockchain/graphene-core/commit/6aae5042) Show each peer's release: build string in the user agent, Version column
- [`356bb2ba`](https://github.com/graphene-blockchain/graphene-core/commit/356bb2ba) gui: Seeds and Peers tab; seeds added to config.ini; Build column
- [`0fd7f542`](https://github.com/graphene-blockchain/graphene-core/commit/0fd7f542) gui: show why a seed failed, not just "unspecified"; seed form in one row
- [`93bce651`](https://github.com/graphene-blockchain/graphene-core/commit/93bce651) gui: the seeds table's header no longer floats over the peers table
- [`0fa2820a`](https://github.com/graphene-blockchain/graphene-core/commit/0fa2820a) gui: split a stalled handshake into columns in the seeds table
- [`f01046c5`](https://github.com/graphene-blockchain/graphene-core/commit/f01046c5) gui: a seed in the middle of its handshake is not a failed one
- [`46adbe25`](https://github.com/graphene-blockchain/graphene-core/commit/46adbe25) gui: seeds table ends at Last attempt for now
- [`f5c655ad`](https://github.com/graphene-blockchain/graphene-core/commit/f5c655ad) gui: recognise the 1.1 carbon build (fc a108c380)
- [`0eef26f4`](https://github.com/graphene-blockchain/graphene-core/commit/0eef26f4) gui: fewer false "API has not answered" alerts
- [`81637af1`](https://github.com/graphene-blockchain/graphene-core/commit/81637af1) gui: show d5a98f9a as the 1.2.0 carbon build
- [`311737bd`](https://github.com/graphene-blockchain/graphene-core/commit/311737bd) gui: days in full; estimated time to sync
- [`79973bab`](https://github.com/graphene-blockchain/graphene-core/commit/79973bab) gui: the "API has not answered" alert only on the Seeds and Peers tab
- [`570bb251`](https://github.com/graphene-blockchain/graphene-core/commit/570bb251) Windows version resources: witness_node 1.2.1, Graphene Node 1.0.0
- [`70de05d4`](https://github.com/graphene-blockchain/graphene-core/commit/70de05d4) LICENSE: add the Graphene contributors; ship LICENSE.txt in the Windows zip
- [`5de1c6af`](https://github.com/graphene-blockchain/graphene-core/commit/5de1c6af) ci: a failed upload to the build cache no longer fails the Docker build
- [`adf7d83d`](https://github.com/graphene-blockchain/graphene-core/commit/adf7d83d) ci: no Windows and Docker builds for pushes and pull requests that change only documentation

**graphene-core: documentation** ([#13](https://github.com/graphene-blockchain/graphene-core/pull/13))
- [`b6b1e067`](https://github.com/graphene-blockchain/graphene-core/commit/b6b1e067) docs: release notes for 1.2.1
- [`02f55078`](https://github.com/graphene-blockchain/graphene-core/commit/02f55078) version: 1.2.1
- [`5bafdf18`](https://github.com/graphene-blockchain/graphene-core/commit/5bafdf18) ci: cross-build the Windows package
- [`93592960`](https://github.com/graphene-blockchain/graphene-core/commit/93592960) gui: Peers tab; 0 % for a fresh node; say when no blocks arrive
- [`6b364d69`](https://github.com/graphene-blockchain/graphene-core/commit/6b364d69) Show each peer's release: build string in the user agent, Version column
- [`2ebdf337`](https://github.com/graphene-blockchain/graphene-core/commit/2ebdf337) gui: Seeds and Peers tab; seeds added to config.ini; Build column
- [`b0d87f29`](https://github.com/graphene-blockchain/graphene-core/commit/b0d87f29) docs: the 1.1 carbon build in the 1.2.1 notes
- [`4317a0e0`](https://github.com/graphene-blockchain/graphene-core/commit/4317a0e0) gui: show d5a98f9a as the 1.2.0 carbon build
- [`465bc6a5`](https://github.com/graphene-blockchain/graphene-core/commit/465bc6a5) Windows version resources: witness_node 1.2.1, Graphene Node 1.0.0
- [`8a8e1aec`](https://github.com/graphene-blockchain/graphene-core/commit/8a8e1aec) LICENSE: add the Graphene contributors; ship LICENSE.txt in the Windows zip
- [`ad89155b`](https://github.com/graphene-blockchain/graphene-core/commit/ad89155b) docs: wording of the Windows zip contents
- [`8a055ecf`](https://github.com/graphene-blockchain/graphene-core/commit/8a055ecf) docs: list every commit of the branch in the 1.2.1 notes
- [`9a3b9875`](https://github.com/graphene-blockchain/graphene-core/commit/9a3b9875) docs: 1.2.1 notes for the release: date, graphene branches, all commits
- [`d304a8e7`](https://github.com/graphene-blockchain/graphene-core/commit/d304a8e7) docs: Graphene Node for Windows guide (README-windows-gui.md)
- [`74695159`](https://github.com/graphene-blockchain/graphene-core/commit/74695159) docs: Windows GUI screenshots: folder, dashboard, journal, seeds and peers, firewall
- [`5bfd54cf`](https://github.com/graphene-blockchain/graphene-core/commit/5bfd54cf) docs: Windows GUI settings screenshot; the path fields show their defaults
- [`6b5b043d`](https://github.com/graphene-blockchain/graphene-core/commit/6b5b043d) docs: Windows GUI tray menu screenshot; all of the menu's items in the text
- [`faf3aa62`](https://github.com/graphene-blockchain/graphene-core/commit/faf3aa62) docs: the last Windows GUI screenshots: synced dashboard, close dialog, file properties
- [`2ba9712d`](https://github.com/graphene-blockchain/graphene-core/commit/2ba9712d) docs: Windows GUI security warning on the first start, with its screenshot
- [`e4a8bd3f`](https://github.com/graphene-blockchain/graphene-core/commit/e4a8bd3f) docs: Windows GUI SmartScreen screenshot
- [`4539c656`](https://github.com/graphene-blockchain/graphene-core/commit/4539c656) docs: Windows GUI SmartScreen screenshots, both steps
- [`731de986`](https://github.com/graphene-blockchain/graphene-core/commit/731de986) docs: Windows GUI guide without the Open File security warning screenshot
- [`0019a9d4`](https://github.com/graphene-blockchain/graphene-core/commit/0019a9d4) docs: a 1px border on the Windows GUI screenshots
- [`61a1dc05`](https://github.com/graphene-blockchain/graphene-core/commit/61a1dc05) docs: tray icons in the Windows GUI guide's state table
- [`bf62b56f`](https://github.com/graphene-blockchain/graphene-core/commit/bf62b56f) docs: connecting RuDEX to the local node, in the Windows GUI guide
