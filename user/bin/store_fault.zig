const console = @import("../console.zig");

export fn main() callconv(.C) i32 {
    console.stdout.info("Into Test store_fault, we will insert an invalid store operation...", .{});
    console.stdout.info("kernel should kill this application !", .{});

    const null_ptr = @intToPtr(*u8, 114514);
    null_ptr.* = 0;

    return 0;
}
