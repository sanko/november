const std = @import("std");
const testing = std.testing;

pub fn main() !void {
    try testing.expect(true);

    return;
}

test "Oh, I hope this works" {
    try testing.expect(true);
}
