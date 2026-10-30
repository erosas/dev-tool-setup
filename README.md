# dev-tool-setup

My personal configs for getting a new Mac up and running quickly. Right now this holds
profiles for the Logitech MX Creative Console keypad; more tools and plugins will land here
over time.

## Layout

```
.
├── logitech/
│   └── mx-creative-console/
│       └── keypad/          # Logi Options+ keypad profiles (.lp5), one per app
└── README.md
```

Each tool gets its own top-level folder with a README explaining how to install and
restore its config.

## Getting a new machine going

1. Clone this repo:
   ```sh
   git clone git@github.com:erosas/dev-tool-setup.git
   cd dev-tool-setup
   ```
2. Install the tools you need (see each folder's README).
3. Import the configs for that tool.

## Contents

| Folder | What it is | Docs |
| --- | --- | --- |
| `logitech/mx-creative-console/keypad` | Per-app button layouts for the MX Creative Console keypad | [README](logitech/mx-creative-console/keypad/README.md) |

## Backing up changes

When you tweak a profile in Logi Options+, re-export it, drop the new `.lp5` over the old
one in this repo, and commit. Keep the file names stable so the table above stays accurate.
