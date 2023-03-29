const std = @import("std");
const syscall = @import("syscall.zig");
const console = @import("console.zig");

extern fn main() callconv(.C) i32;

export fn _start() linksection(".text.entry") callconv(.C) noreturn {
    clear_bss();
    _ = syscall.sys_exit(main());
    unreachable;
}

fn clear_bss() void {
    const ExternOptions = std.builtin.ExternOptions;

    const sbss_ptr: ?[*]u8 = @extern([*]u8, ExternOptions{ .name = "start_bss" });
    const ebss_ptr: ?[*]u8 = @extern([*]u8, ExternOptions{ .name = "end_bss" });
    const sbss_addr = @ptrToInt(sbss_ptr);
    const ebss_addr = @ptrToInt(ebss_ptr);
    const bss_size = ebss_addr - sbss_addr;
    const bss_space = @intToPtr([*]u8, sbss_addr);

    for (bss_space[0..bss_size]) |*b| {
        b.* = 0;
    }
}
