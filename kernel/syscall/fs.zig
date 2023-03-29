const std = @import("std");
const panic = @import("../panic.zig");
const console = @import("../console.zig");

const FD_STDOUT: usize = 1;

/// write buf of length `len`  to a file with `fd`
pub fn sys_write(fd: usize, buf: *const u8, len: usize) isize {
    switch (fd) {
        FD_STDOUT => {
            const buffer = @ptrCast([*]const u8, buf);
            console.logger.print("{s}", .{buffer[0..len]});
            return @intCast(isize, len);
        },
        else => {
            panic.panic("Unsupported fd in sys_write!", .{});
        },
    }
}
