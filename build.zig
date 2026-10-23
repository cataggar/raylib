const std = @import("std");
const builtin = @import("builtin");
const Translator = @import("translate_c").Translator;

pub const android = struct {
    pub fn addNativeActivity(
        b: *std.Build,
        name: []const u8,
        module: *std.Build.Module,
        raylib: *std.Build.Step.Compile,
        ndk_path: []const u8,
    ) *std.Build.Step.Compile {
        if (!module.resolved_target.?.result.abi.isAndroid()) @panic("NativeActivity requires an Android target");
        if (ndk_path.len == 0) @panic("NativeActivity requires an Android NDK path");

        const glue_dir = b.pathJoin(&.{ ndk_path, "sources/android/native_app_glue" });
        module.pic = true;
        module.link_libc = true;
        module.addCMacro("PLATFORM_ANDROID", "");
        module.addSystemIncludePath(.{ .cwd_relative = glue_dir });
        module.addCSourceFile(.{
            .file = .{ .cwd_relative = b.pathJoin(&.{ glue_dir, "android_native_app_glue.c" }) },
            .flags = &.{"-std=c99"},
        });
        module.linkLibrary(raylib);
        module.linkSystemLibrary("android", .{});
        module.linkSystemLibrary("log", .{});
        for (raylib.root_module.lib_paths.items) |library_path| {
            module.addLibraryPath(library_path);
        }

        const activity = b.addLibrary(.{
            .name = name,
            .linkage = .dynamic,
            .root_module = module,
            .use_lld = false,
        });
        activity.setLibCFile(raylib.libc_file);
        activity.forceUndefinedSymbol("ANativeActivity_onCreate");
        activity.link_z_defs = true;
        activity.linker_allow_shlib_undefined = false;
        return activity;
    }

    pub fn installNativeActivity(
        b: *std.Build,
        activity: *std.Build.Step.Compile,
        group: []const u8,
    ) *std.Build.Step.InstallArtifact {
        const abi_dir = switch (activity.root_module.resolved_target.?.result.cpu.arch) {
            .x86 => "x86",
            .x86_64 => "x86_64",
            .arm => "armeabi-v7a",
            .aarch64 => "arm64-v8a",
            .riscv64 => "riscv64",
            else => @panic("unsupported Android ABI"),
        };
        return b.addInstallArtifact(activity, .{
            .dest_dir = .{ .override = .{ .custom = b.pathJoin(&.{ "android", abi_dir, group }) } },
            .dest_sub_path = activity.out_filename,
        });
    }
};

test "NativeActivity graph links real glue and retains the loader entry across Android ABIs" {
    // Inspect graph nodes only; the modeled SDK paths are never compiled or linked.
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const host: std.Build.ResolvedTarget = .{
        .query = .{},
        .result = try std.zig.system.resolveTargetQuery(std.testing.io, .{}),
    };
    var graph: std.Build.Graph = .{
        .io = std.testing.io,
        .arena = allocator,
        .zig_exe = "zig",
        .environ_map = .init(allocator),
        .host = host,
        .generated_files = .empty,
        .wip_configuration = .{ .gpa = allocator },
    };
    const b = try std.Build.create(&graph, .cwd(), &.{});
    for ([_]std.Target.Cpu.Arch{ .x86, .x86_64, .arm, .aarch64 }, [_][]const u8{
        "x86", "x86_64", "armeabi-v7a", "arm64-v8a",
    }) |arch, abi_dir| {
        const query: std.Target.Query = .{
            .cpu_arch = arch,
            .os_tag = .linux,
            .abi = if (arch == .arm) .androideabi else .android,
        };
        const target: std.Build.ResolvedTarget = .{
            .query = query,
            .result = try std.zig.system.resolveTargetQuery(std.testing.io, query),
        };
        for ([_]std.builtin.LinkMode{ .static, .dynamic }) |linkage| {
            const raylib = b.addLibrary(.{
                .name = "raylib",
                .linkage = linkage,
                .root_module = b.createModule(.{ .target = target, .optimize = .Debug }),
            });
            raylib.root_module.addLibraryPath(.{ .cwd_relative = "ndk/usr/lib/35" });
            raylib.setLibCFile(.{ .cwd_relative = "android-libc.txt" });
            const module = b.createModule(.{ .target = target, .optimize = .Debug });
            const activity = android.addNativeActivity(b, "native-test", module, raylib, "ndk");
            try std.testing.expectEqual(std.Build.Step.Compile.Kind.lib, activity.kind);
            try std.testing.expectEqual(std.builtin.LinkMode.dynamic, activity.linkage.?);
            try std.testing.expect(module.pic.?);
            try std.testing.expect(activity.link_z_defs);
            try std.testing.expect(!activity.linker_allow_shlib_undefined.?);
            try std.testing.expect(activity.force_undefined_symbols.contains("ANativeActivity_onCreate"));
            try std.testing.expectEqualStrings("android-libc.txt", activity.libc_file.?.cwd_relative);
            try std.testing.expectEqualStrings("ndk/usr/lib/35", module.lib_paths.items[0].cwd_relative);
            var found_glue = false;
            var found_android = false;
            var found_log = false;
            for (module.link_objects.items) |object| {
                if (object == .c_source_file) {
                    found_glue = std.mem.eql(u8, object.c_source_file.file.cwd_relative, "ndk/sources/android/native_app_glue/android_native_app_glue.c");
                } else if (object == .system_lib) {
                    found_android = found_android or std.mem.eql(u8, object.system_lib.name, "android");
                    found_log = found_log or std.mem.eql(u8, object.system_lib.name, "log");
                }
            }
            try std.testing.expect(found_glue);
            try std.testing.expect(found_android and found_log);
            const install = android.installNativeActivity(b, activity, "core");
            try std.testing.expectEqualStrings(b.pathJoin(&.{ "android", abi_dir, "core" }), install.dest_dir.?.custom);
            try std.testing.expectEqualStrings("libnative-test.so", install.dest_sub_path.?);
        }
    }
}

pub const emsdk = struct {
    const zemscripten = @import("zemscripten");

    pub fn shell(raylib_dep: *std.Build.Dependency) std.Build.LazyPath {
        return raylib_dep.path("src/shell.html");
    }

    pub const FlagsOptions = struct {
        optimize: std.builtin.OptimizeMode,
        asyncify: bool = true,
    };

    pub fn emccDefaultFlags(allocator: std.mem.Allocator, options: FlagsOptions) zemscripten.EmccFlags {
        var emcc_flags = zemscripten.emccDefaultFlags(allocator, .{
            .optimize = options.optimize,
            .fsanitize = true,
        });

        if (options.asyncify)
            emcc_flags.put("-sASYNCIFY", {}) catch unreachable;

        return emcc_flags;
    }

    pub const SettingsOptions = struct {
        optimize: std.builtin.OptimizeMode,
        es3: bool = false,
        glfw3: bool = true,
        memory_growth: bool = false,
        total_memory: u32 = 134217728,
        emsdk_allocator: zemscripten.EmsdkAllocator = .emmalloc,
    };

    pub fn emccDefaultSettings(allocator: std.mem.Allocator, options: SettingsOptions) zemscripten.EmccSettings {
        var emcc_settings = zemscripten.emccDefaultSettings(allocator, .{
            .optimize = options.optimize,
            .emsdk_allocator = options.emsdk_allocator,
        });

        if (options.es3) {
            emcc_settings.put("FULL_ES3", "1") catch unreachable;
            emcc_settings.put("MIN_WEBGL_VERSION", "2") catch unreachable;
            emcc_settings.put("MAX_WEBGL_VERSION", "2") catch unreachable;
        }
        if (options.glfw3) {
            emcc_settings.put("USE_GLFW", "3") catch unreachable;
        }

        const total_memory = std.fmt.allocPrint(allocator, "{d}", .{options.total_memory}) catch unreachable;

        emcc_settings.put("EXPORTED_RUNTIME_METHODS", "['requestFullscreen']") catch unreachable;
        emcc_settings.put("TOTAL_MEMORY", total_memory) catch unreachable;
        emcc_settings.put("FORCE_FILESYSTEM", "1") catch unreachable;
        emcc_settings.put("EXPORTED_RUNTIME_METHODS", "ccall") catch unreachable;

        if (options.memory_growth)
            emcc_settings.put("ALLOW_MEMORY_GROWTH", "1") catch unreachable;

        return emcc_settings;
    }

    pub fn emccStep(b: *std.Build, raylib: *std.Build.Step.Compile, wasm: *std.Build.Step.Compile, options: zemscripten.StepOptions) *std.Build.Step {
        const activate_emsdk_step = zemscripten.activateEmsdkStep(b);

        const emsdk_dep = b.dependency("emsdk", .{});
        raylib.root_module.addIncludePath(emsdk_dep.path("upstream/emscripten/cache/sysroot/include"));
        wasm.root_module.addIncludePath(emsdk_dep.path("upstream/emscripten/cache/sysroot/include"));

        const emcc_step = zemscripten.emccStep(b, wasm, options);
        emcc_step.dependOn(activate_emsdk_step);

        return emcc_step;
    }

    pub fn emrunStep(
        b: *std.Build,
        html_path: anytype,
        extra_args: []const []const u8,
    ) *std.Build.Step {
        return zemscripten.emrunStep(b, html_path, extra_args);
    }
};

pub fn linkWindows(mod: *std.Build.Module, opengl: bool, comptime shcore: bool) void {
    if (opengl) mod.linkSystemLibrary("opengl32", .{});
    mod.linkSystemLibrary("winmm", .{});
    mod.linkSystemLibrary("gdi32", .{});
    if (shcore) mod.linkSystemLibrary("shcore", .{});
}

fn findWaylandScanner(b: *std.Build) void {
    _ = b.findProgram(.{ .names = &.{"wayland-scanner"} }) orelse {
        std.log.err(
            \\ `wayland-scanner` may not be installed on the system.
            \\ You can switch to X11 in your `build.zig` by changing `Options.linux_display_backend`
        , .{});
        @panic("`wayland-scanner` not found");
    };
}

fn androidLibCContents(allocator: std.mem.Allocator, include_path: []const u8, arch_include_path: []const u8, api_lib_path: []const u8) ![]u8 {
    var writer: std.Io.Writer.Allocating = .init(allocator);
    defer writer.deinit();
    try (std.zig.LibCInstallation{
        .include_dir = include_path,
        .sys_include_dir = arch_include_path,
        .cc_dir = api_lib_path,
        .crt_dir = api_lib_path,
    }).render(&writer.writer);
    return writer.toOwnedSlice();
}

test "Android libc metadata preserves the selected ABI and API" {
    const filename = "raylib-libc-test.conf";
    defer std.Io.Dir.cwd().deleteFile(std.testing.io, filename) catch {};
    for ([_]std.Target.Cpu.Arch{ .x86, .x86_64, .arm, .aarch64 }, [_][]const u8{
        "i686-linux-android",
        "x86_64-linux-android",
        "arm-linux-androideabi",
        "aarch64-linux-android",
    }) |arch, triple| {
        const arch_include_path = try std.fs.path.join(std.testing.allocator, &.{ "ndk/usr/include", triple });
        defer std.testing.allocator.free(arch_include_path);
        const api_lib_path = try std.fs.path.join(std.testing.allocator, &.{ "ndk/usr/lib", triple, "35" });
        defer std.testing.allocator.free(api_lib_path);
        const contents = try androidLibCContents(std.testing.allocator, "ndk/usr/include", arch_include_path, api_lib_path);
        defer std.testing.allocator.free(contents);
        try std.Io.Dir.cwd().writeFile(std.testing.io, .{ .sub_path = filename, .data = contents });
        const target = try std.zig.system.resolveTargetQuery(std.testing.io, .{
            .cpu_arch = arch,
            .os_tag = .linux,
            .abi = if (arch == .arm) .androideabi else .android,
        });
        var installation = try std.zig.LibCInstallation.parse(std.testing.allocator, std.testing.io, filename, &target);
        defer installation.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("ndk/usr/include", installation.include_dir.?);
        try std.testing.expectEqualStrings(arch_include_path, installation.sys_include_dir.?);
        try std.testing.expectEqualStrings(api_lib_path, installation.crt_dir.?);
        try std.testing.expectEqualStrings(api_lib_path, installation.cc_dir.?);
    }
}

pub fn linkLinux(mod: *std.Build.Module, comptime display_backend: LinuxDisplayBackend) void {
    if (display_backend == .None) {
        mod.linkSystemLibrary("GL", .{});
    }

    if (display_backend == .X11) {
        mod.linkSystemLibrary("X11", .{});
        mod.linkSystemLibrary("Xrandr", .{});
        mod.linkSystemLibrary("Xinerama", .{});
        mod.linkSystemLibrary("Xi", .{});
        mod.linkSystemLibrary("Xcursor", .{});
    }

    if (display_backend == .Wayland) {
        mod.linkSystemLibrary("wayland-client", .{});
        mod.linkSystemLibrary("wayland-cursor", .{});
        mod.linkSystemLibrary("wayland-egl", .{});
        mod.linkSystemLibrary("xkbcommon", .{});
    }
}

pub fn linkBSD(_: *std.Build, mod: *std.Build.Module) void {
    mod.linkSystemLibrary("GL", .{});
}

pub fn linkMacOS(b: *std.Build, mod: *std.Build.Module) void {
    // Include xcode_frameworks for cross compilation
    if (b.lazyDependency("xcode_frameworks", .{})) |dep| {
        mod.addSystemFrameworkPath(dep.path("Frameworks"));
        mod.addSystemIncludePath(dep.path("include"));
        mod.addLibraryPath(dep.path("lib"));
    }

    mod.linkFramework("Foundation", .{});
    mod.linkFramework("CoreServices", .{});
    mod.linkFramework("CoreGraphics", .{});
    mod.linkFramework("AppKit", .{});
    mod.linkFramework("IOKit", .{});
}

fn compileRaylib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, options: Options) !*std.Build.Step.Compile {
    const raylib_mod = b.createModule(.{
        .optimize = optimize,
        .target = target,
        .link_libc = true,
    });

    const raylib = b.addLibrary(.{
        .name = "raylib",
        .linkage = options.linkage,
        .root_module = raylib_mod,
    });

    raylib_mod.addCMacro("_GNU_SOURCE", "");
    raylib_mod.addCMacro("GL_SILENCE_DEPRECATION", "199309L");

    var arena: std.heap.ArenaAllocator = .init(b.allocator);
    defer arena.deinit();

    var raylib_flags_arr: std.array_list.Managed([]const u8) = .init(arena.allocator());
    var c_source_files: std.array_list.Managed([]const u8) = .init(arena.allocator());

    try c_source_files.append("src/rcore.c");

    if (target.result.os.tag == .emscripten) {
        try raylib_flags_arr.append("-std=gnu99");
    } else {
        try raylib_flags_arr.append("-std=c99");
    }

    if (options.linkage == .dynamic) {
        raylib_mod.pic = true;
        raylib_mod.addCMacro("BUILD_LIBTYPE_SHARED", "");
    }

    if (options.config.len > 0) {
        // Splits a space-separated list of config flags into multiple flags
        //
        // Note: This means certain flags like `-x c++` won't be processed properly.
        // `-xc++` or similar should be used when possible
        var config_iter = std.mem.tokenizeScalar(u8, options.config, ' ');

        // Apply config flags supplied by the user
        while (config_iter.next()) |config_flag| {
            try raylib_flags_arr.append(config_flag);
        }
    }

    raylib_mod.addCMacro("SUPPORT_MODULE_RSHAPES", &.{@as(u8, @intFromBool(options.rshapes)) + 0x30});
    if (options.rshapes) {
        try c_source_files.append("src/rshapes.c");
    }
    raylib_mod.addCMacro("SUPPORT_MODULE_RTEXTURES", &.{@as(u8, @intFromBool(options.rtextures)) + 0x30});
    if (options.rtextures) {
        try c_source_files.append("src/rtextures.c");
    }
    raylib_mod.addCMacro("SUPPORT_MODULE_RTEXT", &.{@as(u8, @intFromBool(options.rtext)) + 0x30});
    if (options.rtext) {
        try c_source_files.append("src/rtext.c");
    }
    raylib_mod.addCMacro("SUPPORT_MODULE_RMODELS", &.{@as(u8, @intFromBool(options.rmodels)) + 0x30});
    if (options.rmodels) {
        try c_source_files.append("src/rmodels.c");
    }
    raylib_mod.addCMacro("SUPPORT_MODULE_RAUDIO", &.{@as(u8, @intFromBool(options.raudio)) + 0x30});
    if (options.raudio) {
        try c_source_files.append("src/raudio.c");
    }

    raylib_mod.addIncludePath(b.path("src/platforms"));
    switch (options.platform) {
        .glfw => {
            var opengl_version: OpenglVersion = options.opengl_version;
            if (opengl_version == .gl_soft) {
                @panic("The opengl version is not supported by this platform");
            }

            raylib_mod.addIncludePath(b.path("src/external/glfw/include"));

            if (target.result.os.tag != .emscripten) {
                if (opengl_version == .auto) {
                    opengl_version = OpenglVersion.gl_3_3;
                }
                raylib_mod.addCMacro("PLATFORM_DESKTOP_GLFW", "");
                try c_source_files.append("src/rglfw.c");
            }

            switch (target.result.os.tag) {
                .windows => linkWindows(raylib_mod, true, false),
                .linux => {
                    if (target.result.abi.isAndroid()) {
                        @panic("Target is not supported with this platform");
                    }

                    linkLinux(raylib_mod, .None);

                    if (options.linux_display_backend == .X11 or options.linux_display_backend == .Both) {
                        raylib_mod.addCMacro("_GLFW_X11", "");
                        linkLinux(raylib_mod, .X11);
                    }

                    if (options.linux_display_backend == .Wayland or options.linux_display_backend == .Both) {
                        findWaylandScanner(b);

                        raylib_mod.addCMacro("_GLFW_WAYLAND", "");
                        linkLinux(raylib_mod, .Wayland);
                        try waylandGenerate(b, raylib, "src/external/glfw/deps/wayland/", false);
                    }
                },
                .freebsd, .openbsd, .netbsd, .dragonfly => linkBSD(b, raylib_mod),
                .macos => {
                    // On macos rglfw.c include Objective-C files.
                    _ = c_source_files.pop();
                    try raylib_flags_arr.append("-ObjC");
                    raylib_mod.addCSourceFile(.{
                        .file = b.path("src/rglfw.c"),
                        .flags = raylib_flags_arr.items,
                    });
                    _ = raylib_flags_arr.pop();

                    linkMacOS(b, raylib_mod);
                },
                .emscripten => {
                    switch (opengl_version) {
                        .auto => opengl_version = OpenglVersion.gles_2,
                        .gles_2, .gles_3, .gl_soft => {},
                        else => @panic("opengl version not supported"),
                    }

                    raylib_mod.addCMacro("PLATFORM_WEB", "");

                    const activate_emsdk_step = emsdk.zemscripten.activateEmsdkStep(b);
                    raylib.step.dependOn(activate_emsdk_step);
                },
                else => @panic("Target is not supported with this platform"),
            }
            raylib_mod.addCMacro(opengl_version.toCMacroStr(), "");
        },
        .rgfw => {
            var opengl_version: OpenglVersion = options.opengl_version;

            if (target.result.os.tag != .emscripten) {
                if (opengl_version == .auto) {
                    opengl_version = OpenglVersion.gl_3_3;
                }
                raylib_mod.addCMacro("PLATFORM_DESKTOP_RGFW", "");
            }

            switch (target.result.os.tag) {
                .windows => linkWindows(raylib_mod, true, false),
                .linux => {
                    if (target.result.abi.isAndroid()) {
                        @panic("Target is not supported with this platform");
                    }

                    linkLinux(raylib_mod, .None);

                    if (options.linux_display_backend == .X11 or options.linux_display_backend == .Both) {
                        raylib_mod.addCMacro("RGFW_X11", "");
                        raylib_mod.addCMacro("RGFW_UNIX", "");

                        linkLinux(raylib_mod, .X11);
                    }

                    if (options.linux_display_backend == .Wayland or options.linux_display_backend == .Both) {
                        findWaylandScanner(b);

                        if (options.linux_display_backend != .Both) {
                            raylib_mod.addCMacro("RGFW_NO_X11", "");
                        }

                        raylib_mod.addCMacro("RGFW_WAYLAND", "");
                        raylib_mod.addCMacro("EGLAPIENTRY", "");

                        linkLinux(raylib_mod, .Wayland);

                        try waylandGenerate(b, raylib, "src/external/RGFW/deps/wayland/", true);
                    }
                },
                .freebsd, .openbsd, .netbsd, .dragonfly => linkBSD(b, raylib_mod),
                .macos => linkMacOS(b, raylib_mod),
                .emscripten => {
                    switch (opengl_version) {
                        .auto => opengl_version = OpenglVersion.gles_2,
                        .gles_2, .gles_3, .gl_soft => {},
                        else => @panic("opengl version not supported"),
                    }

                    raylib_mod.addCMacro("PLATFORM_WEB_RGFW", "");
                    const activate_emsdk_step = emsdk.zemscripten.activateEmsdkStep(b);
                    raylib.step.dependOn(activate_emsdk_step);
                },
                else => @panic("Target is not supported with this platform"),
            }

            raylib_mod.addCMacro(opengl_version.toCMacroStr(), "");
        },
        .sdl, .sdl2, .sdl3 => {
            if (options.opengl_version == .auto) {
                raylib_mod.addCMacro(OpenglVersion.gl_3_3.toCMacroStr(), "");
            } else {
                raylib_mod.addCMacro(options.opengl_version.toCMacroStr(), "");
            }

            raylib_mod.addCMacro("PLATFORM_DESKTOP_SDL", "");

            if (options.platform == .sdl2) {
                raylib_mod.addCMacro("USING_SDL2_PACKAGE", "");
            }
            if (options.platform == .sdl3) {
                raylib_mod.addCMacro("USING_SDL3_PACKAGE", "");
            }
        },
        .memory => {
            if (options.opengl_version != .auto and options.opengl_version != .gl_soft) {
                @panic("The opengl version is not supported by this platform");
            }
            raylib_mod.addCMacro(OpenglVersion.gl_soft.toCMacroStr(), "");
            raylib_mod.addCMacro("PLATFORM_MEMORY", "");
        },
        .win32 => {
            if (target.result.os.tag != .windows) {
                @panic("Target is not supported with this platform");
            }

            if (options.opengl_version == .auto) {
                raylib_mod.addCMacro(OpenglVersion.gl_3_3.toCMacroStr(), "");
            } else {
                raylib_mod.addCMacro(options.opengl_version.toCMacroStr(), "");
            }

            raylib_mod.addCMacro("PLATFORM_DESKTOP_WIN32", "");

            linkWindows(raylib_mod, options.opengl_version != .gl_soft, true);
        },
        .drm => {
            if (target.result.os.tag != .linux) {
                @panic("Target is not supported with this platform");
            }

            raylib_mod.addCMacro("PLATFORM_DRM", "");
            raylib_mod.addCMacro("EGL_NO_X11", "");
            raylib_mod.addCMacro("DEFAULT_BATCH_BUFFER_ELEMENT", "");

            try raylib_flags_arr.append("-Werror=implicit-function-declaration");

            raylib_mod.linkSystemLibrary("libdrm", .{ .use_pkg_config = .force });
            raylib_mod.linkSystemLibrary("drm", .{});
            raylib_mod.linkSystemLibrary("gbm", .{});

            switch (options.opengl_version) {
                .auto, .gles_2 => {
                    raylib_mod.addCMacro(OpenglVersion.gles_2.toCMacroStr(), "");
                    raylib_mod.linkSystemLibrary("GLESv2", .{});
                    raylib_mod.linkSystemLibrary("EGL", .{});
                },
                .gl_soft => {},
                else => @panic("The opengl version is not supported by this platform"),
            }
        },
        .android => {
            if (!target.result.abi.isAndroid()) {
                @panic("Target is not supported with this platform");
            }

            raylib_mod.addCMacro("PLATFORM_ANDROID", "");
            raylib_mod.pic = true;

            raylib_mod.linkSystemLibrary("android", .{});
            raylib_mod.linkSystemLibrary("log", .{});
            raylib_mod.linkSystemLibrary("EGL", .{});
            switch (options.opengl_version) {
                .auto, .gles_2 => {
                    raylib_mod.addCMacro(OpenglVersion.gles_2.toCMacroStr(), "");
                    raylib_mod.linkSystemLibrary("GLESv2", .{});
                },
                else => @panic("The opengl version is not supported by this platform"),
            }

            //these are the only tag options per https://developer.android.com/ndk/guides/other_build_systems
            const hostTuple = switch (builtin.target.os.tag) {
                .linux => "linux-x86_64",
                .windows => "windows-x86_64",
                .macos => "darwin-x86_64",
                else => @panic("unsupported host OS"),
            };

            const androidTriple = switch (target.result.cpu.arch) {
                .x86 => "i686-linux-android",
                .x86_64 => "x86_64-linux-android",
                .arm => "arm-linux-androideabi",
                .aarch64 => "aarch64-linux-android",
                .riscv64 => "riscv64-linux-android",
                else => error.InvalidAndroidTarget,
            } catch @panic("invalid android target!");
            const androidNdkPathString: []const u8 = options.android_ndk;
            if (androidNdkPathString.len < 1) @panic("no ndk path provided and ANDROID_NDK_HOME is not set");
            const androidApiLevel: []const u8 = options.android_api_version;

            const androidSysroot = try std.fs.path.join(b.allocator, &.{ androidNdkPathString, "/toolchains/llvm/prebuilt/", hostTuple, "/sysroot" });
            const androidLibPath = try std.fs.path.join(b.allocator, &.{ androidSysroot, "/usr/lib/", androidTriple });
            const androidApiSpecificPath = try std.fs.path.join(b.allocator, &.{ androidLibPath, androidApiLevel });
            const androidIncludePath = try std.fs.path.join(b.allocator, &.{ androidSysroot, "/usr/include" });
            const androidArchIncludePath = try std.fs.path.join(b.allocator, &.{ androidIncludePath, androidTriple });
            const androidAsmPath = try std.fs.path.join(b.allocator, &.{ androidIncludePath, "/asm-generic" });
            const androidGluePath = try std.fs.path.join(b.allocator, &.{ androidNdkPathString, "/sources/android/native_app_glue/" });

            raylib_mod.addLibraryPath(.{ .cwd_relative = androidLibPath });
            raylib_mod.addLibraryPath(.{ .cwd_relative = androidApiSpecificPath });
            raylib_mod.addSystemIncludePath(.{ .cwd_relative = androidIncludePath });
            raylib_mod.addSystemIncludePath(.{ .cwd_relative = androidArchIncludePath });
            raylib_mod.addSystemIncludePath(.{ .cwd_relative = androidAsmPath });
            raylib_mod.addSystemIncludePath(.{ .cwd_relative = androidGluePath });

            const libc_data = try androidLibCContents(b.allocator, androidIncludePath, androidArchIncludePath, androidApiSpecificPath);
            const write_step = b.addWriteFiles();
            const libcFile = write_step.add("android-libc.txt", libc_data);
            raylib.setLibCFile(libcFile);
        },
    }

    raylib_mod.addCSourceFiles(.{
        .files = c_source_files.items,
        .flags = raylib_flags_arr.items,
    });

    return raylib;
}

fn addRaygui(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, raylib: *std.Build.Step.Compile) void {
    if (b.lazyDependency("raygui", .{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    })) |raygui_dep| {
        var gen_step = b.addWriteFiles();
        raylib.step.dependOn(&gen_step.step);

        const raygui_c_path = gen_step.add("raygui.c", "#define RAYGUI_IMPLEMENTATION\n#include \"raygui.h\"\n");
        raylib.root_module.addCSourceFile(.{ .file = raygui_c_path });
        raylib.root_module.addIncludePath(raygui_dep.path("src"));
        raylib.root_module.addIncludePath(b.path("src"));

        raylib.installHeader(raygui_dep.path("src/raygui.h"), "raygui.h");

        const c: Translator = .init(b.dependency("translate_c", .{}), .{
            .c_source_file = raygui_dep.path("src/raygui.h"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .libc_file = raylib.libc_file,
        });
        c.addIncludePath(b.path("src"));
        const c_mod = c.mod;
        c_mod.linkLibrary(raylib);
        b.modules.put(b.graph.arena, "raygui", c_mod) catch @panic("OOM");
    }
}

pub const Options = struct {
    raudio: bool = true,
    rmodels: bool = true,
    rshapes: bool = true,
    rtext: bool = true,
    rtextures: bool = true,
    raygui: bool = false,
    platform: PlatformBackend = .glfw,
    linkage: std.builtin.LinkMode = .static,
    linux_display_backend: LinuxDisplayBackend = .X11,
    opengl_version: OpenglVersion = .auto,
    android_ndk: []const u8 = "",
    android_api_version: []const u8 = "35",
    /// config should be a list of space-separated cflags, eg, "-DSUPPORT_CUSTOM_FRAME_CONTROL"
    config: []const u8 = &.{},

    const defaults = Options{};

    pub fn getOptions(b: *std.Build) Options {
        return .{
            .platform = b.option(PlatformBackend, "platform", "Choose the platform backend for desktop target") orelse defaults.platform,
            .raudio = b.option(bool, "raudio", "Compile with audio support") orelse defaults.raudio,
            .rmodels = b.option(bool, "rmodels", "Compile with models support") orelse defaults.rmodels,
            .rtext = b.option(bool, "rtext", "Compile with text support") orelse defaults.rtext,
            .rtextures = b.option(bool, "rtextures", "Compile with textures support") orelse defaults.rtextures,
            .rshapes = b.option(bool, "rshapes", "Compile with shapes support") orelse defaults.rshapes,
            .raygui = b.option(bool, "raygui", "Include raygui") orelse defaults.raygui,
            .linkage = b.option(std.builtin.LinkMode, "linkage", "Compile as shared or static library") orelse defaults.linkage,
            .linux_display_backend = b.option(LinuxDisplayBackend, "linux_display_backend", "Linux display backend to use") orelse defaults.linux_display_backend,
            .opengl_version = b.option(OpenglVersion, "opengl_version", "OpenGL version to use") orelse defaults.opengl_version,
            .config = b.option([]const u8, "config", "Compile with custom define macros overriding config.h") orelse &.{},
            .android_ndk = b.option([]const u8, "android_ndk", "specify path to android ndk") orelse b.graph.environ_map.get("ANDROID_NDK_HOME") orelse "",
            .android_api_version = b.option([]const u8, "android_api_version", "specify target android API level") orelse defaults.android_api_version,
        };
    }
};

pub const OpenglVersion = enum {
    auto,
    gl_soft,
    gl_1_1,
    gl_2_1,
    gl_3_3,
    gl_4_3,
    gles_2,
    gles_3,

    pub fn toCMacroStr(self: @This()) []const u8 {
        switch (self) {
            .auto => @panic("OpenglVersion.auto cannot be turned into a C macro string"),
            .gl_soft => return "GRAPHICS_API_OPENGL_SOFTWARE",
            .gl_1_1 => return "GRAPHICS_API_OPENGL_11",
            .gl_2_1 => return "GRAPHICS_API_OPENGL_21",
            .gl_3_3 => return "GRAPHICS_API_OPENGL_33",
            .gl_4_3 => return "GRAPHICS_API_OPENGL_43",
            .gles_2 => return "GRAPHICS_API_OPENGL_ES2",
            .gles_3 => return "GRAPHICS_API_OPENGL_ES3",
        }
    }
};

pub const LinuxDisplayBackend = enum {
    None,
    X11,
    Wayland,
    Both,
};

pub const PlatformBackend = enum {
    glfw,
    rgfw,
    sdl,
    sdl2,
    sdl3,
    memory,
    win32,
    drm,
    android,
};

fn translateCMod(
    comptime header: []const u8,
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    raylib: *std.Build.Step.Compile,
) void {
    const source = if (comptime std.mem.eql(u8, header, "rcamera"))
        b.addWriteFiles().add("rcamera-wrapper.h", "#include \"raylib.h\"\n#include \"rcamera.h\"\n")
    else
        b.path("src/" ++ header ++ ".h");
    const c: Translator = .init(b.dependency("translate_c", .{}), .{
        .name = header,
        .c_source_file = source,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .libc_file = raylib.libc_file,
    });
    c.addIncludePath(b.path("src"));
    const c_mod = c.mod;
    c_mod.linkLibrary(raylib);
    b.modules.put(b.graph.arena, header, c_mod) catch @panic("OOM");
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const options: Options = .getOptions(b);

    const lib = try compileRaylib(b, target, optimize, options);

    lib.installHeader(b.path("src/raylib.h"), "raylib.h");
    lib.installHeader(b.path("src/rcamera.h"), "rcamera.h");
    lib.installHeader(b.path("src/raymath.h"), "raymath.h");
    lib.installHeader(b.path("src/rlgl.h"), "rlgl.h");

    b.installArtifact(lib);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("build.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    const run_tests = b.addRunArtifact(tests);
    run_tests.cwd = tests.getEmittedBin().dirname();
    b.step("test", "Test Zig build helpers").dependOn(&run_tests.step);

    translateCMod("raylib", b, target, optimize, lib);
    translateCMod("rcamera", b, target, optimize, lib);
    translateCMod("raymath", b, target, optimize, lib);
    translateCMod("rlgl", b, target, optimize, lib);

    if (options.raygui) {
        addRaygui(b, target, optimize, lib);
    }

    const module_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/headers.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib", .module = b.modules.get("raylib").? },
                .{ .name = "rcamera", .module = b.modules.get("rcamera").? },
                .{ .name = "raymath", .module = b.modules.get("raymath").? },
            },
        }),
    });
    if (target.result.abi.isAndroid()) {
        for (lib.root_module.lib_paths.items) |library_path| {
            module_tests.root_module.addLibraryPath(library_path);
        }
        module_tests.setLibCFile(lib.libc_file);
    }
    const test_modules = b.step("test-modules", "Test the translated camera and math modules");
    if (target.result.cpu.arch == b.graph.host.result.cpu.arch and
        target.result.os.tag == b.graph.host.result.os.tag and
        target.result.abi == b.graph.host.result.abi)
    {
        test_modules.dependOn(&b.addRunArtifact(module_tests).step);
    } else {
        test_modules.dependOn(&module_tests.step);
    }

    const examples = b.step("examples", "build/install all examples");
    examples.dependOn(try addExamples("core", b, target, optimize, lib, options));
    examples.dependOn(try addExamples("audio", b, target, optimize, lib, options));
    examples.dependOn(try addExamples("models", b, target, optimize, lib, options));
    examples.dependOn(try addExamples("shaders", b, target, optimize, lib, options));
    examples.dependOn(try addExamples("shapes", b, target, optimize, lib, options));
    examples.dependOn(try addExamples("text", b, target, optimize, lib, options));
    examples.dependOn(try addExamples("textures", b, target, optimize, lib, options));
    examples.dependOn(try addExamples("others", b, target, optimize, lib, options));
}

fn addExamples(
    comptime module: []const u8,
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    raylib: *std.Build.Step.Compile,
    options: Options,
) !*std.Build.Step {
    const platform = options.platform;
    const all = b.step(module, "All " ++ module ++ " examples");
    const module_subpath = b.pathJoin(&.{ "examples", module });

    b.dependOnDirectoryContents(b.path(module_subpath));
    var dir = try b.root.openDir(b.graph.io, module_subpath, .{ .iterate = true });
    defer dir.close(b.graph.io);

    var iter = dir.iterate();
    while (try iter.next(b.graph.io)) |entry| {
        if (entry.kind != .file) continue;

        const filetype = std.fs.path.extension(entry.name);
        if (!std.mem.eql(u8, filetype, ".c")) continue;

        const filename = std.fs.path.stem(entry.name);
        const path = b.pathJoin(&.{ module_subpath, entry.name });

        const exe_mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        exe_mod.addCSourceFile(.{ .file = b.path(path) });
        if (platform != .android) exe_mod.linkLibrary(raylib);
        if (target.result.abi.isAndroid() and platform != .android) {
            for (raylib.root_module.lib_paths.items) |library_path| {
                exe_mod.addLibraryPath(library_path);
            }
        }

        if (platform == .sdl) {
            exe_mod.linkSystemLibrary("SDL2", .{});
            exe_mod.linkSystemLibrary("SDL3", .{});
        }
        if (platform == .sdl2) {
            exe_mod.linkSystemLibrary("SDL2", .{});
        }
        if (platform == .sdl3) {
            exe_mod.linkSystemLibrary("SDL3", .{});
        }

        if (std.mem.eql(u8, filename, "rlgl_standalone")) {
            if (platform != .glfw) continue;
            exe_mod.addIncludePath(b.path("src"));
            exe_mod.addIncludePath(b.path("src/external/glfw/include"));
        }
        if (std.mem.eql(u8, filename, "raylib_opengl_interop")) {
            if (platform == .drm) continue;
            if (target.result.os.tag == .macos) continue;
            exe_mod.addIncludePath(b.path("src/external"));
        }

        const run_step = b.step(filename, filename);

        // web exports are completely separate
        if (target.query.os_tag == .emscripten) {
            exe_mod.addCMacro("PLATFORM_WEB", "");

            const wasm = b.addLibrary(.{
                .name = filename,
                .root_module = exe_mod,
            });

            const install_dir: std.Build.InstallDir = .{ .custom = b.fmt("web/{s}/{s}", .{ module, filename }) };
            const emcc_flags = emsdk.emccDefaultFlags(b.allocator, .{ .optimize = optimize });
            const emcc_settings = emsdk.emccDefaultSettings(b.allocator, .{ .optimize = optimize });

            const emcc_step = emsdk.emccStep(b, raylib, wasm, .{
                .optimize = optimize,
                .flags = emcc_flags,
                .settings = emcc_settings,
                .shell_file_path = b.path("src/shell.html"),
                .install_dir = install_dir,
            });
            b.getInstallStep().dependOn(emcc_step);

            const html_filename = try std.fmt.allocPrint(b.allocator, "{s}.html", .{wasm.name});
            const emrun_step = emsdk.emrunStep(
                b,
                b.graph.path(.install_prefix, b.pathJoin(&.{ install_dir.custom, html_filename })),
                &.{},
            );

            emrun_step.dependOn(emcc_step);
            run_step.dependOn(emrun_step);
            all.dependOn(emcc_step);
        } else if (platform == .android) {
            const activity = android.addNativeActivity(b, filename, exe_mod, raylib, options.android_ndk);
            const install = android.installNativeActivity(b, activity, module);
            b.getInstallStep().dependOn(&install.step);
            run_step.dependOn(&install.step);
            all.dependOn(&install.step);
        } else {
            exe_mod.addCMacro("PLATFORM_DESKTOP", "");

            const exe = b.addExecutable(.{
                .name = filename,
                .root_module = exe_mod,
                .use_lld = target.result.os.tag == .windows,
            });
            if (target.result.abi.isAndroid()) {
                exe.setLibCFile(raylib.libc_file);
            }
            b.installArtifact(exe);

            const install_cmd = b.addInstallArtifact(exe, .{ .dest_sub_path = b.fmt("{s}/{s}", .{ module, filename }) });

            const run_cmd = b.addRunArtifact(exe);
            run_cmd.cwd = b.path(module_subpath);
            run_cmd.step.dependOn(&install_cmd.step);

            run_step.dependOn(&run_cmd.step);
            all.dependOn(&install_cmd.step);
        }
    }
    return all;
}

fn waylandGenerate(
    b: *std.Build,
    raylib: *std.Build.Step.Compile,
    comptime waylandDir: []const u8,
    comptime source: bool,
) !void {
    b.dependOnDirectoryContents(b.path(waylandDir));
    const dir = try b.root.openDir(b.graph.io, waylandDir, .{ .iterate = true });
    defer dir.close(b.graph.io);

    var iter = dir.iterate();
    while (try iter.next(b.graph.io)) |entry| {
        if (entry.kind != .file) continue;
        const protocolDir = b.pathJoin(&.{ waylandDir, entry.name });

        const filename = std.fs.path.stem(entry.name);

        const clientHeader = b.fmt("{s}-client-protocol.h", .{filename});
        const client_step = b.addSystemCommand(&.{ "wayland-scanner", "client-header" });
        client_step.addFileArg(b.path(protocolDir));
        raylib.root_module.addIncludePath(client_step.addOutputFileArg(clientHeader).dirname());
        raylib.step.dependOn(&client_step.step);

        if (comptime source) {
            const privateCode = b.fmt("{s}-client-protocol-code.c", .{filename});
            const private_step = b.addSystemCommand(&.{ "wayland-scanner", "private-code" });
            private_step.addFileArg(b.path(protocolDir));
            raylib.root_module.addCSourceFile(.{
                .file = private_step.addOutputFileArg(privateCode),
                .flags = &.{ "-std=c99", "-O2" },
            });
            raylib.step.dependOn(&private_step.step);
        } else {
            const privateCodeHeader = b.fmt("{s}-client-protocol-code.h", .{filename});
            const private_head_step = b.addSystemCommand(&.{ "wayland-scanner", "private-code" });
            private_head_step.addFileArg(b.path(protocolDir));
            raylib.root_module.addIncludePath(private_head_step.addOutputFileArg(privateCodeHeader).dirname());
            raylib.step.dependOn(&private_head_step.step);
        }
    }
}
