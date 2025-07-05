const std = @import("std");
const builtin = @import("builtin");
const emcc = @import("src/emcc.zig");

fn createEmsdkStep(b: *std.Build, emsdk: *std.Build.Dependency) *std.Build.Step.Run {
    if (builtin.os.tag == .windows) {
        return b.addSystemCommand(&.{emsdk.path("emsdk.bat").getPath(b)});
    } else {
        return b.addSystemCommand(&.{emsdk.path("emsdk").getPath(b)});
    }
}

fn emSdkSetupStep(b: *std.Build, emsdk: *std.Build.Dependency) !?*std.Build.Step.Run {
    const dot_emsc_path = emsdk.path(".emscripten").getPath(b);
    std.debug.print("path {s}\n", .{dot_emsc_path});
    const dot_emsc_exists = !std.meta.isError(std.fs.accessAbsolute(dot_emsc_path, .{}));

    if (!dot_emsc_exists) {
        std.debug.print("path exists\n", .{});
        const emsdk_install = createEmsdkStep(b, emsdk);
        emsdk_install.addArgs(&.{ "install", "latest" });
        const emsdk_activate = createEmsdkStep(b, emsdk);
        emsdk_activate.addArgs(&.{ "activate", "latest" });
        emsdk_activate.step.dependOn(&emsdk_install.step);
        return emsdk_activate;
    } else {
        return null;
    }
}

fn emscriptenRunStep(b: *std.Build, emsdk: *std.Build.Dependency, examplePath: []const u8) !*std.Build.Step.Run {
    const dot_emsc_path = emsdk.path("upstream/emscripten/cache/sysroot/include").getPath(b);
    // If compiling on windows , use emrun.bat.
    const emrunExe = switch (builtin.os.tag) {
        .windows => "emrun.bat",
        else => "emrun",
    };
    var emrun_run_arg = try b.allocator.alloc(u8, dot_emsc_path.len + emrunExe.len + 1);
    defer b.allocator.free(emrun_run_arg);

    if (b.sysroot == null) {
        emrun_run_arg = try std.fmt.bufPrint(emrun_run_arg, "{s}", .{emrunExe});
    } else {
        emrun_run_arg = try std.fmt.bufPrint(emrun_run_arg, "{s}" ++ std.fs.path.sep_str ++ "{s}", .{ dot_emsc_path, emrunExe });
    }
    const run_cmd = b.addSystemCommand(&.{ emrun_run_arg, examplePath });
    return run_cmd;
}

const emccOutputDir = "zig-out" ++ std.fs.path.sep_str ++ "htmlout" ++ std.fs.path.sep_str;
const emccOutputFile = "index.html";

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

    const imglib = b.dependency("imglib", .{});
    const termlib = b.dependency("terminal", .{});
    const commonlib = b.dependency("common", .{});
    const emcclib = b.dependency("zig_wasm", .{});

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
    engine_module.addImport("emcc", emcclib.module("emcc"));
    engine_module.addImport("image", imglib.module("image"));
    engine_module.addImport("term", termlib.module("term"));
    engine_module.addImport("common", commonlib.module("common"));
    //INTERNAL MODULES
    engine_module.addImport("event_manager", event_module);
    engine_module.addImport("graphics", graphics_module);
    engine_module.addImport("texture", texture_module);
    engine_module.addImport("sprite", sprite_module);
    if (builtin.target.os.tag == .linux) {
        lib.linkLibC();
        lib.addIncludePath(b.path("../../../linuxbrew/.linuxbrew/include"));
        lib.linkSystemLibrary("X11");
    }
    lib.linkLibrary(emcclib.artifact("zig-wasm"));

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

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

        _ = try emcc.Build(b, lib, wasm_mod, target, optimize, b.path("src/main.zig"), null, "src/shell.html", null);
        // //TODO https://github.com/raysan5/raylib/blob/master/build.zig
        // const wasm_mod = b.createModule(.{
        //     // `root_source_file` is the Zig "entry point" of the module. If a module
        //     // only contains e.g. external object files, you can make this `null`.
        //     // In this case the main source file is merely a path, however, in more
        //     // complicated build scripts, this could be a generated file.
        //     .root_source_file = b.path("src/main.zig"),
        //     .target = target,
        //     .optimize = optimize,
        // });
        // wasm_mod.addImport("image", imglib.module("image"));
        // wasm_mod.addImport("term", termlib.module("term"));
        // wasm_mod.addImport("common", commonlib.module("common"));
        // wasm_mod.addImport("engine", engine_module);
        // const wasmlib = b.addLibrary(.{ .name = "libzigxelwasm", .linkage = .static, .root_module = wasm_mod });
        // wasmlib.linkLibC();
        // wasmlib.linkLibrary(lib);
        // if (b.lazyDependency("emsdk", .{})) |dep| {
        //     if (try emSdkSetupStep(b, dep)) |emSdkStep| {
        //         wasmlib.step.dependOn(&emSdkStep.step);
        //     }
        //     wasmlib.addIncludePath(dep.path("upstream/emscripten/cache/sysroot/include"));
        // }
        // b.installArtifact(wasmlib);
        // const exe_lib = b.addStaticLibrary(.{
        //     .name = "zigxel",
        //     .target = target,
        //     .optimize = optimize,
        // });
        // exe_lib.linkLibC();
        // exe_lib.linkLibrary(wasmlib);

        // // Include emscripten for cross compilation
        // if (b.lazyDependency("emsdk", .{})) |emsdk_dep| {
        //     if (try emSdkSetupStep(b, emsdk_dep)) |emSdkStep| {
        //         exe_lib.step.dependOn(&emSdkStep.step);
        //     }
        //     exe_lib.addIncludePath(emsdk_dep.path("upstream/emscripten/cache/sysroot/include"));
        //     // Create the output directory because emcc can't do it.
        //     const emccOutputDirExample = b.pathJoin(&.{ emccOutputDir, "zigxel", std.fs.path.sep_str });
        //     const mkdir_command = switch (builtin.os.tag) {
        //         .windows => b.addSystemCommand(&.{ "cmd.exe", "/c", "if", "not", "exist", emccOutputDirExample, "mkdir", emccOutputDirExample }),
        //         else => b.addSystemCommand(&.{ "mkdir", "-p", emccOutputDirExample }),
        //     };
        //     const emcc_exe = switch (builtin.os.tag) {
        //         .windows => "emcc.bat",
        //         else => "emcc",
        //     };
        //     const emcc_exe_path = b.pathJoin(&.{ emsdk_dep.path("upstream/emscripten").getPath(b), emcc_exe });
        //     const emcc_command = b.addSystemCommand(&[_][]const u8{emcc_exe_path});
        //     emcc_command.step.dependOn(&mkdir_command.step);
        //     const emccOutputDirExampleWithFile = b.pathJoin(&.{ emccOutputDir, "zigxel", std.fs.path.sep_str, emccOutputFile });
        //     emcc_command.addArgs(&[_][]const u8{
        //         "-o",
        //         emccOutputDirExampleWithFile,
        //         "-sFULL-ES3=1",
        //         "-sUSE_GLFW=3",
        //         "-sSTACK_OVERFLOW_CHECK=1",
        //         "-sEXPORTED_RUNTIME_METHODS=['requestFullscreen']",
        //         "-sASYNCIFY",
        //         "-O0",
        //         "--emrun",
        //         "--preload-file",
        //         //module_resources,
        //         "--shell-file",
        //         b.path("src/shell.html").getPath(b),
        //     });
        //     const link_items: []const *std.Build.Step.Compile = &.{
        //         wasmlib,
        //         exe_lib,
        //     };
        //     for (link_items) |item| {
        //         emcc_command.addFileArg(item.getEmittedBin());
        //         emcc_command.step.dependOn(&item.step);
        //     }
        //     const run_step = try emscriptenRunStep(b, emsdk_dep, emccOutputDirExampleWithFile);
        //     run_step.step.dependOn(&emcc_command.step);
        //     run_step.addArg("--no_browser");
        //     const run_option = b.step("zigxel", "zigxel");
        //     run_option.dependOn(&run_step.step);
        // }
    } else {
        const exe = b.addExecutable(.{
            .name = "zigxel",
            .root_module = b.createModule(.{ // this line was added
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
            }), // this line was added
        });
        //DEPS
        exe.root_module.addImport("emcc", emcclib.module("emcc"));
        exe.root_module.addImport("image", imglib.module("image"));
        exe.root_module.addImport("term", termlib.module("term"));
        exe.root_module.addImport("common", commonlib.module("common"));
        //INTERNAL MODULES
        exe.root_module.addImport("event_manager", event_module);
        exe.root_module.addImport("engine", engine_module);
        exe.root_module.addImport("graphics", graphics_module);
        exe.root_module.addImport("texture", texture_module);
        exe.root_module.addImport("sprite", sprite_module);

        exe.linkLibrary(lib);

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
