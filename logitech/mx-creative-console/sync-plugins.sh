#!/usr/bin/env bash
#
# sync-plugins.sh — back up or restore Logi Plugin Service plugins (MX Creative Console).
#
# Logi Options+ normally downloads these plugins from Logitech's servers. On a machine
# where that download is blocked (corporate proxy / Zscaler), copy them from this repo
# straight into the Logi Plugin Service folder instead.
#
# Usage:
#   ./sync-plugins.sh backup   [--dry-run]            # machine  -> repo
#   ./sync-plugins.sh install  [--dry-run] [--prune]  # repo     -> machine
#   ./sync-plugins.sh list                            # show what's in the repo
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_PLUGINS="$SCRIPT_DIR/plugins"

LPS_ROOT="$HOME/Library/Application Support/Logi/LogiPluginService"
LPS_PLUGINS="$LPS_ROOT/Plugins"
LPS_APP="/Applications/Utilities/LogiPluginService.app"
LPS_PKG="/Library/Application Support/Logi/LogiOptionsPlus/depots/881239/logi_plugin_service/LogiPluginServiceInstaller.pkg"

RSYNC_OPTS=(-a --delete --exclude .DS_Store --exclude '._*')

DRY_RUN=0
PRUNE=0

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

plugin_info() {
  # $1 = plugin dir. Prints "displayName (version)" from metadata/LoupedeckPackage.yaml.
  local yaml="$1/metadata/LoupedeckPackage.yaml"
  [[ -f "$yaml" ]] || { echo "(no metadata)"; return; }
  local name ver
  name=$(sed -n 's/^displayName:[[:space:]]*//p' "$yaml" | head -1)
  ver=$(sed -n 's/^version:[[:space:]]*//p' "$yaml" | head -1)
  echo "${name:-?} (${ver:-?})"
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
  log "Done. Review and commit:"
  (cd "$SCRIPT_DIR" && git status --short -- plugins | head -40) || true
}

cmd_install() {
  [[ "$(uname)" == "Darwin" ]] || die "install only supports macOS"
  [[ -d "$REPO_PLUGINS" ]] || die "No plugins in repo at $REPO_PLUGINS"

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

  for d in "$REPO_PLUGINS"/*/; do
    [[ -d "$d" ]] || continue
    local name; name=$(basename "$d")
    log "Installing $name — $(plugin_info "$d")"
    rsync "${opts[@]}" "$d" "$LPS_PLUGINS/$name/"
  done

  if (( PRUNE )); then
    for d in "$LPS_PLUGINS"/*/; do
      [[ -d "$d" ]] || continue
      local name; name=$(basename "$d")
      if [[ ! -d "$REPO_PLUGINS/$name" ]]; then
        log "Pruning $name (not in repo)"
        (( DRY_RUN )) || rm -rf "$d"
      fi
    done
  fi

  if (( DRY_RUN )); then
    log "Dry run — nothing written."
    return
  fi

  # Clear quarantine in case the repo came in as a downloaded zip rather than a git clone.
  xattr -dr com.apple.quarantine "$LPS_PLUGINS" 2>/dev/null || true
  chmod -R u+rwX "$LPS_PLUGINS"

  start_service
  log "Done. Open Logi Options+ → MX Creative Console → add the app and import its .lp5 profile."
}

CMD="${1:-}"; shift || true
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --prune)   PRUNE=1 ;;
    -h|--help) usage 0 ;;
    *) die "unknown option: $arg" ;;
  esac
done

case "$CMD" in
  backup)  cmd_backup ;;
  install) cmd_install ;;
  list)    cmd_list ;;
  -h|--help|"") usage 0 ;;
  *) die "unknown command: $CMD" ;;
esac
