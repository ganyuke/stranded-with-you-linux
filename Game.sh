#!/bin/sh
# Starts Stranded with You natively on Linux (Electron) instead of through Proton.
launcher_dir="$(dirname "$(readlink -f "$0")")"
runtime="$launcher_dir/linux-runtime/electron"
development_runtime="$launcher_dir/linux/node_modules/electron/dist/electron"
log_file="$launcher_dir/launcher.log"

# In a release, this launcher lives in its own folder beside the game files.
# In a source checkout, it lives directly in the game folder.
if [ -f "$launcher_dir/Game.exe" ] && [ -f "$launcher_dir/index.html" ]; then
    game_dir="$launcher_dir"
else
    game_dir="$(dirname "$launcher_dir")"
fi

export STRANDED_GAME_DIR="$game_dir"

{
    echo
    echo "=== $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="
    echo "Launcher: $0"
    echo "Working directory: $(pwd)"
    echo "Game directory: $game_dir"
    echo "SteamAppId: ${SteamAppId:-<unset>}"
    echo "SteamGameId: ${SteamGameId:-<unset>}"
    echo "XDG session: ${XDG_SESSION_TYPE:-<unset>}"
    echo "Wayland display: ${WAYLAND_DISPLAY:-<unset>}"
    echo "X11 display: ${DISPLAY:-<unset>}"
    echo "LD_PRELOAD: ${LD_PRELOAD:-<unset>}"
} >>"$log_file" 2>&1

# Steam and Bazzite inject overlay/helper libraries through LD_PRELOAD. Those
# libraries can block Electron before its main process starts. Steamworks does
# not require binary injection; it connects to the running Steam client using
# the App ID inherited above.
if [ -n "${LD_PRELOAD:-}" ]; then
    echo "Clearing LD_PRELOAD before starting Electron" >>"$log_file"
    unset LD_PRELOAD
fi

if [ -x "$runtime" ]; then
    # Steam expands %command% to the original Windows executable. Do not pass
    # that through: Electron would treat Game.exe as an application argument.
    echo "Starting bundled Electron: $runtime" >>"$log_file"
    exec "$runtime" >>"$log_file" 2>&1
fi

if [ -x "$development_runtime" ]; then
    echo "Starting development Electron: $development_runtime" >>"$log_file"
    exec "$development_runtime" "$launcher_dir/linux" >>"$log_file" 2>&1
fi

echo "The Linux runtime is missing. Extract the release into this game folder." | tee -a "$log_file"
echo "Developers can instead run: cd \"$launcher_dir/linux\" && npm run setup" | tee -a "$log_file"
exit 1
