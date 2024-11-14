const std = @import("std");
const builtin = @import("builtin");
const net = std.net;
const mem = std.mem;
const testing = std.testing;
const thread = std.Thread;
const SV = @import("Value.zig").SV;
// const test = std.testing;

// const expect = test.expect;

fn ticker(step: u8) void {
    while (true) {
        std.time.sleep(1 * std.time.ns_per_s);
        tick += @as(isize, step);
    }
}

var tick: isize = 0;

test "threading" {
    const t = try thread.spawn(.{}, ticker, .{@as(u8, 1)});
    _ = t;
    try std.testing.expect(tick == 0);
    std.time.sleep(3 * std.time.ns_per_s / 2);
    try std.testing.expect(tick == 1);
}

test "threads w/ sockets" {
    // See https://github.com/ziglang/zig/blob/5c0766b6c8f1aea18815206e0698953a35384a21/lib/std/net/test.zig#L167
    try std.testing.expect(1 == 1);
    if (builtin.single_threaded) return error.SkipZigTest;
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    if (builtin.os.tag == .windows) {
        _ = try std.os.windows.WSAStartup(2, 2);
    }
    defer {
        if (builtin.os.tag == .windows) {
            std.os.windows.WSACleanup() catch unreachable;
        }
    }

    // const localhost = try net.Address.parseIp("127.0.0.1", 0);
    const localhost = try net.Address.parseIp("::1", 0);

    var server = try localhost.listen(.{});
    defer server.deinit();

    const S = struct {
        fn clientFn(server_address: net.Address) !void {
            const socket = try net.tcpConnectToAddress(server_address);
            defer socket.close();

            _ = try socket.writer().writeAll("Hello world!");
        }
    };

    const t = try std.Thread.spawn(.{}, S.clientFn, .{server.listen_address});
    defer t.join();

    var client = try server.accept();
    defer client.stream.close();
    var buf: [16]u8 = undefined;
    const n = try client.stream.reader().read(&buf);

    try testing.expectEqual(@as(usize, 12), n);
    try testing.expectEqualSlices(u8, "Hello world!", buf[0..n]);
}
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
