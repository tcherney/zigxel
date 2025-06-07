const std = @import("std");
const builtin = @import("builtin");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // const lib = b.addStaticLibrary(.{
    //     .name = "engine",
    //     // In this case the main source file is merely a path, however, in more
    //     // complicated build scripts, this could be a generated file.
    //     .root_source_file = b.path("src/engine.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });

    // // This declares intent for the library to be installed into the standard
    // // location when the user invokes the "install" step (the default step when
    // // running `zig build`).
    // b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "zigxel",
        .root_module = b.createModule(.{ // this line was added
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }), // this line was added
    });

    const imglib = b.dependency("imglib", .{});
    exe.root_module.addImport("image", imglib.module("image"));

    const termlib = b.dependency("terminal", .{});
    exe.root_module.addImport("term", termlib.module("term"));

    const commonlib = b.dependency("common", .{});
    exe.root_module.addImport("common", commonlib.module("common"));

    const engine_module = b.addModule("engine", .{
        .root_source_file = b.path("src/engine.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("engine", engine_module);

    const event_module = b.addModule("event_manager", .{
        .root_source_file = b.path("src/event_manager.zig"),
    });
    exe.root_module.addImport("event_manager", event_module);

    const graphics_module = b.addModule("graphics", .{
        .root_source_file = b.path("src/graphics.zig"),
    });
    exe.root_module.addImport("graphics", graphics_module);

    const texture_module = b.addModule("texture", .{
        .root_source_file = b.path("src/texture.zig"),
    });
    exe.root_module.addImport("texture", texture_module);

    const sprite_module = b.addModule("sprite", .{
        .root_source_file = b.path("src/sprite.zig"),
    });
    exe.root_module.addImport("sprite", sprite_module);

    exe.linkLibC();
    //TODO need to change how we build the zigxel library so we actually link to it instead of rebuilding in other projects
    if (builtin.target.os.tag == .linux) {
        exe.addIncludePath(b.path("../../../linuxbrew/.linuxbrew/include"));
        exe.linkSystemLibrary("X11");
    }

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
