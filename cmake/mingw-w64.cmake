# Cross-compile a Windows DLL from Linux with MinGW-w64.
#
#   cmake -B build-win --toolchain cmake/mingw-w64.cmake -G Ninja
#   cmake --build build-win --parallel
#
# Produces bin/godot-box3d.dll. Release builds use the MSVC DLL from CI instead; this is for
# exporting a Windows demo locally without waiting on a CI run.

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)

set(CMAKE_FIND_ROOT_PATH /usr/x86_64-w64-mingw32)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# Godot loads the DLL standalone, so link the runtime statically rather than shipping
# libgcc/libstdc++/winpthread beside it.
set(CMAKE_EXE_LINKER_FLAGS_INIT "-static-libgcc -static-libstdc++ -static")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-static-libgcc -static-libstdc++ -static")

# box3d/src/timer.c includes <Windows.h>, but MinGW ships lowercase windows.h and Linux
# filesystems are case-sensitive. Generate a capitalized symlink rather than patching the
# submodule.
set(GODOT_BOX3D_MINGW_SHIM "${CMAKE_BINARY_DIR}/mingw-compat")
file(MAKE_DIRECTORY "${GODOT_BOX3D_MINGW_SHIM}")
if(NOT EXISTS "${GODOT_BOX3D_MINGW_SHIM}/Windows.h")
	file(CREATE_LINK "${CMAKE_FIND_ROOT_PATH}/include/windows.h"
		"${GODOT_BOX3D_MINGW_SHIM}/Windows.h" SYMBOLIC)
endif()
include_directories(BEFORE SYSTEM "${GODOT_BOX3D_MINGW_SHIM}")
