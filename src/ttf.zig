const std = @import("std");
const ByteStream = @import("image").ByteStream;
const BitReader = @import("image").BitReader;

//TODO ttf struct that loads a ttf utilizing existing texture struct and exposes an api that allows user to generate a texture from a string input utilizing the ttf font

//https://handmade.network/forums/articles/t/7330-implementing_a_font_reader_and_rasterizer_from_scratch%252C_part_1__ttf_font_reader.

pub const TTF = struct {
    bit_reader: BitReader = undefined,
    allocator: std.mem.Allocator,
    font_directory: FontDirectory = undefined,

    const FontDirectory = struct {
        offset_subtable: OffsetSubtable = undefined,
        table_directory: []TableDirectory = undefined,
    };
    const OffsetSubtable = struct {
        scalar_type: u32 = undefined,
        num_tables: u16 = undefined,
        search_range: u16 = undefined,
        entry_selector: u16 = undefined,
        range_shift: u16 = undefined,
    };
    const TableDirectory = struct {
        tag: [4]u8 = undefined,
        checksum: u32 = undefined,
        offset: u32 = undefined,
        length: u32 = undefined,
    };
    const CMAP = struct {
        version: u16 = undefined,
        num_subtables: u16 = undefined,
        cmap_encoding_subtables: []CMAPEncodingSubtable = undefined,
        const CMAPEncodingSubtable = struct {
            platform_id: u16 = undefined,
            platrform_specific_id: u16 = undefined,
            offset: u32 = undefined,
        };
        const Format4 = struct {
            format: u16,
            length: u16,
            language: u16,
            seg_count_x2: u16,
            search_range: u16,
            entry_selector: u16,
            range_shift: u16,
            reserved_pad: u16,
            end_code: []u16,
            start_code: []u16,
            id_delta: []u16,
            id_range_offset: []u16,
            glyph_id_array: []u16,
        };
    };
    pub const Error = error{TableNotFound};
    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.font_directory.table_directory);
    }

    fn find_table(self: *Self, table_name: []const u8) Error!*TableDirectory {
        for (0..self.font_directory.table_directory.len) |i| {
            if (std.mem.eql(u8, &self.font_directory.table_directory[i].tag, table_name)) {
                return &self.font_directory.table_directory[i];
            }
        }
        return Error.TableNotFound;
    }

    fn read_cmap(self: *Self, cmap: *CMAP) !void {
        cmap.version = try self.bit_reader.read_word();
        cmap.num_subtables = try self.bit_reader.read_word();

        cmap.cmap_encoding_subtables = try self.allocator.alloc(CMAP.CMAPEncodingSubtable, cmap.num_subtables);
        for (0..cmap.num_subtables) |i| {
            cmap.cmap_encoding_subtables[i].platform_id = try self.bit_reader.read_word();
            cmap.cmap_encoding_subtables[i].platrform_specific_id = try self.bit_reader.read_word();
            cmap.cmap_encoding_subtables[i].offset = try self.bit_reader.read_int();
        }
    }

    fn read_format4(self: *Self, offset: usize, format4: *CMAP.Format4) !void {
        self.bit_reader.setPos(offset);
        format4.format = try self.bit_reader.read_word();
        format4.length = try self.bit_reader.read_word();
        format4.language = try self.bit_reader.read_word();
        format4.seg_count_x2 = try self.bit_reader.read_word();
        format4.search_range = try self.bit_reader.read_word();
        format4.entry_selector = try self.bit_reader.read_word();
        format4.range_shift = try self.bit_reader.read_word();

        format4.end_code = try self.allocator.alloc(u16, format4.seg_count_x2 / 2);
        format4.start_code = try self.allocator.alloc(u16, format4.seg_count_x2 / 2);
        format4.id_delta = try self.allocator.alloc(u16, format4.seg_count_x2 / 2);
        format4.id_range_offset = try self.allocator.alloc(u16, format4.seg_count_x2 / 2);

        for (0..format4.seg_count_x2 / 2) |i| {
            format4.end_code[i] = try self.bit_reader.read_word();
        }
        self.bit_reader.setPos(self.bit_reader.getPos() + 2);
        for (0..format4.seg_count_x2 / 2) |i| {
            format4.start_code[i] = try self.bit_reader.read_word();
        }
        for (0..format4.seg_count_x2 / 2) |i| {
            format4.id_delta[i] = try self.bit_reader.read_word();
        }
        for (0..format4.seg_count_x2 / 2) |i| {
            format4.id_range_offset[i] = try self.bit_reader.read_word();
        }
        const remaining_bytes = format4.length - (self.bit_reader.getPos() - offset);
        format4.glyph_id_array = try self.allocator.alloc(u16, remaining_bytes / 2);
        for (0..format4.glyph_id_array.len) |i| {
            format4.glyph_id_array[i] = try self.bit_reader.read_word();
        }
    }

    fn print_cmap(cmap: *CMAP) void {
        std.debug.print("#)\tpId\tpsID\toffset\ttype\n", .{});
        for (0..cmap.num_subtables) |i| {
            const subtable: CMAP.CMAPEncodingSubtable = cmap.cmap_encoding_subtables[i];
            std.debug.print("{d})\t{d}\t{d}\t{d}\t", .{ i + 1, subtable.platform_id, subtable.platrform_specific_id, subtable.offset });
            switch (subtable.platform_id) {
                0 => std.debug.print("Unicode", .{}),
                1 => std.debug.print("Mac", .{}),
                2 => std.debug.print("Not Supported", .{}),
                3 => std.debug.print("Microsoft", .{}),
                else => unreachable,
            }
            std.debug.print("\n", .{});
        }
    }

    fn print_format4(format4: *CMAP.Format4) void {
        std.debug.print("Format: {d}, Length: {d}, Language: {d}, Segment Count: {d}\n", .{ format4.format, format4.length, format4.language, format4.seg_count_x2 / 2 });
        std.debug.print("Search Params: (searchRange: {d}, entrySelector: {d}, rangeShift: {d})\n", .{ format4.search_range, format4.entry_selector, format4.range_shift });
        std.debug.print("Segment Ranges:\tstartCode\tendCode\tidDelta\tidRangeOffset\n", .{});
        for (0..format4.seg_count_x2 / 2) |i| {
            std.debug.print("--------------:\t {d:9}\t {d:7}\t {d:7}\t {d:12}\n", .{ format4.start_code[i], format4.end_code[i], format4.id_delta[i], format4.id_range_offset[i] });
        }
    }

    fn get_glyph_index(code_point: u16, format4: *CMAP.Format4) usize {
        var index: ?usize = null;
        for (0..format4.seg_count_x2 / 2) |i| {
            if (format4.end_code[i] > code_point) {
                index = i;
                break;
            }
        }
        if (index == null) return 0;
        if (format4.start_code[index.?] < code_point) {
            if (format4.id_range_offset[index.?] != 0) {
                const offset_index = index.? + (format4.id_range_offset[index.?] / 2) + code_point - format4.start_code[index.?];
                var offset_value: u16 = undefined;
                if (offset_index >= format4.id_range_offset.len) {
                    offset_value = format4.glyph_id_array[offset_index - format4.id_range_offset.len];
                } else {
                    offset_value = format4.id_range_offset[offset_index];
                }
                if (offset_value == 0) return 0;
                return @as(usize, @intCast(offset_value + format4.id_delta[index.?]));
            } else {
                return @as(usize, @intCast(code_point + format4.id_delta[index.?]));
            }
        }
        return 0;
    }

    fn parse_file(self: *Self) !void {
        // offset subtable
        self.font_directory.offset_subtable.scalar_type = try self.bit_reader.read_int();
        self.font_directory.offset_subtable.num_tables = try self.bit_reader.read_word();
        self.font_directory.offset_subtable.search_range = try self.bit_reader.read_word();
        self.font_directory.offset_subtable.entry_selector = try self.bit_reader.read_word();
        self.font_directory.offset_subtable.range_shift = try self.bit_reader.read_word();

        // table directory
        self.font_directory.table_directory = try self.allocator.alloc(TableDirectory, self.font_directory.offset_subtable.num_tables);
        for (0..self.font_directory.table_directory.len) |i| {
            self.font_directory.table_directory[i].tag[0] = try self.bit_reader.read_byte();
            self.font_directory.table_directory[i].tag[1] = try self.bit_reader.read_byte();
            self.font_directory.table_directory[i].tag[2] = try self.bit_reader.read_byte();
            self.font_directory.table_directory[i].tag[3] = try self.bit_reader.read_byte();
            self.font_directory.table_directory[i].checksum = try self.bit_reader.read_int();
            self.font_directory.table_directory[i].offset = try self.bit_reader.read_int();
            self.font_directory.table_directory[i].length = try self.bit_reader.read_int();
        }
        self.print_table();
        const cmap_table = try self.find_table("cmap");
        var cmap: CMAP = undefined;
        defer self.allocator.free(cmap.cmap_encoding_subtables);
        self.bit_reader.setPos(cmap_table.offset);
        try self.read_cmap(&cmap);
        print_cmap(&cmap);
        var format4: CMAP.Format4 = undefined;
        defer self.allocator.free(format4.end_code);
        defer self.allocator.free(format4.start_code);
        defer self.allocator.free(format4.id_delta);
        defer self.allocator.free(format4.id_range_offset);
        defer self.allocator.free(format4.glyph_id_array);
        try self.read_format4(cmap_table.offset + cmap.cmap_encoding_subtables[0].offset, &format4);
        print_format4(&format4);
        for (65..91) |i| {
            std.debug.print("{c} = {d}\n", .{ @as(u8, @intCast(i)), get_glyph_index(@as(u16, @intCast(i)), &format4) });
        }
    }

    fn print_table(self: *Self) void {
        std.debug.print("#)\ttag\tlen\toffset\n", .{});
        for (0..self.font_directory.table_directory.len) |i| {
            const dir = self.font_directory.table_directory[i];
            std.debug.print("{d})\t{c}{c}{c}{c}\t{d}\t{d}\n", .{ i + 1, dir.tag[0], dir.tag[1], dir.tag[2], dir.tag[3], dir.length, dir.offset });
        }
    }

    pub fn load(self: *Self, file_name: []const u8) !void {
        self.bit_reader = try BitReader.init(.{
            .file_name = file_name,
            .allocator = self.allocator,
        });
        try self.parse_file();
        self.bit_reader.deinit();
    }
};
