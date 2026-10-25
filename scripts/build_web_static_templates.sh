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
"$repo_root/scripts/bootstrap_dependencies.sh" --check
for dependency in box3d godot-cpp; do
    git -C "$repo_root/$dependency" diff --quiet HEAD || fail "$dependency has tracked changes; preserve them and use a clean checkout for this build."
done
scons_bin="$(scons_command)"
jobs="$(cpu_jobs)"
case "${GODOT_BOX3D_STATIC_TARGET:-all}" in
    all) targets=(template_release template_debug) ;;
    template_release|template_debug) targets=("$GODOT_BOX3D_STATIC_TARGET") ;;
    *) fail "GODOT_BOX3D_STATIC_TARGET must be all, template_release, or template_debug." ;;
esac

godot_source_dir="${GODOT_SOURCE_DIR:-$repo_root/.deps/godot-static-$GODOT_ENGINE_LABEL}"
ensure_git_checkout "Godot Engine" "$GODOT_ENGINE_REPOSITORY" "$GODOT_ENGINE_REF" "$GODOT_ENGINE_LABEL" "$godot_source_dir"
patch="$repo_root/patches/godot-4.7/web-worker-readback.patch"
[[ -z "$(git -C "$godot_source_dir" ls-files --others --exclude-standard)" ]] || fail "Godot has untracked source files; use a separate clean checkout."
if git -C "$godot_source_dir" diff --quiet HEAD; then
    git -C "$godot_source_dir" apply --check "$patch"
    git -C "$godot_source_dir" apply "$patch"
fi
# Accept exactly the included patch, preserving any other existing edits on failure.
cmp -s "$patch" <(git -C "$godot_source_dir" diff --no-ext-diff --no-renames HEAD | sed '/^index /d') || fail "Godot source differs from the pinned revision plus the included readback patch. Existing edits preserved."

output_dir="${WEB_STATIC_TEMPLATE_OUTPUT_DIR:-$repo_root/dist/web-static-templates}"
mkdir -p "$output_dir/templates" "$output_dir/archives"
for target in "${targets[@]}"; do
    GODOT_BOX3D_STATIC_TARGET="$target" "$repo_root/scripts/build_web_static.sh"
    note "Building static worker-main host: $target"
    "$scons_bin" -C "$godot_source_dir" -j "$jobs" \
        platform=web target="$target" arch=wasm32 precision=single \
        threads=yes dlink_enabled=no proxy_to_pthread=yes \
        custom_modules="$repo_root/examples/godot_static" \
        box3d_archive_dir="$repo_root/bin/web/static"
    expected="$godot_source_dir/bin/godot.web.${target}.wasm32.zip"
    [[ -s "$expected" ]] || fail "Missing static $target template: $expected"
    variant="${target#template_}"
    cp "$expected" "$output_dir/templates/godot-box3d-static-web-$variant.zip"
    for library in libgodot-box3d-static libgodot-cpp; do
        cp "$repo_root/bin/web/static/$library.web.$target.wasm32.a" "$output_dir/archives/"
    done
done

PYTHONPATH="$repo_root/scripts${PYTHONPATH:+:$PYTHONPATH}" python3 - "$output_dir" "$scons_bin" "${targets[@]}" <<'PY'
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from package_addon import REPO_ROOT, sha256, source_provenance, zip_tree
from verify_port import parse_lock

output = Path(sys.argv[1]).resolve()
targets = sys.argv[3:]
lock = parse_lock(REPO_ROOT / "dependencies.lock")
module_files = [Path("examples/godot_static/box3d_static") / name for name in ("config.py", "SCsub", "register_types.h", "register_types.cpp")]
support = [Path(name) for name in ("README.md", "LICENSE", "THIRD_PARTY_NOTICES.md", "dependencies.lock", "patches/godot-4.7/web-worker-readback.patch")]
support += module_files + [Path(path) for path in subprocess.check_output(["git", "ls-files", "docs"], cwd=REPO_ROOT, text=True).splitlines()]
build_inputs = module_files + [Path(name) for name in ("dependencies.lock", "SConstruct", "scripts/build_web_static.sh", "scripts/build_web_static_templates.sh", "patches/godot-4.7/web-worker-readback.patch")]
artifacts = []
for target in targets:
    variant = target.removeprefix("template_")
    artifacts.append(Path(f"templates/godot-box3d-static-web-{variant}.zip"))
    artifacts += [Path(f"archives/{library}.web.{target}.wasm32.a") for library in ("libgodot-box3d-static", "libgodot-cpp")]
manifest = {
    "profile": "static-worker-main",
    "source": source_provenance(),
    "dependencies": lock,
    "compiler": subprocess.check_output(["emcc", "--version"], text=True).splitlines()[0],
    "scons": subprocess.check_output([sys.argv[2], "--version"], text=True).splitlines()[0],
    "build_flags": {"platform": "web", "arch": "wasm32", "precision": "single", "threads": True, "dlink_enabled": False, "proxy_to_pthread": True},
    "targets": targets,
    "inputs": [{"path": path.as_posix(), "sha256": sha256(REPO_ROOT / path)} for path in build_inputs],
    "artifacts": [{"path": path.as_posix(), "size": (output / path).stat().st_size, "sha256": sha256(output / path)} for path in artifacts],
    "qualification": "Build receipt only; browser results are retained separately.",
}
(output / "BUILD_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
with tempfile.TemporaryDirectory(prefix="box3d-static-package-") as temporary:
    staging = Path(temporary)
    for path in artifacts + [Path("BUILD_MANIFEST.json")]:
        destination = staging / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(output / path, destination)
    for path in support:
        destination = staging / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(REPO_ROOT / path, destination)
    archive = output / "godot-box3d-embedded-static-web.zip"
    zip_tree(staging, archive)
(output / (archive.name + ".sha256")).write_text(f"{sha256(archive)}  {archive.name}\n")
print(f"Static templates, archives, manifest and bundle: {output}")
PY
