const std = @import("std");
const testing = std.testing;

pub const SV = union(enum) {
    Undef,
    Bool: bool,
    AV: std.MultiArrayList(SV),
    HV: std.StringHashMap(SV),
    IV: i64,
    NV: f64,
    PV: struct { pv: []const u8, num: ?union(enum) { IV, NV, UV } = null },

    UV: u64,
    RV: *SV,

    pub fn isBool(self: SV) bool {
        return self == .Bool;
    }
    pub fn isUndef(self: SV) bool {
        return self == .Undef;
    }
    pub fn UOK(self: SV) bool {
        return self == .UV;
    }
    pub fn NOK(self: SV) bool {
        return self == .NV;
    }
    pub fn IOK(self: SV) bool {
        return self == .IV;
    }
    pub fn PvOK(self: SV) bool {
        return self == .PV;
    }

    pub fn stringify(self: SV) ![]u8 {
        var buf = [_]u8{0} ** 4096;
        switch (self) {
            .PV => return try std.fmt.bufPrint(&buf, "{s}", .{self.PV.pv}),
            .IV => return try std.fmt.bufPrint(&buf, "{d}", .{self.IV}), //std.debug.print("{d}", .{obj.IV}),
            .NV => return try std.fmt.bufPrint(&buf, "{d}", .{self.NV}),
            .UV => return try std.fmt.bufPrint(&buf, "{d}", .{self.UV}),
            else => return "",
        }
    }
};

test "SV" {
    try testing.expect(true);
    const sv: SV = .Undef;
    _ = sv;
    // var pv: SV = .{ .PV = .{ .pv = "Hello" } };
    // try testing.expectEqualStrings("Hello", try pv.stringify());
    // try testing.expectEqual(0, pv.PV.num.?);
    // sv = SV{ .PV = .{ .pv = "YES\n" } };
    // try testing.expectEqualStrings("YES\n", try sv.stringify());
    // sv = SV{ .NV = 1_000_000.394 };
    // try testing.expectEqualStrings("1000000.394", try sv.stringify());
}

test "HV" {
    {
        var hv: SV = .{ .HV = std.StringHashMap(SV).init(testing.allocator) };
        // var hv = SV.HV.init(testing.allocator);

        defer hv.HV.deinit(); // Do not free here!

        try hv.HV.put("Stored", .{ .IV = 99999 });
    }
    //     try av.insert(testing.allocator, 0, .{ .HV = hv });

    //         try testing.expect(av.len == 10);
    // try testing.expect(av.capacity >= 10);

    var hv: SV = .{ .HV = std.StringHashMap(SV).init(testing.allocator) };

    defer {
        // var key_iter = hv.HV.keyIterator();
        // while (key_iter.next()) |key| {
        //     testing.allocator.free(key.*);
        // }
        hv.HV.deinit();
    }
    try hv.HV.put("int", .{ .IV = 100 });
    try hv.HV.put("str", .{ .PV = .{ .pv = "Test" } });

    try testing.expectEqual(2, hv.HV.count());

    var key_ptr = hv.HV.getKeyPtr("int");
    try testing.expect(key_ptr != null);

    key_ptr = hv.HV.getKeyPtr("int");
    try testing.expect(key_ptr != null);

    const iv = hv.HV.get("int").?;
    const pv = hv.HV.get("str").?;

    try testing.expectEqualStrings("100", try iv.stringify());
    try testing.expectEqualStrings("Test", try pv.stringify());

    if (key_ptr) |ptr| {
        hv.HV.removeByPtr(ptr);
    }

    try testing.expect(hv.HV.count() == 1);
}

test "AV" {
    {
        var av: SV = .{ .AV = std.MultiArrayList(SV){} };

        defer av.AV.deinit(testing.allocator);
        try testing.expect(av.AV.len == 0);
        try testing.expect(av.AV.capacity >= 0);
    }
    {
        var av: SV = .{ .AV = std.MultiArrayList(SV){} };
        defer av.AV.deinit(testing.allocator);

        // push
        {
            var i: usize = 0;
            while (i < 10) : (i += 1) {
                av.AV.append(testing.allocator, .{ .IV = @as(i64, @intCast(i + 1)) }) catch unreachable;
            }
        }

        try testing.expect(av.AV.len == 10);
        try testing.expect(av.AV.capacity >= 10);

        // pop
        {
            const sv = av.AV.pop();
            try testing.expectEqualStrings("10", try sv.stringify());
        }

        try testing.expect(av.AV.len == 9);
        // unshift
        {
            var hv: SV = .{ .HV = std.StringHashMap(SV).init(testing.allocator) };

            // defer hv.HV.deinit(); // Do not free here!
            try hv.HV.put("Stored", .{ .IV = 99999 });

            try av.AV.insert(testing.allocator, 0, hv);

            try testing.expect(av.AV.len == 10);
            try testing.expect(av.AV.capacity >= 10);
        }

        // shift
        {
            var hv = av.AV.get(0);
            av.AV.orderedRemove(0);
            try testing.expectEqual(1, hv.HV.count());
            const stored = hv.HV.get("Stored").?;
            try testing.expectEqual(99999, stored.IV);
            defer hv.HV.deinit(); // Freed here but init in unshift above

            try testing.expect(av.AV.len == 9);
            try testing.expect(av.AV.capacity >= 10);
        }
    }
}

test "PV" {
    try testing.expect(true);
    var pv: SV = .{ .PV = .{ .pv = "Hello" } };
    try testing.expectEqualStrings("Hello", try pv.stringify());
    // try testing.expectEqual(0, pv.PV.num.?);
    // sv = SV{ .PV = .{ .pv = "YES\n" } };
    // try testing.expectEqualStrings("YES\n", try sv.stringify());
    // sv = SV{ .NV = 1_000_000.394 };
    // try testing.expectEqualStrings("1000000.394", try sv.stringify());
}
