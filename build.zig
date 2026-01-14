const std = @import("std");
const builtin = @import("builtin");
const emcc = @import("src/emcc.zig");
const xlib = @import("src/xlib.zig").ENABLED;

const wasm_target: std.Target.Query = .{ .cpu_arch = .wasm32, .os_tag = .emscripten };

pub fn build_target(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !void {
    const imglib = b.dependency("imglib", .{});
    const termlib = b.dependency("terminal", .{});
    const commonlib = b.dependency("common", .{});

    const engine_module = b.addModule("engine", .{
        .root_source_file = b.path("src/engine.zig"),
        .target = target,
        .optimize = optimize,
    });

    const event_module = b.addModule("event_manager", .{
        .root_source_file = b.path("src/event_manager.zig"),
    });
    const graphics_module = b.addModule("graphics", .{
        .root_source_file = b.path("src/graphics.zig"),
    });

    const texture_module = b.addModule("texture", .{
        .root_source_file = b.path("src/texture.zig"),
    });

    const sprite_module = b.addModule("sprite", .{
        .root_source_file = b.path("src/sprite.zig"),
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "libzigxel",
        .root_module = engine_module,
    });

    const wasm_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "wasmzigxel",
        .root_module = engine_module,
    });
    engine_module.addImport("image", imglib.module("image"));
    engine_module.addImport("term", termlib.module("term"));
    engine_module.addImport("common", commonlib.module("common"));
    //INTERNAL MODULES
    engine_module.addImport("event_manager", event_module);
    engine_module.addImport("graphics", graphics_module);
    engine_module.addImport("texture", texture_module);
    engine_module.addImport("sprite", sprite_module);
    if (builtin.target.os.tag == .linux and target.result.os.tag != .emscripten and xlib) {
        lib.linkLibC();
        lib.addIncludePath(b.path("../../../linuxbrew/.linuxbrew/include"));
        lib.linkSystemLibrary("X11");
    }
    if (target.result.os.tag == .emscripten) {
        const wasm_mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        wasm_mod.addImport("image", imglib.module("image"));
        wasm_mod.addImport("term", termlib.module("term"));
        wasm_mod.addImport("common", commonlib.module("common"));
        wasm_mod.addImport("engine", engine_module);
        //TODO figure out multiple preloaded files
        _ = try emcc.Build(b, wasm_lib, wasm_mod, target, optimize, b.path("src/main.zig"), null, "src/shell.html", &[_][]const u8{ "assets/profile.jpg", "assets/envy.ttf" });
        //lib.step.dependOn(wasmStep);
        b.installArtifact(wasm_lib);
    } else {
        const exe = b.addExecutable(.{
            .name = "zigxel",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        b.installArtifact(lib);
        //DEPS
        exe.root_module.addImport("image", imglib.module("image"));
        exe.root_module.addImport("term", termlib.module("term"));
        exe.root_module.addImport("common", commonlib.module("common"));
        //INTERNAL MODULES
        exe.root_module.addImport("event_manager", event_module);
        exe.root_module.addImport("engine", engine_module);
        exe.root_module.addImport("graphics", graphics_module);
        exe.root_module.addImport("texture", texture_module);
        exe.root_module.addImport("sprite", sprite_module);
        //TODO make this configurable, linux builds could then provide their own include
        if (builtin.target.os.tag == .linux and target.result.os.tag != .emscripten) {
            exe.addIncludePath(b.path("../../../linuxbrew/.linuxbrew/include"));
        }
        //exe.linkLibrary(lib);
        // This declares intent for the executable to be installed into the
        // standard location when the user invokes the "install" step (the default
        // step when running `zig build`).
        b.installArtifact(exe);

        // This *creates* a Run step in the build graph, to be executed when another
        // step is evaluated that depends on it. The next line below will establish
        // such a dependency.
        const run_cmd = b.addRunArtifact(exe);

        // By making the run step depend on the install step, it will be run from the
        // installation directory rather than directly from within the cache directory.
        // This is not necessary, however, if the application depends on other installed
        // files, this ensures they will be present and in the expected location.
        run_cmd.step.dependOn(b.getInstallStep());

        // This allows the user to pass arguments to the application in the build
        // command itself, like this: `zig build run -- arg1 arg2 etc`
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        // This creates a build step. It will be visible in the `zig build --help` menu,
        // and can be selected like this: `zig build run`
        // This will evaluate the `run` step rather than the default, which is "install".
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);

        const exe_unit_tests = b.addTest(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
        exe_unit_tests.linkLibC();
        const texture_unit_tests = b.addTest(.{
            .root_source_file = b.path("src/texture.zig"),
            .target = target,
            .optimize = optimize,
        });
        texture_unit_tests.root_module.addImport("image", imglib.module("image"));
        texture_unit_tests.linkLibC();
        const run_texture_unit_tests = b.addRunArtifact(texture_unit_tests);

        const engine_unit_tests = b.addTest(.{
            .root_source_file = b.path("src/engine.zig"),
            .target = target,
            .optimize = optimize,
        });
        engine_unit_tests.root_module.addImport("image", imglib.module("image"));
        engine_unit_tests.root_module.addImport("term", termlib.module("term"));
        engine_unit_tests.linkLibC();
        const run_engine_unit_tests = b.addRunArtifact(engine_unit_tests);
        // Similar to creating the run step earlier, this exposes a `test` step to
        // the `zig build --help` menu, providing a way for the user to request
        // running the unit tests.
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_exe_unit_tests.step);
        test_step.dependOn(&run_texture_unit_tests.step);
        test_step.dependOn(&run_engine_unit_tests.step);
    }
}

pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    try build_target(b, b.resolveTargetQuery(wasm_target), .ReleaseSmall);
    //TODO droping linux build for now windows and web are hte primary targets
    if ((target.result.os.tag == .linux and !xlib)) try build_target(b, target, optimize);
}
