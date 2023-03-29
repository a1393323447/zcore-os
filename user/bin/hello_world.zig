const console = @import("../console.zig");

export fn main() callconv(.C) i32 {
    console.stdout.print("hello world\n", .{});
    return 0;
}
