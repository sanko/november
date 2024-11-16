const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");

pub const VM = struct {
    allocator: std.mem.Allocator,

    pub fn init(self: *VM, alloc: std.mem.Allocator) !void {
        self.* = .{ // lvalue!
            .allocator = alloc,
        };
    }
    pub fn deinit(self: *VM) void {
        _ = self;
    }
};
