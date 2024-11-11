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

pub const OpCode = enum(u64) {
    OP_RETURN,
    pub fn isReturn(self: OpCode) bool {
        return self == OpCode.OP_RETURN;
    }
};

const Chunky = struct {
    code: ArrayList(OpCode),
    constants: ArrayList(SV),

    pub fn init(allocator: Allocator) !Chunky {
        return .{
            .code = std.ArrayList(OpCode).init(allocator),
            .constants = std.ArrayList(SV).init(allocator),
        };
    }

    pub fn deinit(self: Chunky) void {
        self.code.deinit();
        self.constants.deinit();
    }

    pub fn add(self: *Chunky, code: OpCode) error{OutOfMemory}!void {
        try self.code.append(code);
    }

    pub fn simpleInstruction(self: *Chunky, name: []const u8, offset: usize) usize {
        debug.print("{s}\n", .{name});
        _ = self;
        return offset + 1;
    }

    pub fn disassembleChunk(self: *Chunky, name: []const u8) !void {
        debug.print("== {s} ==\n", .{name});
        var offset: usize = 0;
        const y = self.code.items.len;
        while (offset < y) {
            offset = self.disassembleInstruction(offset);
        }
    }
    pub fn disassembleInstruction(self: *Chunky, offset: usize) usize {
        debug.print("{d:05} ", .{offset});
        const instruction = self.code.items[offset];
        switch (instruction) {
            .OP_RETURN => {
                return self.simpleInstruction("OP_RETURN", offset);
            },
            // else => {},
        }
    }
};

test "writeChunk" {
    const allocator = testing.allocator;
    var chunky = try Chunky.init(allocator);
    defer chunky.deinit();
    try testing.expect(chunky.code.capacity >= 0);
    try testing.expect(chunky.code.items.len == 0);
    for (1..1025) |x| {
        _ = x;
        try chunky.add(OpCode.OP_RETURN);
    }
    try testing.expect(chunky.code.capacity >= 1025);
    try testing.expect(chunky.code.items.len == 1024);
}

test "disassembleChunk" {
    const allocator = testing.allocator;
    var chunky = try Chunky.init(allocator);
    defer chunky.deinit();
    try chunky.add(OpCode.OP_RETURN);
    try testing.expect(chunky.code.items.len == 1);
    try chunky.disassembleChunk("Test");
}
