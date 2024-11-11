const std = @import("std");
const SV = @import("SV.zig");
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

pub const OpCode = enum {
    OP_RETURN,
};

const Chunky = struct {
    // allocator: mem.Allocator,
    code: ArrayList(u64),
    constants: ArrayList(SV),

    pub fn init(allocator: Allocator) !Chunky {
        return .{
            // .allocator = allocator,
            .code = std.ArrayList(u64).init(allocator),
            .constants = std.ArrayList(SV).init(allocator),
        };
    }

    pub fn deinit(self: Chunky) void {
        self.code.deinit();
        self.constants.deinit();
    }

    pub fn add(self: *Chunky, code: u64) error{OutOfMemory}!void {
        try self.code.append(code);
    }
};

test "writeChunk" {
    const allocator = gp: {
        if (native_os == .wasi) {
            break :gp heap.wasm_allocator;
        }
        if (use_gpa) {
            var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
            //general_purpose_allocator.deinit();
            break :gp general_purpose_allocator.allocator();
        }
        // We would prefer to use raw libc allocator here, but cannot
        // use it if it won't support the alignment we need.
        if (@alignOf(std.c.max_align_t) < @max(@alignOf(i128), std.atomic.cache_line)) {
            break :gp std.heap.c_allocator;
        }
        break :gp std.heap.raw_c_allocator;
    };

    var chunky = try Chunky.init(allocator);
    defer chunky.deinit();
    for (1..1025) |x| {
        try chunky.add(10);
        std.debug.print("loop: {}, capacity: {}, items: {}\n", .{ x, chunky.code.capacity, chunky.code.items.len });
    }
}

pub const Chunk = struct {
    const Self = @This();
};

// test "return" {
//     try testing.expect(2 == 2);
//     const chunk = Chunk.init();
//     try testing.expect(chunk.count == 0);
// }
