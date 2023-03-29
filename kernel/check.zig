pub const m = @import("main.zig");
pub const sbi = @import("sbi.zig");
pub const console = @import("console.zig");
pub const batch = @import("batch.zig");
pub const trap = @import("trap/trap.zig");
pub const riscv = @import("riscv/riscv.zig");

const Self = @This();

test {
    const std = @import("std");
    std.testing.refAllDecls(Self);
}
