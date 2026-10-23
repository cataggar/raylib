<img align="left" style="width:260px" src="https://github.com/raysan5/raylib/blob/master/logo/raylib_logo_animation.gif" width="288px">

**raylib is a simple and easy-to-use library to enjoy videogames programming.**

raylib is highly inspired by Borland BGI graphics lib and by XNA framework and it's especially well suited for prototyping, tooling, graphical applications, embedded systems and education.

*NOTE for ADVENTURERS: raylib is a programming library to enjoy videogames programming; no fancy interface, no visual helpers, no debug button... just coding in the most pure spartan-programmers way.*

Ready to learn? Jump to [code examples!](https://www.raylib.com/examples.html)

---

<br>

[![GitHub Releases Downloads](https://img.shields.io/github/downloads/raysan5/raylib/total)](https://github.com/raysan5/raylib/releases)
[![GitHub Stars](https://img.shields.io/github/stars/raysan5/raylib?style=flat&label=stars)](https://github.com/raysan5/raylib/stargazers)
[![GitHub commits since tagged version](https://img.shields.io/github/commits-since/raysan5/raylib/5.5)](https://github.com/raysan5/raylib/commits/master)
[![GitHub Sponsors](https://img.shields.io/github/sponsors/raysan5?label=sponsors)](https://github.com/sponsors/raysan5)
[![Packaging Status](https://repology.org/badge/tiny-repos/raylib.svg)](https://repology.org/project/raylib/versions)
[![License](https://img.shields.io/badge/license-zlib%2Flibpng-blue.svg)](LICENSE)

[![Discord Members](https://img.shields.io/discord/426912293134270465.svg?label=Discord&logo=discord)](https://discord.gg/raylib)
[![Reddit Static Badge](https://img.shields.io/badge/-r%2Fraylib-red?style=flat&logo=reddit&label=reddit)](https://www.reddit.com/r/raylib/)
[![Youtube Subscribers](https://img.shields.io/youtube/channel/subscribers/UC8WIBkhYb5sBNqXO1mZ7WSQ?style=flat&label=Youtube&logo=youtube)](https://www.youtube.com/c/raylib)
[![Twitch Status](https://img.shields.io/twitch/status/raysan5?style=flat&label=Twitch&logo=twitch)](https://www.twitch.tv/raysan5)

[![Build Windows](https://github.com/raysan5/raylib/actions/workflows/build_windows.yml/badge.svg)](https://github.com/raysan5/raylib/actions/workflows/build_windows.yml)
[![Build Linux](https://github.com/raysan5/raylib/actions/workflows/build_linux.yml/badge.svg)](https://github.com/raysan5/raylib/actions/workflows/build_linux.yml)
[![Build macOS](https://github.com/raysan5/raylib/actions/workflows/build_macos.yml/badge.svg)](https://github.com/raysan5/raylib/actions/workflows/build_macos.yml)
[![Build WebAssembly](https://github.com/raysan5/raylib/actions/workflows/build_webassembly.yml/badge.svg)](https://github.com/raysan5/raylib/actions/workflows/build_webassembly.yml)

[![Build CMake](https://github.com/raysan5/raylib/actions/workflows/build_cmake.yml/badge.svg)](https://github.com/raysan5/raylib/actions/workflows/build_cmake.yml)
[![Build examples Windows](https://github.com/raysan5/raylib/actions/workflows/build_examples_windows.yml/badge.svg)](https://github.com/raysan5/raylib/actions/workflows/build_examples_windows.yml)
[![Build examples Linux](https://github.com/raysan5/raylib/actions/workflows/build_examples_linux.yml/badge.svg)](https://github.com/raysan5/raylib/actions/workflows/build_examples_linux.yml)

features
--------
  - **NO external dependencies**, all required libraries are [included into raylib](https://github.com/raysan5/raylib/tree/master/src/external)
  - Multiple platforms supported: **Windows, Linux, MacOS, RPI, Android, HTML5... and more!**
  - Written in plain C code (C99) using PascalCase/camelCase notation
  - Hardware accelerated with OpenGL: **1.1, 2.1, 3.3, 4.3, ES 2.0, ES 3.0**
  - **Unique OpenGL abstraction layer** (usable as standalone module): [rlgl](https://github.com/raysan5/raylib/blob/master/src/rlgl.h)
  - **Software Renderer** backend (no OpenGL required!): [rlsw](https://github.com/raysan5/raylib/blob/master/src/external/rlsw.h)
  - Multiple **Fonts** formats supported (TTF, OTF, FNT, BDF, sprite fonts)
  - Multiple texture formats supported, including **compressed formats** (DXT, ETC, ASTC)
  - **Full 3D support**, including 3D Shapes, Models, Billboards, Heightmaps and more!
  - Flexible Materials system, supporting classic maps and **PBR maps**
  - **Animated 3D models** supported (skeletal bones animation) (IQM, M3D, glTF)
  - Shaders support, including model shaders and **postprocessing** shaders
  - **Powerful math module** for Vector, Matrix and Quaternion operations: [raymath](https://github.com/raysan5/raylib/blob/master/src/raymath.h)
  - Audio loading and playing with streaming support (WAV, QOA, OGG, MP3, FLAC, XM, MOD)
  - **VR stereo rendering** support with configurable HMD device parameters
  - Huge examples collection with [+140 code examples](https://github.com/raysan5/raylib/tree/master/examples)!
  - Bindings to [+70 programming languages](https://github.com/raysan5/raylib/blob/master/BINDINGS.md)!
  - **Free and open source**

basic example
--------------
This is a basic raylib example, it creates a window and draws the text `"Congrats! You created your first window!"` in the middle of the screen. Check this example [running live on web here](https://www.raylib.com/examples/core/loader.html?name=core_basic_window).
```c
#include "raylib.h"

int main(void)
{
    InitWindow(800, 450, "raylib example - basic window");

    while (!WindowShouldClose())
    {
        BeginDrawing();
            ClearBackground(RAYWHITE);
            DrawText("Congrats! You created your first window!", 190, 200, 20, LIGHTGRAY);
        EndDrawing();
    }

    CloseWindow();

    return 0;
}
```

build and installation
----------------------

raylib binary releases for Windows, Linux, macOS, Android and HTML5 are available at the [Github Releases page](https://github.com/raysan5/raylib/releases).

raylib is also available via multiple package managers on multiple OS distributions.

#### Installing and building raylib on multiple platforms

[raylib Wiki](https://github.com/raysan5/raylib/wiki#development-platforms) contains detailed instructions on building and usage on multiple platforms.

 - [Working on Windows](https://github.com/raysan5/raylib/wiki/Working-on-Windows)
 - [Working on macOS](https://github.com/raysan5/raylib/wiki/Working-on-macOS)
 - [Working on GNU Linux](https://github.com/raysan5/raylib/wiki/Working-on-GNU-Linux)
 - [Working on Chrome OS](https://github.com/raysan5/raylib/wiki/Working-on-Chrome-OS)
 - [Working on FreeBSD](https://github.com/raysan5/raylib/wiki/Working-on-FreeBSD)
 - [Working on Raspberry Pi](https://github.com/raysan5/raylib/wiki/Working-on-Raspberry-Pi)
 - [Working for Android](https://github.com/raysan5/raylib/wiki/Working-for-Android)
 - [Working for Web (HTML5)](https://github.com/raysan5/raylib/wiki/Working-for-Web-(HTML5))
 - [Working anywhere with CMake](https://github.com/raysan5/raylib/wiki/Working-with-CMake)

*Note that the Wiki is open for edit, if you find some issues while building raylib for your target platform, feel free to edit the Wiki or open an issue related to it.*

#### Building with Zig

The Zig package requires Zig 0.17.0 and retains the raylib 6.0 C API.
`zig build` installs the library, headers, and desktop examples.
`zig build examples` builds all example groups, and `zig build test` tests
the build helpers. `zig build test-modules` checks the translated camera and
math modules, running their headless tests on a matching native target.
Existing backend, graphics, linkage, and feature options
remain available through `zig build --help`.

Android builds use `-Dplatform=android`, an Android target such as
`-Dtarget=aarch64-linux-android`, and an NDK directory supplied through
`-Dandroid_ndk` or `ANDROID_NDK_HOME`. `-Dandroid_api_version` still defaults
to `35`; generated libc metadata follows the selected ABI and API level.
The Android library records its `android`, `log`, `EGL`, and `GLESv2` link
dependencies. Android examples build PIC shared NativeActivity libraries
with the selected NDK's real `android_native_app_glue.c`, retain
`ANativeActivity_onCreate`, and require a fully resolved final link. They
install under `android/<abi>/<group>/lib<example>.so`; an individual example
step builds and installs its library rather than attempting to execute it
on the host. The selected raylib static/shared linkage remains independent
of the NativeActivity library's shared linkage. The activity directly links
`android` and `log` for native-app-glue, including with shared raylib.

Final Android links also require true `--wrap=fopen` semantics for APK asset
loading. The current Zig driver does not expose that linker option, so the
shared-link compiler boundary remains visible; no alias or undefined-symbol
allowance substitutes for wrapping. Native linker and other compiler
diagnostics also remain unwaived. This graph does not
assemble, sign, install, or launch an APK.

The Zig project template uses a typed C-ABI adapter on Android to call its
unchanged program after raylib initializes the NativeActivity state. The
retained OpenGL interop example uses real GLES2 declarations and raylib's
context-loaded OES VAO helpers on Android. If VAOs are unavailable, it
binds the same particle VBO and vertex attribute explicitly for each draw.
Context, required GLSL100 shader, and buffer failures are reported rather
than treating a missing feature as a working demo. Desktop and Web paths
are unchanged; source compilation alone does not qualify Android runtime.

The NativeActivity final link requests `-z defs`; the current native linker
can nevertheless emit a shared library with unresolved `__real_fopen`.
A successful command is therefore not proof of a fully resolved or
loadable Android library. Final ELF and runtime acceptance remain separate
from build-graph and native-host regression checks.
The exported `raylib`, `rcamera`, `raymath`, and `rlgl` modules and optional
raygui integration remain available. Web examples retain their
`web/<group>/<example>` directories and `emrun` entrypoints.

| Zig build dependency | Version | Revision |
| --- | --- | --- |
| zemscripten (default-output, 3fa4 generation) | 0.2.0-dev | `41f772b0fb097b25340103cd6ce3c49c855e9a69` |
| translate-c | 2.0.0 | `62d06a5d3e93c82727544e8113e4762a315ca0ed` |
| Aro (via translate-c) | 0.0.0 | `d0c8c4d9c55daa7ef6e40cf0f630a5b5e900989b` |

#### Setup raylib with multiple IDEs

raylib has been developed on Windows platform using [Notepad++](https://notepad-plus-plus.org/) and [MinGW GCC](https://www.mingw-w64.org/) compiler but it can be used with other IDEs on multiple platforms.

[Projects directory](https://github.com/raysan5/raylib/tree/master/projects) contains several ready-to-use **project templates** to build raylib and code examples with multiple IDEs.

*Note that there are lots of IDEs supported, some of the provided templates could require some review, so please, if you find some issue with a template or you think they could be improved, feel free to send a PR or open a related issue.*

learning and docs
------------------

raylib is designed to be learned using [the examples](https://github.com/raysan5/raylib/tree/master/examples) as the main reference. There is no standard API documentation but there is a [**cheatsheet**](https://www.raylib.com/cheatsheet/cheatsheet.html) containing all the functions available on the library a short description of each one of them, input parameters and result value names should be intuitive enough to understand how each function works.

Some additional documentation about raylib design can be found in [raylib GitHub Wiki](https://github.com/raysan5/raylib/wiki). Here are the relevant links:

 - [raylib cheatsheet](https://www.raylib.com/cheatsheet/cheatsheet.html)
 - [raylib architecture](https://github.com/raysan5/raylib/wiki/raylib-architecture)
 - [raylib library design](https://github.com/raysan5/raylib/wiki)
 - [raylib examples collection](https://github.com/raysan5/raylib/tree/master/examples)
 - [raylib games collection](https://github.com/raysan5/raylib-games)


contact and networks
---------------------

raylib is present in several networks and raylib community is growing everyday. If you are using raylib and enjoying it, feel free to join us in any of these networks. The most active network is our [Discord server](https://discord.gg/raylib)! :)

 - Webpage: [https://www.raylib.com](https://www.raylib.com)
 - Discord: [https://discord.gg/raylib](https://discord.gg/raylib)
 - X: [https://x.com/raysan5](https://x.com/raysan5)
 - BlueSky: [https://bsky.app/profile/raysan5](https://bsky.app/profile/raysan5.bsky.social)
 - Twitch:  [https://www.twitch.tv/raysan5](https://www.twitch.tv/raysan5)
 - Reddit:  [https://www.reddit.com/r/raylib](https://www.reddit.com/r/raylib)
 - Patreon: [https://www.patreon.com/raylib](https://www.patreon.com/raylib)
 - YouTube: [https://www.youtube.com/channel/raylib](https://www.youtube.com/c/raylib)

contributors
------------

<a href="https://github.com/raysan5/raylib/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=raysan5/raylib&max=800&columns=24&anon=0" />
</a>

license
-------

raylib is licensed under an unmodified zlib/libpng license, which is an OSI-certified, BSD-like license that allows static linking with closed source software. Check [LICENSE](LICENSE) for further details.

raylib uses internally some libraries for window/graphics/inputs management and also to support different file formats loading, all those libraries are embedded with and are available in [src/external](https://github.com/raysan5/raylib/tree/master/src/external) directory. Check [raylib dependencies LICENSES](https://github.com/raysan5/raylib/wiki/raylib-dependencies) on [raylib Wiki](https://github.com/raysan5/raylib/wiki) for details.
