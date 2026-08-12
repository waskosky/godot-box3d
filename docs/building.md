---
title: Building from source
---

# Building from source

## Requirements

- CMake 3.22 or newer
- A C++17 compiler (GCC, Clang, or MSVC)
- Git, for the Box3D submodule

`godot-cpp` is fetched automatically during configure, so it does not need to be installed.

## Clone and build

```sh
git clone --recurse-submodules https://github.com/bearlikelion/godot-box3d.git
cd godot-box3d
cmake -B build
cmake --build build --parallel
```

If you cloned without `--recurse-submodules`:

```sh
git submodule update --init --recursive
```

The library lands in `bin/` and is copied into `test_project/addons/godot-box3d/bin/`, so the demo project always runs against a fresh build.

## Cross-compiling a Windows DLL from Linux

Needs MinGW-w64 installed.

```sh
cmake -B build-win --toolchain "$(pwd)/cmake/mingw-w64.cmake" -G Ninja
cmake --build build-win --parallel
```

This produces `bin/godot-box3d.dll`, statically linked against the MinGW runtime so no extra DLLs ship beside it. Release builds use the MSVC DLL from CI instead; this exists for exporting a Windows demo locally without waiting on a CI run.

The toolchain file also generates a capitalised `Windows.h` symlink, because `box3d/src/timer.c` includes it capitalised while MinGW ships lowercase `windows.h` and Linux filesystems are case-sensitive.

## Running the tests

```sh
GODOT_BIN=/path/to/godot scripts/run_headless_tests.sh
```

The runner builds the extension, registers it, checks the Box3D backend actually loaded, then runs the headless regression tests. It exits non-zero if a test fails or leaks a Box3D RID. `GODOT_BIN` can be omitted when a suitable `godot` is on `PATH`.

CI runs the suite with Godot 4.7 on Linux, Windows, and macOS, plus a Linux compatibility run on the minimum supported Godot 4.3. It also executes the suite under UndefinedBehaviorSanitizer and compile/link checks a Debug build instrumented with AddressSanitizer. Runtime ASan requires an ASan-built Godot host because stock Linux binaries load extensions with `RTLD_DEEPBIND`.

The UBSan job retains full coverage for the C++ extension. Its Box3D C build excludes only the alignment category because Box3D's x86 SIMD loader deliberately uses an unaligned-capable `movsd` instruction through an intrinsic whose pointer type triggers GCC's alignment instrumentation. The regular native and Web jobs continue to exercise that production SIMD path.

The runner registers only Box3D. A second GDExtension built against a different Godot version can abort the process before Box3D registers, which would fail every test for an unrelated reason.

Tests live in `test_project/tests/`, one file per behavior, each extending `SceneTree`. Assertions were validated against stock Godot Physics first, so they encode real engine behavior rather than whatever this backend happened to do.

## Regenerating demo screenshots

```sh
godot --path test_project --script res://tools/capture_demos.gd
```

Needs a real GPU. `--headless` forces the dummy rasterizer and writes blank images, so the script refuses to run there.
