const batch = @import("../batch.zig");
const console = @import("../console.zig");

/// task exits and submit an exit code
pub fn sys_exit(exit_code: i32) noreturn {
    console.logger.info("[kernel] Application exited with code {d}", .{exit_code});
    batch.run_next_app();
}
