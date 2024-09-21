const std = @import("std");
const ByteStream = @import("image").ByteStream;
const BitReader = @import("image").BitReader;

//TODO ttf struct that loads a ttf utilizing existing texture struct and exposes an api that allows user to generate a texture from a string input utilizing the ttf font

//https://handmade.network/forums/articles/t/7330-implementing_a_font_reader_and_rasterizer_from_scratch%252C_part_1__ttf_font_reader.

pub const TTF = struct {
    bit_reader: BitReader = undefined,
    allocator: std.mem.Allocator,

    const FontDirectory = struct {
        offset_subtable: OffsetSubtable,
        table_directory: *TableDirectory,
    };
    const OffsetSubtable = struct {
        scalar_type: u32,
        num_tables: u16,
        search_range: u16,
        entry_selector: u16,
        range_shift: u16,
    };
    const TableDirectory = struct {
        tag: Tag,
        checksum: u32,
        offset: u32,
        length: u32,
        const Tag = union {
            tag_c: [4]u8,
            tag: u32,
        };
    };
    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }
    pub fn load(self: *Self, file_name: []const u8) void {
        self.bit_reader = BitReader.init(.{
            .file_name = file_name,
            .allocator = self.allocator,
        });
    }
};
