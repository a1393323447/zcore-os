pub const console = @import("console.zig");
pub const lib = @import("lib.zig");
pub const syscall = @import("syscall.zig");

const Self = @This();

test {
    const std = @import("std");
    std.testing.refAllDecls(Self);
}
