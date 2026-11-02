# MX Creative Console plugins

Raw copies of the Logi Plugin Service plugins that back the keypad profiles in
[`../keypad`](../keypad). Logi Options+ normally downloads these from Logitech's servers;
on a Mac where that download is blocked (corporate proxy, Zscaler, etc.) the keypad app
list stays empty and the `.lp5` profiles have nothing to attach to. This folder lets you
drop the plugins in place without the download.

Source on the machine:

```
~/Library/Application Support/Logi/LogiPluginService/Plugins/
```

## What's here

| Folder | Plugin | Version | Used by profile |
| --- | --- | --- | --- |
| `IntelliJ` | IntelliJ | 2.1.1.1060 | `intellij.lp5` |
| `CopilotAppMac` | GitHub Copilot app | 0.1.2 | `github-copilot.lp5` |
| `MicrosoftTeams-BB539293FA49494A` | Microsoft Teams | 1.0.0.31 | `microsoft-teams.lp5` |
| `Powerpointformac-7733EF4907924942` | PowerPoint for Mac | 1.0.0.59 | `powerpoint.lp5` |
| `Word-1DAA6242EA4E470F` | Word | 1.0.0.130 | `word.lp5` |
| `Excelformac-242BA841C6FF494C` | Excel for Mac | 1.0.0.51 | — |
| `ChromeExtension` | Chrome (Beta) | 6.0.5 | — |
| `ClaudeDesktop` | Claude Desktop (Beta) | 1.0.1.0899 | — |
| `ClaudeConsole` | Claude Console (third-party, S. Ravi Shankar) | 2.3.2 | — |
| `GitHubActions` | GitHub Actions | 1.8 | — |

Run `../sync-plugins.sh list` to regenerate this from the plugin metadata.

## Install on a new Mac

```sh
cd logitech/mx-creative-console
./sync-plugins.sh install            # add --dry-run to preview
```

The script stops the Logi Plugin Service, copies any existing `Plugins` folder to a
timestamped `Plugins.bak-*` next to it, rsyncs each plugin from this folder into place,
clears macOS quarantine flags, and restarts the service. Pass `--prune` to also remove
plugins on the machine that aren't in this repo.

Then open Logi Options+ → MX Creative Console → add the app with **+** and import the
matching `.lp5` from [`../keypad`](../keypad).

### Prerequisite: Logi Plugin Service itself

The plugins run inside `LogiPluginService.app` (`/Applications/Utilities`), which Logi
Options+ also downloads. If it's missing on the locked-down Mac, the script will tell you.
The installer is cached on a working Mac at:

```
/Library/Application Support/Logi/LogiOptionsPlus/depots/881239/logi_plugin_service/LogiPluginServiceInstaller.pkg
```

It's ~130 MB (too large to commit here). Copy it over by AirDrop/USB and run:

```sh
sudo installer -pkg LogiPluginServiceInstaller.pkg -target /
```

## Back up after Logi updates a plugin

```sh
cd logitech/mx-creative-console
./sync-plugins.sh backup
git add plugins && git commit -m "Update MX Creative Console plugins"
```

## Notes

- Everything here is binary (`.dll`, `.dylib`, `.exe`, `.png`, `.svg`…) and marked as
  such in `.gitattributes`. Expect ~60 MB.
- Plugins were captured from Logi Options+ 2.9 / Logi Plugin Service 6.4.2 on macOS.
  The Windows halves (`win/` folders, `.exe`) ride along but are untested.
- `PackageHash.bin` in each `metadata/` folder is Logitech's integrity hash; it's copied
  as-is, so don't hand-edit plugin files or the service may refuse to load them.
