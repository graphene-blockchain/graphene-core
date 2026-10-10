Screenshots for [README-windows-gui.md](../../README-windows-gui.md). Each is linked from there by this name.

| File | What it shows |
|---|---|
| `01-folder.png` | the unpacked zip in Explorer: the three programs and `LICENSE.txt` |
| `02-dashboard-syncing.png` | the dashboard while the node syncs, with the time to sync |
| `03-dashboard-synced.png` | the dashboard of a node in sync, green icon |
| `04-journal.png` | the Journal, raw log with a few coloured warnings |
| `05-seeds-peers.png` | Seeds and Peers: seed statuses and the peer table |
| `06-settings.png` | Settings, with the versions line at the bottom |
| `07-tray-menu.png` | the tray icon's menu |
| `08-close-dialog.png` | the dialog when the window is closed |
| `09-file-properties.png` | the "Details" tab of `witness_node.exe`'s properties |
| `10-smartscreen.png` | SmartScreen's "Windows protected your PC" on the first start of the downloaded app |
| `10-smartscreen-run.png` | the same after **More info**, with **Run anyway** |
| `11-firewall.png` | Windows Defender Firewall asking about `witness_node.exe` |
| `12-rudex-add-node.png` | RuDEX: Settings, Nodes, Add Node with the local address |
| `13-rudex-active-node.png` | RuDEX connected to the local node |
| `tray-*.png` | the tray icons, drawn from `gui/src/glyphs.rs` at 40 px (shown at 20) |

PNG, the window at its normal size; crop to the window or dialog. Each has a 1px #d0d7de border, as GitHub draws
its own boxes, so a white window does not merge into the page:
`convert shot.png -bordercolor "#d0d7de" -border 1 NN-name.png`.
