const std = @import("std");
const SV = @import("value.zig").SV;

const debug = std.debug;
const assert = debug.assert;

const testing = std.testing;
const mem = std.mem;
const math = std.math;
const io = std.io;

pub fn BufferedWriter(comptime buffer_size: usize, comptime WriterType: type) type {
    return struct {
        unbuffered_writer: WriterType,
        buf: [buffer_size]u8 = undefined,
        end: usize = 0,

        pub const Error = WriterType.Error;
        pub const Writer = io.Writer(*Self, Error, write);

        const Self = @This();

        pub fn flush(self: *Self) !void {
            try self.unbuffered_writer.writeAll(self.buf[0..self.end]);
            self.end = 0;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn write(self: *Self, bytes: []const u8) Error!usize {
            if (self.end + bytes.len > self.buf.len) {
                try self.flush();
                if (bytes.len > self.buf.len)
                    return self.unbuffered_writer.write(bytes);
            }

            const new_end = self.end + bytes.len;
            @memcpy(self.buf[self.end..new_end], bytes);
            self.end = new_end;
            return bytes.len;
        }
    };
}

pub fn bufferedWriter(underlying_stream: anytype) BufferedWriter(4096, @TypeOf(underlying_stream)) {
    return .{ .unbuffered_writer = underlying_stream };
}

pub fn BufferedReader(comptime buffer_size: usize, comptime ReaderType: type) type {
    return struct {
        unbuffered_reader: ReaderType,
        buf: [buffer_size]u8 = undefined,
        start: usize = 0,
        end: usize = 0,

        pub const Error = ReaderType.Error;
        pub const Reader = io.Reader(*Self, Error, read);

        const Self = @This();

        pub fn read(self: *Self, dest: []u8) Error!usize {
            // First try reading from the already buffered data onto the destination.
            const current = self.buf[self.start..self.end];
            if (current.len != 0) {
                const to_transfer = @min(current.len, dest.len);
                @memcpy(dest[0..to_transfer], current[0..to_transfer]);
                self.start += to_transfer;
                return to_transfer;
            }

            // If dest is large, read from the unbuffered reader directly into the destination.
            if (dest.len >= buffer_size) {
                return self.unbuffered_reader.read(dest);
            }

            // If dest is small, read from the unbuffered reader into our own internal buffer,
            // and then transfer to destination.
            self.end = try self.unbuffered_reader.read(&self.buf);
            const to_transfer = @min(self.end, dest.len);
            @memcpy(dest[0..to_transfer], self.buf[0..to_transfer]);
            self.start = to_transfer;
            return to_transfer;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}

pub fn bufferedReader(reader: anytype) BufferedReader(4096, @TypeOf(reader)) {
    return .{ .unbuffered_reader = reader };
}

pub fn bufferedReaderSize(comptime size: usize, reader: anytype) BufferedReader(size, @TypeOf(reader)) {
    return .{ .unbuffered_reader = reader };
}

test "OneByte" {
    const OneByteReadReader = struct {
        str: []const u8,
        curr: usize,

        const Error = error{NoError};
        const Self = @This();
        const Reader = io.Reader(*Self, Error, read);

        fn init(str: []const u8) Self {
            return Self{
                .str = str,
                .curr = 0,
            };
        }

        fn read(self: *Self, dest: []u8) Error!usize {
            if (self.str.len <= self.curr or dest.len == 0)
                return 0;

            dest[0] = self.str[self.curr];
            self.curr += 1;
            return 1;
        }

        fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };

    const str = "This is a test";
    var one_byte_stream = OneByteReadReader.init(str);
    var buf_reader = bufferedReader(one_byte_stream.reader());
    const stream = buf_reader.reader();

    const res = try stream.readAllAlloc(testing.allocator, str.len + 1);
    defer testing.allocator.free(res);
    try testing.expectEqualSlices(u8, str, res);
}

fn smallBufferedReader(underlying_stream: anytype) BufferedReader(8, @TypeOf(underlying_stream)) {
    return .{ .unbuffered_reader = underlying_stream };
}
test "Block" {
    const BlockReader = struct {
        block: []const u8,
        reads_allowed: usize,
        curr_read: usize,

        const Error = error{NoError};
        const Self = @This();
        const Reader = io.Reader(*Self, Error, read);

        fn init(block: []const u8, reads_allowed: usize) Self {
            return Self{
                .block = block,
                .reads_allowed = reads_allowed,
                .curr_read = 0,
            };
        }

        fn read(self: *Self, dest: []u8) Error!usize {
            if (self.curr_read >= self.reads_allowed) return 0;
            @memcpy(dest[0..self.block.len], self.block);

            self.curr_read += 1;
            return self.block.len;
        }

        fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
    {
        const block = "0123";

        // len out == block
        {
            var test_buf_reader: BufferedReader(4, BlockReader) = .{
                .unbuffered_reader = BlockReader.init(block, 2),
            };
            const reader = test_buf_reader.reader();
            var out_buf: [4]u8 = undefined;
            _ = try reader.readAll(&out_buf);
            try testing.expectEqualSlices(u8, &out_buf, block);
            _ = try reader.readAll(&out_buf);
            try testing.expectEqualSlices(u8, &out_buf, block);
            try testing.expectEqual(try reader.readAll(&out_buf), 0);
        }

        // len out < block
        {
            var test_buf_reader: BufferedReader(4, BlockReader) = .{
                .unbuffered_reader = BlockReader.init(block, 2),
            };
            const reader = test_buf_reader.reader();
            var out_buf: [3]u8 = undefined;
            _ = try reader.readAll(&out_buf);
            try testing.expectEqualSlices(u8, &out_buf, "012");
            _ = try reader.readAll(&out_buf);
            try testing.expectEqualSlices(u8, &out_buf, "301");
            const n = try reader.readAll(&out_buf);
            try testing.expectEqualSlices(u8, out_buf[0..n], "23");
            try testing.expectEqual(try reader.readAll(&out_buf), 0);
        }

        // len out > block
        {
            var test_buf_reader: BufferedReader(4, BlockReader) = .{
                .unbuffered_reader = BlockReader.init(block, 2),
            };
            const reader = test_buf_reader.reader();
            var out_buf: [5]u8 = undefined;
            _ = try reader.readAll(&out_buf);
            try testing.expectEqualSlices(u8, &out_buf, "01230");
            const n = try reader.readAll(&out_buf);
            try testing.expectEqualSlices(u8, out_buf[0..n], "123");
            try testing.expectEqual(try reader.readAll(&out_buf), 0);
        }

        // len out == 0
        {
            var test_buf_reader: BufferedReader(4, BlockReader) = .{
                .unbuffered_reader = BlockReader.init(block, 2),
            };
            const reader = test_buf_reader.reader();
            var out_buf: [0]u8 = undefined;
            _ = try reader.readAll(&out_buf);
            try testing.expectEqualSlices(u8, &out_buf, "");
        }

        // len bufreader buf > block
        {
            var test_buf_reader: BufferedReader(5, BlockReader) = .{
                .unbuffered_reader = BlockReader.init(block, 2),
            };
            const reader = test_buf_reader.reader();
            var out_buf: [4]u8 = undefined;
            _ = try reader.readAll(&out_buf);
            try testing.expectEqualSlices(u8, &out_buf, block);
            _ = try reader.readAll(&out_buf);
            try testing.expectEqualSlices(u8, &out_buf, block);
            try testing.expectEqual(try reader.readAll(&out_buf), 0);
        }
    }
}

const MyWriter = struct {
    allocator: mem.Allocator,
    items: std.ArrayList(u8),
    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        return .{ .allocator = allocator, .items = std.ArrayList(u8).init(allocator) };
    }

    pub fn deinit(self: Self) !void {
        self.items.deinit();
    }

    // context: *const anyopaque,
    // writeFn: *const fn (context: *const anyopaque, bytes: []const u8) anyerror!usize,

    pub const Error = anyerror;

    const Writer = std.io.Writer(
        *Self,
        error{ EndOfBuffer, OutOfMemory },
        appendWrite,
    );
    fn appendWrite(
        self: *Self,
        data: []const u8,
    ) error{ EndOfBuffer, OutOfMemory }!usize {
        try self.items.appendSlice(data);
        return data.len;
    }

    fn writer(self: *Self) Writer {
        return .{ .context = self };
    }

    pub fn write(self: Self, bytes: []const u8) anyerror!usize {
        return self.writeFn(self.context, bytes);
    }

    pub fn writeAll(self: Self, bytes: []const u8) anyerror!void {
        var index: usize = 0;
        while (index != bytes.len) {
            index += try self.write(bytes[index..]);
        }
    }

    pub fn print(self: Self, comptime format: []const u8, args: anytype) anyerror!void {
        return std.fmt.format(self, format, args);
    }

    pub fn writeByte(self: Self, byte: u8) anyerror!void {
        const array = [1]u8{byte};
        return self.writeAll(&array);
    }

    pub fn writeByteNTimes(self: Self, byte: u8, n: usize) anyerror!void {
        var bytes: [256]u8 = undefined;
        @memset(bytes[0..], byte);

        var remaining: usize = n;
        while (remaining > 0) {
            const to_write = @min(remaining, bytes.len);
            try self.writeAll(bytes[0..to_write]);
            remaining -= to_write;
        }
    }

    pub fn writeBytesNTimes(self: Self, bytes: []const u8, n: usize) anyerror!void {
        var i: usize = 0;
        while (i < n) : (i += 1) {
            try self.writeAll(bytes);
        }
    }

    pub inline fn writeInt(self: Self, comptime T: type, value: T, endian: std.builtin.Endian) anyerror!void {
        var bytes: [@divExact(@typeInfo(T).int.bits, 8)]u8 = undefined;
        mem.writeInt(std.math.ByteAlignedInt(@TypeOf(value)), &bytes, value, endian);
        return self.writeAll(&bytes);
    }

    pub fn writeFile(self: Self, file: std.fs.File) anyerror!void {
        // TODO: figure out how to adjust std lib abstractions so that this ends up
        // doing sendfile or maybe even copy_file_range under the right conditions.
        var buf: [4000]u8 = undefined;
        while (true) {
            const n = try file.readAll(&buf);
            try self.writeAll(buf[0..n]);
            if (n < buf.len) return;
        }
    }
};

test "custom writer" {
    // const fh = std.io.getStdOut();
    // var stdin = MyReader{};
    // try stdin.reader().read(10);
    {
        // const in = std.io.getStdIn();
        // var buf = std.io.bufferedReader(in.reader());

        // // Get the Reader interface from BufferedReader
        // var r = buf.reader();

        // std.debug.print("Write something: ", .{});
        // // Ideally we would want to issue more than one read
        // // otherwise there is no point in buffering.
        // var msg_buf: [4096]u8 = undefined;
        // const msg = try r.readUntilDelimiterOrEof(&msg_buf, '\n');

        // if (msg) |m| {
        //     std.debug.print("msg: {s}\n", .{m});
        // }
    }

    {
        var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
        var stdout = bw.writer();
        debug.print("buf: {d}\n", .{bw.end});

        try stdout.print("{s}\n", .{"hipppppppppppppppppppppppppppppppppppppppppppppppppppppppppp\n"});
        debug.print("buf: {d}\n", .{bw.end});

        try stdout.writeAll("fdsafdsafddddddddddddd\n");
        debug.print("buf: {d}\n", .{bw.end});

        try stdout.writeByte('\n');
        debug.print("buf: {d}\n", .{bw.end});
        try bw.flush();
        // try stdout.writeAll();
    }

    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // _ = try bw.write("Here");
    // try bw.flush();
    // _ = try stdout_file.writer().write("hi");
    // _ = fh;
    var stdout = try MyWriter.init(testing.allocator);
    defer {
        stdout.deinit() catch
            {};
    }
    _ = try stdout.writer().write("hi");
    // _ = try stdout.writer().write("Hello");
    // _ = try stdout.writer().write(" Writer!");
    try testing.expectEqualStrings(stdout.items.items, "hi");
}
