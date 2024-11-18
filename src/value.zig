const std = @import("std");
const testing = std.testing;

pub const Bool = bool;

pub const AV = std.MultiArrayList(SV);

test "AV" {
    {
        var av: AV = std.MultiArrayList(SV){};
        defer av.deinit(testing.allocator);
        try testing.expect(av.len == 0);
        // try testing.expect(av.capacity >= 1);
    }
    {
        var av = AV{};
        defer av.deinit(testing.allocator);

        // push
        {
            var i: usize = 0;
            while (i < 10) : (i += 1) {
                av.append(testing.allocator, .{ .IV = @as(i64, @intCast(i + 1)) }) catch unreachable;
            }
        }

        try testing.expect(av.len == 10);
        try testing.expect(av.capacity >= 10);

        // pop
        {
            const sv = av.pop();
            try testing.expectEqualStrings("10", try sv.stringify());
        }

        try testing.expect(av.len == 9);
        // unshift
        {
            var hv = HV.init(testing.allocator);
            // defer hv.deinit(); // Do not free here!
            try hv.put("Stored", .{ .IV = 99999 });

            try av.insert(testing.allocator, 0, .{ .HV = hv });
        }
        try testing.expect(av.len == 10);
        try testing.expect(av.capacity >= 10);
        // shift
        {
            var hv = av.get(0).HV;
            av.orderedRemove(0);
            try testing.expectEqual(1, hv.count());
            const stored = hv.get("Stored").?;
            try testing.expectEqual(99999, stored.IV);
            defer hv.deinit(); // Freed here but init in unshift above
        }
        try testing.expect(av.len == 9);
        try testing.expect(av.capacity >= 10);
    }
}

pub const HV = std.hash_map.StringHashMap(SV);

test "HV" {
    var hv = HV.init(testing.allocator);
    defer hv.deinit();

    try hv.put("int", .{ .IV = 100 });
    try hv.put("str", .{ .PV = .{ .pv = "Test" } });

    try testing.expectEqual(2, hv.count());

    var key_ptr = hv.getKeyPtr("int");
    try testing.expect(key_ptr != null);

    key_ptr = hv.getKeyPtr("int");
    try testing.expect(key_ptr != null);

    const iv = hv.get("int").?;
    const pv = hv.get("str").?;

    try testing.expectEqualStrings("100", try iv.stringify());
    try testing.expectEqualStrings("Test", try pv.stringify());

    if (key_ptr) |ptr| {
        hv.removeByPtr(ptr);
    }

    try testing.expect(hv.count() == 1);
}

pub const IV = i64;

pub const NV = f64;

pub const PV = struct { pv: []const u8, num: ?union(enum) { IV, NV, UV } = null };

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

pub const UV = u64;

pub const RV = *SV;

pub const SV = union(enum) {
    Undef,
    Bool: Bool,
    AV: AV,
    HV: HV,
    IV: IV,
    NV: NV,
    PV: PV,
    UV: UV,
    RV: RV,

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
