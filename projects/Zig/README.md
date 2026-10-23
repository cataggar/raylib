# Starting your raylib project with Zig (0.17.0)

## How to compile and run it

To compile the project:

```sh
zig build
```

To run the project:

```sh
zig build run
```

## Compile with different optimization

To change from debug to release build you can do it with the `-Doptimize=` flag.

```
Debug
ReleaseSafe
ReleaseFast
ReleaseSmall
```

## Choose a different platform

To compile with a different platform you can use the `-Dplatform=` flag.
Here all the options:

```
glfw
rgfw
sdl
sdl2
sdl3
memory
win32
drm
android
```

In this example the platform `sdl` and `sdl2` are not supported

Important for the android platform you also have to compile for the right target

### Android NativeActivity

The C project builds a PIC NativeActivity shared library using the selected
NDK's real native-app-glue source and retains `ANativeActivity_onCreate`.
For example:

```sh
zig build -Dplatform=android -Dtarget=aarch64-linux-android
```

Supply `ANDROID_NDK_HOME` or `-Dandroid_ndk`; `-Dandroid_api_version` defaults
to `35`. The output is
`android/arm64-v8a/project/libcore_basic_window.so`. On Android, `zig build
run` builds and installs this library only; it does not execute a shared
library on the host or perform device actions.

Final links require true `fopen` wrapping, which the current Zig driver does
not expose. The link requests rejection of undefined symbols, but the current
native linker can still emit unresolved `__real_fopen`; a successful command
is not proof that the library is loadable.
With `-Dzig`, a thin typed C-ABI `main` adapter calls the unchanged Zig
program's `main`. Raylib's real `android_main` sets up the activity state
before invoking the adapter; the original program then initializes its
window and runs its normal drawing loop. Desktop and Web builds continue
to use the original Zig entrypoint directly.
No APK assembly, signing, installation, or launch is performed.

`zig build test` checks the Android, desktop, and Web entrypoint module
wiring headlessly; it does not execute the application or require a GPU.

## Compile for a different target

To compile for a different [target](https://ziglang.org/download/0.17.0/release-notes.html#Support-Table) you can use the `-Dtarget=` flag.
Not all targets are supported

## Example: Compile for web and run it

To compile for the web we use emscripten and you run it like that:

```sh
zig build -Dtarget=wasm32-emscripten
```

To run it we do:

```sh
zig build run -Dtarget=wasm32-emscripten
```

And to make a relase build we do:

```sh
zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseFast
```

If we want to use rgfw for the web build we could do:

```sh
zig build -Dplatform=rgfw -Dtarget=wasm32-emscripten -Doptimize=ReleaseFast
```

## Compiling the Zig code? Just add `-Dzig` and try out zig ;)

## More Resources

See [Zig Build System](https://ziglang.org/learn/build-system/)
