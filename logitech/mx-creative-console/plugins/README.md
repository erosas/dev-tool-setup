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

### Fastest: straight from GitHub (no git, no Git LFS)

The plugin folder is bundled as `mx-creative-console-plugins.tar.gz` on the repo's
[Releases page](https://github.com/erosas/dev-tool-setup/releases). The script downloads
the latest bundle, verifies its SHA-256, and installs it. Only `curl` and `tar` are needed:

```sh
curl -fsSL https://raw.githubusercontent.com/erosas/dev-tool-setup/main/logitech/mx-creative-console/sync-plugins.sh \
  | bash -s -- install --from-github            # add --dry-run to preview, --tag plugins-YYYY.MM.DD to pin
```

### From a clone

The binaries in this folder are stored in [Git LFS](https://git-lfs.com). Without
`git-lfs` installed, a clone gives you small pointer files instead of the real `.dll` /
`.dylib` files, and the script will refuse to install them.

```sh
brew install git-lfs && git lfs install       # once per machine, before cloning
git clone git@github.com:erosas/dev-tool-setup.git
cd dev-tool-setup/logitech/mx-creative-console
./sync-plugins.sh install                       # add --dry-run to preview
```

(Already cloned without LFS? `git lfs install && git lfs pull`, or just use `--from-github`.)

Either way, the script stops the Logi Plugin Service, copies any existing `Plugins` folder to a
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
git add plugins && git commit -m "Update MX Creative Console plugins" && git push
./sync-plugins.sh publish                       # refresh the GitHub Release tarball
```

## Publish a release

`./sync-plugins.sh publish` tars this folder (minus this README), writes a `.sha256`
next to it, and creates a GitHub Release tagged `plugins-YYYY.MM.DD` (override with
`--tag`) marked as *latest*, which is what `install --from-github` downloads. It needs the
[GitHub CLI](https://cli.github.com) (`brew install gh && gh auth login`). Re-running with
an existing tag replaces that release's assets.

## Notes

- The executables (`.dll`, `.dylib`, `.so`, `.exe`, `.pdb`, `.bin`, `.ggml`, `.ict`, and
  the two Mach-O helpers under `ClaudeConsole/bin/voice`) are tracked with Git LFS; see
  `.gitattributes`. Icons (`.svg`, `.png`) and metadata stay in plain git. Expect ~60 MB
  of LFS objects.
- Plugins were captured from Logi Options+ 2.9 / Logi Plugin Service 6.4.2 on macOS.
  The Windows halves (`win/` folders, `.exe`) ride along but are untested.
- `PackageHash.bin` in each `metadata/` folder is Logitech's integrity hash; it's copied
  as-is, so don't hand-edit plugin files or the service may refuse to load them.
