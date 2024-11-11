const std = @import("std");
const SV = @import("SV.zig");
const handy = @import("handy.zig");

const debug = std.debug;
const testing = std.testing;
const mem = std.mem;
const ArrayList = std.ArrayList;

const builtin = @import("builtin");
const native_os = builtin.os.tag;

pub const OpCode = enum {
    OP_RETURN,
};

pub const Chunk = struct {
    count: i64 = 0,
    capacity: i64 = 0,
    code: ArrayList(u8),
    constants: ArrayList(SV),

    //    writeChunk: fn (byte: u8) void,
    pub fn init() Chunk {
        Chunk{ .code = ArrayList(u8).init(handy.allocator), .constants = ArrayList(u8).init(handy.allocator) };
    }

    test "return" {
        try testing.expect(2 == 2);

        const chunk = Chunk.init();

        try testing.expect(chunk.count == 0);

        // const memory = try handy.allocator.alloc(u8, 100);
        // defer _ = chunk.allocator.free(memory);
    }

    fn GROW_CAPACITY(capacity: u8) u8 {
        if (capacity < 8) {
            return 8;
        }
        return capacity * 2; // TODO: Make this smart. Up to a certain point, we double every time.
    }

    fn writeChunk(chunk: Chunk, byte: u8) void {
        if (chunk.capacity < chunk.count + 1) {
            debug.print("capacity: {}", .{chunk.capacity});
            const oldCapacity = chunk.capacity;
            chunk.capacity = GROW_CAPACITY(oldCapacity);
            chunk.allocator.realloc(oldCapacity, chunk.capacity);
        }
        chunk.code[chunk.count] = byte;
        chunk.count += 1;
    }

    test "writeChunk" {
        const chunk = Chunk.init();
        try testing.expect(chunk.count == 0);
        chunk.writeChunk(0);
        try testing.expect(chunk.count == 1);
        try testing.expect(chunk.capacity == 8);
        for (1..10) |i| {
            chunk.writeChunk(0);
            std.debug.print("{d}\n", .{i});
        }
        try testing.expect(chunk.count == 1);
        try testing.expect(chunk.capacity == 16);

        // const memory = try handy.allocator.alloc(u8, 100);
        // defer _ = chunk.allocator.free(memory);
    }
};
