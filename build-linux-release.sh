#!/bin/sh
set -eu

project_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
electron_dist="$project_dir/linux/node_modules/electron/dist"
steamworks_module="$project_dir/linux/node_modules/steamworks.js"
runtime_manifest="$project_dir/linux/package.runtime.json"
output_dir="$project_dir/dist"

if [ "$(uname -m)" != "x86_64" ]; then
    echo "This release currently supports Linux x86_64 only." >&2
    exit 1
fi

if [ ! -x "$electron_dist/electron" ] || [ ! -f "$steamworks_module/index.js" ]; then
    echo "Build dependencies are missing. Run this first:" >&2
    echo "    cd \"$project_dir/linux\" && npm ci" >&2
    exit 1
fi

version="$(node -p "require('$runtime_manifest').version")"
archive="$output_dir/stranded-with-you-linux-v${version}-x64.tar.gz"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/stranded-linux-build.XXXXXX")"
bundle_dir="$build_dir/stranded-with-you-linux"

cleanup() {
    rm -rf -- "$build_dir"
}
trap cleanup EXIT HUP INT TERM

packaged_steamworks="$bundle_dir/linux-runtime/resources/app/node_modules/steamworks.js"

mkdir -p "$packaged_steamworks/dist/linux64" "$output_dir"

cp -a "$electron_dist/." "$bundle_dir/linux-runtime/"
cp "$project_dir/Game.sh" "$project_dir/install.sh" "$project_dir/patch-game.sh" \
    "$project_dir/steam-game-path.sh" "$project_dir/README.md" "$bundle_dir/"
cp "$project_dir/linux/main.js" "$project_dir/linux/preload.js" \
    "$bundle_dir/linux-runtime/resources/app/"
cp "$runtime_manifest" "$bundle_dir/linux-runtime/resources/app/package.json"
cp "$steamworks_module/index.js" "$steamworks_module/package.json" \
    "$steamworks_module/LICENSE" "$packaged_steamworks/"
cp -a "$steamworks_module/dist/linux64/." "$packaged_steamworks/dist/linux64/"

chmod +x "$bundle_dir/Game.sh" "$bundle_dir/install.sh" "$bundle_dir/linux-runtime/electron"
tar -C "$build_dir" -czf "$archive" stranded-with-you-linux

echo "Built $archive"
