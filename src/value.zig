const std = @import("std");
const testing = std.testing;

const Bool = bool;

const AV = struct {};

const HV = std.hash_map.StringHashMap(SV);

test "HV" {
    try testing.expect(true);
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

const IV = i64;

const NV = f64;

const PV = struct { pv: []const u8, num: ?union(enum) { IV, NV, UV } = null };

const UV = u64;

const RV = *SV;

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
