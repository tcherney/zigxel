const std = @import("std");
const px = "▀▀▀▀▀▀";
pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{s}\n", .{px});
    _ = try stdout.write("\x1B[2J");

    try bw.flush();
}
