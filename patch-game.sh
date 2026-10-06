#!/usr/bin/env bash
# Install the extracted English patch over the game, or restore the originals.
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
game_arg=
patch_arg=
steam_root_arg=
backup_name=.stranded-with-you-patch-backups

usage() {
    printf 'Usage: %s install|restore [--game GAME_DIR] [--steam-root STEAM_DIR] [--patch PATCH_FILES_DIR_OR_ZIP]\n' "$0" >&2
    exit 2
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    if [[ ${installing:-0} == 1 ]]; then
        rollback_after_error 1
    fi
    exit 1
}

hash_file() {
    local line
    IFS= read -r -d '' line < <(sha256sum --zero -- "$1")
    printf '%s' "${line:0:64}"
}

write_state() {
    printf '%s\n' "$2" > "$1/.state.tmp"
    mv -f -- "$1/.state.tmp" "$1/state"
}

check_parents() {
    local root=$1 parent
    parent=$(dirname -- "$2")
    while [[ "$parent" != "$root" ]]; do
        [[ "$parent" == "$root/"* ]] || fail "Path escapes game or backup: $2"
        [[ ! -L "$parent" && ( ! -e "$parent" || -d "$parent" ) ]] || fail "Unsafe directory: $parent"
        parent=$(dirname -- "$parent")
    done
}

load_manifest() {
    local relative hash
    declare -gA original=() expected=() new_directory=()
    while IFS= read -r -d '' relative; do original["$relative"]=1; done < "$snapshot/existing.list"
    while IFS= read -r -d '' relative && IFS= read -r -d '' hash; do
        expected["$relative"]=$hash
    done < "$snapshot/hashes.list"
    while IFS= read -r -d '' relative; do new_directory["$game/$relative"]=1; done < "$snapshot/new-dirs.list"
}

restore_snapshot() {
    local relative target saved actual parent state
    state=$(<"$snapshot/state")
    load_manifest

    # Check all touched files before removing any patched file.
    while IFS= read -r -d '' relative; do
        target="$game/$relative"
        saved="$snapshot/originals/$relative"
        check_parents "$game" "$target"
        check_parents "$snapshot" "$saved"
        [[ ! -L "$target" && ! -L "$saved" ]] || fail "Unsafe restore path: $relative"
        if [[ "$state" == installed && -v original["$relative"] && ! -f "$saved" ]]; then
            fail "Original missing from backup: $saved"
        fi
        if [[ -f "$saved" || ! -v original["$relative"] ]]; then
            if [[ -e "$target" ]]; then
                [[ -f "$target" ]] || fail "Expected a file: $target"
                actual=$(hash_file "$target")
                [[ "$actual" == "${expected[$relative]}" ]] || fail "Patched file changed; restore stopped: $target"
            fi
        fi
    done < "$snapshot/files.list"

    write_state "$snapshot" restoring
    while IFS= read -r -d '' relative; do
        target="$game/$relative"
        saved="$snapshot/originals/$relative"
        if [[ -f "$saved" ]]; then
            [[ ! -e "$target" ]] || rm -- "$target"
            mkdir -p -- "$(dirname -- "$target")"
            mv -- "$saved" "$target"
        elif [[ ! -v original["$relative"] ]]; then
            [[ ! -e "$target" ]] || rm -- "$target"
        fi
    done < "$snapshot/files.list"

    while IFS= read -r -d '' relative; do
        parent=$(dirname -- "$game/$relative")
        while [[ "$parent" != "$game" && -v new_directory["$parent"] ]]; do
            rmdir -- "$parent" 2>/dev/null || break
            parent=$(dirname -- "$parent")
        done
    done < "$snapshot/files.list"
    write_state "$snapshot" restored
}

rollback_after_error() {
    local status=$1
    installing=0
    trap - ERR INT TERM
    printf 'Installation failed. Restoring from %s\n' "$snapshot" >&2
    restore_snapshot
    exit "$status"
}

[[ $# -ge 1 ]] || usage
action=$1
shift
[[ "$action" == install || "$action" == restore ]] || usage
while [[ $# -gt 0 ]]; do
    case "$1" in
        --game) [[ $# -ge 2 ]] || usage; game_arg=$2; shift 2 ;;
        --steam-root) [[ $# -ge 2 ]] || usage; steam_root_arg=$2; shift 2 ;;
        --patch) [[ $# -ge 2 && "$action" == install ]] || usage; patch_arg=$2; shift 2 ;;
        *) usage ;;
    esac
done

if [[ -n "$game_arg" ]]; then
    game=$(cd -- "$game_arg" && pwd -P) || fail "Game directory not found: $game_arg"
elif [[ -f "$script_dir/Game.exe" && -f "$script_dir/index.html" ]]; then
    game=$script_dir
elif [[ -f "$(dirname -- "$script_dir")/Game.exe" && -f "$(dirname -- "$script_dir")/index.html" ]]; then
    game=$(dirname -- "$script_dir")
else
    . "$script_dir/steam-game-path.sh"
    find_steam_game
fi
[[ -f "$game/Game.exe" && -f "$game/index.html" ]] || fail "Not a game directory: $game"
if [[ -z "$patch_arg" ]]; then
    candidates=(
        "$(dirname -- "$game")/Stranded-with-You-Patch-en/Patch Files"
        "$(dirname -- "$script_dir")/Stranded-with-You-Patch-en/Patch Files"
        "$PWD/Stranded-with-You-Patch-en/Patch Files"
        "$(dirname -- "$game")/Stranded-with-You-Patch-en.zip"
        "$(dirname -- "$script_dir")/Stranded-with-You-Patch-en.zip"
        "$PWD/Stranded-with-You-Patch-en.zip"
    )
    if [[ -f "$script_dir/.install-origin" ]]; then
        IFS= read -r original_bundle < "$script_dir/.install-origin"
        candidates+=("$(dirname -- "$original_bundle")/Stranded-with-You-Patch-en.zip")
    fi
    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate" || -f "$candidate" ]]; then
            patch_arg=$candidate
            break
        fi
    done
fi
backups="$game/$backup_name"
[[ ! -L "$backups" && ( ! -e "$backups" || -d "$backups" ) ]] || fail "Unsafe backup directory: $backups"
mkdir -p -- "$backups"
[[ ! -L "$backups/.lock" ]] || fail "Unsafe lock file: $backups/.lock"
exec 9>"$backups/.lock"
flock -x 9

active=()
while IFS= read -r -d '' folder; do
    [[ -f "$folder/state" ]] || continue # No game files moved before state exists.
    state=$(<"$folder/state")
    [[ "$state" == restored ]] || active+=("$folder")
done < <(find "$backups" -mindepth 1 -maxdepth 1 -type d -print0)

if [[ "$action" == restore ]]; then
    [[ ${#active[@]} -eq 1 ]] || fail "Expected one active backup, found ${#active[@]}"
    snapshot=${active[0]}
    restore_snapshot
    printf 'Restored original game files from %s\n' "$snapshot"
    exit 0
fi

[[ ${#active[@]} -eq 0 ]] || fail "A patch backup is active; restore it first"
[[ -n "$patch_arg" ]] || fail "Patch not found; pass --patch /path/to/Stranded-with-You-Patch-en.zip"
if [[ -d "$patch_arg" ]]; then
    patch=$(cd -- "$patch_arg" && pwd -P)
elif [[ -f "$patch_arg" && "$patch_arg" == *.zip ]]; then
    archive=$(realpath -- "$patch_arg")
    if ! command -v unzip >/dev/null && ! command -v python3 >/dev/null; then
        fail "Supply the extracted directory instead, or install unzip or Python 3 to let the script extract the ZIP for you."
    fi
    temp_extract=$(mktemp -d "${TMPDIR:-/tmp}/stranded-patch.XXXXXXXX")
    trap 'rm -rf -- "$temp_extract"' EXIT
    if command -v unzip >/dev/null; then
        unzip -tqq "$archive" || fail "Patch ZIP is damaged: $archive"
        while IFS= read -r entry; do
            case "$entry" in
                /*|..|../*|*/..|*/../*) fail "Unsafe path in patch ZIP: $entry" ;;
            esac
        done < <(unzip -Z -1 "$archive")
        if unzip -Z -l "$archive" | awk '$1 ~ /^l/ {found=1} END {exit !found}'; then
            fail "Patch ZIP contains a symlink"
        fi
        unzip -q "$archive" 'Patch Files/*' -d "$temp_extract"
    else
        python3 - "$archive" "$temp_extract" <<'PY'
import pathlib
import shutil
import stat
import sys
import zipfile

archive_path, output_dir = sys.argv[1:]
root = pathlib.Path(output_dir)
try:
    with zipfile.ZipFile(archive_path) as archive:
        bad_file = archive.testzip()
        if bad_file:
            raise ValueError(f"Patch ZIP is damaged: {bad_file}")
        entries = archive.infolist()
        for entry in entries:
            name = entry.filename
            if not name or name.startswith("/") or ".." in name.split("/"):
                raise ValueError(f"Unsafe path in patch ZIP: {name}")
            if stat.S_ISLNK(entry.external_attr >> 16):
                raise ValueError(f"Patch ZIP contains a symlink: {name}")
        for entry in entries:
            if not entry.filename.startswith("Patch Files/"):
                continue
            destination = root.joinpath(*entry.filename.split("/"))
            if entry.is_dir():
                destination.mkdir(parents=True, exist_ok=True)
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(entry) as source, destination.open("wb") as target:
                    shutil.copyfileobj(source, target)
except (OSError, ValueError, zipfile.BadZipFile) as error:
    sys.exit(f"Error: {error}")
PY
    fi
    patch="$temp_extract/Patch Files"
else
    fail "Patch must be the extracted Patch Files directory or its ZIP: $patch_arg"
fi
[[ "$patch" != "$game" && "$patch" != "$game/"* && "$game" != "$patch/"* ]] || fail "Patch directory overlaps game"
[[ -f "$patch/Game.exe" && -f "$patch/index.html" && -f "$patch/data/System.json" ]] || fail "Not the extracted full-game patch: $patch"
[[ -z $(find "$patch" -type l -print -quit) ]] || fail "Patch contains a symlink"

snapshot=$(mktemp -d "$backups/$(date -u +%Y%m%dT%H%M%SZ)-XXXXXXXX")
: > "$snapshot/files.list"
: > "$snapshot/existing.list"
: > "$snapshot/hashes.list"
: > "$snapshot/new-dirs.list"
count=0
while IFS= read -r -d '' source; do
    relative=${source#"$patch"/}
    case "$relative" in
        "$backup_name"/*|save/*|saves/*|config/*|www/save/*|www/saves/*)
            fail "Patch contains a protected path: $relative" ;;
    esac
    target="$game/$relative"
    check_parents "$game" "$target"
    [[ ! -L "$target" && ( ! -e "$target" || -f "$target" ) ]] || fail "Unsafe game file: $target"
    printf '%s\0' "$relative" >> "$snapshot/files.list"
    if [[ -f "$target" ]]; then
        printf '%s\0' "$relative" >> "$snapshot/existing.list"
    fi
    parent=$(dirname -- "$target")
    while [[ "$parent" != "$game" ]]; do
        [[ -d "$parent" ]] || printf '%s\0' "${parent#"$game"/}" >> "$snapshot/new-dirs.list"
        parent=$(dirname -- "$parent")
    done
    hash=$(hash_file "$source")
    printf '%s\0%s\0' "$relative" "$hash" >> "$snapshot/hashes.list"
    ((count += 1))
done < <(find "$patch" -type f -print0)
((count > 0)) || fail "Patch has no files: $patch"

load_manifest
write_state "$snapshot" installing
installing=1
trap 'rollback_after_error $?' ERR
trap 'rollback_after_error 130' INT
trap 'rollback_after_error 143' TERM
while IFS= read -r -d '' relative; do
    source="$patch/$relative"
    target="$game/$relative"
    saved="$snapshot/originals/$relative"
    check_parents "$game" "$target"
    if [[ -v original["$relative"] ]]; then
        [[ -f "$target" && ! -L "$target" ]] || fail "Original game file changed during install: $target"
        mkdir -p -- "$(dirname -- "$saved")"
        mv -- "$target" "$saved"
    else
        [[ ! -e "$target" && ! -L "$target" ]] || fail "New game file appeared during install: $target"
    fi
    mkdir -p -- "$(dirname -- "$target")"
    temporary=$(mktemp "$snapshot/.patch-XXXXXXXX")
    cp -p -- "$source" "$temporary"
    [[ $(hash_file "$temporary") == "${expected[$relative]}" ]] || fail "Patch source changed during install: $source"
    mv -- "$temporary" "$target"
done < "$snapshot/files.list"
trap - ERR INT TERM
installing=0
write_state "$snapshot" installed
printf 'Installed %s patch files. Backup: %s\n' "$count" "$snapshot"
printf 'To undo: %q restore --game %q\n' "$0" "$game"
