const std = @import("std");
const SV = @import("value.zig").SV;

const debug = std.debug;
const testing = std.testing;
const mem = std.mem;
const ArrayList = std.ArrayList;
const MultiArrayList = std.MultiArrayList;

const Allocator = mem.Allocator;

const heap = std.heap;
const process = std.process;
const fatal = process.fatal;
const io = std.io;
const builtin = @import("builtin");
const native_os = builtin.os.tag;
const use_gpa = (!builtin.link_libc) and native_os != .wasi;

const sv = @import("value.zig");
const AV = sv.AV;

pub const OpCode = usize;

pub const OP_CONSTANT: OpCode = 0;
pub const OP_RETURN: OpCode = 1;

pub const Chunk = struct {
    alloc: mem.Allocator,
    code: ArrayList(OpCode),
    constants: MultiArrayList(SV),
    lines: ArrayList(usize),

    pub fn init(allocator: Allocator) !Chunk {
        return .{
            .alloc = allocator,
            .code = std.ArrayList(OpCode).init(allocator),
            .constants = std.MultiArrayList(SV){},
            .lines = std.ArrayList(usize).init(allocator),
        };
    }

    pub fn deinit(self: *Chunk) void {
        self.code.deinit();
        //var consts = self.constants;
        self.constants.clearAndFree(self.alloc);
        //consts.deinit(self.alloc);
        self.lines.deinit();
    }

    pub fn add(self: *Chunk, code: OpCode, line: usize) error{OutOfMemory}!void {
        self.code.append(code) catch |err| {
            return err;
        };
        return self.lines.append(line);
    }

    pub fn simpleInstruction(self: *Chunk, name: []const u8, offset: usize) usize {
        debug.print("{s}\n", .{name});
        _ = self;
        return offset + 1;
    }

    pub fn constantInstruction(self: *Chunk, name: []const u8, offset: usize) usize {
        debug.print("{s} @ {d}\n", .{ name, offset });
        const value =
            self.constants.get(self.code.items[offset + 1]);
        debug.print("    {s} @ {d}\n", .{ name, value.NV });
        return offset + 2;
    }

    pub fn disassembleChunk(self: *Chunk, name: []const u8) !void {
        debug.print("== {s} ==\n", .{name});
        var offset: usize = 0;
        const y = self.code.items.len;
        while (offset < y) {
            offset = self.disassembleInstruction(offset);
        }
    }

    pub fn disassembleInstruction(self: *Chunk, offset: usize) usize {
        debug.print("{d:05} ", .{offset});
        const instruction = self.code.items[offset];
        switch (instruction) {
            OP_RETURN => return self.simpleInstruction("OP_RETURN", offset),
            OP_CONSTANT => return self.constantInstruction("OP_CONSTANT", offset),
            else => return 0,
        }
    }

    pub fn addConstant(self: *Chunk, value: SV) error{OutOfMemory}!usize {
        try self.constants.append(self.alloc, value);
        // var y = self;
        // try y.add(OP_CONSTANT);
        // try y.add(self.constants.len);
        return self.constants.len;
    }
};

test "writeChunk" {
    const allocator = testing.allocator;
    var chunky = try Chunk.init(allocator);
    defer chunky.deinit();
    try testing.expect(chunky.code.capacity >= 0);
    try testing.expect(chunky.code.items.len == 0);
    for (1..1025) |x| {
        _ = x;
        try chunky.add(OP_RETURN, 1);
    }
    try testing.expect(chunky.code.capacity >= 1025);
    try testing.expect(chunky.code.items.len == 1024);
}

test "disassembleChunk" {
    const allocator = testing.allocator;
    var chunky = try Chunk.init(allocator);
    defer chunky.deinit();
    try chunky.add(OP_RETURN, 1);
    try testing.expect(chunky.code.items.len == 1);
    try chunky.disassembleChunk("Test");
}

test "writeConstant" {
    const allocator = testing.allocator;
    var chunky = try Chunk.init(allocator);
    defer chunky.deinit();
    _ = try chunky.addConstant(.{ .NV = 1.2 });

    // try chunky.disassembleChunk("Test");
}
