const std = @import("std");
const console = @import("../console.zig");

const SIZE: usize = 10;
const P: u32 = 3;
const STEP: usize = 100000;
const MOD: u32 = 10007;

export fn main() callconv(.C) i32 {
    var pow = std.mem.zeroes([SIZE]u32);
    var index: usize = 0;
    pow[index] = 1;
    for (1..(STEP + 1)) |i| {
        const last = pow[index];
        index = (index + 1) % SIZE;
        pow[index] = last * P % MOD;
        if (i % 10000 == 0) {
            console.stdout.print("{d}^{d}={d}(MOD {d})\n", .{ P, i, pow[index], MOD });
        }
    }
    console.stdout.print("Test power OK!\n", .{});
    return 0;
}
