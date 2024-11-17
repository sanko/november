const std = @import("std");
const builtin = @import("builtin");
const net = std.net;
const mem = std.mem;
const testing = std.testing;
const thread = std.Thread;
const SV = @import("value.zig").SV;

pub const Fiber = struct {
    func: ?fn (value: SV) SV = null,
    is_done: bool = false,

    pub fn init(comptime fun: fn (value: SV) SV) Fiber {
        return .{ .func = fun };
    }

    fn deinit(self: Fiber) !void {
        //  self.out
        _ = self;
    }

    pub fn call(self: Fiber, value: SV) !bool {
        if (self.func == null) {
            return false;
        }
        _ = self.func.?(value);
        return true;
    }
    pub fn yield(self: Fiber) void {
        _ = self;
    }
};

fn ugh(value: SV) SV { // will eventually be a spot in bytecode
    return value;
    // value.format("Hi", .{}, .{});
    // std.debug.print("{s}\n", .{str});
}

test "Fibers" {
    const fiber = Fiber.init(ugh);
    // defer fiber.deinit();
    const one = SV{ .IV = 1 };
    try std.testing.expect(try fiber.call(one));
}
