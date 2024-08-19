// Heavily inspired by https://github.com/const-void/DOOM-fire-zig
// https://en.wikipedia.org/wiki/ANSI_escape_code
// https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797

const builtin = @import("builtin");
const std = @import("std");
const utils = @import("utils.zig");

const TIOCGWINSZ = std.c.T.IOCGWINSZ; // ioctl flag

//term size
pub const Size = struct { height: usize, width: usize };
pub const Error = error{SizeError} || std.fmt.AllocPrintError || std.fs.File.Writer.Error;

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

pub const FULL_SCREEN = CSI ++ "8;200;500t";

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

//TODO RGB true color
//"ESC[38;2;{r};{g};{b}m" Set foreground color as RGB
//"ESC[48;2;{r};{g};{b}m" Set background color as RGB

pub const FG: [MAX_COLOR][]const u8 = init_color("{s}38;5;{d}m");
pub const BG: [MAX_COLOR][]const u8 = init_color("{s}48;5;{d}m");

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

    pub extern "kernel32" fn SetConsoleScreenBufferSize(
        hConsoleOutput: ?HANDLE,
        dwSize: std.os.windows.COORD,
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
        //try ret.out(FULL_SCREEN);
        return ret;
    }

    pub fn deinit(self: *Self) !void {
        try self.out(TERM_OFF);
    }

    pub fn set_bg_color(self: *Self, r: u8, g: u8, b: u8) Error!void {
        try self.out(BG[utils.rgb_256(r, g, b)]);
    }

    pub fn set_fg_color(self: *Self, r: u8, g: u8, b: u8) Error!void {
        try self.out(FG[utils.rgb_256(r, g, b)]);
    }

    pub fn out(self: *const Self, s: []const u8) Error!void {
        _ = try self.stdout.write(s);
    }

    pub fn out_fmt(self: *const Self, comptime s: []const u8, args: anytype) Error!void {
        const t = try std.fmt.allocPrint(self.allocator, s, args);
        defer self.allocator.free(t);
        try self.out(t);
    }
    fn get_Size(tty: std.posix.fd_t) Error!Size {
        if (builtin.os.tag == .windows) {
            //Microsoft Windows Case
            var info: win32.CONSOLE_SCREEN_BUFFER_INFO = undefined;
            if (std.os.windows.FALSE == win32.GetConsoleScreenBufferInfo(tty, &info)) switch (std.os.windows.kernel32.GetLastError()) {
                else => return Error.SizeError,
            };

            return Size{
                .height = @as(usize, @intCast(info.srWindow.Bottom - info.srWindow.Top + 1)) * 2,
                .width = @intCast(info.srWindow.Right - info.srWindow.Left + 1),
            };
        } else {
            //Linux-MacOS Case
            var winsz = std.posix.winsize{ .col = 0, .row = 0, .xpixel = 0, .ypixel = 0 };
            const rv = std.c.ioctl(tty, TIOCGWINSZ, @intFromPtr(&winsz));

            if (rv >= 0) {
                return Size{ .height = winsz.row, .width = winsz.col };
            } else {
                return Error.SizeError;
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
