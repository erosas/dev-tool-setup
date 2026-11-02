#!/usr/bin/env bash
#
# sync-plugins.sh — back up or restore Logi Plugin Service plugins (MX Creative Console).
#
# Logi Options+ normally downloads these plugins from Logitech's servers. On a machine
# where that download is blocked (corporate proxy / Zscaler), copy them from this repo
# or from a GitHub Release straight into the Logi Plugin Service folder instead.
#
# Usage:
#   ./sync-plugins.sh backup   [--dry-run]                       # machine  -> repo
#   ./sync-plugins.sh install  [--dry-run] [--prune]             # repo     -> machine
#   ./sync-plugins.sh install  --from-github [--tag TAG] [...]   # GitHub   -> machine (no git/LFS needed)
#   ./sync-plugins.sh publish  [--tag TAG]                       # repo     -> GitHub Release (needs gh)
#   ./sync-plugins.sh list                                       # show what's in the repo
#
# One-liner for a fresh Mac (only needs curl + tar):
#   curl -fsSL https://raw.githubusercontent.com/erosas/dev-tool-setup/main/logitech/mx-creative-console/sync-plugins.sh \
#     | bash -s -- install --from-github
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
REPO_PLUGINS="$SCRIPT_DIR/plugins"

GH_REPO="${GH_REPO:-erosas/dev-tool-setup}"
ASSET_NAME="mx-creative-console-plugins.tar.gz"

LPS_ROOT="$HOME/Library/Application Support/Logi/LogiPluginService"
LPS_PLUGINS="$LPS_ROOT/Plugins"
LPS_APP="/Applications/Utilities/LogiPluginService.app"
LPS_PKG="/Library/Application Support/Logi/LogiOptionsPlus/depots/881239/logi_plugin_service/LogiPluginServiceInstaller.pkg"

RSYNC_OPTS=(-a --delete --exclude .DS_Store --exclude '._*')

DRY_RUN=0
PRUNE=0
FROM_GITHUB=0
TAG=""
TMP_DIR=""

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

cleanup() { [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT

usage() {
  cat <<'USAGE'
sync-plugins.sh — back up or restore Logi Plugin Service plugins (MX Creative Console).

Usage:
  ./sync-plugins.sh backup   [--dry-run]                       # machine  -> repo
  ./sync-plugins.sh install  [--dry-run] [--prune]             # repo     -> machine
  ./sync-plugins.sh install  --from-github [--tag TAG] [...]   # GitHub   -> machine (no git/LFS needed)
  ./sync-plugins.sh publish  [--tag TAG]                       # repo     -> GitHub Release (needs gh)
  ./sync-plugins.sh list                                       # show what's in the repo

One-liner for a fresh Mac (only needs curl + tar):
  curl -fsSL https://raw.githubusercontent.com/erosas/dev-tool-setup/main/logitech/mx-creative-console/sync-plugins.sh \
    | bash -s -- install --from-github
USAGE
  exit "${1:-0}"
}

plugin_info() {
  # $1 = plugin dir. Prints "displayName (version)" from metadata/LoupedeckPackage.yaml.
  local yaml="$1/metadata/LoupedeckPackage.yaml"
  [[ -f "$yaml" ]] || { echo "(no metadata)"; return; }
  local name ver
  name=$(sed -n 's/^displayName:[[:space:]]*//p' "$yaml" | head -1)
  ver=$(sed -n 's/^version:[[:space:]]*//p' "$yaml" | head -1)
  echo "${name:-?} (${ver:-?})"
}

is_lfs_pointer() {
  # True if $1 is a Git LFS pointer file rather than real content.
  [[ -f "$1" ]] && head -n 1 "$1" 2>/dev/null | grep -q '^version https://git-lfs.github.com/spec/v1'
}

check_not_pointers() {
  # Die if the plugins dir holds LFS pointers (cloned without git-lfs / `git lfs pull`).
  local f
  f=$(find "$1" -type f \( -name '*.dll' -o -name '*.dylib' -o -name '*.so' -o -name '*.exe' \) | head -1)
  [[ -n "$f" ]] || return 0
  if is_lfs_pointer "$f"; then
    die "$1 contains Git LFS pointer files, not binaries.
Either run 'git lfs install && git lfs pull' in this repo, or skip git entirely with:
  $0 install --from-github"
  fi
}

service_running() { pgrep -x LogiPluginService >/dev/null 2>&1; }

stop_service() {
  if service_running; then
    log "Stopping Logi Plugin Service"
    pkill -x LogiPluginService || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      service_running || break
      sleep 1
    done
    service_running && warn "Logi Plugin Service is still running; files may be locked."
  fi
}

start_service() {
  if [[ -d "$LPS_APP" ]]; then
    log "Starting Logi Plugin Service"
    open -g -a "$LPS_APP" || warn "Could not launch $LPS_APP; open Logi Options+ to restart it."
  fi
}

release_url() {
  # $1 = asset file name. Latest release unless --tag was given.
  if [[ -n "$TAG" ]]; then
    echo "https://github.com/$GH_REPO/releases/download/$TAG/$1"
  else
    echo "https://github.com/$GH_REPO/releases/latest/download/$1"
  fi
}

fetch_from_github() {
  # Downloads the plugin bundle (and its checksum) into a temp dir and extracts it.
  # Sets SRC_PLUGINS to the extracted folder.
  command -v curl >/dev/null || die "curl is required for --from-github"
  TMP_DIR=$(mktemp -d -t mxcc-plugins)
  local tgz="$TMP_DIR/$ASSET_NAME" sum="$TMP_DIR/$ASSET_NAME.sha256"

  log "Downloading $(release_url "$ASSET_NAME")"
  curl -fsSL --retry 3 -o "$tgz" "$(release_url "$ASSET_NAME")" \
    || die "Download failed. Is there a published release on https://github.com/$GH_REPO/releases ?"

  if curl -fsSL --retry 3 -o "$sum" "$(release_url "$ASSET_NAME.sha256")" 2>/dev/null; then
    log "Verifying checksum"
    local want have
    want=$(awk '{print $1}' "$sum")
    have=$(shasum -a 256 "$tgz" | awk '{print $1}')
    [[ "$want" == "$have" ]] || die "Checksum mismatch for $ASSET_NAME (expected $want, got $have)"
  else
    warn "No checksum published for this release; skipping verification."
  fi

  mkdir -p "$TMP_DIR/plugins"
  tar -xzf "$tgz" -C "$TMP_DIR/plugins"
  SRC_PLUGINS="$TMP_DIR/plugins"
  log "Bundle contains:"
  for d in "$SRC_PLUGINS"/*/; do
    [[ -d "$d" ]] || continue
    printf '    %-40s %s\n' "$(basename "$d")" "$(plugin_info "$d")"
  done
}

cmd_list() {
  [[ -d "$REPO_PLUGINS" ]] || die "No plugins backed up yet at $REPO_PLUGINS"
  printf '%-40s %s\n' "FOLDER" "PLUGIN"
  for d in "$REPO_PLUGINS"/*/; do
    [[ -d "$d" ]] || continue
    printf '%-40s %s\n' "$(basename "$d")" "$(plugin_info "$d")"
  done
}

cmd_backup() {
  [[ -d "$LPS_PLUGINS" ]] || die "No plugins found at $LPS_PLUGINS (is Logi Plugin Service installed?)"
  mkdir -p "$REPO_PLUGINS"
  local opts=("${RSYNC_OPTS[@]}")
  (( DRY_RUN )) && opts+=(-n -v)

  for d in "$LPS_PLUGINS"/*/; do
    [[ -d "$d" ]] || continue
    local name; name=$(basename "$d")
    log "Backing up $name — $(plugin_info "$d")"
    rsync "${opts[@]}" "$d" "$REPO_PLUGINS/$name/"
  done

  (( DRY_RUN )) && { log "Dry run — nothing written."; return; }
  log "Done. Review, commit, then publish a release so --from-github picks it up:"
  (cd "$SCRIPT_DIR" && git status --short -- plugins | head -40) || true
  echo "    git add plugins && git commit -m 'Update MX Creative Console plugins' && git push"
  echo "    $0 publish"
}

cmd_install() {
  [[ "$(uname)" == "Darwin" ]] || die "install only supports macOS"

  local SRC_PLUGINS
  if (( FROM_GITHUB )); then
    fetch_from_github
  else
    [[ -d "$REPO_PLUGINS" ]] || die "No plugins in repo at $REPO_PLUGINS (try: $0 install --from-github)"
    check_not_pointers "$REPO_PLUGINS"
    SRC_PLUGINS="$REPO_PLUGINS"
  fi

  if [[ ! -d "$LPS_APP" ]]; then
    warn "Logi Plugin Service is not installed at $LPS_APP."
    warn "Logi Options+ normally installs it from:"
    warn "  $LPS_PKG"
    warn "Copy that .pkg from a working Mac and run it (sudo installer -pkg <file> -target /), then re-run install."
  fi

  local opts=("${RSYNC_OPTS[@]}")
  (( DRY_RUN )) && opts+=(-n -v)

  if (( ! DRY_RUN )); then
    stop_service
    mkdir -p "$LPS_PLUGINS"
    if [[ -n "$(ls -A "$LPS_PLUGINS" 2>/dev/null)" ]]; then
      local bak="$LPS_ROOT/Plugins.bak-$(date +%Y%m%d-%H%M%S)"
      log "Backing up existing plugins to $bak"
      cp -R "$LPS_PLUGINS" "$bak"
    fi
  fi

  for d in "$SRC_PLUGINS"/*/; do
    [[ -d "$d" ]] || continue
    local name; name=$(basename "$d")
    log "Installing $name — $(plugin_info "$d")"
    rsync "${opts[@]}" "$d" "$LPS_PLUGINS/$name/"
  done

  if (( PRUNE )); then
    for d in "$LPS_PLUGINS"/*/; do
      [[ -d "$d" ]] || continue
      local name; name=$(basename "$d")
      if [[ ! -d "$SRC_PLUGINS/$name" ]]; then
        log "Pruning $name (not in source)"
        (( DRY_RUN )) || rm -rf "$d"
      fi
    done
  fi

  if (( DRY_RUN )); then
    log "Dry run — nothing written."
    return
  fi

  # Clear quarantine in case the files came in as a download rather than a git clone.
  xattr -dr com.apple.quarantine "$LPS_PLUGINS" 2>/dev/null || true
  chmod -R u+rwX "$LPS_PLUGINS"

  start_service
  log "Done. Open Logi Options+ → MX Creative Console → add the app and import its .lp5 profile."
}

cmd_publish() {
  # Tar up plugins/ and attach it to a GitHub Release so `install --from-github` works
  # without git or Git LFS on the target machine.
  command -v gh >/dev/null || die "gh (GitHub CLI) is required: brew install gh && gh auth login"
  [[ -d "$REPO_PLUGINS" ]] || die "No plugins in repo at $REPO_PLUGINS"
  check_not_pointers "$REPO_PLUGINS"

  local tag="${TAG:-plugins-$(date +%Y.%m.%d)}"
  TMP_DIR=$(mktemp -d -t mxcc-publish)
  local tgz="$TMP_DIR/$ASSET_NAME" sum="$TMP_DIR/$ASSET_NAME.sha256"

  log "Bundling $REPO_PLUGINS -> $ASSET_NAME"
  COPYFILE_DISABLE=1 tar -czf "$tgz" -C "$REPO_PLUGINS" \
    --exclude .DS_Store --exclude '._*' --exclude README.md .
  (cd "$TMP_DIR" && shasum -a 256 "$ASSET_NAME" > "$sum")
  log "Bundle: $(du -h "$tgz" | awk '{print $1}')  sha256: $(awk '{print $1}' "$sum")"

  local notes="MX Creative Console plugins backed up $(date +%Y-%m-%d).

Install without git:
\`\`\`sh
curl -fsSL https://raw.githubusercontent.com/$GH_REPO/main/logitech/mx-creative-console/sync-plugins.sh \\
  | bash -s -- install --from-github --tag $tag
\`\`\`

Contents:
\`\`\`
$(cmd_list)
\`\`\`"

  if gh release view "$tag" --repo "$GH_REPO" >/dev/null 2>&1; then
    log "Release $tag exists; replacing assets"
    gh release upload "$tag" "$tgz" "$sum" --repo "$GH_REPO" --clobber
  else
    log "Creating release $tag"
    gh release create "$tag" "$tgz" "$sum" --repo "$GH_REPO" --title "$tag" --notes "$notes" --latest
  fi
  log "Published: https://github.com/$GH_REPO/releases/tag/$tag"
}

CMD="${1:-}"; shift || true
while (( $# )); do
  case "$1" in
    --dry-run)     DRY_RUN=1 ;;
    --prune)       PRUNE=1 ;;
    --from-github) FROM_GITHUB=1 ;;
    --tag)         shift; TAG="${1:-}"; [[ -n "$TAG" ]] || die "--tag needs a value" ;;
    -h|--help)     usage 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

case "$CMD" in
  backup)  cmd_backup ;;
  install) cmd_install ;;
  publish) cmd_publish ;;
  list)    cmd_list ;;
  -h|--help|"") usage 0 ;;
  *) die "unknown command: $CMD" ;;
esac
