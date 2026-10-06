#!/usr/bin/env bash
# Shared Steam library lookup for this game's launcher and patch installer.

steam_app_id=4260270

# These fields are quoted, single-line KeyValues entries in Steam's library
# list and app manifest. --game handles unusual or missing metadata.
vdf_values() {
    awk -F '"' -v wanted="$1" '$2 == wanted { print $4 }' "$2"
}

add_library() {
    local path=$1 resolved
    [[ -d "$path" ]] || return 0
    resolved=$(cd -- "$path" && pwd -P)
    [[ -v library_seen["$resolved"] ]] && return 0
    library_seen["$resolved"]=1
    libraries+=("$resolved")
}

find_steam_game() {
    local root list path library manifest manifest_id install_dir candidate resolved
    local -a roots=() libraries=() matches=()
    local -A library_seen=() game_seen=()

    if [[ -n "$steam_root_arg" ]]; then
        roots+=("$steam_root_arg")
    else
        roots+=(
            "${XDG_DATA_HOME:-$HOME/.local/share}/Steam"
            "$HOME/.steam/root"
            "$HOME/.steam/steam"
            "$HOME/.steam/debian-installation"
            "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
            "$HOME/.var/app/com.valvesoftware.Steam/.steam/root"
            "$HOME/snap/steam/common/.local/share/Steam"
        )
    fi

    for root in "${roots[@]}"; do
        [[ -d "$root" ]] || continue
        add_library "$root"
        for list in "$root/steamapps/libraryfolders.vdf" "$root/config/libraryfolders.vdf"; do
            [[ -f "$list" ]] || continue
            while IFS= read -r path; do
                [[ "$path" == /* ]] && add_library "$path"
            done < <(vdf_values path "$list")
        done
    done

    for library in "${libraries[@]}"; do
        manifest="$library/steamapps/appmanifest_${steam_app_id}.acf"
        [[ -f "$manifest" ]] || continue
        manifest_id=$(vdf_values appid "$manifest" | head -n 1)
        [[ "$manifest_id" == "$steam_app_id" ]] || continue
        install_dir=$(vdf_values installdir "$manifest" | head -n 1)
        [[ -n "$install_dir" && "$install_dir" != . && "$install_dir" != .. &&
           "$install_dir" != */* && "$install_dir" != *\\* ]] || continue
        candidate="$library/steamapps/common/$install_dir"
        [[ -f "$candidate/Game.exe" && -f "$candidate/index.html" ]] || continue
        resolved=$(cd -- "$candidate" && pwd -P)
        [[ -v game_seen["$resolved"] ]] && continue
        game_seen["$resolved"]=1
        matches+=("$resolved")
    done

    if [[ ${#matches[@]} -eq 0 ]]; then
        fail "Steam app $steam_app_id was not found; pass --game /path/to/game"
    fi
    if [[ ${#matches[@]} -gt 1 ]]; then
        printf 'Multiple copies of Steam app %s found:\n' "$steam_app_id" >&2
        printf '  %s\n' "${matches[@]}" >&2
        fail 'Pass --game to select one'
    fi
    game=${matches[0]}
}
