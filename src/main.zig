const std = @import("std");
const game = @import("game.zig");
pub const std_options: std.Options = .{
    .log_level = .err,
    .logFn = myLogFn,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .png_image, .level = .err },
        .{ .scope = .jpeg_image, .level = .err },
        .{ .scope = .bmp_image, .level = .err },
        .{ .scope = .event_manager, .level = .info },
        .{ .scope = .xlib, .level = .info },
        .{ .scope = .engine, .level = .err },
        .{ .scope = .texture, .level = .err },
        .{ .scope = .graphics, .level = .err },
        .{ .scope = .ttf, .level = .err },
        .{ .scope = .game, .level = .info },
        .{ .scope = .font, .level = .err },
        .{ .scope = .physics_pixel, .level = .info },
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var app = try game.Game.init(allocator);
    try app.run();
    try app.deinit();
    if (gpa.deinit() == .leak) {
        std.log.warn("Leaked!\n", .{});
    }
}
