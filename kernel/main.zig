const console = @import("console.zig");
const riscv = @import("riscv/riscv.zig");
const batch = @import("batch.zig");
const trap = @import("trap/trap.zig");

export fn _kmain() noreturn {
    clear_bss();

    trap.init();
    batch.init();

    batch.run_next_app();
}

fn clear_bss() void {
    const std = @import("std");
    const ExternOptions = std.builtin.ExternOptions;

    const sbss_ptr: ?[*]u8 = @extern([*]u8, ExternOptions{ .name = "sbss" });
    const ebss_ptr: ?[*]u8 = @extern([*]u8, ExternOptions{ .name = "ebss" });
    const sbss_addr = @ptrToInt(sbss_ptr);
    const ebss_addr = @ptrToInt(ebss_ptr);
    const bss_size = ebss_addr - sbss_addr;
    const bss_space = @intToPtr([*]u8, sbss_addr);

    for (bss_space[0..bss_size]) |*b| {
        b.* = 0;
    }
}
