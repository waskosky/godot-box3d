#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

emsdk_dir="${EMSDK_DIR:-$repo_root/.deps/emsdk}"
if ! command -v emcc >/dev/null 2>&1 && [[ -f "$emsdk_dir/emsdk_env.sh" ]]; then
    # shellcheck disable=SC1090
    source "$emsdk_dir/emsdk_env.sh" >/dev/null
fi

require_pinned_emscripten
require_dependency_trees
scons_bin="$(scons_command)"
jobs="$(cpu_jobs)"
target="${GODOT_BOX3D_STATIC_TARGET:-template_release}"

case "$target" in
    template_debug|template_release) ;;
    *) fail "GODOT_BOX3D_STATIC_TARGET must be template_debug or template_release." ;;
esac

note "Building Web $target static archives with thread-capable objects"
GODOT_BOX3D_LINK_MODE=static "$scons_bin" -C "$repo_root" -j "$jobs" \
    platform=web \
    target="$target" \
    arch=wasm32 \
    threads=yes \
    "$@"

output_dir="$repo_root/bin/web/static"
box3d_archive="$(find "$output_dir" -maxdepth 1 -type f -name "libgodot-box3d-static.web.${target}.wasm32.a" -print -quit)"
godot_cpp_archive="$(find "$output_dir" -maxdepth 1 -type f -name "libgodot-cpp.web.${target}.wasm32.a" -print -quit)"
[[ -n "$box3d_archive" && -s "$box3d_archive" ]] || fail "Static Box3D archive was not produced."
[[ -n "$godot_cpp_archive" && -s "$godot_cpp_archive" ]] || fail "Static godot-cpp archive was not staged."

for archive in "$box3d_archive" "$godot_cpp_archive"; do
    [[ "$(LC_ALL=C head -c 7 "$archive")" == "!<arch>" ]] || fail "Invalid static archive: $archive"
done

note "Static Web archives are ready under $output_dir"
