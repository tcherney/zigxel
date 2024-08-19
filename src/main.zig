const std = @import("std");
const engine = @import("engine.zig");
const utils = @import("utils.zig");
const image = @import("image");

var running: bool = true;
var e: engine.Engine = undefined;
var fps_buffer: [64]u8 = undefined;
var tex: engine.TextureTrue = undefined;
pub fn on_key_press(key: engine.KEYS) void {
    //std.debug.print("{}\n", .{key});
    if (key == engine.KEYS.KEY_q) {
        running = false;
    } else if (key == engine.KEYS.KEY_a) {
        tex.x -= 1;
    } else if (key == engine.KEYS.KEY_d) {
        tex.x += 1;
    } else if (key == engine.KEYS.KEY_w) {
        tex.y -= 1;
    } else if (key == engine.KEYS.KEY_s) {
        tex.y += 1;
    }
}

pub fn on_render() engine.Error!void {
    e.renderer.set_bg(0, 0, 0);

    e.renderer.draw_rect(60, 8, 2, 3, 0, 255, 255);
    e.renderer.draw_rect(60, 8, 3, 1, 128, 75, 0);
    e.renderer.draw_rect(95, 15, 2, 1, 255, 128, 0);
    try e.renderer.draw_texture(tex);
    try e.renderer.draw_text(try std.fmt.bufPrint(&fps_buffer, "FPS:{d:.2}", .{e.fps}), 30, 40, 0, 255, 0);
    try e.renderer.flip();
}
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    try utils.gen_rand();
    tex = engine.TextureTrue.init(allocator);
    e = try engine.Engine.init(allocator);
    var img = image.Image(image.JPEGImage){};
    try img.load("../img2ascii/tests/jpeg/cat.jpg", allocator);
    try tex.load_image(5, 5, img);
    try tex.scale(68, 45);
    //std.debug.print("{any}\n", .{tex.pixel_buffer});
    //std.debug.print("{d}\n", .{utils.rgb_256(255, 255, 255)});
    e.on_key_press(on_key_press);
    e.on_render(on_render);
    e.set_fps(60);
    try e.start();

    while (running) {
        // do game logic on seperate thread
        std.time.sleep(e.frame_limit);
    }
    try e.deinit();
    img.deinit();
    tex.deinit();
    if (gpa.deinit() == .leak) {
        std.debug.print("Leaked!\n", .{});
    }
}
