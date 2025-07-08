const std = @import("std");
const builtin = @import("builtin");
const game = @import("game.zig");
pub const std_options: std.Options = .{
    .log_level = .err,
    .logFn = myLogFn,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .png_image, .level = .err },
        .{ .scope = .jpeg_image, .level = .err },
        .{ .scope = .bmp_image, .level = .err },
        .{ .scope = .event_manager, .level = .err },
        .{ .scope = .xlib, .level = .err },
        .{ .scope = .engine, .level = .err },
        .{ .scope = .texture, .level = .err },
        .{ .scope = .graphics, .level = .err },
        .{ .scope = .ttf, .level = .err },
        .{ .scope = .game, .level = .info },
        .{ .scope = .font, .level = .err },
        .{ .scope = .physics_pixel, .level = .info },
        .{ .scope = .pixel_renderer, .level = .info },
        .{ .scope = .ascii_renderer, .level = .err },
        .{ .scope = .tui, .level = .info },
    },
};

pub fn myLogFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const prefix = "[" ++ comptime level.asText() ++ "] (" ++ @tagName(scope) ++ "): ";
    // Print the message to stderr, silently ignoring any errors
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format, args) catch return;
}

pub const WASM: bool = if (builtin.os.tag == .emscripten or builtin.os.tag == .wasi) true else false;
pub fn main() !void {
    var allocator: std.mem.Allocator = undefined;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    if (!WASM) {
        allocator = gpa.allocator();
    } else {
        allocator = std.heap.raw_c_allocator;
    }
    var app = try game.Game.init(allocator);
    try app.run();
    try app.deinit();
    if (!WASM) {
        if (gpa.deinit() == .leak) {
            std.log.warn("Leaked!\n", .{});
        }
    }
}
