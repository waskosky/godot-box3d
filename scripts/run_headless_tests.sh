#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

godot_bin="${GODOT_BIN:-godot}"
godot_metadata_dir="$repo_root/test_project/.godot"
jobs="$(cpu_jobs)"

require_command "$godot_bin"
require_dependency_trees
scons_bin="$(scons_command)"

case "$(uname -s)" in
    Darwin)
        platform=macos
        arch=universal
        ;;
    Linux)
        platform=linux
        case "$(uname -m)" in
            x86_64|amd64) arch=x86_64 ;;
            aarch64|arm64) arch=arm64 ;;
            *) fail "Unsupported Linux test architecture: $(uname -m)" ;;
        esac
        ;;
    *)
        fail "scripts/run_headless_tests.sh currently supports Linux and macOS hosts."
        ;;
esac

note "Building host template_debug extension for $platform / $arch"
"$scons_bin" -C "$repo_root" -j "$jobs" \
    platform="$platform" \
    target=template_debug \
    arch="$arch"

mkdir -p "$godot_metadata_dir"
printf '%s\n' 'res://addons/godot-box3d/godot-box3d.gdextension' > "$godot_metadata_dir/extension_list.cfg"

tests=(
    backend_activation_test.gd
    collision_filter_test.gd
    custom_integrator_test.gd
    direct_query_test.gd
    body_dynamics_test.gd
    review_regression_test.gd
    physics_contract_test.gd
    ray_pickability_test.gd
    fall_test.gd
    settle_test.gd
    area_test.gd
    area_ignores_trimesh_body_test.gd
    trimesh_area_detects_body_test.gd
    trimesh_collision_test.gd
    cylinder_test.gd
    default_area_test.gd
    joint_test.gd
)

run_test() {
    local test_script="$1"
    local test_output
    local test_status=0

    printf '\n== %s ==\n' "$test_script"
    test_output="$("$godot_bin" --headless --path "$repo_root/test_project" --script "res://$test_script" 2>&1)" || test_status=$?
    printf '%s\n' "$test_output"

    if (( test_status != 0 )); then
        return "$test_status"
    fi
    if [[ "$test_output" == *"RIDs in Godot Box3D were found to not have been freed"* ]]; then
        printf 'ERROR: %s leaked one or more Box3D RIDs.\n' "$test_script" >&2
        return 1
    fi
}

for test_script in "${tests[@]}"; do
    run_test "$test_script"
done
