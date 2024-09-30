const std = @import("std");
const utils = @import("utils.zig");
const ByteStream = @import("image").ByteStream;
const BitReader = @import("image").BitReader;

//TODO ttf struct that loads a ttf utilizing existing texture struct and exposes an api that allows user to generate a texture from a string input utilizing the ttf font

//https://handmade.network/forums/articles/t/7330-implementing_a_font_reader_and_rasterizer_from_scratch%252C_part_1__ttf_font_reader.
//https://handmade.network/forums/wip/t/7610-reading_ttf_files_and_rasterizing_them_using_a_handmade_approach%252C_part_2__rasterization#23867
//https://stevehanov.ca/blog/index.php?id=143
//https://tchayen.github.io/posts/ttf-file-parsing
//https://learn.microsoft.com/en-us/typography/opentype/spec/
//https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6cmap.html

pub const TTF = struct {
    bit_reader: BitReader = undefined,
    allocator: std.mem.Allocator,
    font_directory: FontDirectory = undefined,
    char_map: std.AutoHashMap(u8, GlyphOutline) = undefined,

    pub const FontDirectory = struct {
        offset_subtable: OffsetSubtable = undefined,
        table_directory: []TableDirectory = undefined,
        format4: CMAP.Format4 = undefined,
        cmap: CMAP = undefined,
        glyf_offset: u32 = undefined,
        loca_offset: u32 = undefined,
        head_offset: u32 = undefined,
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
            format: u16 = undefined,
            length: u16 = undefined,
            language: u16 = undefined,
            seg_count_x2: u16 = undefined,
            search_range: u16 = undefined,
            entry_selector: u16 = undefined,
            range_shift: u16 = undefined,
            reserved_pad: u16 = undefined,
            end_code: []u16 = undefined,
            start_code: []u16 = undefined,
            id_delta: []u16 = undefined,
            id_range_offset: []u16 = undefined,
            glyph_id_array: []u16 = undefined,
        };
    };
    pub const GlyphOutline = struct {
        num_contours: i16 = undefined,
        x_min: i16 = undefined,
        y_min: i16 = undefined,
        y_max: i16 = undefined,
        x_max: i16 = undefined,
        instruction_length: u16 = undefined,
        instructions: []u8 = undefined,
        flags: []u8 = undefined,
        x_coord: []i16 = undefined,
        y_coord: []i16 = undefined,
        end_contours: []u16 = undefined,
        curves: []BezierCurve = undefined,
        const Flag = enum(u8) { on_curve = 1, x_short = 2, y_short = 4, repeat = 8, x_short_pos = 16, y_short_pos = 32, reservered };
    };
    pub const Point = utils.Point(i16);
    pub const BezierCurve = struct {
        p0: Point,
        p1: Point,
        p2: Point,
    };
    pub const Error = error{ TableNotFound, CompoundNotImplemented };
    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.font_directory.table_directory);
        self.allocator.free(self.font_directory.cmap.cmap_encoding_subtables);
        self.allocator.free(self.font_directory.format4.end_code);
        self.allocator.free(self.font_directory.format4.start_code);
        self.allocator.free(self.font_directory.format4.id_delta);
        self.allocator.free(self.font_directory.format4.id_range_offset);
        self.allocator.free(self.font_directory.format4.glyph_id_array);
        self.char_map.deinit();
    }

    fn find_table(self: *Self, table_name: []const u8) Error!*TableDirectory {
        for (0..self.font_directory.table_directory.len) |i| {
            if (std.mem.eql(u8, &self.font_directory.table_directory[i].tag, table_name)) {
                return &self.font_directory.table_directory[i];
            }
        }
        return Error.TableNotFound;
    }

    fn read_cmap(self: *Self, cmap_table: *TableDirectory) !void {
        self.bit_reader.setPos(cmap_table.offset);
        self.font_directory.cmap.version = try self.bit_reader.read_word();
        self.font_directory.cmap.num_subtables = try self.bit_reader.read_word();

        self.font_directory.cmap.cmap_encoding_subtables = try self.allocator.alloc(CMAP.CMAPEncodingSubtable, self.font_directory.cmap.num_subtables);
        for (0..self.font_directory.cmap.num_subtables) |i| {
            self.font_directory.cmap.cmap_encoding_subtables[i].platform_id = try self.bit_reader.read_word();
            self.font_directory.cmap.cmap_encoding_subtables[i].platrform_specific_id = try self.bit_reader.read_word();
            self.font_directory.cmap.cmap_encoding_subtables[i].offset = try self.bit_reader.read_int();
        }
    }

    fn read_format4(self: *Self, offset: usize) !void {
        self.bit_reader.setPos(offset);
        self.font_directory.format4.format = try self.bit_reader.read_word();
        self.font_directory.format4.length = try self.bit_reader.read_word();
        self.font_directory.format4.language = try self.bit_reader.read_word();
        self.font_directory.format4.seg_count_x2 = try self.bit_reader.read_word();
        self.font_directory.format4.search_range = try self.bit_reader.read_word();
        self.font_directory.format4.entry_selector = try self.bit_reader.read_word();
        self.font_directory.format4.range_shift = try self.bit_reader.read_word();

        self.font_directory.format4.end_code = try self.allocator.alloc(u16, self.font_directory.format4.seg_count_x2 / 2);
        self.font_directory.format4.start_code = try self.allocator.alloc(u16, self.font_directory.format4.seg_count_x2 / 2);
        self.font_directory.format4.id_delta = try self.allocator.alloc(u16, self.font_directory.format4.seg_count_x2 / 2);
        self.font_directory.format4.id_range_offset = try self.allocator.alloc(u16, self.font_directory.format4.seg_count_x2 / 2);

        for (0..self.font_directory.format4.seg_count_x2 / 2) |i| {
            self.font_directory.format4.end_code[i] = try self.bit_reader.read_word();
        }
        self.bit_reader.setPos(self.bit_reader.getPos() + 2);
        for (0..self.font_directory.format4.seg_count_x2 / 2) |i| {
            self.font_directory.format4.start_code[i] = try self.bit_reader.read_word();
        }
        for (0..self.font_directory.format4.seg_count_x2 / 2) |i| {
            self.font_directory.format4.id_delta[i] = try self.bit_reader.read_word();
        }
        for (0..self.font_directory.format4.seg_count_x2 / 2) |i| {
            self.font_directory.format4.id_range_offset[i] = try self.bit_reader.read_word();
        }
        const remaining_bytes = self.font_directory.format4.length - (self.bit_reader.getPos() - offset);
        self.font_directory.format4.glyph_id_array = try self.allocator.alloc(u16, remaining_bytes / 2);
        for (0..self.font_directory.format4.glyph_id_array.len) |i| {
            self.font_directory.format4.glyph_id_array[i] = try self.bit_reader.read_word();
        }
    }

    fn print_cmap(self: *Self) void {
        std.debug.print("#)\tpId\tpsID\toffset\ttype\n", .{});
        for (0..self.font_directory.cmap.num_subtables) |i| {
            const subtable: CMAP.CMAPEncodingSubtable = self.font_directory.cmap.cmap_encoding_subtables[i];
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

    fn print_format4(self: *Self) void {
        std.debug.print("Format: {d}, Length: {d}, Language: {d}, Segment Count: {d}\n", .{ self.font_directory.format4.format, self.font_directory.format4.length, self.font_directory.format4.language, self.font_directory.format4.seg_count_x2 / 2 });
        std.debug.print("Search Params: (searchRange: {d}, entrySelector: {d}, rangeShift: {d})\n", .{ self.font_directory.format4.search_range, self.font_directory.format4.entry_selector, self.font_directory.format4.range_shift });
        std.debug.print("Segment Ranges:\tstartCode\tendCode\tidDelta\tidRangeOffset\n", .{});
        for (0..self.font_directory.format4.seg_count_x2 / 2) |i| {
            std.debug.print("--------------:\t {d:9}\t {d:7}\t {d:7}\t {d:12}\n", .{ self.font_directory.format4.start_code[i], self.font_directory.format4.end_code[i], self.font_directory.format4.id_delta[i], self.font_directory.format4.id_range_offset[i] });
        }
    }

    fn print_glyph_outline(glyph_outline: *const GlyphOutline) void {
        std.debug.print("#contours\t(xMin,yMin)\t(xMax,yMax)\tinst_length\n", .{});
        std.debug.print("%{d:9}\t({d},{d})\t\t({d},{d})\t{d}\n", .{ glyph_outline.num_contours, glyph_outline.x_min, glyph_outline.y_min, glyph_outline.x_max, glyph_outline.y_max, glyph_outline.instruction_length });

        std.debug.print("#)\t(  x  ,  y  )\n", .{});
        const last_index = glyph_outline.end_contours[glyph_outline.end_contours.len - 1];
        for (0..last_index + 1) |i| {
            std.debug.print("{d})\t({d:5},{d:5})\n", .{ i, glyph_outline.x_coord[i], glyph_outline.y_coord[i] });
        }
    }

    fn get_glyph_outline(self: *Self, glyph_index: usize) !GlyphOutline {
        const offset: usize = try self.get_glyph_offset(glyph_index);
        var glyph_outline: GlyphOutline = undefined;
        self.bit_reader.setPos(self.font_directory.glyf_offset + offset);
        glyph_outline.num_contours = @as(i16, @bitCast(try self.bit_reader.read_word()));
        glyph_outline.x_min = @as(i16, @bitCast(try self.bit_reader.read_word()));
        glyph_outline.y_min = @as(i16, @bitCast(try self.bit_reader.read_word()));
        glyph_outline.x_max = @as(i16, @bitCast(try self.bit_reader.read_word()));
        glyph_outline.y_max = @as(i16, @bitCast(try self.bit_reader.read_word()));

        std.debug.print("num contours {d}\n", .{glyph_outline.num_contours});
        if (glyph_outline.num_contours == -1) {
            return Error.CompoundNotImplemented;
        }

        glyph_outline.end_contours = try self.allocator.alloc(u16, @as(u16, @bitCast(glyph_outline.num_contours)));
        for (0..glyph_outline.end_contours.len) |i| {
            glyph_outline.end_contours[i] = try self.bit_reader.read_word();
        }
        glyph_outline.instruction_length = try self.bit_reader.read_word();
        glyph_outline.instructions = try self.allocator.alloc(u8, glyph_outline.instruction_length);
        for (0..glyph_outline.instructions.len) |i| {
            glyph_outline.instructions[i] = try self.bit_reader.read_byte();
        }
        const last_index = glyph_outline.end_contours[glyph_outline.end_contours.len - 1];
        glyph_outline.flags = try self.allocator.alloc(u8, last_index + 1);
        var i: usize = 0;
        while (i < glyph_outline.flags.len) : (i += 1) {
            glyph_outline.flags[i] = try self.bit_reader.read_byte();
            if ((glyph_outline.flags[i] & @intFromEnum(GlyphOutline.Flag.repeat)) != 0) {
                var repeat_count = @as(i8, @bitCast(try self.bit_reader.read_byte()));
                while (repeat_count > 0) {
                    repeat_count -= 1;
                    i += 1;
                    glyph_outline.flags[i] = glyph_outline.flags[i - 1];
                }
            }
        }
        glyph_outline.x_coord = try self.allocator.alloc(i16, (last_index + 1));
        var cur_coord: i16 = 0;
        for (0..(last_index + 1)) |j| {
            const flag_combined: u8 = (glyph_outline.flags[j] & @intFromEnum(GlyphOutline.Flag.x_short)) | (glyph_outline.flags[j] & @intFromEnum(GlyphOutline.Flag.x_short_pos)) >> 4;
            switch (flag_combined) {
                0 => {
                    cur_coord += @as(i16, @bitCast(try self.bit_reader.read_word()));
                },
                1 => {},
                2 => {
                    cur_coord -= @as(i16, @bitCast(@as(u16, @intCast(try self.bit_reader.read_byte()))));
                },
                3 => {
                    cur_coord += @as(i16, @bitCast(@as(u16, @intCast(try self.bit_reader.read_byte()))));
                },
                else => unreachable,
            }
            glyph_outline.x_coord[j] = cur_coord;
        }

        glyph_outline.y_coord = try self.allocator.alloc(i16, (last_index + 1));
        cur_coord = 0;
        for (0..(last_index + 1)) |j| {
            const flag_combined: u8 = (glyph_outline.flags[j] & @intFromEnum(GlyphOutline.Flag.y_short)) >> 1 | (glyph_outline.flags[j] & @intFromEnum(GlyphOutline.Flag.y_short_pos)) >> 5;
            switch (flag_combined) {
                0 => {
                    cur_coord += @as(i16, @bitCast(try self.bit_reader.read_word()));
                },
                1 => {},
                2 => {
                    cur_coord -= @as(i16, @bitCast(@as(u16, @intCast(try self.bit_reader.read_byte()))));
                },
                3 => {
                    cur_coord += @as(i16, @bitCast(@as(u16, @intCast(try self.bit_reader.read_byte()))));
                },
                else => unreachable,
            }
            glyph_outline.y_coord[j] = cur_coord;
        }

        return glyph_outline;
    }

    fn get_glyph_index(self: *Self, code_point: u16) usize {
        var index: ?usize = null;
        for (0..self.font_directory.format4.seg_count_x2 / 2) |i| {
            if (self.font_directory.format4.end_code[i] > code_point) {
                index = i;
                break;
            }
        }
        if (index == null) return 0;
        if (self.font_directory.format4.start_code[index.?] < code_point) {
            if (self.font_directory.format4.id_range_offset[index.?] != 0) {
                const offset_index = index.? + (self.font_directory.format4.id_range_offset[index.?] / 2) + code_point - self.font_directory.format4.start_code[index.?];
                var offset_value: u16 = undefined;
                if (offset_index >= self.font_directory.format4.id_range_offset.len) {
                    offset_value = self.font_directory.format4.glyph_id_array[offset_index - self.font_directory.format4.id_range_offset.len];
                } else {
                    offset_value = self.font_directory.format4.id_range_offset[offset_index];
                }
                if (offset_value == 0) return 0;
                return @as(usize, @intCast(offset_value + self.font_directory.format4.id_delta[index.?])) & 0xFFFF;
            } else {
                return @as(usize, @intCast(code_point + self.font_directory.format4.id_delta[index.?])) & 0xFFFF;
            }
        }
        return 0;
    }

    fn get_glyph_offset(self: *Self, glyph_index: usize) !usize {
        self.bit_reader.setPos(self.font_directory.head_offset + 50);
        const loca_type = try self.bit_reader.read_word();
        if (loca_type == 0) {
            self.bit_reader.setPos((self.font_directory.loca_offset + (glyph_index * 2)));
            return @as(usize, @intCast(try self.bit_reader.read_word())) * 2;
        } else {
            self.bit_reader.setPos(self.font_directory.loca_offset + (glyph_index * 4));
            return @as(usize, @intCast(try self.bit_reader.read_int()));
        }
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
        const cmap_table = try self.find_table("cmap");
        try self.read_cmap(cmap_table);
        try self.read_format4(cmap_table.offset + self.font_directory.cmap.cmap_encoding_subtables[0].offset);

        const glyf_table = try self.find_table("glyf");
        self.font_directory.glyf_offset = glyf_table.offset;
        const loca_table = try self.find_table("loca");
        self.font_directory.loca_offset = loca_table.offset;
        const head_table = try self.find_table("head");
        self.font_directory.head_offset = head_table.offset;

        self.print_table();
        self.print_cmap();
        self.print_format4();
        for (65..91) |i| {
            std.debug.print("{c} = {d}, {d}\n", .{ @as(u8, @intCast(i)), self.get_glyph_index(@as(u16, @intCast(i))), try self.get_glyph_offset(self.get_glyph_index(@as(u16, @intCast(i)))) });
        }
    }

    fn print_table(self: *Self) void {
        std.debug.print("#)\ttag\tlen\toffset\n", .{});
        for (0..self.font_directory.table_directory.len) |i| {
            const dir = self.font_directory.table_directory[i];
            std.debug.print("{d})\t{c}{c}{c}{c}\t{d}\t{d}\n", .{ i + 1, dir.tag[0], dir.tag[1], dir.tag[2], dir.tag[3], dir.length, dir.offset });
        }
    }

    fn gen_curves(self: *Self, glyph_outline: *GlyphOutline) std.mem.Allocator.Error!void {
        var points: std.ArrayList(Point) = std.ArrayList(Point).init(self.allocator);
        var previous_point: ?Point = null;
        var cur_point: Point = undefined;
        var previous_flag: bool = false;
        var cur_flag: bool = false;
        std.debug.print("num contours {d} {any}\n", .{ glyph_outline.num_contours, glyph_outline.end_contours });
        var contour_index: usize = 0;
        for (0..glyph_outline.x_coord.len) |i| {
            var curve_completed = false;
            cur_point.x = glyph_outline.x_coord[i];
            cur_point.y = glyph_outline.y_coord[i];
            cur_flag = (glyph_outline.flags[i] & @intFromEnum(GlyphOutline.Flag.on_curve)) == @intFromEnum(GlyphOutline.Flag.on_curve);
            std.debug.print("{any} {any} {any} {any} {any}\n", .{ previous_point, glyph_outline.flags[i], glyph_outline.flags[i] & @intFromEnum(GlyphOutline.Flag.on_curve), cur_flag, previous_flag });
            if (previous_point != null and !cur_flag and !previous_flag) {
                var midpoint: Point = undefined;
                midpoint.x = @divFloor(cur_point.x + previous_point.?.x, 2);
                midpoint.y = @divFloor(cur_point.y + previous_point.?.y, 2);
                try points.append(midpoint);
                curve_completed = true;
            } else if (cur_flag and previous_flag) {
                var midpoint: Point = undefined;
                midpoint.x = @divFloor(cur_point.x + previous_point.?.x, 2);
                midpoint.y = @divFloor(cur_point.y + previous_point.?.y, 2);
                try points.append(midpoint);
                curve_completed = true;
            }
            if (curve_completed) {
                try points.append(cur_point);
            }
            try points.append(cur_point);
            if (previous_point == null) {
                previous_point = Point{};
            }
            if (i == glyph_outline.end_contours[contour_index]) {
                if (contour_index == 0) {
                    if (curve_completed) {
                        var midpoint: Point = undefined;
                        midpoint.x = @divFloor(cur_point.x + glyph_outline.x_coord[0], 2);
                        midpoint.y = @divFloor(cur_point.y + glyph_outline.y_coord[0], 2);
                        try points.append(midpoint);
                    }
                    try points.append(.{
                        .x = glyph_outline.x_coord[0],
                        .y = glyph_outline.y_coord[0],
                    });
                } else {
                    if (curve_completed) {
                        var midpoint: Point = undefined;
                        midpoint.x = @divFloor(cur_point.x + glyph_outline.x_coord[glyph_outline.end_contours[contour_index - 1] + 1], 2);
                        midpoint.y = @divFloor(cur_point.y + glyph_outline.y_coord[glyph_outline.end_contours[contour_index - 1] + 1], 2);
                        try points.append(midpoint);
                    }
                    try points.append(.{
                        .x = glyph_outline.x_coord[glyph_outline.end_contours[contour_index - 1] + 1],
                        .y = glyph_outline.y_coord[glyph_outline.end_contours[contour_index - 1] + 1],
                    });
                }
                contour_index += 1;
                previous_point = null;
                previous_flag = false;
            } else {
                previous_point.?.x = cur_point.x;
                previous_point.?.y = cur_point.y;
                previous_flag = cur_flag;
            }
        }
        // var j: usize = 0;
        // var index: usize = 0;
        // var curves: std.ArrayList(BezierCurve) = std.ArrayList(BezierCurve).init(self.allocator);
        // for (0..glyph_outline.end_contours.len) |i| {
        //     const contour_start_index: usize = j;
        //     const points_start_index: usize = index;
        //     var contour_start: bool = true;
        //     var contour_started_off: bool = false;
        //     while (j < glyph_outline.end_contours[i]) : (j += 1) {
        //         const curr_flag = (glyph_outline.flags[i] & @intFromEnum(GlyphOutline.Flag.on_curve)) != 0;
        //         var x: i16 = glyph_outline.x_coord[j];
        //         var y: i16 = glyph_outline.y_coord[j];

        //         const contour_len: usize = glyph_outline.end_contours[i] - contour_start_index + 1;
        //         const next_index: usize = (j + 1 - contour_start_index) % contour_len + contour_start_index;

        //         if (curr_flag) {
        //             try points.append(.{ .x = x, .y = y });
        //             index += 1;
        //         } else {
        //             if (contour_start) {
        //                 contour_started_off = true;
        //                 if (glyph_outline.flags[next_index] & @intFromEnum(GlyphOutline.Flag.on_curve) != 0) {
        //                     try points.append(.{ .x = glyph_outline.x_coord[next_index], .y = glyph_outline.y_coord[next_index] });
        //                     index += 1;
        //                     j += 1;
        //                     continue;
        //                 }
        //                 x = x + @divFloor(glyph_outline.x_coord[next_index], 2);
        //                 y = y + @divFloor(glyph_outline.y_coord[next_index], 2);
        //                 try points.append(.{ .x = x, .y = y });
        //                 index += 1;
        //             }
        //             const p0: Point = points.items[index - 1];
        //             const p1: Point = .{ .x = x, .y = y };
        //             var p2: Point = .{ .x = glyph_outline.x_coord[next_index], .y = glyph_outline.y_coord[next_index] };
        //             if (glyph_outline.flags[next_index] & @intFromEnum(GlyphOutline.Flag.on_curve) == 0) {
        //                 p2.x = p1.x + @divFloor(p2.x - p1.x, 2);
        //                 p2.y = p1.y + @divFloor(p2.y - p1.y, 2);
        //             } else {
        //                 j += 1;
        //             }
        //             try curves.append(BezierCurve{
        //                 .p0 = .{ .x = p0.x, .y = p0.y },
        //                 .p1 = .{ .x = p1.x, .y = p1.y },
        //                 .p2 = .{ .x = p2.x, .y = p2.y },
        //             });
        //         }
        //         contour_start = false;
        //     }
        //     if (glyph_outline.flags[j - 1] & @intFromEnum(GlyphOutline.Flag.on_curve) != 0) {
        //         try points.append(.{ .x = points.items[points_start_index].x, .y = points.items[points_start_index].y });
        //         index += 1;
        //     }
        //     if (contour_started_off) {
        //         const p0: Point = points.items[index - 1];
        //         const p1: Point = .{ .x = glyph_outline.x_coord[contour_start_index], .y = glyph_outline.y_coord[contour_start_index] };
        //         const p2: Point = points.items[points_start_index];
        //         try curves.append(BezierCurve{
        //             .p0 = .{ .x = p0.x, .y = p0.y },
        //             .p1 = .{ .x = p1.x, .y = p1.y },
        //             .p2 = .{ .x = p2.x, .y = p2.y },
        //         });
        //     }
        // }
        var curves: std.ArrayList(BezierCurve) = std.ArrayList(BezierCurve).init(self.allocator);
        var i: usize = 0;
        std.debug.print("flags\n", .{});
        for (glyph_outline.flags) |flag| {
            std.debug.print("{d}\n", .{flag & @intFromEnum(GlyphOutline.Flag.on_curve)});
        }
        std.debug.print("{any} len {d}\n", .{ points.items, points.items.len });

        const height = glyph_outline.y_max - glyph_outline.y_min;
        while (i < points.items.len - 1) : (i += 2) {
            std.debug.print("i {d}\n", .{i});
            if (i + 2 >= points.items.len) break;
            try curves.append(BezierCurve{
                .p0 = .{ .x = points.items[i].x, .y = height - points.items[i].y },
                .p1 = .{ .x = points.items[i + 1].x, .y = height - points.items[i + 1].y },
                .p2 = .{ .x = points.items[i + 2].x, .y = height - points.items[i + 2].y },
            });
        }
        glyph_outline.curves = try curves.toOwnedSlice();
    }

    pub fn load(self: *Self, file_name: []const u8) !void {
        self.bit_reader = try BitReader.init(.{
            .file_name = file_name,
            .allocator = self.allocator,
        });
        try self.parse_file();
        self.char_map = std.AutoHashMap(u8, GlyphOutline).init(self.allocator);
        const alphabet = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";
        for (alphabet) |a| {
            var glyph_outline: ?GlyphOutline = self.get_glyph_outline(self.get_glyph_index(@as(u16, @intCast(a)))) catch null;
            if (glyph_outline != null) {
                std.debug.print("simple {c}\n", .{a});
                print_glyph_outline(&glyph_outline.?);
                std.debug.print("{any}\n", .{glyph_outline.?.x_coord});
                try self.gen_curves(&glyph_outline.?);
                try self.char_map.put(a, glyph_outline.?);
            } else {
                std.debug.print("compound {c}\n", .{a});
            }
        }
        self.bit_reader.deinit();
    }
};
