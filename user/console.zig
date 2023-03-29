const shared = @import("shared");
const syscall = @import("syscall.zig");

pub var stdout = Stdout.init(Context{});

// TODO Mutex
const STDOUT: usize = 1;
const Context = struct {};
const WriteError = error{};
fn write(context: Context, bytes: []const u8) WriteError!usize {
    _ = context;
    // TODO handle Error
    const len = syscall.sys_write(STDOUT, bytes);
    return @intCast(usize, len);
}
const Stdout = shared.console.Stdout(Context, WriteError, write);
