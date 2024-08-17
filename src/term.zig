// Heavily inspired by https://github.com/const-void/DOOM-fire-zig
// https://en.wikipedia.org/wiki/ANSI_escape_code
const builtin = @import("builtin");
const std = @import("std");

const TIOCGWINSZ = std.c.T.IOCGWINSZ; // ioctl flag

//term size
const Size = struct { height: usize, width: usize };

//ansi escape codes
pub const ESC = "\x1B";
pub const CSI = ESC ++ "[";

pub const CURSOR_SAVE = ESC ++ "7";
pub const CURSOR_LOAD = ESC ++ "8";

pub const CURSOR_SHOW = CSI ++ "?25h"; //h=high
pub const CURSOR_HIDE = CSI ++ "?25l"; //l=low
pub const CURSOR_HOME = CSI ++ "1;1H"; //1,1

pub const SCREEN_CLEAR = CSI ++ "2J";
pub const SCREEN_BUF_ON = CSI ++ "?1049h"; //h=high
pub const SCREEN_BUF_OFF = CSI ++ "?1049l"; //l=low

pub const LINE_CLEAR_TO_EOL = CSI ++ "0K";

pub const COLOR_RESET = CSI ++ "0m";
pub const COLOR_FG = "38;5;";
pub const COLOR_BG = "48;5;";

pub const COLOR_FG_DEF = CSI ++ COLOR_FG ++ "15m"; // white
pub const COLOR_BG_DEF = CSI ++ COLOR_BG ++ "0m"; // black
pub const COLOR_DEF = COLOR_BG_DEF ++ COLOR_FG_DEF;
pub const COLOR_ITALIC = CSI ++ "3m";
pub const COLOR_NOT_ITALIC = CSI ++ "23m";

pub const TERM_ON = SCREEN_BUF_ON ++ CURSOR_HIDE ++ CURSOR_HOME ++ SCREEN_CLEAR ++ COLOR_DEF;
pub const TERM_OFF = SCREEN_BUF_OFF ++ CURSOR_SHOW ++ N1;

//handy characters
pub const N1 = "\n";
pub const SEP = '▏';

//colors
pub const MAX_COLOR = 256;
pub const LAST_COLOR = MAX_COLOR - 1;

fn init_color(color_code: []const u8) [MAX_COLOR][]const u8 {
    var color_idx: u16 = 0;
    var colors: [MAX_COLOR][]const u8 = undefined;
    while (color_idx < MAX_COLOR) : (color_idx += 1) {
        colors[color_idx] = std.fmt.comptimePrint(color_code, .{ CSI, color_idx });
    }
    return colors;
}

pub const FG: [MAX_COLOR][]const u8 = init_color("{s}38;5;{d}m");
pub const BG: [MAX_COLOR][]const u8 = init_color("{s}48;5;{d}m");

const q2c: [6]u8 = [6]u8{ 0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff };

const win32 = struct {
    pub const BOOL = i32;
    pub const HANDLE = std.os.windows.HANDLE;
    pub const COORD = extern struct {
        X: i16,
        Y: i16,
    };
    pub const SMALL_RECT = extern struct {
        Left: i16,
        Top: i16,
        Right: i16,
        Bottom: i16,
    };
    pub const CONSOLE_SCREEN_BUFFER_INFO = extern struct {
        dwSize: COORD,
        dwCursorPosition: COORD,
        wAttributes: u16,
        srWindow: SMALL_RECT,
        dwMaximumWindowSize: COORD,
    };
    pub extern "kernel32" fn GetConsoleScreenBufferInfo(
        hConsoleOutput: ?HANDLE,
        lpConsoleScreenBufferInfo: ?*CONSOLE_SCREEN_BUFFER_INFO,
    ) callconv(std.os.windows.WINAPI) BOOL;
};

pub const Term = struct {
    size: Size = undefined,
    allocator: std.mem.Allocator = undefined,
    stdout: std.fs.File.Writer = undefined,
    stdin: std.fs.File.Reader = undefined,
    buffer: []u8 = undefined,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const stdout = std.io.getStdOut().writer();
        const stdin = std.io.getStdIn().reader();
        const ret = Self{
            .size = try get_Size(stdout.context.handle),
            .allocator = allocator,
            .stdout = stdout,
            .stdin = stdin,
        };
        try ret.out(TERM_ON);
        return ret;
    }

    pub fn deinit(self: *Self) !void {
        try self.out(TERM_OFF);
    }

    pub fn set_bg_color(self: *Self, r: u8, g: u8, b: u8) !void {
        try self.out(BG[self.rgb_256(r, g, b)]);
    }

    pub fn set_fg_color(self: *Self, r: u8, g: u8, b: u8) !void {
        try self.out(FG[self.rgb_256(r, g, b)]);
    }

    fn colour_dist_sq(R: i32, G: i32, B: i32, r: i32, g: i32, b: i32) i32 {
        return ((R - r) * (R - r) + (G - g) * (G - g) + (B - b) * (B - b));
    }

    fn colour_to_6cube(v: u8) u8 {
        if (v < 48)
            return (0);
        if (v < 114)
            return (1);
        return ((v - 35) / 40);
    }

    pub fn rgb_256(_: *Self, r: u8, g: u8, b: u8) usize {
        var qr: u8 = undefined;
        var qg: u8 = undefined;
        var qb: u8 = undefined;
        var cr: u8 = undefined;
        var cg: u8 = undefined;
        var cb: u8 = undefined;
        var d: i32 = undefined;
        var gray: i32 = undefined;
        var gray_avg: i32 = undefined;
        var idx: usize = undefined;
        var gray_idx: usize = undefined;

        qr = colour_to_6cube(r);
        cr = q2c[qr];
        qg = colour_to_6cube(g);
        cg = q2c[qg];
        qb = colour_to_6cube(b);
        cb = q2c[qb];

        if (cr == r and cg == g and cb == b) {
            return ((16 + (36 * @as(usize, @intCast(qr))) + (6 * @as(usize, @intCast(qg))) + @as(usize, @intCast(qb))));
        }

        gray_avg = @divFloor((@as(i32, @intCast(r)) + @as(i32, @intCast(g)) + @as(i32, @intCast(b))), 3);
        if (gray_avg > 238) {
            gray_idx = 23;
        } else {
            gray_idx = @as(usize, @intCast(@divFloor((gray_avg - 3), 10)));
        }
        gray = 8 + (10 * @as(i32, @intCast(gray_idx)));
        d = colour_dist_sq(@as(i32, @intCast(cr)), @as(i32, @intCast(cg)), @as(i32, @intCast(cb)), @as(i32, @intCast(r)), @as(i32, @intCast(g)), @as(i32, @intCast(b)));
        if (colour_dist_sq(gray, gray, gray, @as(i32, @intCast(r)), @as(i32, @intCast(g)), @as(i32, @intCast(b))) < d) {
            idx = 232 + gray_idx;
        } else {
            idx = 16 + (36 * @as(usize, @intCast(qr))) + (6 * @as(usize, @intCast(qg))) + @as(usize, @intCast(qb));
        }
        return idx;
    }

    pub fn out(self: *const Self, s: []const u8) !void {
        _ = try self.stdout.write(s);
    }

    pub fn out_fmt(self: *const Self, comptime s: []const u8, args: anytype) !void {
        const t = try std.fmt.allocPrint(self.allocator, s, args);
        defer self.allocator.free(t);
        try self.out(t);
    }
    fn get_Size(tty: std.posix.fd_t) !Size {
        if (builtin.os.tag == .windows) {
            //Microsoft Windows Case
            var info: win32.CONSOLE_SCREEN_BUFFER_INFO = undefined;
            if (0 == win32.GetConsoleScreenBufferInfo(tty, &info)) switch (std.os.windows.kernel32.GetLastError()) {
                else => |e| return std.os.windows.unexpectedError(e),
            };

            return Size{
                .height = @intCast(info.srWindow.Bottom - info.srWindow.Top + 1),
                .width = @intCast(info.srWindow.Right - info.srWindow.Left + 1),
            };
        } else {
            //Linux-MacOS Case
            var winsz = std.posix.winsize{ .col = 0, .row = 0, .xpixel = 0, .ypixel = 0 };
            const rv = std.c.ioctl(tty, TIOCGWINSZ, @intFromPtr(&winsz));
            const err = std.posix.errno(rv);

            if (rv >= 0) {
                return Size{ .height = winsz.row, .width = winsz.col };
            } else {
                std.process.exit(0);
                return std.posix.unexpectedErrno(err);
            }
        }
    }
};

// test "hello world" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator = gpa.allocator();
//     var term = try Term.init(allocator);
//     try term.set_bg_color(40, 40, 40);
//     try term.set_fg_color(255, 128, 0);
//     try term.out("hello world\n");
//     _ = try term.stdin.readByte();
//     try term.deinit();

//     if (gpa.deinit() == .leak) {
//         std.debug.print("Leaked!\n", .{});
//     }
// }
