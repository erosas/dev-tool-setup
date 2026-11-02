# dev-tool-setup

My personal configs for getting a new Mac up and running quickly. Right now this holds
profiles for the Logitech MX Creative Console keypad; more tools and plugins will land here
over time.

## Layout

```
.
├── logitech/
│   └── mx-creative-console/
│       ├── keypad/          # Logi Options+ keypad profiles (.lp5), one per app
│       ├── plugins/         # Logi Plugin Service plugins those profiles depend on (binaries in Git LFS)
│       └── sync-plugins.sh  # backup / install / publish the plugins
└── README.md
```

Each tool gets its own top-level folder with a README explaining how to install and
restore its config.

## Getting a new machine going

1. Clone this repo. Plugin binaries are stored in [Git LFS](https://git-lfs.com), so install
   that first if you want them to come down with the clone:
   ```sh
   brew install git-lfs && git lfs install
   git clone git@github.com:erosas/dev-tool-setup.git
   cd dev-tool-setup
   ```
2. Install the tools you need (see each folder's README).
3. Import the configs for that tool.

### No git, no LFS: pull the plugins straight from GitHub

On a Mac behind a corporate proxy where Logi Options+ can't fetch plugins, you don't need
to clone anything. The plugins are also attached to a
[GitHub Release](https://github.com/erosas/dev-tool-setup/releases) as a tarball, and the
sync script can install from there with nothing but `curl` and `tar`:

```sh
curl -fsSL https://raw.githubusercontent.com/erosas/dev-tool-setup/main/logitech/mx-creative-console/sync-plugins.sh \
  | bash -s -- install --from-github
```

Then grab the keypad profiles (small, plain files in git) and import them in Logi Options+:

```sh
curl -fsSL https://github.com/erosas/dev-tool-setup/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=4 '*/logitech/mx-creative-console/keypad/*.lp5'
```

## Contents

| Folder | What it is | Docs |
| --- | --- | --- |
| `logitech/mx-creative-console/keypad` | Per-app button layouts for the MX Creative Console keypad | [README](logitech/mx-creative-console/keypad/README.md) |
| `logitech/mx-creative-console/plugins` | The Logi plugins behind those layouts, for Macs that can't download them (Zscaler etc.) | [README](logitech/mx-creative-console/plugins/README.md) |

## Backing up changes

When you tweak a profile in Logi Options+, re-export it, drop the new `.lp5` over the old
one in this repo, and commit. Keep the file names stable so the table above stays accurate.

When Logi updates a plugin, run `sync-plugins.sh backup`, commit, push, then
`sync-plugins.sh publish` so the GitHub Release tarball matches the repo.
