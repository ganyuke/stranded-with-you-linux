#!/usr/bin/env bash
# Move the release bundle into a Steam game installation, or move it back out.
set -euo pipefail

bundle_name=stranded-with-you-linux
bundle=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
action=install
game_arg=
steam_root_arg=
return_dir=

usage() {
    printf 'Usage: %s [install|uninstall] [--game GAME_DIR] [--steam-root STEAM_DIR] [--to DIRECTORY]\n' "$0" >&2
    exit 2
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

. "$bundle/steam-game-path.sh"

if [[ $# -gt 0 && ( "$1" == install || "$1" == uninstall ) ]]; then
    action=$1
    shift
fi
while [[ $# -gt 0 ]]; do
    case "$1" in
        --game) [[ $# -ge 2 ]] || usage; game_arg=$2; shift 2 ;;
        --steam-root) [[ $# -ge 2 ]] || usage; steam_root_arg=$2; shift 2 ;;
        --to) [[ $# -ge 2 && "$action" == uninstall ]] || usage; return_dir=$2; shift 2 ;;
        *) usage ;;
    esac
done

if [[ -n "$game_arg" ]]; then
    game=$(cd -- "$game_arg" && pwd -P) || fail "Game directory not found: $game_arg"
    [[ -f "$game/Game.exe" && -f "$game/index.html" ]] || fail "Not the base game directory: $game"
else
    find_steam_game
fi
target="$game/$bundle_name"

if [[ "$action" == install ]]; then
    [[ "$(basename -- "$bundle")" == "$bundle_name" && -f "$bundle/Game.sh" &&
       -x "$bundle/linux-runtime/electron" ]] || fail "Run this from an extracted release bundle"
    [[ "$bundle" != "$target" ]] || fail "Launcher is already installed at $target"
    [[ ! -e "$target" && ! -L "$target" ]] || fail "Destination already exists: $target"
    printf '%s\n' "$bundle" > "$bundle/.install-origin.tmp"
    mv -f -- "$bundle/.install-origin.tmp" "$bundle/.install-origin"
    mv -T -n -- "$bundle" "$target"
    [[ ! -e "$bundle" && -f "$target/.install-origin" ]] || fail "Move did not complete; inspect $bundle and $target"
    printf 'Installed launcher at %s\n' "$target"
    printf 'To move it back: %q uninstall --game %q\n' "$target/install.sh" "$game"
    printf 'Set Steam Properties > General > Launch Options to:\n'
    printf '%s\n' '"./stranded-with-you-linux/Game.sh" # %command%'
else
    [[ -d "$target" && -f "$target/.install-origin" && -f "$target/Game.sh" ]] || fail "No launcher installed by this script at $target"
    IFS= read -r origin < "$target/.install-origin"
    if [[ -n "$return_dir" ]]; then
        [[ -d "$return_dir" ]] || fail "Return directory not found: $return_dir"
        origin="$(cd -- "$return_dir" && pwd -P)/$bundle_name"
    fi
    [[ "$origin" == /* && "$(basename -- "$origin")" == "$bundle_name" ]] || fail "Unsafe recorded return path: $origin"
    [[ -d "$(dirname -- "$origin")" ]] || fail "Original parent directory is gone; use --to DIRECTORY"
    [[ ! -e "$origin" && ! -L "$origin" ]] || fail "Return destination already exists: $origin (use --to DIRECTORY)"
    mv -T -n -- "$target" "$origin"
    [[ ! -e "$target" && -d "$origin" ]] || fail "Move did not complete; inspect $target and $origin"
    printf 'Moved launcher back to %s\n' "$origin"
    printf 'Remove the custom Steam Launch Options entry before starting the original game.\n'
fi
