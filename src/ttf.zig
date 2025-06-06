const std = @import("std");
const common = @import("common");
const ByteStream = @import("image").ByteStream;
const BitReader = @import("image").BitReader;

//https://handmade.network/forums/articles/t/7330-implementing_a_font_reader_and_rasterizer_from_scratch%252C_part_1__ttf_font_reader.
//https://handmade.network/forums/wip/t/7610-reading_ttf_files_and_rasterizing_them_using_a_handmade_approach%252C_part_2__rasterization#23867
//https://stevehanov.ca/blog/index.php?id=143
//https://tchayen.github.io/posts/ttf-file-parsing
//https://learn.microsoft.com/en-us/typography/opentype/spec/
//https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6cmap.html

const TTF_LOG = std.log.scoped(.ttf);

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
        gpos: ?GPOS = undefined,
        glyf_offset: u32 = undefined,
        loca_offset: u32 = undefined,
        head_offset: u32 = undefined,
        head: Head = undefined,
        kern: ?Kern = undefined,
        hhea: Hhea = undefined,
        hmtx: Hmtx = undefined,
        maxp: Maxp = undefined,
    };
    pub const Maxp = struct {
        version: u32,
        num_glyphs: u16,
    };
    pub const Hhea = struct {
        major_version: u16,
        minor_version: u16,
        ascender: i16,
        descender: i16,
        line_gap: i16,
        advance_width_max: u16,
        min_left_side_bearing: i16,
        min_right_side_bearing: i16,
        x_max_extent: i16,
        caret_slope_rise: i16,
        caret_slope_run: i16,
        caret_offset: i16,
        reserved: i64,
        metric_data_format: i16,
        number_of_h_metrics: u16,
    };
    pub const Hmtx = struct {
        h_metrics: []LongHorMetric,
        left_side_bearings: ?[]i16 = null,
        pub const LongHorMetric = struct {
            advance_width: u16,
            lsb: i16,
        };
    };
    pub const Kern = struct {
        header: Header = undefined,
        sub_tables: []SubTable = undefined,
        pub const Header = struct {
            version: u16,
            n_tables: u16,
        };
        pub const SubTable = struct {
            version: u16,
            length: u16,
            coverage: u16,
            kern_subtable_format0: KernSubtableFormat0,
            pub const Coverage = enum(u16) {
                horizontal = 1,
                minimum = 2,
                cross_stream = 4,
                override = 8,
                reserved = 0x00F0,
                format = 0xFF00,
            };
            pub const KernSubtableFormat0 = struct {
                n_pairs: u16,
                search_range: u16,
                entry_selector: u16,
                range_shift: u16,
                kern_pairs: []KernPair,
                pub const KernPair = struct {
                    left: u16,
                    right: u16,
                    value: i16,
                };
            };
        };
    };
    pub const GPOS = struct {
        header: Header = undefined,
        script_list: ScriptList = undefined,
        lookup_list: LookupList = undefined,
        feature_list: FeatureList = undefined,
        pub const Header = struct { major_version: u16, minor_version: u16, script_list_offset: u16, feature_list_offset: u16, lookup_list_offset: u16, feature_variations_offset: ?u32 = null };
        pub const ScriptList = struct {
            script_count: u16,
            script_records: []ScriptRecord,
            pub const ScriptRecord = struct {
                script_tag: [4]u8,
                script_offset: u16,
                script_table: ScriptTable,
                pub const ScriptTable = struct {
                    default_lang_sys_offset: u16,
                    lang_sys_count: u16,
                    lang_sys_records: []LangSysRecord,
                    pub const LangSysRecord = struct {
                        lang_sys_tag: [4]u8,
                        lang_sys_offset: u16,
                        lang_sys: LangSys,
                        pub const LangSys = struct {
                            lookup_order_offset: u16,
                            required_feature_index: u16,
                            feature_index_count: u16,
                            feature_indicies: []u16,
                        };
                    };
                };
            };
        };
        pub const FeatureList = struct {
            feature_count: u16,
            feature_records: []FeatureRecord,
            pub const FeatureRecord = struct {
                feature_tag: [4]u8,
                feature_offset: u16,
                feature_params_offset: u16,
                lookup_index_count: u16,
                lookup_list_indicies: []u16,
            };
        };
        pub const LookupList = struct {
            lookup_count: u16,
            lookups: []Lookup,
            pub const Lookup = struct {
                lookup_offset: u16,
                lookup_type: u16,
                lookup_flag: u16,
                subtable_count: u16,
                subtables: []SubTable,
                pub const SubTable = struct {
                    offset: u16,
                    single_pos_format: ?SinglePosFormat = null,
                    pair_pos_format: ?PairPosFormat = null,
                    cursive_pos_format: ?CursivePosFormat = null,
                    mark_base_pos_format: ?MarkBasePosFormat = null,
                    mark_lig_pos_format: ?MarkLigPosFormat = null,
                    mark_mark_pos_format: ?MarkMarkPosFormat = null,
                    sequence_context_format: ?SequenceContextFormat = null,
                    chained_sequence_context_format: ?ChainedSequenceContextFormat = null,
                    pos_extension_format: ?PosExtensionFormat = null,
                    pub fn adjustment(self: *SubTable, lhs_index: usize, rhs_index: usize, lookup_type: u16) ?Point {
                        switch (lookup_type) {
                            1 => {
                                return self.single_pos_format.?.adjustment(lhs_index, rhs_index);
                            },
                            2 => {
                                return self.pair_pos_format.?.adjustment(lhs_index, rhs_index);
                            },
                            3 => {
                                return self.cursive_pos_format.?.adjustment(lhs_index, rhs_index);
                            },
                            4 => {
                                return self.mark_base_pos_format.?.adjustment(lhs_index, rhs_index);
                            },
                            5 => {
                                return self.mark_lig_pos_format.?.adjustment(lhs_index, rhs_index);
                            },
                            6 => {
                                return self.mark_mark_pos_format.?.adjustment(lhs_index, rhs_index);
                            },
                            7 => {
                                return self.sequence_context_format.?.adjustment(lhs_index, rhs_index);
                            },
                            8 => {
                                return self.chained_sequence_context_format.?.adjustment(lhs_index, rhs_index);
                            },
                            9 => {
                                return self.adjustment(lhs_index, rhs_index, self.pos_extension_format.?.extension_lookup_type);
                            },
                            else => return null,
                        }
                    }
                };
            };
        };

        pub const Coverage = struct {
            format: u16 = 0,
            glyph_count: ?u16 = null,
            glyph_array: ?[]u16 = null,
            range_count: ?u16 = null,
            range_records: ?[]RangeRecord = null,
            pub const RangeRecord = struct { start_glyph_id: u16, end_glyph_id: u16, start_coverage_index: u16 };
            pub fn deinit(self: *Coverage, allocator: std.mem.Allocator) void {
                if (self.format == 1) {
                    allocator.free(self.glyph_array.?);
                } else if (self.format == 2) {
                    allocator.free(self.range_records.?);
                }
            }
            pub fn read(self: *Coverage, bit_reader: *BitReader, offset: u32, allocator: std.mem.Allocator) Error!void {
                bit_reader.setPos(offset);
                self.format = try bit_reader.read(u16);
                if (self.format == 1) {
                    self.glyph_count = try bit_reader.read(u16);
                    self.glyph_array = try allocator.alloc(u16, self.glyph_count.?);
                    for (0..self.glyph_array.?.len) |k| {
                        self.glyph_array.?[k] = try bit_reader.read(u16);
                    }
                } else {
                    self.range_count = try bit_reader.read(u16);
                    self.range_records = try allocator.alloc(GPOS.Coverage.RangeRecord, self.range_count.?);
                    for (0..self.range_records.?.len) |k| {
                        self.range_records.?[k].start_glyph_id = try bit_reader.read(u16);
                        self.range_records.?[k].end_glyph_id = try bit_reader.read(u16);
                        self.range_records.?[k].start_coverage_index = try bit_reader.read(u16);
                    }
                }
            }
            pub fn print(self: *Coverage) void {
                if (self.format == 1) {
                    TTF_LOG.info("Coverage Table format = {d}, glyph_count = {d}, glyph_array = {any}\n", .{ self.format, self.glyph_count.?, self.glyph_array.? });
                } else if (self.format == 2) {
                    TTF_LOG.info("Coverage Table format = {d}, range_count = {d}\n", .{ self.format, self.range_count.? });
                    for (0..self.range_records.?.len) |k| {
                        TTF_LOG.info("RangeRecord start_glyph_id = {d}, end_glyph_id = {d}, start_coverage_index = {d}\n", .{ self.range_records.?[k].start_glyph_id, self.range_records.?[k].end_glyph_id, self.range_records.?[k].start_coverage_index });
                    }
                }
            }
            fn search_index(self: *Coverage, index: usize) ?usize {
                if (self.format == 1) {
                    var low: usize = 0;
                    var high: usize = self.glyph_array.?.len - 1;
                    while (low <= high) {
                        const mid = low + (high - low) / 2;
                        if (self.glyph_array.?[mid] == index) return mid;
                        if (self.glyph_array.?[mid] < index) {
                            low = mid + 1;
                        } else {
                            if (mid == 0) break;
                            high = mid - 1;
                        }
                    }
                    return null;
                } else {
                    var low: usize = 0;
                    var high: usize = self.range_records.?.len - 1;
                    while (low <= high) {
                        const mid = low + (high - low) / 2;
                        if (self.range_records.?[mid].end_glyph_id < index) {
                            low = mid + 1;
                        } else if (self.range_records.?[mid].start_glyph_id > index) {
                            if (mid == 0) break;
                            high = mid - 1;
                        } else {
                            return self.range_records.?[mid].start_coverage_index + index - self.range_records.?[mid].start_glyph_id;
                        }
                    }
                    return null;
                }
            }
        };
        pub const SinglePosFormat = struct {
            format: u16 = undefined,
            coverage_offset: u16 = undefined,
            value_format: u16 = undefined,
            value_record: ?ValueRecord = null,
            value_count: ?u16 = null,
            value_records: ?[]ValueRecord = null,
            coverage: Coverage = undefined,
            pub fn init() SinglePosFormat {
                return SinglePosFormat{};
            }
            pub fn read(self: *SinglePosFormat, bit_reader: *BitReader, offset: u32, allocator: std.mem.Allocator) Error!void {
                bit_reader.setPos(offset);
                self.format = try bit_reader.read(u16);
                self.coverage_offset = try bit_reader.read(u16);
                self.value_format = try bit_reader.read(u16);
                TTF_LOG.info("SinglePosFormat format = {d}, coverage_offset = {d}, value_format = {d}\n", .{ self.format, self.coverage_offset, self.value_format });
                if (self.format == 1) {
                    self.value_records = null;
                    self.value_count = null;
                    self.value_record = GPOS.ValueRecord.init();
                    try self.value_record.?.read(bit_reader, self.value_format);
                    TTF_LOG.info("ValueRecord = {any}\n", .{self.value_record});
                } else if (self.format == 2) {
                    self.value_record = null;
                    self.value_count = try bit_reader.read(u16);
                    self.value_records = try allocator.alloc(GPOS.ValueRecord, self.value_count.?);
                    TTF_LOG.info("ValueRecords count = {any}\n", .{self.value_count});
                    for (0..self.value_records.?.len) |i| {
                        self.value_records.?[i] = GPOS.ValueRecord.init();
                        try self.value_records.?[i].read(bit_reader, self.value_format);
                        TTF_LOG.info("ValueRecord = {any}\n", .{self.value_records.?[i]});
                    }
                }
                try self.coverage.read(bit_reader, offset + self.coverage_offset, allocator);
            }
            pub fn print(self: *SinglePosFormat) void {
                TTF_LOG.info("SinglePosFormat format = {d}, coverage_offset = {d}, value_format = {d}\n", .{ self.format, self.coverage_offset, self.value_format });
                self.coverage.print();
                if (self.format == 1) {
                    TTF_LOG.info("ValueRecord = {any}\n", .{self.value_record});
                } else if (self.format == 2) {
                    TTF_LOG.info("ValueRecords count = {any}\n", .{self.value_count});
                    for (0..self.value_records.?.len) |i| {
                        TTF_LOG.info("ValueRecord = {any}\n", .{self.value_records.?[i]});
                    }
                }
            }
            pub fn deinit(self: *SinglePosFormat, allocator: std.mem.Allocator) void {
                if (self.format == 2) {
                    allocator.free(self.value_records.?);
                }
                self.coverage.deinit(allocator);
            }
            pub fn adjustment(self: *SinglePosFormat, _: usize, rhs_index: usize) ?Point {
                if (self.coverage.search_index(rhs_index)) |coverage_index| {
                    var ret: ?Point = null;
                    if (self.format == 1) {
                        TTF_LOG.info("record {any}\n", .{self.value_record});
                        if (self.value_record) |record| {
                            ret = Point{};
                            ret.?.x += record.x_placement + record.x_advance;
                            ret.?.y += record.y_placement + record.y_advance;
                        }
                    } else {
                        TTF_LOG.info("coverage_index {d} record {any}\n", .{ coverage_index, self.value_records.?[coverage_index] });
                        const record = self.value_records.?[coverage_index];
                        ret = Point{};
                        ret.?.x += record.x_placement + record.x_advance;
                        ret.?.y += record.y_placement + record.y_advance;
                    }
                    return ret;
                } else return null;
            }
        };
        pub const PairPosFormat = struct {
            format: u16 = undefined,
            coverage_offset: u16 = undefined,
            value_format1: u16 = undefined,
            value_format2: u16 = undefined,
            pair_set_count: ?u16 = null,
            class_def1_offset: ?u16 = null,
            class_def2_offset: ?u16 = null,
            class1_count: ?u16 = null,
            class2_count: ?u16 = null,
            class1_records: ?[]Class1 = null,
            pair_set_records: ?[]PairSet = null,
            class_def1: ClassDefFormat = undefined,
            class_def2: ClassDefFormat = undefined,
            coverage: Coverage = undefined,
            pub const Class1 = struct {
                class2_records: []Class2 = undefined,
            };
            pub const Class2 = struct {
                value_record1: ?ValueRecord = null,
                value_record2: ?ValueRecord = null,
            };
            pub const PairSet = struct {
                pair_set_offset: u16 = undefined,
                pair_value_count: u16 = undefined,
                pair_value_records: []PairValue = undefined,
                pub const PairValue = struct {
                    second_glyph: u16 = undefined,
                    value_record1: ?ValueRecord = undefined,
                    value_record2: ?ValueRecord = undefined,
                };
                pub fn search(self: *PairSet, index: usize) ?usize {
                    var low: usize = 0;
                    var high: usize = self.pair_value_records.len - 1;
                    while (low <= high) {
                        const mid = low + (high - low) / 2;
                        if (self.pair_value_records[mid].second_glyph == index) return mid;
                        if (self.pair_value_records[mid].second_glyph < index) {
                            low = mid + 1;
                        } else {
                            if (mid == 0) break;
                            high = mid - 1;
                        }
                    }
                    return null;
                }
            };
            pub fn init() PairPosFormat {
                return PairPosFormat{};
            }
            pub fn read(self: *PairPosFormat, bit_reader: *BitReader, offset: u32, allocator: std.mem.Allocator) Error!void {
                bit_reader.setPos(offset);
                self.format = try bit_reader.read(u16);
                self.coverage_offset = try bit_reader.read(u16);
                self.value_format1 = try bit_reader.read(u16);
                self.value_format2 = try bit_reader.read(u16);
                if (self.format == 1) {
                    self.pair_set_count = try bit_reader.read(u16);
                    self.pair_set_records = try allocator.alloc(GPOS.PairPosFormat.PairSet, self.pair_set_count.?);
                    for (0..self.pair_set_records.?.len) |i| {
                        self.pair_set_records.?[i].pair_set_offset = try bit_reader.read(u16);
                    }
                    for (0..self.pair_set_records.?.len) |i| {
                        bit_reader.setPos(offset + self.pair_set_records.?[i].pair_set_offset);
                        self.pair_set_records.?[i].pair_value_count = try bit_reader.read(u16);
                        self.pair_set_records.?[i].pair_value_records = try allocator.alloc(GPOS.PairPosFormat.PairSet.PairValue, self.pair_set_records.?[i].pair_value_count);
                        for (0..self.pair_set_records.?[i].pair_value_records.len) |j| {
                            self.pair_set_records.?[i].pair_value_records[j].second_glyph = try bit_reader.read(u16);
                            if (self.value_format1 != 0) {
                                self.pair_set_records.?[i].pair_value_records[j].value_record1 = GPOS.ValueRecord.init();
                                try self.pair_set_records.?[i].pair_value_records[j].value_record1.?.read(bit_reader, self.value_format1);
                            } else {
                                self.pair_set_records.?[i].pair_value_records[j].value_record1 = null;
                            }
                            if (self.value_format2 != 0) {
                                self.pair_set_records.?[i].pair_value_records[j].value_record2 = GPOS.ValueRecord.init();
                                try self.pair_set_records.?[i].pair_value_records[j].value_record2.?.read(bit_reader, self.value_format2);
                            } else {
                                self.pair_set_records.?[i].pair_value_records[j].value_record2 = null;
                            }
                        }
                    }
                } else {
                    self.class_def1_offset = try bit_reader.read(u16);
                    self.class_def2_offset = try bit_reader.read(u16);
                    self.class1_count = try bit_reader.read(u16);
                    self.class2_count = try bit_reader.read(u16);
                    self.class1_records = try allocator.alloc(GPOS.PairPosFormat.Class1, self.class1_count.?);
                    for (0..self.class1_records.?.len) |i| {
                        self.class1_records.?[i].class2_records = try allocator.alloc(GPOS.PairPosFormat.Class2, self.class2_count.?);
                        for (0..self.class1_records.?[i].class2_records.len) |j| {
                            if (self.value_format1 != 0) {
                                self.class1_records.?[i].class2_records[j].value_record1 = GPOS.ValueRecord.init();
                                try self.class1_records.?[i].class2_records[j].value_record1.?.read(bit_reader, self.value_format1);
                            } else {
                                self.class1_records.?[i].class2_records[j].value_record1 = null;
                            }
                            if (self.value_format2 != 0) {
                                self.class1_records.?[i].class2_records[j].value_record2 = GPOS.ValueRecord.init();
                                try self.class1_records.?[i].class2_records[j].value_record2.?.read(bit_reader, self.value_format2);
                            } else {
                                self.class1_records.?[i].class2_records[j].value_record2 = null;
                            }
                        }
                    }
                    bit_reader.setPos(offset + self.class_def1_offset.?);
                    self.class_def1.format = try bit_reader.read(u16);
                    if (self.class_def1.format == 1) {
                        self.class_def1.start_glyph_id = try bit_reader.read(u16);
                        self.class_def1.glyph_count = try bit_reader.read(u16);
                        self.class_def1.class_values = try allocator.alloc(u16, self.class_def1.glyph_count.?);
                        for (0..self.class_def1.class_values.?.len) |i| {
                            self.class_def1.class_values.?[i] = try bit_reader.read(u16);
                        }
                        self.class_def1.class_range_count = null;
                        self.class_def1.class_range_records = null;
                    } else {
                        self.class_def1.start_glyph_id = null;
                        self.class_def1.glyph_count = null;
                        self.class_def1.class_values = null;
                        self.class_def1.class_range_count = try bit_reader.read(u16);
                        self.class_def1.class_range_records = try allocator.alloc(GPOS.ClassDefFormat.ClassRange, self.class_def1.class_range_count.?);
                        for (0..self.class_def1.class_range_records.?.len) |i| {
                            self.class_def1.class_range_records.?[i].start_glyph_id = try bit_reader.read(u16);
                            self.class_def1.class_range_records.?[i].end_glyph_id = try bit_reader.read(u16);
                            self.class_def1.class_range_records.?[i].class = try bit_reader.read(u16);
                        }
                    }
                    bit_reader.setPos(offset + self.class_def2_offset.?);
                    self.class_def2.format = try bit_reader.read(u16);
                    if (self.class_def2.format == 1) {
                        self.class_def2.start_glyph_id = try bit_reader.read(u16);
                        self.class_def2.glyph_count = try bit_reader.read(u16);
                        self.class_def2.class_values = try allocator.alloc(u16, self.class_def2.glyph_count.?);
                        for (0..self.class_def2.class_values.?.len) |i| {
                            self.class_def2.class_values.?[i] = try bit_reader.read(u16);
                        }
                        self.class_def2.class_range_count = null;
                        self.class_def2.class_range_records = null;
                    } else {
                        self.class_def2.start_glyph_id = null;
                        self.class_def2.glyph_count = null;
                        self.class_def2.class_values = null;
                        self.class_def2.class_range_count = try bit_reader.read(u16);
                        self.class_def2.class_range_records = try allocator.alloc(GPOS.ClassDefFormat.ClassRange, self.class_def2.class_range_count.?);
                        for (0..self.class_def2.class_range_records.?.len) |i| {
                            self.class_def2.class_range_records.?[i].start_glyph_id = try bit_reader.read(u16);
                            self.class_def2.class_range_records.?[i].end_glyph_id = try bit_reader.read(u16);
                            self.class_def2.class_range_records.?[i].class = try bit_reader.read(u16);
                        }
                    }
                }

                try self.coverage.read(bit_reader, offset + self.coverage_offset, allocator);
            }
            pub fn deinit(self: *PairPosFormat, allocator: std.mem.Allocator) void {
                if (self.format == 1) {
                    for (0..self.pair_set_records.?.len) |k| {
                        allocator.free(self.pair_set_records.?[k].pair_value_records);
                    }
                    allocator.free(self.pair_set_records.?);
                } else {
                    for (0..self.class1_records.?.len) |k| {
                        allocator.free(self.class1_records.?[k].class2_records);
                    }
                    allocator.free(self.class1_records.?);
                    if (self.class_def1.class_range_records != null) {
                        allocator.free(self.class_def1.class_range_records.?);
                    }
                    if (self.class_def1.class_values != null) {
                        allocator.free(self.class_def1.class_values.?);
                    }
                    if (self.class_def2.class_range_records != null) {
                        allocator.free(self.class_def2.class_range_records.?);
                    }
                    if (self.class_def2.class_values != null) {
                        allocator.free(self.class_def2.class_values.?);
                    }
                }

                self.coverage.deinit(allocator);
            }
            pub fn print(self: *PairPosFormat) void {
                if (self.format == 1) {
                    TTF_LOG.info("PairPosFormat format = {d}, coverage_offset = {d}, value_format1 = {d}, value_format2 = {d}, pairset_count = {d}\n", .{ self.format, self.coverage_offset, self.value_format1, self.value_format2, self.pair_set_count.? });
                    self.coverage.print();
                    for (0..self.pair_set_records.?.len) |i| {
                        TTF_LOG.info("Pairset offset = {d}, count = {d}\n", .{ self.pair_set_records.?[i].pair_set_offset, self.pair_set_records.?[i].pair_value_count });
                        TTF_LOG.info("PairValue records\n", .{});
                        for (0..self.pair_set_records.?[i].pair_value_records.len) |j| {
                            TTF_LOG.info("value_record1 = {any}, value_record2 = {any}\n", .{ self.class1_records.?[i].class2_records[j].value_record1, self.class1_records.?[i].class2_records[j].value_record2 });
                        }
                    }
                } else {
                    TTF_LOG.info("PairPosFormat format = {d}, coverage_offset = {d}, value_format1 = {d}, value_format2 = {d}, class_def1_offset = {d}, class_def2_offset = {d}, class1_count = {d}, class2_count = {d}\n", .{ self.format, self.coverage_offset, self.value_format1, self.value_format2, self.class_def1_offset.?, self.class_def2_offset.?, self.class1_count.?, self.class2_count.? });
                    self.coverage.print();
                    for (0..self.class1_records.?.len) |i| {
                        TTF_LOG.info("Class Records\n", .{});
                        for (0..self.class1_records.?[i].class2_records.len) |j| {
                            TTF_LOG.info("value_record1 = {any}, value_record2 = {any}\n", .{ self.class1_records.?[i].class2_records[j].value_record1, self.class1_records.?[i].class2_records[j].value_record2 });
                        }
                    }
                    TTF_LOG.info("ClassDef1 format = {d}, start_glyph_id = {any}, glyph_count = {any}, class_values = {any}, class_range_count = {any}\n", .{ self.class_def1.format, self.class_def1.start_glyph_id, self.class_def1.glyph_count, self.class_def1.class_values, self.class_def1.class_range_count });
                    if (self.class_def1.class_range_records != null) {
                        for (0..self.class_def1.class_range_records.?.len) |i| {
                            TTF_LOG.info("ClassRange start_glyph_id = {d}, end_glyph_id = {d}, class = {d}\n", .{ self.class_def1.class_range_records.?[i].start_glyph_id, self.class_def1.class_range_records.?[i].end_glyph_id, self.class_def1.class_range_records.?[i].class });
                        }
                    }
                    TTF_LOG.info("ClassDef2 format = {d}, start_glyph_id = {any}, glyph_count = {any}, class_values = {any}, class_range_count = {any}\n", .{ self.class_def2.format, self.class_def2.start_glyph_id, self.class_def2.glyph_count, self.class_def2.class_values, self.class_def2.class_range_count });
                    if (self.class_def2.class_range_records != null) {
                        for (0..self.class_def2.class_range_records.?.len) |i| {
                            TTF_LOG.info("ClassRange start_glyph_id = {d}, end_glyph_id = {d}, class = {d}\n", .{ self.class_def2.class_range_records.?[i].start_glyph_id, self.class_def2.class_range_records.?[i].end_glyph_id, self.class_def2.class_range_records.?[i].class });
                        }
                    }
                }
            }
            pub fn adjustment(self: *PairPosFormat, lhs_index: usize, rhs_index: usize) ?Point {
                //TODO need both values
                if (self.coverage.search_index(lhs_index)) |coverage_index| {
                    var ret: ?Point = null;
                    if (self.format == 1) {
                        const pair_value_index = self.pair_set_records.?[coverage_index].search(rhs_index) orelse return null;
                        const pair_value = self.pair_set_records.?[coverage_index].pair_value_records[pair_value_index];
                        TTF_LOG.info("pair value found {any}\n", .{pair_value});
                        if (pair_value.value_record2) |record| {
                            ret = Point{};
                            ret.?.x += record.x_placement + record.x_advance;
                            ret.?.y += record.y_placement + record.y_advance;
                        }
                    } else {
                        const lhs_class = self.class_def1.search_index(lhs_index) orelse return null;
                        const rhs_class = self.class_def2.search_index(rhs_index) orelse return null;
                        TTF_LOG.info("lhs_class {d}, rhs_class {d}, record {any}\n", .{ lhs_class, rhs_class, self.class1_records.?[lhs_class].class2_records[rhs_class] });
                        if (self.class1_records.?[lhs_class].class2_records[rhs_class].value_record2) |record| {
                            ret = Point{};
                            ret.?.x += record.x_placement + record.x_advance;
                            ret.?.y += record.y_placement + record.y_advance;
                        }
                    }
                    return ret;
                } else return null;
            }
        };
        pub const CursivePosFormat = struct {
            format: u16 = undefined,
            coverage_offset: u16 = undefined,
            entry_exit_count: u16 = undefined,
            entry_exit_records: []EntryExit = undefined,
            coverage: Coverage = undefined,
            pub const EntryExit = struct {
                entry_anchor_offset: ?u16 = null,
                exit_anchor_offset: ?u16 = null,
            };
            pub fn init() CursivePosFormat {
                return CursivePosFormat{};
            }
            pub fn read(self: *CursivePosFormat, bit_reader: *BitReader, offset: u32, allocator: std.mem.Allocator) Error!void {
                bit_reader.setPos(offset);
                self.format = try bit_reader.read(u16);
                self.coverage_offset = try bit_reader.read(u16);
                self.entry_exit_count = try bit_reader.read(u16);
                self.entry_exit_records = try allocator.alloc(GPOS.CursivePosFormat.EntryExit, self.entry_exit_count);
                for (0..self.entry_exit_records.len) |i| {
                    self.entry_exit_records[i].entry_anchor_offset = try bit_reader.read(u16);
                    self.entry_exit_records[i].exit_anchor_offset = try bit_reader.read(u16);
                }

                //TODO grab anchor tables, need cursive font example
                try self.coverage.read(bit_reader, offset + self.coverage_offset, allocator);
            }
            pub fn deinit(self: *CursivePosFormat, allocator: std.mem.Allocator) void {
                allocator.free(self.entry_exit_records);
                self.coverage.deinit(allocator);
            }
            pub fn print(self: *CursivePosFormat) void {
                TTF_LOG.info("CursivePosFormat format = {d}, coverage_offset = {d}, entry_exit_count = {d}\n", .{ self.format, self.coverage_offset, self.entry_exit_count });
                self.coverage.print();
                for (0..self.entry_exit_records.len) |i| {
                    TTF_LOG.info("EntryExit {any}\n", .{self.entry_exit_records[i]});
                }
            }
            pub fn adjustment(self: *CursivePosFormat, lhs_index: usize, rhs_index: usize) ?Point {
                _ = self;
                _ = lhs_index;
                _ = rhs_index;
                //TODO
                return null;
            }
        };
        pub const MarkBasePosFormat = struct {
            format: u16 = undefined,
            mark_coverage_offset: u16 = undefined,
            base_coverage_offset: u16 = undefined,
            mark_class_count: u16 = undefined,
            mark_array_offset: u16 = undefined,
            base_array_offset: u16 = undefined,
            base_array: BaseArray = undefined,
            mark_array: MarkArray = undefined,
            base_coverage: Coverage = undefined,
            mark_coverage: Coverage = undefined,
            pub const BaseArray = struct {
                base_count: u16 = undefined,
                base_records: []BaseRecord = undefined,
                base_anchor_offsets: []?u16,
                pub const BaseRecord = struct {
                    base_anchors: []Anchor,
                };
            };
            pub fn init() MarkBasePosFormat {
                return MarkBasePosFormat{};
            }
            pub fn read(self: *MarkBasePosFormat, bit_reader: *BitReader, offset: u32, allocator: std.mem.Allocator) Error!void {
                bit_reader.setPos(offset);
                self.format = try bit_reader.read(u16);
                self.mark_coverage_offset = try bit_reader.read(u16);
                self.base_coverage_offset = try bit_reader.read(u16);
                self.mark_class_count = try bit_reader.read(u16);
                self.mark_array_offset = try bit_reader.read(u16);
                self.base_array_offset = try bit_reader.read(u16);

                bit_reader.setPos(offset + self.base_array_offset);
                self.base_array.base_count = try bit_reader.read(u16);
                self.base_array.base_records = try allocator.alloc(GPOS.MarkBasePosFormat.BaseArray.BaseRecord, self.base_array.base_count);
                self.base_array.base_anchor_offsets = try allocator.alloc(?u16, self.mark_class_count);
                for (0..self.base_array.base_anchor_offsets.len) |i| {
                    self.base_array.base_anchor_offsets[i] = try bit_reader.read(u16);
                }

                for (0..self.base_array.base_records.len) |i| {
                    self.base_array.base_records[i].base_anchors = try allocator.alloc(GPOS.Anchor, self.mark_class_count);
                }

                for (0..self.base_array.base_anchor_offsets.len) |i| {
                    bit_reader.setPos(offset + self.base_array_offset + self.base_array.base_anchor_offsets[i].?);
                    for (0..self.base_array.base_records.len) |j| {
                        try self.base_array.base_records[j].base_anchors[i].read(bit_reader);
                    }
                }

                try self.mark_array.read(bit_reader, offset + self.mark_array_offset, allocator);

                try self.base_coverage.read(bit_reader, offset + self.base_coverage_offset, allocator);
                try self.mark_coverage.read(bit_reader, offset + self.mark_coverage_offset, allocator);
            }
            pub fn deinit(self: *MarkBasePosFormat, allocator: std.mem.Allocator) void {
                for (0..self.base_array.base_records.len) |i| {
                    allocator.free(self.base_array.base_records[i].base_anchors);
                }
                allocator.free(self.base_array.base_anchor_offsets);
                allocator.free(self.base_array.base_records);
                self.base_coverage.deinit(allocator);
                self.mark_coverage.deinit(allocator);
                self.mark_array.deinit(allocator);
            }
            pub fn print(self: *MarkBasePosFormat) void {
                TTF_LOG.info("MarkBasePosFormat format = {d}, class_count = {d}\n", .{ self.format, self.mark_class_count });
                TTF_LOG.info("BaseCoverage\n", .{});
                self.base_coverage.print();
                TTF_LOG.info("MarkCoverage\n", .{});
                self.mark_coverage.print();
                TTF_LOG.info("BaseArray base_count = {d}\n", .{self.base_array.base_count});
                for (0..self.base_array.base_anchor_offsets.len) |i| {
                    for (0..self.base_array.base_records.len) |j| {
                        TTF_LOG.info("BaseAnchor = {any}\n", .{self.base_array.base_records[j].base_anchors[i]});
                    }
                }

                self.mark_array.print();
            }
            pub fn adjustment(self: *MarkBasePosFormat, lhs_index: usize, rhs_index: usize) ?Point {
                _ = self;
                _ = lhs_index;
                _ = rhs_index;
                //TODO
                return null;
            }
        };
        pub const MarkLigPosFormat = struct {
            format: u16 = undefined,
            mark_coverage_offset: u16 = undefined,
            ligature_coverage_offset: u16 = undefined,
            mark_class_count: u16 = undefined,
            mark_array_offset: u16 = undefined,
            ligature_array_offset: u16 = undefined,
            lig_coverage: Coverage = undefined,
            mark_coverage: Coverage = undefined,
            lig_array: LigatureArray = undefined,
            mark_array: MarkArray = undefined,
            pub const LigatureArray = struct {
                ligature_count: u16 = undefined,
                ligature_attach: []LigatureAttach,
                pub fn read(self: *LigatureArray, bit_reader: *BitReader, offset: u32, class_count: u16, allocator: std.mem.Allocator) Error!void {
                    bit_reader.setPos(offset);
                    self.ligature_count = try bit_reader.read(u16);
                    self.ligature_attach = try allocator.alloc(LigatureAttach, self.ligature_count);
                    for (0..self.ligature_attach.len) |i| {
                        self.ligature_attach[i].offset = try bit_reader.read(u16);
                    }
                    for (0..self.ligature_attach.len) |i| {
                        try self.ligature_attach[i].read(bit_reader, offset, class_count, allocator);
                    }
                }
                pub fn deinit(self: *LigatureArray, allocator: std.mem.Allocator) void {
                    for (0..self.ligature_attach.len) |i| {
                        self.ligature_attach[i].deinit(allocator);
                    }
                    allocator.free(self.ligature_attach);
                }
                pub fn print(self: *LigatureArray) void {
                    TTF_LOG.info("LigatureArray count = {d}\n", .{self.ligature_count});
                    for (0..self.ligature_attach.len) |i| {
                        self.ligature_attach[i].print();
                    }
                }
            };
            pub const LigatureAttach = struct {
                offset: u16 = undefined,
                component_count: u16 = undefined,
                component_records: []ComponentRecord = undefined,
                pub const ComponentRecord = struct {
                    anchor_offsets: []?u16 = undefined,
                    anchors: []Anchor,
                    pub fn read(
                        self: *ComponentRecord,
                        bit_reader: *BitReader,
                        offset: u32,
                    ) Error!void {
                        for (0..self.anchors.len) |i| {
                            bit_reader.setPos(offset + self.anchor_offsets[i].?);
                            try self.anchors[i].read(bit_reader);
                        }
                    }
                    pub fn print(self: *ComponentRecord) void {
                        TTF_LOG.info("ComponentRecord\n", .{});
                        for (0..self.anchors.len) |i| {
                            TTF_LOG.info("offset = {d}, anchor = {any}\n", .{ self.anchor_offsets[i].?, self.anchors[i] });
                        }
                    }
                };
                pub fn read(self: *LigatureAttach, bit_reader: *BitReader, offset: u32, class_count: u16, allocator: std.mem.Allocator) Error!void {
                    bit_reader.setPos(offset + self.offset);
                    self.component_count = try bit_reader.read(u16);
                    self.component_records = try allocator.alloc(ComponentRecord, self.component_count);
                    for (0..self.component_records.len) |i| {
                        self.component_records[i].anchor_offsets = try allocator.alloc(?u16, class_count);
                        self.component_records[i].anchors = try allocator.alloc(Anchor, class_count);
                    }
                    for (0..self.component_records.len) |i| {
                        for (0..self.component_records[i].anchor_offsets.len) |j| {
                            self.component_records[i].anchor_offsets[j] = try bit_reader.read(u16);
                        }
                    }
                    for (0..self.component_records.len) |i| {
                        try self.component_records[i].read(bit_reader, offset + self.offset);
                    }
                }
                pub fn deinit(self: *LigatureAttach, allocator: std.mem.Allocator) void {
                    for (0..self.component_records.len) |i| {
                        allocator.free(self.component_records[i].anchor_offsets);
                        allocator.free(self.component_records[i].anchors);
                    }
                    allocator.free(self.component_records);
                }
                pub fn print(self: *LigatureAttach) void {
                    TTF_LOG.info("LigatureAttach offset = {d}, component_count = {d}\n", .{ self.offset, self.component_count });
                    for (0..self.component_records.len) |i| {
                        self.component_records[i].print();
                    }
                }
            };
            pub fn init() MarkLigPosFormat {
                return MarkLigPosFormat{};
            }
            pub fn read(self: *MarkLigPosFormat, bit_reader: *BitReader, offset: u32, allocator: std.mem.Allocator) Error!void {
                bit_reader.setPos(offset);
                self.format = try bit_reader.read(u16);
                self.mark_coverage_offset = try bit_reader.read(u16);
                self.ligature_coverage_offset = try bit_reader.read(u16);
                self.mark_class_count = try bit_reader.read(u16);
                self.mark_array_offset = try bit_reader.read(u16);
                self.ligature_array_offset = try bit_reader.read(u16);

                try self.lig_array.read(bit_reader, offset + self.ligature_array_offset, self.mark_class_count, allocator);
                try self.mark_array.read(bit_reader, offset + self.mark_array_offset, allocator);
                try self.lig_coverage.read(bit_reader, offset + self.ligature_coverage_offset, allocator);
                try self.mark_coverage.read(bit_reader, offset + self.mark_coverage_offset, allocator);
            }
            pub fn deinit(self: *MarkLigPosFormat, allocator: std.mem.Allocator) void {
                self.lig_array.deinit(allocator);
                self.mark_array.deinit(allocator);
                self.lig_coverage.deinit(allocator);
                self.mark_coverage.deinit(allocator);
            }

            pub fn print(self: *MarkLigPosFormat) void {
                TTF_LOG.info("MarkLigPosFormat format = {d}, class_count = {d}\n", .{ self.format, self.mark_class_count });
                TTF_LOG.info("LigCoverage\n", .{});
                self.lig_coverage.print();
                TTF_LOG.info("MarkCoverage\n", .{});
                self.mark_coverage.print();
                self.lig_array.print();
                self.mark_array.print();
            }
            pub fn adjustment(self: *MarkLigPosFormat, lhs_index: usize, rhs_index: usize) ?Point {
                _ = self;
                _ = lhs_index;
                _ = rhs_index;
                //TODO
                return null;
            }
        };
        pub const MarkMarkPosFormat = struct {
            format: u16 = undefined,
            mark1_coverage_offset: u16 = undefined,
            mark2_coverage_offset: u16 = undefined,
            mark_class_count: u16 = undefined,
            mark1_array_offset: u16 = undefined,
            mark2_array_offset: u16 = undefined,
            mark1_array: MarkArray = undefined,
            mark2_array: Mark2Array = undefined,
            mark1_coverage: Coverage = undefined,
            mark2_coverage: Coverage = undefined,
            pub const Mark2Array = struct {
                mark2_count: u16 = undefined,
                mark2_records: []Mark2 = undefined,
                pub const Mark2 = struct {
                    mark2_anchor_offsets: []u16 = undefined,
                    anchors: []Anchor = undefined,
                };
                pub fn deinit(self: *Mark2Array, allocator: std.mem.Allocator) void {
                    for (0..self.mark2_records.len) |i| {
                        allocator.free(self.mark2_records[i].mark2_anchor_offsets);
                        allocator.free(self.mark2_records[i].anchors);
                    }
                    allocator.free(self.mark2_records);
                }
                pub fn read(self: *Mark2Array, bit_reader: *BitReader, offset: u32, class_count: u16, allocator: std.mem.Allocator) Error!void {
                    bit_reader.setPos(offset);
                    self.mark2_count = try bit_reader.read(u16);
                    self.mark2_records = try allocator.alloc(GPOS.MarkMarkPosFormat.Mark2Array.Mark2, self.mark2_count);
                    for (0..self.mark2_records.len) |i| {
                        self.mark2_records[i].mark2_anchor_offsets = try allocator.alloc(u16, class_count);
                        self.mark2_records[i].anchors = try allocator.alloc(Anchor, class_count);
                        for (0..self.mark2_records[i].mark2_anchor_offsets.len) |j| {
                            self.mark2_records[i].mark2_anchor_offsets[j] = try bit_reader.read(u16);
                        }
                    }
                    for (0..self.mark2_records.len) |i| {
                        for (0..self.mark2_records[i].mark2_anchor_offsets.len) |j| {
                            bit_reader.setPos(offset + self.mark2_records[i].mark2_anchor_offsets[j]);
                            try self.mark2_records[i].anchors[j].read(bit_reader);
                        }
                    }
                }

                pub fn print(self: *Mark2Array) void {
                    TTF_LOG.info("Mark2Array count = {d}\n", .{self.mark2_count});
                    for (0..self.mark2_records.len) |i| {
                        TTF_LOG.info("Mark2Array offset = {any}, anchor = {any}\n", .{ self.mark2_records[i].mark2_anchor_offsets, self.mark2_records[i].anchors });
                    }
                }
            };
            pub fn init() MarkMarkPosFormat {
                return MarkMarkPosFormat{};
            }
            pub fn read(self: *MarkMarkPosFormat, bit_reader: *BitReader, offset: u32, allocator: std.mem.Allocator) Error!void {
                bit_reader.setPos(offset);
                self.format = try bit_reader.read(u16);
                self.mark1_coverage_offset = try bit_reader.read(u16);
                self.mark2_coverage_offset = try bit_reader.read(u16);
                self.mark_class_count = try bit_reader.read(u16);
                self.mark1_array_offset = try bit_reader.read(u16);
                self.mark2_array_offset = try bit_reader.read(u16);

                try self.mark1_array.read(bit_reader, offset + self.mark1_array_offset, allocator);
                try self.mark2_array.read(bit_reader, offset + self.mark2_array_offset, self.mark_class_count, allocator);

                try self.mark1_coverage.read(bit_reader, offset + self.mark1_coverage_offset, allocator);
                try self.mark2_coverage.read(bit_reader, offset + self.mark2_coverage_offset, allocator);
            }
            pub fn deinit(self: *MarkMarkPosFormat, allocator: std.mem.Allocator) void {
                self.mark1_coverage.deinit(allocator);
                self.mark2_coverage.deinit(allocator);
                self.mark1_array.deinit(allocator);
                self.mark2_array.deinit(allocator);
            }

            pub fn print(self: *MarkMarkPosFormat) void {
                TTF_LOG.info("MarkMarkPosFormat format = {d}, class_count = {d}\n", .{ self.format, self.mark_class_count });
                TTF_LOG.info("Mark1Coverage\n", .{});
                self.mark1_coverage.print();
                TTF_LOG.info("Mark2Coverage\n", .{});
                self.mark2_coverage.print();
                self.mark1_array.print();
                self.mark2_array.print();
            }
            pub fn adjustment(self: *MarkMarkPosFormat, lhs_index: usize, rhs_index: usize) ?Point {
                _ = self;
                _ = lhs_index;
                _ = rhs_index;
                //TODO
                return null;
            }
        };
        //TODO
        pub const SequenceContextFormat = struct {
            pub fn init() SequenceContextFormat {
                return SequenceContextFormat{};
            }
            pub fn read(self: *SequenceContextFormat, bit_reader: *BitReader, offset: u32, allocator: std.mem.Allocator) Error!void {
                bit_reader.setPos(offset);
                _ = self;
                _ = allocator;
            }
            pub fn print(self: *SequenceContextFormat) void {
                _ = self;
                TTF_LOG.info("SequenceContextFormat\n", .{});
            }
            pub fn deinit(self: *SequenceContextFormat, allocator: std.mem.Allocator) void {
                _ = self;
                _ = allocator;
            }
            pub fn adjustment(self: *SequenceContextFormat, lhs_index: usize, rhs_index: usize) ?Point {
                _ = self;
                _ = lhs_index;
                _ = rhs_index;
                //TODO
                return null;
            }
        };
        pub const ChainedSequenceContextFormat = struct {
            format: u16 = undefined,
            coverage_offset: ?u16 = null,
            coverage: ?Coverage = null,
            chained_seq_rule_set_count: ?u16 = null,
            chained_seq_rule_sets: ?[]ChainedSequenceRuleSet = null,
            backtrack_class_def_offset: ?u16 = null,
            backtrack_class_def: ?ClassDefFormat = null,
            input_class_def_offset: ?u16 = null,
            input_class_def: ?ClassDefFormat = null,
            lookahead_class_def_offset: ?u16 = null,
            lookahead_class_def: ?ClassDefFormat = null,
            backtrack_glyph_count: ?u16 = null,
            backtrack_coverage_offsets: ?[]u16 = null,
            backtrack_coverage: ?[]Coverage = null,
            input_glyph_count: ?u16 = null,
            input_coverage_offsets: ?[]u16 = null,
            input_coverage: ?[]Coverage = null,
            lookahead_glyph_count: ?u16 = null,
            lookahead_coverage_offsets: ?[]u16 = null,
            lookahead_coverage: ?[]Coverage = null,
            seq_lookup_count: ?u16 = null,
            seq_lookup_records: ?[]SequenceLookup = null,
            pub const ChainedSequenceRuleSet = struct {
                offset: u16 = undefined,
                chained_seq_rule_count: u16 = undefined,
                chained_seq_rules: []ChainedSequenceRule = undefined,
                pub const ChainedSequenceRule = struct {
                    offset: u16 = undefined,
                    backtrack_glyph_count: u16 = undefined,
                    backtrack_sequence: []u16 = undefined,
                    input_glyph_count: u16 = undefined,
                    input_sequence: []u16 = undefined,
                    lookahead_glyph_count: u16 = undefined,
                    lookahead_sequence: []u16 = undefined,
                    seq_lookup_count: u16 = undefined,
                    seq_lookup_records: []SequenceLookup = undefined,
                    pub fn read(self: *ChainedSequenceRule, bit_reader: *BitReader, offset: u32, allocator: std.mem.Allocator) Error!void {
                        bit_reader.setPos(offset + self.offset);
                        self.backtrack_glyph_count = try bit_reader.read(u16);
                        self.backtrack_sequence = try allocator.alloc(u16, self.backtrack_glyph_count);
                        for (0..self.backtrack_sequence.len) |i| {
                            self.backtrack_sequence[i] = try bit_reader.read(u16);
                        }
                        self.input_glyph_count = try bit_reader.read(u16);
                        self.input_sequence = try allocator.alloc(u16, self.input_glyph_count - 1);
                        for (0..self.input_sequence.len) |i| {
                            self.input_sequence[i] = try bit_reader.read(u16);
                        }
                        self.lookahead_glyph_count = try bit_reader.read(u16);
                        self.lookahead_sequence = try allocator.alloc(u16, self.lookahead_glyph_count);
                        for (0..self.lookahead_sequence.len) |i| {
                            self.lookahead_sequence[i] = try bit_reader.read(u16);
                        }
                        self.seq_lookup_count = try bit_reader.read(u16);
                        self.seq_lookup_records = try allocator.alloc(SequenceLookup, self.seq_lookup_count);
                        for (0..self.seq_lookup_records.len) |i| {
                            self.seq_lookup_records[i].sequence_index = try bit_reader.read(u16);
                            self.seq_lookup_records[i].lookup_list_index = try bit_reader.read(u16);
                        }
                    }
                    pub fn print(self: *ChainedSequenceRule) void {
                        TTF_LOG.info("ChainedSequenceRule backtrack_glyph_count = {d}, backtrack_sequence = {any}, input_glyph_count = {d}, input_seqeuence = {any}, lookahead_glyph_count = {d}, lookahead_sequence = {any}\n", .{ self.backtrack_glyph_count, self.backtrack_sequence, self.input_glyph_count, self.input_sequence, self.lookahead_glyph_count, self.lookahead_sequence });
                        TTF_LOG.info("seq_lookup_count = {d}\n", .{self.seq_lookup_count});
                        for (0..self.seq_lookup_records.len) |i| {
                            self.seq_lookup_records[i].print();
                        }
                    }
                    pub fn deinit(self: *ChainedSequenceRule, allocator: std.mem.Allocator) void {
                        allocator.free(self.backtrack_sequence);
                        allocator.free(self.input_sequence);
                        allocator.free(self.lookahead_sequence);
                        allocator.free(self.seq_lookup_records);
                    }
                };
            };
            pub fn init() ChainedSequenceContextFormat {
                return ChainedSequenceContextFormat{};
            }
            pub fn read(self: *ChainedSequenceContextFormat, bit_reader: *BitReader, offset: u32, allocator: std.mem.Allocator) Error!void {
                bit_reader.setPos(offset);
                self.format = try bit_reader.read(u16);
                switch (self.format) {
                    1 => {
                        self.coverage_offset = try bit_reader.read(u16);
                        self.chained_seq_rule_set_count = try bit_reader.read(u16);
                        self.chained_seq_rule_sets = try allocator.alloc(ChainedSequenceRuleSet, self.chained_seq_rule_set_count.?);
                        for (0..self.chained_seq_rule_sets.?.len) |i| {
                            self.chained_seq_rule_sets.?[i].offset = try bit_reader.read(u16);
                        }
                        for (0..self.chained_seq_rule_sets.?.len) |i| {
                            bit_reader.setPos(offset + self.chained_seq_rule_sets.?[i].offset);
                            self.chained_seq_rule_sets.?[i].chained_seq_rule_count = try bit_reader.read(u16);
                            self.chained_seq_rule_sets.?[i].chained_seq_rules = try allocator.alloc(ChainedSequenceRuleSet.ChainedSequenceRule, self.chained_seq_rule_sets.?[i].chained_seq_rule_count);
                            for (0..self.chained_seq_rule_sets.?[i].chained_seq_rules.len) |j| {
                                self.chained_seq_rule_sets.?[i].chained_seq_rules[j].offset = try bit_reader.read(u16);
                            }
                            for (0..self.chained_seq_rule_sets.?[i].chained_seq_rules.len) |j| {
                                try self.chained_seq_rule_sets.?[i].chained_seq_rules[j].read(bit_reader, offset + self.chained_seq_rule_sets.?[i].offset, allocator);
                            }
                        }

                        self.coverage = Coverage{};
                        try self.coverage.?.read(bit_reader, offset + self.coverage_offset.?, allocator);
                    },
                    2 => {
                        //TODO
                    },
                    3 => {
                        self.backtrack_glyph_count = try bit_reader.read(u16);
                        self.backtrack_coverage_offsets = try allocator.alloc(u16, self.backtrack_glyph_count.?);
                        self.backtrack_coverage = try allocator.alloc(Coverage, self.backtrack_glyph_count.?);
                        for (0..self.backtrack_coverage_offsets.?.len) |i| {
                            self.backtrack_coverage_offsets.?[i] = try bit_reader.read(u16);
                        }
                        self.input_glyph_count = try bit_reader.read(u16);
                        self.input_coverage_offsets = try allocator.alloc(u16, self.input_glyph_count.?);
                        self.input_coverage = try allocator.alloc(Coverage, self.input_glyph_count.?);
                        for (0..self.input_coverage_offsets.?.len) |i| {
                            self.input_coverage_offsets.?[i] = try bit_reader.read(u16);
                        }
                        self.lookahead_glyph_count = try bit_reader.read(u16);
                        self.lookahead_coverage_offsets = try allocator.alloc(u16, self.lookahead_glyph_count.?);
                        self.lookahead_coverage = try allocator.alloc(Coverage, self.lookahead_glyph_count.?);
                        for (0..self.lookahead_coverage_offsets.?.len) |i| {
                            self.lookahead_coverage_offsets.?[i] = try bit_reader.read(u16);
                        }
                        self.seq_lookup_count = try bit_reader.read(u16);
                        self.seq_lookup_records = try allocator.alloc(SequenceLookup, self.seq_lookup_count.?);
                        for (0..self.seq_lookup_records.?.len) |i| {
                            self.seq_lookup_records.?[i].sequence_index = try bit_reader.read(u16);
                            self.seq_lookup_records.?[i].lookup_list_index = try bit_reader.read(u16);
                        }
                        for (0..self.backtrack_coverage_offsets.?.len) |i| {
                            try self.backtrack_coverage.?[i].read(bit_reader, offset + self.backtrack_coverage_offsets.?[i], allocator);
                        }

                        for (0..self.input_coverage_offsets.?.len) |i| {
                            try self.input_coverage.?[i].read(bit_reader, offset + self.input_coverage_offsets.?[i], allocator);
                        }

                        for (0..self.lookahead_coverage_offsets.?.len) |i| {
                            try self.lookahead_coverage.?[i].read(bit_reader, offset + self.lookahead_coverage_offsets.?[i], allocator);
                        }
                    },
                    else => unreachable,
                }
            }
            pub fn print(self: *ChainedSequenceContextFormat) void {
                TTF_LOG.info("ChainedSequenceContextFormat format = {d}\n", .{self.format});
                switch (self.format) {
                    1 => {
                        TTF_LOG.info("chained_seq_rule_set_count = {d}\n", .{self.chained_seq_rule_set_count.?});
                        for (0..self.chained_seq_rule_sets.?.len) |i| {
                            TTF_LOG.info("ChainedSequenceRuleSet chained_seq_rule_count = {d}", .{self.chained_seq_rule_sets.?[i].chained_seq_rule_count});
                            for (0..self.chained_seq_rule_sets.?[i].chained_seq_rules.len) |j| {
                                self.chained_seq_rule_sets.?[i].chained_seq_rules[j].print();
                            }
                        }
                        TTF_LOG.info("Coverage\n", .{});
                        self.coverage.?.print();
                    },
                    2 => {
                        //TODO
                    },
                    3 => {
                        TTF_LOG.info("seq_lookup_count = {d}\n", .{self.seq_lookup_count.?});
                        for (0..self.seq_lookup_records.?.len) |i| {
                            self.seq_lookup_records.?[i].print();
                        }
                        TTF_LOG.info("BacktrackCoverage count = {d}\n", .{self.backtrack_glyph_count.?});
                        for (0..self.backtrack_coverage_offsets.?.len) |i| {
                            TTF_LOG.info("Table {d}: ", .{i});
                            self.backtrack_coverage.?[i].print();
                        }
                        TTF_LOG.info("InputCoverage count = {d}\n", .{self.input_glyph_count.?});
                        for (0..self.input_coverage_offsets.?.len) |i| {
                            TTF_LOG.info("Table {d}: ", .{i});
                            self.input_coverage.?[i].print();
                        }
                        TTF_LOG.info("LookaheadCoverage count = {d}\n", .{self.lookahead_glyph_count.?});
                        for (0..self.lookahead_coverage_offsets.?.len) |i| {
                            TTF_LOG.info("Table {d}: ", .{i});
                            self.lookahead_coverage.?[i].print();
                        }
                    },
                    else => unreachable,
                }
            }
            pub fn deinit(self: *ChainedSequenceContextFormat, allocator: std.mem.Allocator) void {
                switch (self.format) {
                    1 => {
                        for (0..self.chained_seq_rule_sets.?.len) |i| {
                            for (0..self.chained_seq_rule_sets.?[i].chained_seq_rules.len) |j| {
                                self.chained_seq_rule_sets.?[i].chained_seq_rules[j].deinit(allocator);
                            }
                            allocator.free(self.chained_seq_rule_sets.?[i].chained_seq_rules);
                        }
                        allocator.free(self.chained_seq_rule_sets.?);
                        self.coverage.?.deinit(allocator);
                    },
                    2 => {
                        //TODO
                    },
                    3 => {
                        allocator.free(self.backtrack_coverage_offsets.?);
                        allocator.free(self.input_coverage_offsets.?);
                        allocator.free(self.lookahead_coverage_offsets.?);
                        allocator.free(self.seq_lookup_records.?);
                        for (0..self.backtrack_coverage.?.len) |i| {
                            self.backtrack_coverage.?[i].deinit(allocator);
                        }

                        for (0..self.input_coverage.?.len) |i| {
                            self.input_coverage.?[i].deinit(allocator);
                        }

                        for (0..self.lookahead_coverage.?.len) |i| {
                            self.lookahead_coverage.?[i].deinit(allocator);
                        }
                        allocator.free(self.backtrack_coverage.?);
                        allocator.free(self.input_coverage.?);
                        allocator.free(self.lookahead_coverage.?);
                    },
                    else => unreachable,
                }
            }
            pub fn adjustment(self: *ChainedSequenceContextFormat, lhs_index: usize, rhs_index: usize) ?Point {
                _ = self;
                _ = lhs_index;
                _ = rhs_index;
                //TODO
                return null;
            }
        };
        pub const PosExtensionFormat = struct {
            format: u16 = undefined,
            extension_lookup_type: u16 = undefined,
            extension_offset: u32 = undefined,
            pub fn init() PosExtensionFormat {
                return PosExtensionFormat{};
            }
            pub fn read(self: *PosExtensionFormat, bit_reader: *BitReader, offset: u32) Error!void {
                bit_reader.setPos(offset);
                self.format = try bit_reader.read(u16);
                self.extension_lookup_type = try bit_reader.read(u16);
                self.extension_offset = try bit_reader.read(u32);
            }
            pub fn print(self: *PosExtensionFormat) void {
                TTF_LOG.info("PosExtensionFormat format = {d}, extensionLookupType = {d}, extensionOffset = {d}\n", .{ self.format, self.extension_lookup_type, self.extension_offset });
            }
        };
        pub const SequenceLookup = struct {
            sequence_index: u16 = undefined,
            lookup_list_index: u16 = undefined,
            pub fn print(self: *SequenceLookup) void {
                TTF_LOG.info("SequenceLookup sequence_index = {d}, lookup_list_index = {d}\n", .{ self.sequence_index, self.lookup_list_index });
            }
        };
        pub const ValueRecord = struct {
            x_placement: i16 = undefined,
            y_placement: i16 = undefined,
            x_advance: i16 = undefined,
            y_advance: i16 = undefined,
            x_place_device_offset: ?u16 = null,
            y_place_device_offset: ?u16 = null,
            x_adv_device_offset: ?u16 = null,
            y_adv_device_offset: ?u16 = null,
            pub fn init() ValueRecord {
                return ValueRecord{};
            }
            pub fn read(self: *ValueRecord, bit_reader: *BitReader, value_format: u16) Error!void {
                if (value_format & @intFromEnum(GPOS.ValueFormat.X_PLACEMENT) != 0) {
                    self.x_placement = try bit_reader.read(i16);
                } else {
                    self.x_placement = 0;
                }
                if (value_format & @intFromEnum(GPOS.ValueFormat.Y_PLACEMENT) != 0) {
                    self.y_placement = try bit_reader.read(i16);
                } else {
                    self.y_placement = 0;
                }
                if (value_format & @intFromEnum(GPOS.ValueFormat.X_ADVANCE) != 0) {
                    self.x_advance = try bit_reader.read(i16);
                } else {
                    self.x_advance = 0;
                }
                if (value_format & @intFromEnum(GPOS.ValueFormat.Y_ADVANCE) != 0) {
                    self.y_advance = try bit_reader.read(i16);
                } else {
                    self.y_advance = 0;
                }
                if (value_format & @intFromEnum(GPOS.ValueFormat.X_PLACEMENT_DEVICE) != 0) {
                    self.x_place_device_offset = try bit_reader.read(u16);
                } else {
                    self.x_place_device_offset = null;
                }
                if (value_format & @intFromEnum(GPOS.ValueFormat.Y_PLACEMENT_DEVICE) != 0) {
                    self.y_place_device_offset = try bit_reader.read(u16);
                } else {
                    self.y_place_device_offset = null;
                }
                if (value_format & @intFromEnum(GPOS.ValueFormat.X_ADVANCE_DEVICE) != 0) {
                    self.x_adv_device_offset = try bit_reader.read(u16);
                } else {
                    self.x_adv_device_offset = null;
                }
                if (value_format & @intFromEnum(GPOS.ValueFormat.Y_ADVANCE_DEVICE) != 0) {
                    self.y_adv_device_offset = try bit_reader.read(u16);
                } else {
                    self.y_adv_device_offset = null;
                }
            }
        };
        pub const ValueFormat = enum(u16) {
            X_PLACEMENT = 1,
            Y_PLACEMENT = 2,
            X_ADVANCE = 4,
            Y_ADVANCE = 8,
            X_PLACEMENT_DEVICE = 0x10,
            Y_PLACEMENT_DEVICE = 0x20,
            X_ADVANCE_DEVICE = 0x40,
            Y_ADVANCE_DEVICE = 0x80,
            Reserved = 0xFF00,
        };
        pub const Anchor = struct {
            format: u16,
            x_coord: i16,
            y_coord: i16,
            anchor_point: ?u16 = null,
            x_device_offset: ?u16 = null,
            y_device_offset: ?u16 = null,
            pub fn read(self: *Anchor, bit_reader: *BitReader) Error!void {
                self.format = try bit_reader.read(u16);
                self.x_coord = try bit_reader.read(i16);
                self.y_coord = try bit_reader.read(i16);
                self.anchor_point = null;
                self.x_device_offset = null;
                self.y_device_offset = null;
                if (self.format == 2) {
                    self.anchor_point = try bit_reader.read(u16);
                } else if (self.format == 3) {
                    self.x_device_offset = try bit_reader.read(u16);
                    self.y_device_offset = try bit_reader.read(u16);
                }
            }
        };
        pub const MarkArray = struct {
            mark_count: u16,
            mark_records: []MarkRecord,
            pub const MarkRecord = struct {
                mark_class: u16,
                mark_anchor_offset: u16,
                anchor: Anchor,
            };
            pub fn deinit(self: *MarkArray, allocator: std.mem.Allocator) void {
                allocator.free(self.mark_records);
            }
            pub fn read(self: *MarkArray, bit_reader: *BitReader, offset: u32, allocator: std.mem.Allocator) Error!void {
                bit_reader.setPos(offset);
                self.mark_count = try bit_reader.read(u16);
                self.mark_records = try allocator.alloc(GPOS.MarkArray.MarkRecord, self.mark_count);
                for (0..self.mark_records.len) |i| {
                    self.mark_records[i].mark_class = try bit_reader.read(u16);
                    self.mark_records[i].mark_anchor_offset = try bit_reader.read(u16);
                }
                for (0..self.mark_records.len) |i| {
                    bit_reader.setPos(offset + self.mark_records[i].mark_anchor_offset);
                    try self.mark_records[i].anchor.read(bit_reader);
                }
            }

            pub fn print(self: *MarkArray) void {
                TTF_LOG.info("MarkArray count = {d}\n", .{self.mark_count});
                for (0..self.mark_records.len) |i| {
                    TTF_LOG.info("MarkRecord class = {d}, offset = {d}, anchor = {any}\n", .{ self.mark_records[i].mark_class, self.mark_records[i].mark_anchor_offset, self.mark_records[i].anchor });
                }
            }
        };
        pub const ClassDefFormat = struct {
            format: u16 = undefined,
            start_glyph_id: ?u16 = undefined,
            glyph_count: ?u16 = undefined,
            class_values: ?[]u16 = undefined,
            class_range_count: ?u16 = undefined,
            class_range_records: ?[]ClassRange = undefined,
            pub const ClassRange = struct {
                start_glyph_id: u16,
                end_glyph_id: u16,
                class: u16,
            };
            fn search_index(self: *ClassDefFormat, index: usize) ?usize {
                if (self.format == 1) {
                    if (index < self.start_glyph_id.? or (index - self.start_glyph_id.?) >= self.glyph_count.?) {
                        return null;
                    }
                    return self.class_values.?[index - self.start_glyph_id.?];
                } else {
                    var low: usize = 0;
                    var high: usize = self.class_range_records.?.len - 1;
                    while (low <= high) {
                        const mid = low + (high - low) / 2;
                        if (self.class_range_records.?[mid].end_glyph_id < index) {
                            low = mid + 1;
                        } else if (self.class_range_records.?[mid].start_glyph_id > index) {
                            if (mid == 0) break;
                            high = mid - 1;
                        } else {
                            return self.class_range_records.?[mid].class;
                        }
                    }
                    return null;
                }
            }
        };
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
    const Head = struct {
        major_version: u16,
        minor_version: u16,
        font_revision: u32,
        check_sum: u32,
        magic_number: u32,
        flags: u16,
        units_per_em: u16,
        created: u64,
        modified: u64,
        x_min: i16,
        y_min: i16,
        x_max: i16,
        y_max: i16,
        mac_style: u16,
        lowest_rec_PPEM: u16,
        font_direction_hint: i16,
        index_to_loc_format: i16,
        glyph_data_format: i16,
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
        end_curves: []u16 = undefined,
        curves: []BezierCurve = undefined,
        allocator: std.mem.Allocator = undefined,
        const Flag = enum(u8) { on_curve = 1, x_short = 2, y_short = 4, repeat = 8, x_short_pos = 16, y_short_pos = 32, reservered };
        pub fn deinit(self: *GlyphOutline) void {
            self.allocator.free(self.instructions);
            self.allocator.free(self.flags);
            self.allocator.free(self.x_coord);
            self.allocator.free(self.y_coord);
            self.allocator.free(self.end_contours);
            self.allocator.free(self.curves);
            self.allocator.free(self.end_curves);
        }
    };
    pub const Point = common.Point(2, i16);
    pub const BezierCurve = struct {
        p0: Point,
        p1: Point,
        p2: Point,
    };
    pub const Error = error{ MissingRequiredTable, CompoundNotImplemented, KernFormatUnsupported } || std.mem.Allocator.Error || BitReader.Error || ByteStream.Error;
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
        var iter = self.char_map.valueIterator();
        var outline: ?*GlyphOutline = iter.next();
        while (outline != null) {
            outline.?.deinit();
            outline = iter.next();
        }
        self.char_map.deinit();
        if (self.font_directory.kern != null) {
            for (0..self.font_directory.kern.?.sub_tables.len) |i| {
                self.allocator.free(self.font_directory.kern.?.sub_tables[i].kern_subtable_format0.kern_pairs);
            }
            self.allocator.free(self.font_directory.kern.?.sub_tables);
        }
        self.allocator.free(self.font_directory.hmtx.h_metrics);
        if (self.font_directory.hmtx.left_side_bearings != null) {
            self.allocator.free(self.font_directory.hmtx.left_side_bearings.?);
        }

        if (self.font_directory.gpos != null) {
            for (0..self.font_directory.gpos.?.script_list.script_records.len) |i| {
                for (0..self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records.len) |j| {
                    self.allocator.free(self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys.feature_indicies);
                }
                self.allocator.free(self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records);
            }
            self.allocator.free(self.font_directory.gpos.?.script_list.script_records);
            for (0..self.font_directory.gpos.?.feature_list.feature_records.len) |i| {
                self.allocator.free(self.font_directory.gpos.?.feature_list.feature_records[i].lookup_list_indicies);
            }
            self.allocator.free(self.font_directory.gpos.?.feature_list.feature_records);

            for (0..self.font_directory.gpos.?.lookup_list.lookups.len) |i| {
                for (0..self.font_directory.gpos.?.lookup_list.lookups[i].subtables.len) |j| {
                    if (self.font_directory.gpos.?.lookup_list.lookups[i].lookup_type == 9) {
                        self.deinit_subtable(&self.font_directory.gpos.?.lookup_list.lookups[i].subtables[j], self.font_directory.gpos.?.lookup_list.lookups[i].subtables[j].pos_extension_format.?.extension_lookup_type);
                    } else {
                        self.deinit_subtable(&self.font_directory.gpos.?.lookup_list.lookups[i].subtables[j], self.font_directory.gpos.?.lookup_list.lookups[i].lookup_type);
                    }
                }
                self.allocator.free(self.font_directory.gpos.?.lookup_list.lookups[i].subtables);
            }
            self.allocator.free(self.font_directory.gpos.?.lookup_list.lookups);
        }
    }

    fn deinit_subtable(self: *Self, subtable: *GPOS.LookupList.Lookup.SubTable, lookup_type: u16) void {
        switch (lookup_type) {
            1 => {
                subtable.single_pos_format.?.deinit(self.allocator);
            },
            2 => {
                subtable.pair_pos_format.?.deinit(self.allocator);
            },
            3 => {
                subtable.cursive_pos_format.?.deinit(self.allocator);
            },
            4 => {
                subtable.mark_base_pos_format.?.deinit(self.allocator);
            },
            5 => {
                subtable.mark_lig_pos_format.?.deinit(self.allocator);
            },
            6 => {
                subtable.mark_mark_pos_format.?.deinit(self.allocator);
            },
            7 => {
                subtable.sequence_context_format.?.deinit(self.allocator);
            },
            8 => {
                subtable.chained_sequence_context_format.?.deinit(self.allocator);
            },
            else => unreachable,
        }
    }

    fn find_table(self: *Self, table_name: []const u8) ?*TableDirectory {
        for (0..self.font_directory.table_directory.len) |i| {
            if (std.mem.eql(u8, &self.font_directory.table_directory[i].tag, table_name)) {
                return &self.font_directory.table_directory[i];
            }
        }
        return null;
    }

    fn read_cmap(self: *Self, cmap_table: *TableDirectory) Error!void {
        self.bit_reader.setPos(cmap_table.offset);
        self.font_directory.cmap.version = try self.bit_reader.read(u16);
        self.font_directory.cmap.num_subtables = try self.bit_reader.read(u16);

        self.font_directory.cmap.cmap_encoding_subtables = try self.allocator.alloc(CMAP.CMAPEncodingSubtable, self.font_directory.cmap.num_subtables);
        for (0..self.font_directory.cmap.num_subtables) |i| {
            self.font_directory.cmap.cmap_encoding_subtables[i].platform_id = try self.bit_reader.read(u16);
            self.font_directory.cmap.cmap_encoding_subtables[i].platrform_specific_id = try self.bit_reader.read(u16);
            self.font_directory.cmap.cmap_encoding_subtables[i].offset = try self.bit_reader.read(u32);
        }
    }

    fn read_format4(self: *Self, offset: usize) Error!void {
        self.bit_reader.setPos(offset);
        self.font_directory.format4.format = try self.bit_reader.read(u16);
        self.font_directory.format4.length = try self.bit_reader.read(u16);
        self.font_directory.format4.language = try self.bit_reader.read(u16);
        self.font_directory.format4.seg_count_x2 = try self.bit_reader.read(u16);
        self.font_directory.format4.search_range = try self.bit_reader.read(u16);
        self.font_directory.format4.entry_selector = try self.bit_reader.read(u16);
        self.font_directory.format4.range_shift = try self.bit_reader.read(u16);

        self.font_directory.format4.end_code = try self.allocator.alloc(u16, self.font_directory.format4.seg_count_x2 / 2);
        self.font_directory.format4.start_code = try self.allocator.alloc(u16, self.font_directory.format4.seg_count_x2 / 2);
        self.font_directory.format4.id_delta = try self.allocator.alloc(u16, self.font_directory.format4.seg_count_x2 / 2);
        self.font_directory.format4.id_range_offset = try self.allocator.alloc(u16, self.font_directory.format4.seg_count_x2 / 2);

        for (0..self.font_directory.format4.seg_count_x2 / 2) |i| {
            self.font_directory.format4.end_code[i] = try self.bit_reader.read(u16);
        }
        self.bit_reader.setPos(self.bit_reader.getPos() + 2);
        for (0..self.font_directory.format4.seg_count_x2 / 2) |i| {
            self.font_directory.format4.start_code[i] = try self.bit_reader.read(u16);
        }
        for (0..self.font_directory.format4.seg_count_x2 / 2) |i| {
            self.font_directory.format4.id_delta[i] = try self.bit_reader.read(u16);
        }
        for (0..self.font_directory.format4.seg_count_x2 / 2) |i| {
            self.font_directory.format4.id_range_offset[i] = try self.bit_reader.read(u16);
        }
        const remaining_bytes = self.font_directory.format4.length - (self.bit_reader.getPos() - offset);
        self.font_directory.format4.glyph_id_array = try self.allocator.alloc(u16, remaining_bytes / 2);
        for (0..self.font_directory.format4.glyph_id_array.len) |i| {
            self.font_directory.format4.glyph_id_array[i] = try self.bit_reader.read(u16);
        }
    }

    fn print_cmap(self: *Self) void {
        TTF_LOG.info("#)\tpId\tpsID\toffset\ttype\n", .{});
        for (0..self.font_directory.cmap.num_subtables) |i| {
            const subtable: CMAP.CMAPEncodingSubtable = self.font_directory.cmap.cmap_encoding_subtables[i];
            const platform = switch (subtable.platform_id) {
                0 => "Unicode",
                1 => "Mac",
                2 => "Not Supported",
                3 => "Microsoft",
                else => unreachable,
            };
            TTF_LOG.info("{d})\t{d}\t{d}\t{d}\t{s}\n", .{ i + 1, subtable.platform_id, subtable.platrform_specific_id, subtable.offset, platform });
        }
    }

    fn print_format4(self: *Self) void {
        TTF_LOG.info("Format: {d}, Length: {d}, Language: {d}, Segment Count: {d}\n", .{ self.font_directory.format4.format, self.font_directory.format4.length, self.font_directory.format4.language, self.font_directory.format4.seg_count_x2 / 2 });
        TTF_LOG.info("Search Params: (searchRange: {d}, entrySelector: {d}, rangeShift: {d})\n", .{ self.font_directory.format4.search_range, self.font_directory.format4.entry_selector, self.font_directory.format4.range_shift });
        TTF_LOG.info("Segment Ranges:\tstartCode\tendCode\tidDelta\tidRangeOffset\n", .{});
        for (0..self.font_directory.format4.seg_count_x2 / 2) |i| {
            TTF_LOG.info("--------------:\t {d:9}\t {d:7}\t {d:7}\t {d:12}\n", .{ self.font_directory.format4.start_code[i], self.font_directory.format4.end_code[i], self.font_directory.format4.id_delta[i], self.font_directory.format4.id_range_offset[i] });
        }
    }

    fn print_glyph_outline(glyph_outline: *const GlyphOutline) void {
        TTF_LOG.info("#contours\t(xMin,yMin)\t(xMax,yMax)\tinst_length\n", .{});
        TTF_LOG.info("%{d:9}\t({d},{d})\t\t({d},{d})\t{d}\n", .{ glyph_outline.num_contours, glyph_outline.x_min, glyph_outline.y_min, glyph_outline.x_max, glyph_outline.y_max, glyph_outline.instruction_length });

        TTF_LOG.info("#)\t(  x  ,  y  )\n", .{});
        const last_index = glyph_outline.end_contours[glyph_outline.end_contours.len - 1];
        for (0..last_index + 1) |i| {
            TTF_LOG.info("{d})\t({d:5},{d:5})\n", .{ i, glyph_outline.x_coord[i], glyph_outline.y_coord[i] });
        }
    }

    fn get_glyph_outline(self: *Self, glyph_index: usize) Error!GlyphOutline {
        const offset: usize = try self.get_glyph_offset(glyph_index);
        var glyph_outline: GlyphOutline = undefined;
        glyph_outline.allocator = self.allocator;
        self.bit_reader.setPos(self.font_directory.glyf_offset + offset);
        glyph_outline.num_contours = try self.bit_reader.read(i16);
        glyph_outline.x_min = try self.bit_reader.read(i16);
        glyph_outline.y_min = try self.bit_reader.read(i16);
        glyph_outline.x_max = try self.bit_reader.read(i16);
        glyph_outline.y_max = try self.bit_reader.read(i16);

        TTF_LOG.info("num contours {d}\n", .{glyph_outline.num_contours});
        if (glyph_outline.num_contours == -1) {
            return Error.CompoundNotImplemented;
        }

        glyph_outline.end_contours = try self.allocator.alloc(u16, @as(u16, @bitCast(glyph_outline.num_contours)));
        for (0..glyph_outline.end_contours.len) |i| {
            glyph_outline.end_contours[i] = try self.bit_reader.read(u16);
        }
        glyph_outline.instruction_length = try self.bit_reader.read(u16);
        glyph_outline.instructions = try self.allocator.alloc(u8, glyph_outline.instruction_length);
        for (0..glyph_outline.instructions.len) |i| {
            glyph_outline.instructions[i] = try self.bit_reader.read(u8);
        }
        const last_index = glyph_outline.end_contours[glyph_outline.end_contours.len - 1];
        glyph_outline.flags = try self.allocator.alloc(u8, last_index + 1);
        var i: usize = 0;
        while (i < glyph_outline.flags.len) : (i += 1) {
            glyph_outline.flags[i] = try self.bit_reader.read(u8);
            if ((glyph_outline.flags[i] & @intFromEnum(GlyphOutline.Flag.repeat)) != 0) {
                var repeat_count = @as(i8, @bitCast(try self.bit_reader.read(u8)));
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
                    cur_coord += try self.bit_reader.read(i16);
                },
                1 => {},
                2 => {
                    cur_coord -= @as(i16, @bitCast(@as(u16, @intCast(try self.bit_reader.read(u8)))));
                },
                3 => {
                    cur_coord += @as(i16, @bitCast(@as(u16, @intCast(try self.bit_reader.read(u8)))));
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
                    cur_coord += try self.bit_reader.read(i16);
                },
                1 => {},
                2 => {
                    cur_coord -= @as(i16, @bitCast(@as(u16, @intCast(try self.bit_reader.read(u8)))));
                },
                3 => {
                    cur_coord += @as(i16, @bitCast(@as(u16, @intCast(try self.bit_reader.read(u8)))));
                },
                else => unreachable,
            }
            glyph_outline.y_coord[j] = cur_coord;
        }

        return glyph_outline;
    }

    pub fn get_glyph_index(self: *Self, code_point: u16) usize {
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
                return (@as(usize, @intCast(offset_value)) + @as(usize, @intCast(self.font_directory.format4.id_delta[index.?]))) & 0xFFFF;
            } else {
                return (@as(usize, @intCast(code_point)) + @as(usize, @intCast(self.font_directory.format4.id_delta[index.?]))) & 0xFFFF;
            }
        }
        return 0;
    }

    fn get_glyph_offset(self: *Self, glyph_index: usize) Error!usize {
        self.bit_reader.setPos(self.font_directory.head_offset + 50);
        const loca_type = try self.bit_reader.read(u16);
        if (loca_type == 0) {
            self.bit_reader.setPos((self.font_directory.loca_offset + (glyph_index * 2)));
            return @as(usize, @intCast(try self.bit_reader.read(u16))) * 2;
        } else {
            self.bit_reader.setPos(self.font_directory.loca_offset + (glyph_index * 4));
            return @as(usize, @intCast(try self.bit_reader.read(u32)));
        }
    }

    fn process_lookup_format(self: *Self, lookup_type: u16, subtable: *GPOS.LookupList.Lookup.SubTable, offset: u32) Error!void {
        switch (lookup_type) {
            1 => {
                subtable.single_pos_format = GPOS.SinglePosFormat.init();
                try subtable.single_pos_format.?.read(&self.bit_reader, offset, self.allocator);
                subtable.single_pos_format.?.print();
            },
            2 => {
                subtable.pair_pos_format = GPOS.PairPosFormat.init();
                try subtable.pair_pos_format.?.read(&self.bit_reader, offset, self.allocator);
                subtable.pair_pos_format.?.print();
            },
            3 => {
                subtable.cursive_pos_format = GPOS.CursivePosFormat.init();
                try subtable.cursive_pos_format.?.read(&self.bit_reader, offset, self.allocator);
                subtable.cursive_pos_format.?.print();
            },
            4 => {
                subtable.mark_base_pos_format = GPOS.MarkBasePosFormat.init();
                try subtable.mark_base_pos_format.?.read(&self.bit_reader, offset, self.allocator);
                subtable.mark_base_pos_format.?.print();
            },
            5 => {
                subtable.mark_lig_pos_format = GPOS.MarkLigPosFormat.init();
                try subtable.mark_lig_pos_format.?.read(&self.bit_reader, offset, self.allocator);
                subtable.mark_lig_pos_format.?.print();
            },
            6 => {
                subtable.mark_mark_pos_format = GPOS.MarkMarkPosFormat.init();
                try subtable.mark_mark_pos_format.?.read(&self.bit_reader, offset, self.allocator);
                subtable.mark_mark_pos_format.?.print();
            },
            7 => {
                subtable.sequence_context_format = GPOS.SequenceContextFormat.init();
                try subtable.sequence_context_format.?.read(&self.bit_reader, offset, self.allocator);
                subtable.sequence_context_format.?.print();
            },
            8 => {
                subtable.chained_sequence_context_format = GPOS.ChainedSequenceContextFormat.init();
                try subtable.chained_sequence_context_format.?.read(&self.bit_reader, offset, self.allocator);
                subtable.chained_sequence_context_format.?.print();
            },
            9 => {
                subtable.pos_extension_format = GPOS.PosExtensionFormat.init();
                try subtable.pos_extension_format.?.read(&self.bit_reader, offset);
                subtable.pos_extension_format.?.print();
            },
            else => unreachable,
        }
    }

    //https://learn.microsoft.com/en-us/typography/opentype/spec/gpos
    //TODO store GPOS data to be used in glyph rendering
    fn read_gpos(self: *Self, offset: u32) Error!void {
        self.bit_reader.setPos(offset);
        self.font_directory.gpos = GPOS{};
        self.font_directory.gpos.?.header.major_version = try self.bit_reader.read(u16);
        self.font_directory.gpos.?.header.minor_version = try self.bit_reader.read(u16);
        self.font_directory.gpos.?.header.script_list_offset = try self.bit_reader.read(u16);
        self.font_directory.gpos.?.header.feature_list_offset = try self.bit_reader.read(u16);
        self.font_directory.gpos.?.header.lookup_list_offset = try self.bit_reader.read(u16);
        self.font_directory.gpos.?.header.feature_variations_offset = if (self.font_directory.gpos.?.header.minor_version == 1) try self.bit_reader.read(u16) else null;
        //TODO missing default lang??
        //scriptlist
        self.bit_reader.setPos(offset + self.font_directory.gpos.?.header.script_list_offset);
        self.font_directory.gpos.?.script_list.script_count = try self.bit_reader.read(u16);
        self.font_directory.gpos.?.script_list.script_records = try self.allocator.alloc(GPOS.ScriptList.ScriptRecord, self.font_directory.gpos.?.script_list.script_count);
        for (0..self.font_directory.gpos.?.script_list.script_records.len) |i| {
            self.font_directory.gpos.?.script_list.script_records[i].script_tag[0] = try self.bit_reader.read(u8);
            self.font_directory.gpos.?.script_list.script_records[i].script_tag[1] = try self.bit_reader.read(u8);
            self.font_directory.gpos.?.script_list.script_records[i].script_tag[2] = try self.bit_reader.read(u8);
            self.font_directory.gpos.?.script_list.script_records[i].script_tag[3] = try self.bit_reader.read(u8);
            self.font_directory.gpos.?.script_list.script_records[i].script_offset = try self.bit_reader.read(u16);
        }
        for (0..self.font_directory.gpos.?.script_list.script_records.len) |i| {
            self.bit_reader.setPos(offset + self.font_directory.gpos.?.header.script_list_offset + self.font_directory.gpos.?.script_list.script_records[i].script_offset);
            self.font_directory.gpos.?.script_list.script_records[i].script_table.default_lang_sys_offset = try self.bit_reader.read(u16);
            self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_count = try self.bit_reader.read(u16);
            self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records = try self.allocator.alloc(GPOS.ScriptList.ScriptRecord.ScriptTable.LangSysRecord, self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_count);
            for (0..self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records.len) |j| {
                self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys_tag[0] = try self.bit_reader.read(u8);
                self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys_tag[1] = try self.bit_reader.read(u8);
                self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys_tag[2] = try self.bit_reader.read(u8);
                self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys_tag[3] = try self.bit_reader.read(u8);
                self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys_offset = try self.bit_reader.read(u16);
            }
            for (0..self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records.len) |j| {
                self.bit_reader.setPos(offset + self.font_directory.gpos.?.header.script_list_offset + self.font_directory.gpos.?.script_list.script_records[i].script_offset + self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys_offset);
                self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys.lookup_order_offset = try self.bit_reader.read(u16);
                self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys.required_feature_index = try self.bit_reader.read(u16);
                self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys.feature_index_count = try self.bit_reader.read(u16);
                self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys.feature_indicies = try self.allocator.alloc(u16, self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys.feature_index_count);
                for (0..self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys.feature_indicies.len) |k| {
                    self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys.feature_indicies[k] = try self.bit_reader.read(u16);
                }
            }
        }
        TTF_LOG.info("-----GPOS table-----\n{any}\n", .{self.font_directory.gpos.?.header});
        TTF_LOG.info("ScriptList Count = {d}\n", .{self.font_directory.gpos.?.script_list.script_count});
        for (0..self.font_directory.gpos.?.script_list.script_records.len) |i| {
            TTF_LOG.info("ScriptRecords tag = {s}, offset = {d}, default_lang_sys_offset = {d}, lang_sys_count = {d}\n", .{ self.font_directory.gpos.?.script_list.script_records[i].script_tag, self.font_directory.gpos.?.script_list.script_records[i].script_offset, self.font_directory.gpos.?.script_list.script_records[i].script_table.default_lang_sys_offset, self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_count });
            for (0..self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records.len) |j| {
                TTF_LOG.info("LangSysRecords tag = {s}, lang_sys_offset = {d}, lookup_order_offset = {d}, required_feature_index = {d}, feature_index_count = {d}, feature_indicies = {any} \n", .{ self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys_tag, self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys_offset, self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys.lookup_order_offset, self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys.required_feature_index, self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys.feature_index_count, self.font_directory.gpos.?.script_list.script_records[i].script_table.lang_sys_records[j].lang_sys.feature_indicies });
            }
        }
        //lookup
        self.bit_reader.setPos(offset + self.font_directory.gpos.?.header.lookup_list_offset);
        self.font_directory.gpos.?.lookup_list.lookup_count = try self.bit_reader.read(u16);
        self.font_directory.gpos.?.lookup_list.lookups = try self.allocator.alloc(GPOS.LookupList.Lookup, self.font_directory.gpos.?.lookup_list.lookup_count);
        for (0..self.font_directory.gpos.?.lookup_list.lookups.len) |i| {
            self.font_directory.gpos.?.lookup_list.lookups[i].lookup_offset = try self.bit_reader.read(u16);
        }
        TTF_LOG.info("LookupList Count = {d}\n", .{self.font_directory.gpos.?.lookup_list.lookup_count});
        for (0..self.font_directory.gpos.?.lookup_list.lookups.len) |i| {
            self.bit_reader.setPos(offset + self.font_directory.gpos.?.header.lookup_list_offset + self.font_directory.gpos.?.lookup_list.lookups[i].lookup_offset);
            self.font_directory.gpos.?.lookup_list.lookups[i].lookup_type = try self.bit_reader.read(u16);
            self.font_directory.gpos.?.lookup_list.lookups[i].lookup_flag = try self.bit_reader.read(u16);
            self.font_directory.gpos.?.lookup_list.lookups[i].subtable_count = try self.bit_reader.read(u16);
            self.font_directory.gpos.?.lookup_list.lookups[i].subtables = try self.allocator.alloc(GPOS.LookupList.Lookup.SubTable, self.font_directory.gpos.?.lookup_list.lookups[i].subtable_count);
            for (0..self.font_directory.gpos.?.lookup_list.lookups[i].subtables.len) |j| {
                self.font_directory.gpos.?.lookup_list.lookups[i].subtables[j].offset = try self.bit_reader.read(u16);
            }
            TTF_LOG.info("Lookups offset = {d}, lookup_type = {d}, lookup_flag = {d}, subtable_count = {d}\n", .{ self.font_directory.gpos.?.lookup_list.lookups[i].lookup_offset, self.font_directory.gpos.?.lookup_list.lookups[i].lookup_type, self.font_directory.gpos.?.lookup_list.lookups[i].lookup_flag, self.font_directory.gpos.?.lookup_list.lookups[i].subtable_count });
            for (0..self.font_directory.gpos.?.lookup_list.lookups[i].subtables.len) |j| {
                try self.process_lookup_format(self.font_directory.gpos.?.lookup_list.lookups[i].lookup_type, &self.font_directory.gpos.?.lookup_list.lookups[i].subtables[j], offset + self.font_directory.gpos.?.header.lookup_list_offset + self.font_directory.gpos.?.lookup_list.lookups[i].lookup_offset + self.font_directory.gpos.?.lookup_list.lookups[i].subtables[j].offset);
                if (self.font_directory.gpos.?.lookup_list.lookups[i].lookup_type == 9) {
                    try self.process_lookup_format(self.font_directory.gpos.?.lookup_list.lookups[i].subtables[j].pos_extension_format.?.extension_lookup_type, &self.font_directory.gpos.?.lookup_list.lookups[i].subtables[j], self.font_directory.gpos.?.lookup_list.lookups[i].subtables[j].pos_extension_format.?.extension_offset + offset + self.font_directory.gpos.?.header.lookup_list_offset + self.font_directory.gpos.?.lookup_list.lookups[i].lookup_offset + self.font_directory.gpos.?.lookup_list.lookups[i].subtables[j].offset);
                }
            }
        }

        //featurelist
        self.bit_reader.setPos(offset + self.font_directory.gpos.?.header.feature_list_offset);
        self.font_directory.gpos.?.feature_list.feature_count = try self.bit_reader.read(u16);
        self.font_directory.gpos.?.feature_list.feature_records = try self.allocator.alloc(GPOS.FeatureList.FeatureRecord, self.font_directory.gpos.?.feature_list.feature_count);
        for (0..self.font_directory.gpos.?.feature_list.feature_records.len) |i| {
            self.font_directory.gpos.?.feature_list.feature_records[i].feature_tag[0] = try self.bit_reader.read(u8);
            self.font_directory.gpos.?.feature_list.feature_records[i].feature_tag[1] = try self.bit_reader.read(u8);
            self.font_directory.gpos.?.feature_list.feature_records[i].feature_tag[2] = try self.bit_reader.read(u8);
            self.font_directory.gpos.?.feature_list.feature_records[i].feature_tag[3] = try self.bit_reader.read(u8);
            self.font_directory.gpos.?.feature_list.feature_records[i].feature_offset = try self.bit_reader.read(u16);
        }
        for (0..self.font_directory.gpos.?.feature_list.feature_records.len) |i| {
            self.bit_reader.setPos(self.font_directory.gpos.?.feature_list.feature_records[i].feature_offset + offset + self.font_directory.gpos.?.header.feature_list_offset);
            self.font_directory.gpos.?.feature_list.feature_records[i].feature_params_offset = try self.bit_reader.read(u16);
            self.font_directory.gpos.?.feature_list.feature_records[i].lookup_index_count = try self.bit_reader.read(u16);
            self.font_directory.gpos.?.feature_list.feature_records[i].lookup_list_indicies = try self.allocator.alloc(u16, self.font_directory.gpos.?.feature_list.feature_records[i].lookup_index_count);
            for (0..self.font_directory.gpos.?.feature_list.feature_records[i].lookup_list_indicies.len) |j| {
                self.font_directory.gpos.?.feature_list.feature_records[i].lookup_list_indicies[j] = try self.bit_reader.read(u16);
            }
        }
        TTF_LOG.info("FeatureList Count = {d}\n", .{self.font_directory.gpos.?.feature_list.feature_count});
        for (0..self.font_directory.gpos.?.feature_list.feature_records.len) |i| {
            TTF_LOG.info("FeatureRecord tag = {s}, offset = {d}, feature_params_offset = {d}, lookup_index_count = {d}, lookup_list_indicies = {any}\n", .{ self.font_directory.gpos.?.feature_list.feature_records[i].feature_tag, self.font_directory.gpos.?.feature_list.feature_records[i].feature_offset, self.font_directory.gpos.?.feature_list.feature_records[i].feature_params_offset, self.font_directory.gpos.?.feature_list.feature_records[i].lookup_index_count, self.font_directory.gpos.?.feature_list.feature_records[i].lookup_list_indicies });
        }
    }

    //TODO fix linear scan to be binary search
    pub fn kerning_adj(self: *Self, lhs_codepoint: u16, rhs_codepoint: u16) ?Point {
        var ret: ?Point = null;
        const lhs_index = self.get_glyph_index(lhs_codepoint);
        const rhs_index = self.get_glyph_index(rhs_codepoint);
        if (self.font_directory.kern) |kern| {
            for (0..kern.sub_tables.len) |i| {
                for (0..kern.sub_tables[i].kern_subtable_format0.kern_pairs.len) |j| {
                    //TTF_LOG.info("kerning left index {d}, right index {d}, looking for {d}\n", .{ self.kern.sub_tables[i].kern_subtable_format0.kern_pairs[j].left, kern.sub_tables[i].kern_subtable_format0.kern_pairs[j].right, lhs_index });
                    if (kern.sub_tables[i].kern_subtable_format0.kern_pairs[j].left != lhs_index) continue;
                    if (kern.sub_tables[i].kern_subtable_format0.kern_pairs[j].left != rhs_index) continue;
                    TTF_LOG.info("found kerning data\n", .{});
                    // found kerning value for these indicies
                    //vertical
                    if (kern.sub_tables[i].coverage & @as(u16, @intFromEnum(Kern.SubTable.Coverage.horizontal)) == 0) {
                        if (kern.sub_tables[i].coverage & @as(u16, @intFromEnum(Kern.SubTable.Coverage.override)) != 0) {
                            if (ret == null) {
                                ret = Point{};
                            }
                            ret.?.y = kern.sub_tables[i].kern_subtable_format0.kern_pairs[j].value;
                        } else if (kern.sub_tables[i].coverage & @as(u16, @intFromEnum(Kern.SubTable.Coverage.minimum)) != 0) {
                            if (ret == null) {
                                ret = Point{};
                            }
                            ret.?.y = @min(kern.sub_tables[i].kern_subtable_format0.kern_pairs[j].value, ret.?.y);
                        }
                    }
                    // horizontal
                    else {
                        if (kern.sub_tables[i].coverage & @as(u16, @intFromEnum(Kern.SubTable.Coverage.override)) != 0) {
                            if (ret == null) {
                                ret = Point{};
                            }
                            ret.?.x = kern.sub_tables[i].kern_subtable_format0.kern_pairs[j].value;
                        } else if (kern.sub_tables[i].coverage & @as(u16, @intFromEnum(Kern.SubTable.Coverage.minimum)) != 0) {
                            if (ret == null) {
                                ret = Point{};
                            }
                            ret.?.x = @min(kern.sub_tables[i].kern_subtable_format0.kern_pairs[j].value, ret.?.x);
                        }
                    }
                }
            }
        }
        //TODO adjust x y based on gpos data
        if (self.font_directory.gpos) |gpos| {
            for (0..gpos.lookup_list.lookups.len) |i| {
                for (0..gpos.lookup_list.lookups[i].subtables.len) |j| {
                    const point = gpos.lookup_list.lookups[i].subtables[j].adjustment(lhs_index, rhs_index, gpos.lookup_list.lookups[i].lookup_type);
                    if (point) |p| {
                        TTF_LOG.info("found subtable data\n", .{});
                        if (ret == null) ret = Point{};
                        ret.?.x += p.x;
                        ret.?.y += p.y;
                    }
                }
            }
        }
        return ret;
    }

    fn read_kern(self: *Self, offset: u32) Error!void {
        self.bit_reader.setPos(offset);
        self.font_directory.kern = Kern{};
        self.font_directory.kern.?.header.version = try self.bit_reader.read(u16);
        self.font_directory.kern.?.header.n_tables = try self.bit_reader.read(u16);
        self.font_directory.kern.?.sub_tables = try self.allocator.alloc(Kern.SubTable, self.font_directory.kern.?.header.n_tables);
        for (0..self.font_directory.kern.?.sub_tables.len) |i| {
            self.font_directory.kern.?.sub_tables[i].version = try self.bit_reader.read(u16);
            self.font_directory.kern.?.sub_tables[i].length = try self.bit_reader.read(u16);
            self.font_directory.kern.?.sub_tables[i].coverage = try self.bit_reader.read(u16);
            if (self.font_directory.kern.?.sub_tables[i].coverage & @as(u16, @intFromEnum(Kern.SubTable.Coverage.format)) != 0) {
                return Error.KernFormatUnsupported;
            }
            self.font_directory.kern.?.sub_tables[i].kern_subtable_format0.n_pairs = try self.bit_reader.read(u16);
            self.font_directory.kern.?.sub_tables[i].kern_subtable_format0.search_range = try self.bit_reader.read(u16);
            self.font_directory.kern.?.sub_tables[i].kern_subtable_format0.entry_selector = try self.bit_reader.read(u16);
            self.font_directory.kern.?.sub_tables[i].kern_subtable_format0.range_shift = try self.bit_reader.read(u16);
            TTF_LOG.info("num pairs {d}\n", .{self.font_directory.kern.?.sub_tables[i].kern_subtable_format0.n_pairs});
            self.font_directory.kern.?.sub_tables[i].kern_subtable_format0.kern_pairs = try self.allocator.alloc(Kern.SubTable.KernSubtableFormat0.KernPair, self.font_directory.kern.?.sub_tables[i].kern_subtable_format0.n_pairs);
            for (0..self.font_directory.kern.?.sub_tables[i].kern_subtable_format0.kern_pairs.len) |j| {
                self.font_directory.kern.?.sub_tables[i].kern_subtable_format0.kern_pairs[j].left = try self.bit_reader.read(u16);
                self.font_directory.kern.?.sub_tables[i].kern_subtable_format0.kern_pairs[j].right = try self.bit_reader.read(u16);
                self.font_directory.kern.?.sub_tables[i].kern_subtable_format0.kern_pairs[j].value = try self.bit_reader.read(i16);
            }
        }
        TTF_LOG.info("-----kern table-----\n{any}\n", .{self.font_directory.kern.?});
    }

    //TODO grab more metrics from maxp
    fn read_maxp(self: *Self, offset: u32) Error!void {
        self.bit_reader.setPos(offset);
        self.font_directory.maxp.version = try self.bit_reader.read(u32);
        self.font_directory.maxp.num_glyphs = try self.bit_reader.read(u16);
        TTF_LOG.info("-----maxp table-----\n", .{});
        TTF_LOG.info("version = {d}\n", .{self.font_directory.maxp.version});
        TTF_LOG.info("num_glyphs = {d}\n", .{self.font_directory.maxp.num_glyphs});
    }

    fn read_hhea(self: *Self, offset: u32) Error!void {
        self.bit_reader.setPos(offset);
        self.font_directory.hhea.major_version = try self.bit_reader.read(u16);
        self.font_directory.hhea.minor_version = try self.bit_reader.read(u16);
        self.font_directory.hhea.ascender = try self.bit_reader.read(i16);
        self.font_directory.hhea.descender = try self.bit_reader.read(i16);
        self.font_directory.hhea.line_gap = try self.bit_reader.read(i16);
        self.font_directory.hhea.advance_width_max = try self.bit_reader.read(u16);
        self.font_directory.hhea.min_left_side_bearing = try self.bit_reader.read(i16);
        self.font_directory.hhea.min_right_side_bearing = try self.bit_reader.read(i16);
        self.font_directory.hhea.x_max_extent = try self.bit_reader.read(i16);
        self.font_directory.hhea.caret_slope_rise = try self.bit_reader.read(i16);
        self.font_directory.hhea.caret_slope_run = try self.bit_reader.read(i16);
        self.font_directory.hhea.caret_offset = try self.bit_reader.read(i16);
        self.font_directory.hhea.reserved = try self.bit_reader.read(i64);
        self.font_directory.hhea.metric_data_format = try self.bit_reader.read(i16);
        self.font_directory.hhea.number_of_h_metrics = try self.bit_reader.read(u16);
        TTF_LOG.info("-----hhea table-----\n", .{});
        TTF_LOG.info("major_version = {d}\n", .{self.font_directory.hhea.major_version});
        TTF_LOG.info("minor_version = {d}\n", .{self.font_directory.hhea.minor_version});
        TTF_LOG.info("ascender = {d}\n", .{self.font_directory.hhea.ascender});
        TTF_LOG.info("descender = {d}\n", .{self.font_directory.hhea.descender});
        TTF_LOG.info("line_gap = {d}\n", .{self.font_directory.hhea.line_gap});
        TTF_LOG.info("advance_width_max = {d}\n", .{self.font_directory.hhea.advance_width_max});
        TTF_LOG.info("min_left_side_bearing = {d}\n", .{self.font_directory.hhea.min_left_side_bearing});
        TTF_LOG.info("min_right_side_bearing = {d}\n", .{self.font_directory.hhea.min_right_side_bearing});
        TTF_LOG.info("x_max_extent = {d}\n", .{self.font_directory.hhea.x_max_extent});
        TTF_LOG.info("caret_slope_rise = {d}\n", .{self.font_directory.hhea.caret_slope_rise});
        TTF_LOG.info("caret_slope_run = {d}\n", .{self.font_directory.hhea.caret_slope_run});
        TTF_LOG.info("caret_offset = {d}\n", .{self.font_directory.hhea.caret_offset});
        TTF_LOG.info("reserved = {d}\n", .{self.font_directory.hhea.reserved});
        TTF_LOG.info("metric_data_format = {d}\n", .{self.font_directory.hhea.metric_data_format});
        TTF_LOG.info("number_of_h_metrics = {d}\n", .{self.font_directory.hhea.number_of_h_metrics});
    }

    pub fn get_horizontal_metrics(self: *Self, glyph_index: u16) struct { advance_width: u16, lsb: i16 } {
        if (glyph_index > self.font_directory.hmtx.h_metrics.len) {
            return .{
                .advance_width = self.font_directory.hmtx.h_metrics[self.font_directory.hmtx.h_metrics.len - 1].advance_width,
                .lsb = self.font_directory.hmtx.left_side_bearings.?[glyph_index - self.font_directory.hmtx.h_metrics.len],
            };
        } else {
            return .{
                .advance_width = self.font_directory.hmtx.h_metrics[glyph_index].advance_width,
                .lsb = self.font_directory.hmtx.h_metrics[glyph_index].lsb,
            };
        }
    }

    fn read_hmtx(self: *Self, offset: u32) Error!void {
        self.bit_reader.setPos(offset);
        self.font_directory.hmtx.h_metrics = try self.allocator.alloc(Hmtx.LongHorMetric, self.font_directory.hhea.number_of_h_metrics);
        for (0..self.font_directory.hmtx.h_metrics.len) |i| {
            self.font_directory.hmtx.h_metrics[i].advance_width = try self.bit_reader.read(u16);
            self.font_directory.hmtx.h_metrics[i].lsb = try self.bit_reader.read(i16);
        }
        if (self.font_directory.maxp.num_glyphs > self.font_directory.hmtx.h_metrics.len) {
            self.font_directory.hmtx.left_side_bearings = try self.allocator.alloc(i16, self.font_directory.maxp.num_glyphs - self.font_directory.hmtx.h_metrics.len);
            for (0..self.font_directory.hmtx.left_side_bearings.?.len) |i| {
                self.font_directory.hmtx.left_side_bearings.?[i] = try self.bit_reader.read(i16);
            }
        }

        TTF_LOG.info("-----hmtx table-----\n", .{});
        TTF_LOG.info("index) advance_width lsb\n", .{});
        for (0..self.font_directory.hmtx.h_metrics.len) |i| {
            TTF_LOG.info(" {d:4}) {d:<13} {d}\n", .{ i, self.font_directory.hmtx.h_metrics[i].advance_width, self.font_directory.hmtx.h_metrics[i].lsb });
        }
        if (self.font_directory.maxp.num_glyphs > self.font_directory.hmtx.h_metrics.len) {
            TTF_LOG.info("i) left_side_bearings\n", .{});
            for (0..self.font_directory.hmtx.left_side_bearings.?.len) |i| {
                TTF_LOG.info("{d}) {d}\n", .{ i, self.font_directory.hmtx.left_side_bearings.?[i] });
            }
        }
    }

    fn read_head(self: *Self, offset: u32) Error!void {
        self.bit_reader.setPos(offset);
        self.font_directory.head.major_version = try self.bit_reader.read(u16);
        self.font_directory.head.minor_version = try self.bit_reader.read(u16);
        self.font_directory.head.font_revision = try self.bit_reader.read(u32);
        self.font_directory.head.check_sum = try self.bit_reader.read(u32);
        self.font_directory.head.magic_number = try self.bit_reader.read(u32);
        self.font_directory.head.flags = try self.bit_reader.read(u16);
        self.font_directory.head.units_per_em = try self.bit_reader.read(u16);
        self.font_directory.head.created = try self.bit_reader.read(u32);
        self.font_directory.head.created += try self.bit_reader.read(u32);
        self.font_directory.head.modified = try self.bit_reader.read(u32);
        self.font_directory.head.modified += try self.bit_reader.read(u32);
        self.font_directory.head.x_min = try self.bit_reader.read(i16);
        self.font_directory.head.y_min = try self.bit_reader.read(i16);
        self.font_directory.head.x_max = try self.bit_reader.read(i16);
        self.font_directory.head.y_max = try self.bit_reader.read(i16);
        self.font_directory.head.mac_style = try self.bit_reader.read(u16);
        self.font_directory.head.lowest_rec_PPEM = try self.bit_reader.read(u16);
        self.font_directory.head.font_direction_hint = try self.bit_reader.read(i16);
        self.font_directory.head.index_to_loc_format = try self.bit_reader.read(i16);
        self.font_directory.head.glyph_data_format = try self.bit_reader.read(i16);
        TTF_LOG.info("-----head table-----\n", .{});
        TTF_LOG.info("major_version = {d}\n", .{self.font_directory.head.major_version});
        TTF_LOG.info("minor_version = {d}\n", .{self.font_directory.head.minor_version});
        TTF_LOG.info("font_revision = {d}\n", .{self.font_directory.head.font_revision});
        TTF_LOG.info("check_sum = {d}\n", .{self.font_directory.head.check_sum});
        TTF_LOG.info("magic_number = {d}\n", .{self.font_directory.head.magic_number});
        TTF_LOG.info("flags = {d}\n", .{self.font_directory.head.flags});
        TTF_LOG.info("units_per_em = {d}\n", .{self.font_directory.head.units_per_em});
        TTF_LOG.info("created = {d}\n", .{self.font_directory.head.created});
        TTF_LOG.info("modified = {d}\n", .{self.font_directory.head.modified});
        TTF_LOG.info("x_min = {d}\n", .{self.font_directory.head.x_min});
        TTF_LOG.info("y_min = {d}\n", .{self.font_directory.head.y_min});
        TTF_LOG.info("x_max = {d}\n", .{self.font_directory.head.x_max});
        TTF_LOG.info("y_max = {d}\n", .{self.font_directory.head.y_max});
        TTF_LOG.info("mac_style = {d}\n", .{self.font_directory.head.mac_style});
        TTF_LOG.info("lowest_rec_PPEM = {d}\n", .{self.font_directory.head.lowest_rec_PPEM});
        TTF_LOG.info("font_direction_hint = {d}\n", .{self.font_directory.head.font_direction_hint});
        TTF_LOG.info("index_to_loc_format = {d}\n", .{self.font_directory.head.index_to_loc_format});
        TTF_LOG.info("glyph_data_format = {d}\n", .{self.font_directory.head.glyph_data_format});
    }

    fn parse_file(self: *Self) !void {
        // offset subtable
        self.font_directory.offset_subtable.scalar_type = try self.bit_reader.read(u32);
        self.font_directory.offset_subtable.num_tables = try self.bit_reader.read(u16);
        self.font_directory.offset_subtable.search_range = try self.bit_reader.read(u16);
        self.font_directory.offset_subtable.entry_selector = try self.bit_reader.read(u16);
        self.font_directory.offset_subtable.range_shift = try self.bit_reader.read(u16);

        // table directory
        self.font_directory.table_directory = try self.allocator.alloc(TableDirectory, self.font_directory.offset_subtable.num_tables);
        for (0..self.font_directory.table_directory.len) |i| {
            self.font_directory.table_directory[i].tag[0] = try self.bit_reader.read(u8);
            self.font_directory.table_directory[i].tag[1] = try self.bit_reader.read(u8);
            self.font_directory.table_directory[i].tag[2] = try self.bit_reader.read(u8);
            self.font_directory.table_directory[i].tag[3] = try self.bit_reader.read(u8);
            self.font_directory.table_directory[i].checksum = try self.bit_reader.read(u32);
            self.font_directory.table_directory[i].offset = try self.bit_reader.read(u32);
            self.font_directory.table_directory[i].length = try self.bit_reader.read(u32);
        }
        const cmap_table = self.find_table("cmap") orelse return Error.MissingRequiredTable;
        try self.read_cmap(cmap_table);
        try self.read_format4(cmap_table.offset + self.font_directory.cmap.cmap_encoding_subtables[0].offset);

        const glyf_table = self.find_table("glyf") orelse return Error.MissingRequiredTable;
        self.font_directory.glyf_offset = glyf_table.offset;
        const loca_table = self.find_table("loca") orelse return Error.MissingRequiredTable;
        self.font_directory.loca_offset = loca_table.offset;
        const head_table = self.find_table("head") orelse return Error.MissingRequiredTable;
        self.font_directory.head_offset = head_table.offset;
        try self.read_head(self.font_directory.head_offset);
        if (self.find_table("GPOS")) |table| {
            try self.read_gpos(table.offset);
        } else {
            TTF_LOG.warn("no gpos table found\n", .{});
            self.font_directory.gpos = null;
        }
        if (self.find_table("kern")) |table| {
            self.read_kern(table.offset) catch {
                TTF_LOG.warn("Unsupported kern format\n", .{});
                self.font_directory.kern = null;
            };
        } else {
            TTF_LOG.warn("no kern table found\n", .{});
            self.font_directory.kern = null;
        }
        const maxp_table = self.find_table("maxp") orelse return Error.MissingRequiredTable;
        try self.read_maxp(maxp_table.offset);
        const hhea_table = self.find_table("hhea") orelse return Error.MissingRequiredTable;
        try self.read_hhea(hhea_table.offset);
        const hmtx_table = self.find_table("hmtx") orelse return Error.MissingRequiredTable;
        try self.read_hmtx(hmtx_table.offset);
        self.print_table();
        self.print_cmap();
        self.print_format4();
        for (65..91) |i| {
            TTF_LOG.info("{c} = {d}, {d}\n", .{ @as(u8, @intCast(i)), self.get_glyph_index(@as(u16, @intCast(i))), try self.get_glyph_offset(self.get_glyph_index(@as(u16, @intCast(i)))) });
        }
        for (97..123) |i| {
            TTF_LOG.info("{c} = {d}, {d}\n", .{ @as(u8, @intCast(i)), self.get_glyph_index(@as(u16, @intCast(i))), try self.get_glyph_offset(self.get_glyph_index(@as(u16, @intCast(i)))) });
        }
    }

    fn print_table(self: *Self) void {
        TTF_LOG.info("#)\ttag\tlen\toffset\n", .{});
        for (0..self.font_directory.table_directory.len) |i| {
            const dir = self.font_directory.table_directory[i];
            TTF_LOG.info("{d})\t{c}{c}{c}{c}\t{d}\t{d}\n", .{ i + 1, dir.tag[0], dir.tag[1], dir.tag[2], dir.tag[3], dir.length, dir.offset });
        }
    }

    fn gen_curves(self: *Self, glyph_outline: *GlyphOutline) Error!void {
        var points: std.ArrayList(Point) = std.ArrayList(Point).init(self.allocator);
        var previous_point: ?Point = null;
        var cur_point: Point = undefined;
        var previous_flag: bool = false;
        var cur_flag: bool = false;
        TTF_LOG.info("num contours {d} {any}\n", .{ glyph_outline.num_contours, glyph_outline.end_contours });
        glyph_outline.end_curves = try self.allocator.alloc(u16, glyph_outline.end_contours.len);
        var num_curves: u16 = 0;
        var contour_index: usize = 0;
        var curve_points: usize = 0;
        for (0..glyph_outline.x_coord.len) |i| {
            cur_point.x = glyph_outline.x_coord[i];
            cur_point.y = glyph_outline.y_coord[i];
            cur_flag = (glyph_outline.flags[i] & @intFromEnum(GlyphOutline.Flag.on_curve)) == @intFromEnum(GlyphOutline.Flag.on_curve);
            TTF_LOG.debug("{any} {any} {any} {any} {any}\n", .{ previous_point, glyph_outline.flags[i], glyph_outline.flags[i] & @intFromEnum(GlyphOutline.Flag.on_curve), cur_flag, previous_flag });
            if (previous_point != null and !cur_flag and !previous_flag) {
                var midpoint: Point = undefined;
                midpoint.x = @divFloor(cur_point.x + previous_point.?.x, 2);
                midpoint.y = @divFloor(cur_point.y + previous_point.?.y, 2);
                try points.append(midpoint);
                curve_points += 1;
                if (curve_points == 3) {
                    try points.append(midpoint);
                    curve_points = 1;
                    num_curves += 1;
                }
            } else if (previous_point != null and cur_flag and previous_flag and curve_points == 1) {
                var midpoint: Point = undefined;
                midpoint.x = @divFloor(cur_point.x + previous_point.?.x, 2);
                midpoint.y = @divFloor(cur_point.y + previous_point.?.y, 2);
                try points.append(midpoint);
                curve_points += 1;
            }

            try points.append(cur_point);
            curve_points += 1;
            if (curve_points >= 3) {
                try points.append(cur_point);
                curve_points = 1;
                num_curves += 1;
            }
            if (previous_point == null) {
                previous_point = Point{};
            }
            if (i == glyph_outline.end_contours[contour_index]) {
                if (contour_index == 0) {
                    if (curve_points == 1) {
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
                    TTF_LOG.debug("adding point at index {d}\n", .{glyph_outline.end_contours[contour_index - 1] + 1});
                    if (curve_points == 1) {
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
                num_curves += 1;
                glyph_outline.end_curves[contour_index] = num_curves;
                contour_index += 1;
                previous_point = null;
                previous_flag = false;
                curve_points = 0;
            } else {
                previous_point.?.x = cur_point.x;
                previous_point.?.y = cur_point.y;
                previous_flag = cur_flag;
            }
        }
        var curves: std.ArrayList(BezierCurve) = std.ArrayList(BezierCurve).init(self.allocator);
        var i: usize = 0;
        TTF_LOG.debug("flags\n", .{});
        for (glyph_outline.flags) |flag| {
            TTF_LOG.debug("{d}\n", .{flag & @intFromEnum(GlyphOutline.Flag.on_curve)});
        }
        var counter: usize = 0;
        while (i < points.items.len) : (i += 3) {
            if (i + 2 >= points.items.len or i + 1 >= points.items.len) break;
            TTF_LOG.debug("{d} {any} {any} {any}\n", .{ counter, points.items[i], points.items[i + 1], points.items[i + 2] });
            counter += 1;
        }
        i = 0;
        const height = glyph_outline.y_max - glyph_outline.y_min;
        while (i < points.items.len) : (i += 3) {
            if (i + 2 >= points.items.len or i + 1 >= points.items.len) break;
            try curves.append(BezierCurve{
                .p0 = .{ .x = points.items[i].x - glyph_outline.x_min, .y = height - (points.items[i].y - glyph_outline.y_min) },
                .p1 = .{ .x = points.items[i + 1].x - glyph_outline.x_min, .y = height - (points.items[i + 1].y - glyph_outline.y_min) },
                .p2 = .{ .x = points.items[i + 2].x - glyph_outline.x_min, .y = height - (points.items[i + 2].y - glyph_outline.y_min) },
            });
        }
        points.deinit();
        glyph_outline.curves = try curves.toOwnedSlice();
    }

    pub fn load(self: *Self, file_name: []const u8) Error!void {
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
                TTF_LOG.info("simple {c}\n", .{a});
                print_glyph_outline(&glyph_outline.?);
                TTF_LOG.info("{any}\n", .{glyph_outline.?.x_coord});
                try self.gen_curves(&glyph_outline.?);
                try self.char_map.put(a, glyph_outline.?);
            } else {
                TTF_LOG.info("compound {c}\n", .{a});
            }
        }
        self.bit_reader.deinit();
    }
};
