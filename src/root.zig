//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

pub const bytecode = @import("bytecode.zig");
pub const chunk = @import("chunk.zig");
pub const ffi = @import("ffi.zig");
pub const fiber = @import("fiber.zig");
pub const io = @import("io.zig");
pub const jit = @import("jit.zig");
pub const platform = @import("platform.zig");
pub const scanner = @import("scanner.zig");
pub const threads = @import("threads.zig");
pub const tokenizer = @import("tokenizer.zig");
pub const value = @import("value.zig");
pub const vm = @import("vm.zig");
pub const VM = vm.VM;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

test "suite" {
    testing.refAllDeclsRecursive(@This());
}
