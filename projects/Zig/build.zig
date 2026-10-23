const std = @import("std");
const rl = @import("raylib");

pub fn zigProgramModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    native_activity: bool,
    raylib_module: *std.Build.Module,
) *std.Build.Module {
    const program = b.createModule(.{
        .root_source_file = b.path("src/core_basic_window.zig"),
        .target = target,
        .optimize = optimize,
    });
    program.addImport("raylib", raylib_module);
    if (!native_activity) return program;
    return b.createModule(.{
        .root_source_file = b.path("src/android_main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "program", .module = program }},
    });
}

test "Android adapter imports the original app while desktop and Web retain their entrypoint" {
    // These nodes inspect module wiring only; no application or modeled provider is executed.
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
    for ([_]std.Target.Query{
        .{},
        .{ .cpu_arch = .wasm32, .os_tag = .emscripten },
        .{ .cpu_arch = .x86, .os_tag = .linux, .abi = .android },
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .android },
        .{ .cpu_arch = .arm, .os_tag = .linux, .abi = .androideabi },
        .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .android },
    }) |query| {
        const target: std.Build.ResolvedTarget = .{
            .query = query,
            .result = try std.zig.system.resolveTargetQuery(std.testing.io, query),
        };
        const raylib_module = b.createModule(.{ .target = target, .optimize = .Debug });
        const native_activity = target.result.abi.isAndroid();
        const module = zigProgramModule(b, target, .Debug, native_activity, raylib_module);
        const program = if (native_activity) module.import_table.get("program").? else module;
        try std.testing.expectEqualStrings("src/core_basic_window.zig", program.root_source_file.?.src_path.sub_path);
        try std.testing.expect(program.import_table.get("raylib").? == raylib_module);
        if (native_activity) {
            try std.testing.expectEqualStrings("src/android_main.zig", module.root_source_file.?.src_path.sub_path);
        } else {
            try std.testing.expect(module.import_table.get("program") == null);
        }
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const platform = b.option(rl.PlatformBackend, "platform", "select the platform") orelse rl.PlatformBackend.glfw;
    const zig = b.option(bool, "zig", "compile zig code") orelse false;
    const android_ndk = b.option([]const u8, "android_ndk", "path to the Android NDK") orelse b.graph.environ_map.get("ANDROID_NDK_HOME") orelse "";
    const android_api_version = b.option([]const u8, "android_api_version", "Android API version") orelse "35";

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
        .platform = platform,
        .android_ndk = android_ndk,
        .android_api_version = android_api_version,
    });
    const raylib_artifact = raylib_dep.artifact("raylib");
    const entry_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("build.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    b.step("test", "Test platform entrypoint wiring").dependOn(&b.addRunArtifact(entry_tests).step);

    if (platform == .sdl3) {
        if (b.lazyDependency("sdl3", .{ .optimize = optimize, .target = target })) |dep| {
            raylib_artifact.root_module.linkLibrary(dep.artifact("SDL3"));
        }
    }

    var exe_mod: *std.Build.Module = undefined;

    if (zig) {
        exe_mod = zigProgramModule(b, target, optimize, platform == .android, raylib_dep.module("raylib"));
    } else {
        exe_mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        exe_mod.addCSourceFile(.{ .file = b.path("src/core_basic_window.c") });
        if (platform != .android) exe_mod.linkLibrary(raylib_artifact);
    }

    const run_step = b.step("run", if (platform == .android) "Build/install the NativeActivity library" else "Run the app");

    // web exports are completely separate
    if (target.query.os_tag == .emscripten) {
        const emsdk = rl.emsdk;
        const wasm = b.addLibrary(.{
            .name = "core_basic_window_web",
            .root_module = exe_mod,
        });

        const install_dir: std.Build.InstallDir = .{ .custom = "web" };
        const emcc_flags = emsdk.emccDefaultFlags(b.allocator, .{ .optimize = optimize });
        const emcc_settings = emsdk.emccDefaultSettings(b.allocator, .{ .optimize = optimize });

        const emcc_step = emsdk.emccStep(b, raylib_artifact, wasm, .{
            .optimize = optimize,
            .flags = emcc_flags,
            .settings = emcc_settings,
            .shell_file_path = emsdk.shell(raylib_dep),
            .install_dir = install_dir,
        });
        b.getInstallStep().dependOn(emcc_step);

        const html_filename = try std.fmt.allocPrint(b.allocator, "{s}.html", .{wasm.name});
        const emrun_step = emsdk.emrunStep(
            b,
            b.graph.path(.install_prefix, b.pathJoin(&.{ "web", html_filename })),
            &.{},
        );

        emrun_step.dependOn(emcc_step);
        run_step.dependOn(emrun_step);
    } else if (platform == .android) {
        const activity = rl.android.addNativeActivity(b, "core_basic_window", exe_mod, raylib_artifact, android_ndk);
        const install = rl.android.installNativeActivity(b, activity, "project");
        b.getInstallStep().dependOn(&install.step);
        run_step.dependOn(&install.step);
    } else {
        const exe = b.addExecutable(.{
            .name = "core_basic_window",
            .root_module = exe_mod,
            .use_lld = target.result.os.tag == .windows,
        });
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        run_step.dependOn(&run_cmd.step);
    }
}
