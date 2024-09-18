//TODO ttf struct that loads a ttf utilizing existing texture struct and exposes an api that allows user to generate a texture from a string input utilizing the ttf font

//https://handmade.network/forums/articles/t/7330-implementing_a_font_reader_and_rasterizer_from_scratch%252C_part_1__ttf_font_reader.

pub const TTF = struct {
    const Self = @This();
    pub fn load(self: *Self, file_name: []const u8) void {
        _ = self;
        _ = file_name;
    }
};
