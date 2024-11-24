const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
const v = @import("value.zig");
const SV = v.SV;
const IV = v.SV.IV;
const AV = v.SV.AV;
const chunk_ = @import("chunk.zig");
const Chunk = chunk_.Chunk;
const OpCode = chunk_.OpCode;
const testing = std.testing;

const debug_trace: bool = true;
pub const max_frames = 64;
pub const max_stack = max_frames * @sizeOf(u8);

pub fn clockNative(argCount: u32, args: []SV) SV {
    _ = argCount;
    _ = args;
    return .{ .IV = std.time.timestamp() };
}

const InterpreterResult = enum { OK, COMPILE_ERROR, RUNTIME_ERROR };

pub const Frame = struct {
    //  ObjClosure* closure;

    ip: std.ArrayList(u8),
    slots: std.ArrayList(SV),
};

pub const VM = struct {
    allocator: std.mem.Allocator,
    stack: std.ArrayList(SV),
    // ip: std.ArrayList(u8),
    chunk: Chunk,

    pub fn init(self: *VM, alloc: std.mem.Allocator, chunk: Chunk) !void {
        var av: SV = .{ .AV = std.MultiArrayList(SV){} };
        defer av.AV.deinit(alloc);

        self.* = .{ // lvalue!
            .allocator = alloc,
            .stack = std.ArrayList(SV).init(alloc),
            // .ip = std.ArrayList(u8).init(alloc),
            .chunk = chunk,
        };
    }
    pub fn deinit(self: *VM) void {
        self.stack.deinit();
        // self.ip.deinit();
    }

    pub fn run(self: VM) InterpreterResult {
        var instruction: chunk_.OpCode = 0;
        var i: usize = 0;
        var c: Chunk = undefined;
        while (i < self.chunk.code.items.len) {
            if (debug_trace) {
                // for (1..self.stack.items.len) |index| {
                // std.debug.print("{d:04}: {s}", .{ index, self.stack.items.ptr[index] });
                // std.debug.print("{d:05} ", .{offset});
                // const instruction = self.code.items[offset];
                // }
                c = self.chunk;
                _ = c.disassembleInstruction(i);
            }
            instruction = self.chunk.code.items[i];

            switch (instruction) {
                chunk_.OP_RETURN => {
                    i += 1;
                },
                chunk_.OP_CONSTANT => {
                    const value =
                        self.chunk.constants.get(self.chunk.code.items[instruction + 1]);
                    // std.debug.print("{s}", .{try value.stringify()});
                    _ = value;
                    i += 2;
                },
                else => return InterpreterResult.RUNTIME_ERROR,
            }
            // switch(instruction = )

        }

        return InterpreterResult.OK;
    }

    pub fn interpret(self: VM, source: []u8) InterpreterResult {
        _ = self;
        _ = source;
        return InterpreterResult.COMPILE_ERROR;
    }

    pub fn resetStack(self: *VM) void {
        self.stack.clearAndFree();
    }
    pub fn popStack(self: *VM) SV {
        return self.stack.pop();
    }
    pub fn pushStack(self: *VM, value: SV) !void {
        return self.stack.append(value);
    }
};

test "alpha" {
    const allocator = testing.allocator;
    var chunky = try Chunk.init(allocator);
    defer chunky.deinit();
    _ = try chunky.addConstant(.{ .NV = 1.2 });
    try chunky.add(chunk_.OP_RETURN, 1);

    var vm: VM = undefined;
    try vm.init(testing.allocator, chunky);
    defer vm.deinit();
    _ = vm.run();
    try chunky.disassembleChunk("Test");
}
