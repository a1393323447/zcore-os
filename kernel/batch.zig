const console = @import("console.zig");
const trap = @import("trap/trap.zig");
const panic = @import("panic.zig");

const std = @import("std");

const K: usize = 4096;
const USER_STACK_SIZE: usize = 2 * K;
const KERNEL_STACK_SIZE: usize = 2 * K;

pub var KERNEL_STACK = KernelStack{ .data = std.mem.zeroes([KERNEL_STACK_SIZE]u8) };
pub var USER_STACK = UserStack{ .data = std.mem.zeroes([USER_STACK_SIZE]u8) };

const MAX_APP_NUM: usize = 16;
const APP_BASE_ADDRESS: usize = 0x80400000;
const APP_SIZE_LIMIT: usize = 0x20000;

pub var APP_MANAGER: AppManager = undefined;

pub fn init() void {
    APP_MANAGER = AppManager.load_symbols();
    APP_MANAGER.print_app_info();
}

pub fn print_app_info() void {
    APP_MANAGER.print_app_info();
}

extern fn __restore(ctx_addr: usize) callconv(.C) noreturn;

pub fn run_next_app() noreturn {
    const current_app_id = APP_MANAGER.current_app;
    APP_MANAGER.load_app(current_app_id);
    APP_MANAGER.move_to_next_app();

    const ctx = trap.TrapContext.app_init_context(APP_BASE_ADDRESS, USER_STACK.get_sp());
    const ctx_ptr = KERNEL_STACK.push_context(ctx);

    __restore(@ptrToInt(ctx_ptr));

    unreachable;
}

const KernelStack align(1 * K) = struct {
    data: [KERNEL_STACK_SIZE]u8 align(1 * K),

    const Self = @This();

    pub fn get_sp(self: *const Self) usize {
        const ptr = &self.data[0];
        const sp = @ptrToInt(ptr) + KERNEL_STACK_SIZE;
        return sp;
    }

    pub fn push_context(self: *const Self, ctx: trap.TrapContext) *trap.TrapContext {
        const ctx_addr = self.get_sp() - @sizeOf(trap.TrapContext);
        const ctx_ptr = @intToPtr(*trap.TrapContext, ctx_addr);
        ctx_ptr.* = ctx;
        return ctx_ptr;
    }
};

const UserStack align(1 * K) = struct {
    data: [USER_STACK_SIZE]u8 align(1 * K),

    const Self = @This();

    pub fn get_sp(self: *const Self) usize {
        const ptr = &self.data[0];
        const sp = @ptrToInt(ptr) + USER_STACK_SIZE;
        return sp;
    }
};

const AppManager = struct {
    num_app: usize,
    current_app: usize,
    app_start: [MAX_APP_NUM + 1]usize,

    const Self = @This();

    pub fn load_symbols() AppManager {
        const ExternOptions = std.builtin.ExternOptions;
        const num_app_ptr = comptime @extern([*]usize, ExternOptions{
            .name = "_num_app",
        });
        const num_app = num_app_ptr[0];
        var app_start = std.mem.zeroes([MAX_APP_NUM + 1]usize);
        const app_start_raw = num_app_ptr[1..(num_app + 2)];
        std.mem.copy(usize, &app_start, app_start_raw);

        return AppManager{
            .num_app = num_app,
            .current_app = 0,
            .app_start = app_start,
        };
    }

    pub fn load_app(self: *const Self, app_id: usize) void {
        if (app_id >= self.num_app) {
            panic.panic("All applications completed !", .{});
        }
        console.logger.info("[kernel] Loading app_{}", .{app_id});
        // clear app area
        const app_area = @intToPtr(*[APP_SIZE_LIMIT]u8, APP_BASE_ADDRESS);
        std.mem.set(u8, app_area, 0);

        const app_start_addr = self.app_start[app_id];
        const app_end_addr = self.app_start[app_id + 1];
        const app_size = app_end_addr - app_start_addr;

        if (app_size > APP_SIZE_LIMIT) {
            panic.panic("app_{d} size up to limit!", .{app_id});
        }

        const app_src_ptr = @intToPtr([*]const u8, app_start_addr);
        std.mem.copy(u8, app_area[0..app_size], app_src_ptr[0..app_size]);

        // Memory fence about fetching the instruction memory
        // It is guaranteed that a subsequent instruction fetch must
        // observes all previous writes to the instruction memory.
        // Therefore, fence.i must be executed after we have loaded
        // the code of the next app into the instruction memory.
        // See also: riscv non-priv spec chapter 3, 'Zifencei' extension.
        asm volatile ("fence.i");
    }

    pub fn move_to_next_app(self: *Self) void {
        self.current_app += 1;
    }

    pub fn print_app_info(self: *const Self) void {
        console.logger.info("[kernel] num_app = {}", .{self.num_app});
        for (0..self.num_app) |idx| {
            console.logger.info("[kernel] app_{} [{x}, {x}]", .{
                idx,
                self.app_start[idx],
                self.app_start[idx + 1],
            });
        }
    }
};
