const console = @import("console.zig");
const riscv = @import("riscv/riscv.zig");
const batch = @import("batch.zig");
const trap = @import("trap/trap.zig");

export fn _kmain() noreturn {
    clear_bss();

    print_logo();

    trap.init();
    batch.init();

    batch.run_next_app();
}

fn print_logo() void {
    const logo =
        \\  ________   ____                                  _____   ____       
        \\ /\_____  \ /\  _`\                               /\  __`\/\  _`\     
        \\ \/____//'/'\ \ \/\_\    ___   _ __    __         \ \ \/\ \ \,\L\_\   
        \\     //'/'  \ \ \/_/_  / __`\/\`'__\/'__`\ _______\ \ \ \ \/_\__ \   
        \\     //'/'___ \ \ \L\ \/\ \L\ \ \ \//\  __//\______\\ \ \_\ \/\ \L\ \ 
        \\     /\_______\\ \____/\ \____/\ \_\\ \____\/______/ \ \_____\ `\____\
        \\     \/_______/ \/___/  \/___/  \/_/ \/____/          \/_____/\/_____/
    ;
    console.logger.print(console.Color.Green.dye(logo ++ "\n"), .{});
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
