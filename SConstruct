#!/usr/bin/env python
"""Primary cross-platform build for godot-box3d.

The project intentionally compiles Box3D directly into the GDExtension shared
library. This avoids shipping a second native library and keeps Android, iOS,
and Web packaging aligned with Godot's official godot-cpp template.
"""

import os
import sys
from pathlib import Path


LIBRARY_NAME = "godot-box3d"
TEST_ADDON_DIR = "test_project/addons/godot-box3d"
LINK_MODE = os.environ.get("GODOT_BOX3D_LINK_MODE", "dynamic").strip().lower()

if LINK_MODE not in ("dynamic", "static"):
    print("ERROR: GODOT_BOX3D_LINK_MODE must be 'dynamic' or 'static'.")
    Exit(1)


def _is_nonempty_directory(path):
    return os.path.isdir(path) and bool(os.listdir(path))


def _print_dependency_error(path, command):
    print(
        "ERROR: Required dependency '{}' is missing or empty.\n"
        "Run this command from the repository root, then rebuild:\n\n"
        "    {}\n".format(path, command)
    )


def _recursive_sources(root, suffix):
    return [str(path) for path in sorted(Path(root).rglob("*{}".format(suffix))) if path.is_file()]


def _object_target(group, source, root, variant):
    relative = os.path.relpath(source, root)
    stem = os.path.splitext(relative)[0]
    return os.path.join("#build", "scons", variant, group, stem)


def _compile_shared_objects(build_env, sources, source_root, group, variant):
    objects = []
    for source in sources:
        target = _object_target(group, source, source_root, variant)
        objects.extend(build_env.SharedObject(target=target, source=source))
    return objects


def _compile_static_objects(build_env, sources, source_root, group, variant):
    objects = []
    for source in sources:
        target = _object_target(group, source, source_root, variant)
        objects.extend(build_env.Object(target=target, source=source))
    return objects


if not _is_nonempty_directory("godot-cpp"):
    _print_dependency_error("godot-cpp", "scripts/bootstrap_dependencies.sh")
    Exit(1)

if not _is_nonempty_directory("box3d"):
    _print_dependency_error("box3d", "scripts/bootstrap_dependencies.sh")
    Exit(1)

# Start without host-platform defaults. godot-cpp applies the selected target
# toolchain after it parses SCons command-line options.
local_env = Environment(tools=["default"], PLATFORM="")

# Generate only the Godot engine classes required by this physics backend and
# their transitive dependencies. This substantially reduces build time and
# binary size on Android, iOS, and Web. Callers can override the profile with
# build_profile=<path> when developing new wrapper features.
if "build_profile" not in ARGUMENTS:
    local_env["build_profile"] = os.path.abspath("godot_cpp_build_profile.json")

# godot-cpp writes generated built-in wrappers into one shared gen/ directory.
# Their opaque sizes depend on the target pointer width, but target width is not
# part of the generated-file dependency signature in the pinned 4.3 bindings.
# Always regenerate before a platform build so a preceding wasm32 build cannot
# leak 32-bit wrappers into Android, iOS, or desktop libraries (or vice versa).
local_env["generate_bindings"] = True

# The recommended browser configuration is deliberately single-threaded. It
# avoids SharedArrayBuffer/cross-origin-isolation deployment requirements and
# matches the .gdextension filenames committed in this repository. A caller may
# still override this explicitly with threads=yes for an experimental build.
if ARGUMENTS.get("platform") == "web" and "threads" not in ARGUMENTS:
    local_env["threads"] = False

env = SConscript("godot-cpp/SConstruct", {"env": local_env, "customs": []})

platform_name = env["platform"]
if LINK_MODE == "static" and platform_name != "web":
    print("ERROR: The embedded static archive is currently supported only for Web builds.")
    Exit(1)
is_ios_simulator = platform_name == "ios" and bool(env.get("ios_simulator", False))
variant = "{}-{}-{}{}{}".format(
    platform_name,
    env["target"],
    env["arch"],
    "-simulator" if is_ios_simulator else "",
    "-nothreads" if not env["threads"] else "",
)
if LINK_MODE == "static":
    variant += "-static"

# The pinned Godot 4.3 iOS tool applies its deployment target to compilation
# but not linking. New Xcode versions then stamp the dylib with the SDK version
# as its minimum OS. Keep the older API-compatible bindings while applying the
# same target to the final link, matching current godot-cpp behavior.
if platform_name == "ios":
    ios_min_version = str(env["ios_min_version"])
    deployment_flag = (
        "-mios-simulator-version-min=" if is_ios_simulator else "-miphoneos-version-min="
    ) + ios_min_version
    env.AppendUnique(LINKFLAGS=[deployment_flag])

common_include_dirs = [
    env.Dir("#src"),
    env.Dir("#box3d/include"),
    env.Dir("#box3d/src"),
]

env.AppendUnique(CPPPATH=common_include_dirs)

extension_env = env.Clone()
box3d_env = env.Clone()
box3d_env.AppendUnique(CPPPATH=common_include_dirs)

# Box3D v0.1.0 is C17. Give only its C objects the appropriate compiler flag
# without changing godot-cpp's C++ mode.
if box3d_env.get("is_msvc", False):
    box3d_env.Prepend(CFLAGS=["/std:c17"])
else:
    box3d_env.Prepend(CFLAGS=["-std=gnu17"])
    box3d_env.AppendUnique(CCFLAGS=["-ffp-contract=off"])

# Emscripten maps Box3D's SSE2 implementation to WebAssembly SIMD128. This is
# the upstream-recommended fast path. Set BOX3D_DISABLE_SIMD=1 only as a
# compatibility diagnostic; the resulting binary is slower.
disable_simd = os.environ.get("BOX3D_DISABLE_SIMD", "0").strip().lower() in (
    "1",
    "true",
    "yes",
    "on",
)
if disable_simd:
    box3d_env.AppendUnique(CPPDEFINES=["BOX3D_DISABLE_SIMD"])
elif platform_name == "web":
    box3d_env.AppendUnique(CCFLAGS=["-msimd128", "-msse2"])

# Box3D uses libm on Unix-like targets. Apple and Emscripten provide these
# symbols through their system runtimes; Linux and Android use libm explicitly.
if platform_name in ("linux", "android"):
    env.AppendUnique(LIBS=["m"])

extension_sources = _recursive_sources("src", ".cpp")
box3d_sources = _recursive_sources("box3d/src", ".c")

if not extension_sources:
    print("ERROR: No extension C++ sources were found under src/.")
    Exit(1)
if not box3d_sources:
    print("ERROR: No Box3D C sources were found under box3d/src/.")
    Exit(1)

objects = []
compile_objects = _compile_static_objects if LINK_MODE == "static" else _compile_shared_objects
objects.extend(compile_objects(extension_env, extension_sources, "src", "extension", variant))
objects.extend(compile_objects(box3d_env, box3d_sources, "box3d/src", "box3d", variant))

# Match the naming convention used by godot-cpp's official template. Removing
# .universal keeps the macOS filename architecture-neutral while preserving the
# platform, target, precision, architecture, simulator, and threading tags.
suffix = env["suffix"].replace(".dev", "").replace(".universal", "")
library_filename = "{}{}{}{}".format(
    env.subst("$SHLIBPREFIX"),
    LIBRARY_NAME,
    suffix,
    env.subst("$SHLIBSUFFIX"),
)

if LINK_MODE == "static":
    static_output_dir = os.path.join("bin", platform_name, "static")
    static_filename = "libgodot-box3d-static{}{}".format(suffix, env.subst("$LIBSUFFIX"))
    library = env.StaticLibrary(
        target=os.path.join(static_output_dir, static_filename),
        source=objects,
    )
    godot_cpp_libraries = [
        candidate
        for candidate in env["LIBS"]
        if os.path.basename(str(candidate)).startswith("libgodot-cpp")
    ]
    if len(godot_cpp_libraries) != 1:
        print("ERROR: Expected exactly one godot-cpp static library dependency.")
        Exit(1)
    godot_cpp_copy = env.Install(static_output_dir, godot_cpp_libraries[0])
    Default(library, godot_cpp_copy)
else:
    library = env.SharedLibrary(
        target=os.path.join("bin", platform_name, library_filename),
        source=objects,
    )

    test_copy = env.Install(os.path.join(TEST_ADDON_DIR, "bin", platform_name), library)

    Default(library, test_copy)
