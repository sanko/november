const std = @import("std");
const handy = @import("handy.zig");

const debug = std.debug;
const testing = std.testing;
const mem = std.mem;
const ArrayList = std.ArrayList;

const Allocator = mem.Allocator;

const heap = std.heap;
const process = std.process;
const fatal = process.fatal;
const io = std.io;
const builtin = @import("builtin");
const native_os = builtin.os.tag;

const use_gpa = (!builtin.link_libc) and native_os != .wasi;

// const Obj = @import("./object.zig").Obj;
// const NAN_BOXING = @import("./debug.zig").NAN_BOXING;

// pub const Value = if (NAN_BOXING) NanBoxedValue else UnionValue;

// pub const NanBoxedValue = packed struct {
//     data: u64,

//     const SIGN_BIT: u64 = 0x8000000000000000;
//     const QNAN: u64 = 0x7ffc000000000000;

//     const TAG_NIL = 1; // 01.
//     const TAG_FALSE = 2; // 10.
//     const TAG_TRUE = 3; // 11.

//     const NIL_VAL = NanBoxedValue{ .data = QNAN | TAG_NIL };
//     const TRUE_VAL = NanBoxedValue{ .data = QNAN | TAG_TRUE };
//     const FALSE_VAL = NanBoxedValue{ .data = QNAN | TAG_FALSE };

//     pub fn isBool(self: NanBoxedValue) bool {
//         return (self.data & FALSE_VAL.data) == FALSE_VAL.data;
//     }

//     pub fn isNil(self: NanBoxedValue) bool {
//         return self.data == NIL_VAL.data;
//     }

//     pub fn isNumber(self: NanBoxedValue) bool {
//         return (self.data & QNAN) != QNAN;
//     }

//     pub fn isObj(self: NanBoxedValue) bool {
//         return (self.data & (QNAN | SIGN_BIT)) == (QNAN | SIGN_BIT);
//     }

//     pub fn asNumber(self: NanBoxedValue) f64 {
//         std.debug.assert(self.isNumber());
//         return @bitCast(f64, self.data);
//     }

//     pub fn asBool(self: NanBoxedValue) bool {
//         std.debug.assert(self.isBool());
//         return self.data == TRUE_VAL.data;
//     }

//     pub fn asObj(self: NanBoxedValue) *Obj {
//         std.debug.assert(self.isObj());
//         return @intToPtr(*Obj, @intCast(usize, self.data & ~(SIGN_BIT | QNAN)));
//     }

//     pub fn fromNumber(x: f64) NanBoxedValue {
//         return NanBoxedValue{ .data = @bitCast(u64, x) };
//     }

//     pub fn fromBool(x: bool) NanBoxedValue {
//         return if (x) TRUE_VAL else FALSE_VAL;
//     }

//     pub fn fromObj(x: *Obj) NanBoxedValue {
//         return NanBoxedValue{ .data = SIGN_BIT | QNAN | @ptrToInt(x) };
//     }

//     pub fn nil() NanBoxedValue {
//         return NIL_VAL;
//     }

//     pub fn isFalsey(self: NanBoxedValue) bool {
//         if (self.isBool()) return !self.asBool();
//         if (self.isNil()) return true;
//         return false;
//     }

//     pub fn equals(self: NanBoxedValue, other: NanBoxedValue) bool {
//         // Be careful about IEEE NaN equality semantics
//         if (self.isNumber() and other.isNumber()) return self.asNumber() == other.asNumber();
//         return self.data == other.data;
//     }

//     pub fn format(self: NanBoxedValue, comptime fmt: []const u8, options: std.fmt.FormatOptions, out_stream: anytype) !void {
//         _ = fmt;
//         _ = options;
//         if (self.isNumber()) {
//             try out_stream.print("{d}", .{self.asNumber()});
//         } else if (self.isBool()) {
//             try out_stream.print("{}", .{self.asBool()});
//         } else if (self.isNil()) {
//             try out_stream.print("nil", .{});
//         } else {
//             const obj = self.asObj();
//             try printObject(obj, out_stream);
//         }
//     }
// };

const AV = struct {
    values: ArrayList(SV),

    pub fn init(allocator: Allocator) !AV {
        return .{
            .values = std.ArrayList(SV).init(allocator),
        };
    }

    pub fn deinit(self: AV) void {
        self.values.deinit();
    }

    pub fn push(self: *AV, value: SV) error{OutOfMemory}!void {
        try self.values.append(value);
    }
    pub fn pop(self: *AV) !SV {
        return try self.values.pop();
    }
    pub fn shift(self: *AV) SV {
        return self.values.orderedRemove(0);
    }
    pub fn unshift(self: *AV, value: SV) !SV {
        const dst = self.values.addManyAt(1, 1);
        dst[0] = value;
        return value;
    }
};

test "AV" {
    const allocator = testing.allocator;
    var array = try AV.init(allocator);
    defer array.deinit();
    try testing.expect(array.values.capacity >= 0);
    try testing.expect(array.values.items.len == 0);

    const one = SV{ .IV = 1 };
    try array.push(one);
    for (1..1025) |x| {
        try array.push(SV{ .UV = @intCast(x) });
    }
    try testing.expect(array.values.capacity >= 1025);
    try testing.expect(array.values.items.len == 1025);

    const shifted = array.shift();
    try testing.expect(shifted.IOK());
}

// TODO: dualvar support will require some thinking as Zig doens't allow multiple fields to be defined
pub const SV = union(enum) {
    Bool: bool,
    //     Nil,
    IV: i64,
    UV: u64,
    PV: []u8,
    NV: f64,
    AV: AV,
    // Obj: *Obj,

    pub fn isBool(self: *SV) bool {
        return self == .Bool;
    }

    // pub fn isNil(self: UnionValue) bool {
    //     return self == .Nil;
    // }

    pub fn UOK(self: SV) bool {
        return self == .UV;
    }

    pub fn NOK(self: SV) bool {
        return self == .NV;
    }
    pub fn IOK(self: SV) bool {
        return self == .IV;
    }
    //     pub fn isObj(self: SV) bool {
    //         return self == .Obj;
    //     }

    pub fn asBool(self: SV) bool {
        std.debug.assert(self.isBool());
        return self.Bool;
    }

    pub fn asNumber(self: SV) f64 {
        std.debug.assert(self.isNumber());
        return self.NV;
    }

    //     pub fn asObj(self: SV) *Obj {
    //         std.debug.assert(self.isObj());
    //         return self.Obj;
    //     }

    pub fn fromBool(x: bool) SV {
        return SV{ .Bool = x };
    }

    //     pub fn nil() UnionValue {
    //         return .Nil;
    //     }

    pub fn fromNumber(x: f64) SV {
        return SV{ .NV = x };
    }

    //     pub fn fromObj(x: *Obj) SV {
    //         return SV{ .Obj = x };
    //     }

    pub fn isFalsey(self: SV) bool {
        return switch (self) {
            .Bool => |x| !x,
            // .Nil => true,
            .NV => false,
            // .Obj => false,
        };
    }

    pub fn equals(aBoxed: SV, bBoxed: SV) bool {
        return switch (aBoxed) {
            .Bool => |a| {
                return switch (bBoxed) {
                    .Bool => |b| a == b,
                    else => false,
                };
            },
            // .Nil => {
            //     return switch (bBoxed) {
            //         .Nil => true,
            //         else => false,
            //     };
            // },
            .NV => |a| {
                return switch (bBoxed) {
                    .NV => |b| a == b,
                    else => false,
                };
            },
            // .Obj => |a| {
            //     return switch (bBoxed) {
            //         .Obj => |b| a == b,
            //         else => false,
            //     };
            // },
        };
    }

    pub fn format(self: SV, comptime fmt: []const u8, options: std.fmt.FormatOptions, out_stream: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .Bool => |value| try out_stream.print("{}", .{value}),
            .NV => |value| try out_stream.print("{d}", .{value}),
            // .Nil => try out_stream.print("nil", .{}),
            // .Obj => |obj| try printObject(obj, out_stream),
        }
    }
};

// // Shared between the two value representations
// fn printObject(obj: *Obj, out_stream: anytype) !void {
//     switch (obj.objType) {
//         .String => try out_stream.print("{s}", .{obj.asString().bytes}),
//         .Function => {
//             const name = if (obj.asFunction().name) |str| str.bytes else "<script>";
//             try out_stream.print("<fn {s}>", .{name});
//         },
//         .NativeFunction => {
//             try out_stream.print("<native fn>", .{});
//         },
//         .Closure => {
//             const name = if (obj.asClosure().function.name) |str| str.bytes else "<script>";
//             try out_stream.print("<fn {s}>", .{name});
//         },
//         .Upvalue => {
//             try out_stream.print("upvalue", .{});
//         },
//         .Class => {
//             try out_stream.print("{s}", .{obj.asClass().name.bytes});
//         },
//         .Instance => {
//             try out_stream.print("{s} instance", .{obj.asInstance().class.name.bytes});
//         },
//         .BoundMethod => {
//             const name = if (obj.asBoundMethod().method.function.name) |str| str.bytes else "<script>";
//             try out_stream.print("<fn {s}>", .{name});
//         },
//     }
// }
