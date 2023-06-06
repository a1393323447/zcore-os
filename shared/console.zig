const std = @import("std");
const lock = @import("lock.zig");

pub const Color = enum {
    Red,
    Yellow,
    Blue,
    Green,
    Gray,

    const Self = @This();

    pub fn dye(self: Self, comptime str: []const u8) []const u8 {
        return switch (self) {
            Self.Red => "\x1b[31m" ++ str ++ "\x1b[0m",
            Self.Yellow => "\x1b[93m" ++ str ++ "\x1b[0m",
            Self.Blue => "\x1b[34m" ++ str ++ "\x1b[0m",
            Self.Green => "\x1b[32m" ++ str ++ "\x1b[0m",
            Self.Gray => "\x1b[90m" ++ str ++ "\x1b[0m",
        };
    }
};

pub const Level = enum {
    Error,
    Warn,
    Info,
    Debug,
    Trace,

    const Self = @This();

    pub fn fmt(self: Self, comptime str: []const u8) []const u8 {
        return switch (self) {
            Self.Error => Color.Red.dye("[ERROR] " ++ str),
            Self.Warn => Color.Yellow.dye("[WARN]] " ++ str),
            Self.Info => Color.Blue.dye("[INFO] " ++ str),
            Self.Debug => Color.Green.dye("[DEBUG] " ++ str),
            Self.Trace => Color.Gray.dye("[TRACE] " ++ str),
        };
    }
};

var std_spin_lock = lock.SpinLock.init();

pub fn Stdout(
    comptime Context: type,
    comptime WriteError: type,
    comptime writeFn: fn (context: Context, bytes: []const u8) WriteError!usize,
) type {
    const StdoutWriter = std.io.Writer(Context, WriteError, writeFn);

    const stdout = struct {
        writer: StdoutWriter,

        const Self = @This();

        pub fn init(ctx: Context) Self {
            return Self{ .writer = StdoutWriter{ .context = ctx } };
        }

        pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) void {
            std_spin_lock.acquire();
            defer std_spin_lock.release();
            nosuspend self.writer.print(fmt, args) catch return;
        }

        pub fn printWithColor(self: *Self, comptime fmt: []const u8, args: anytype, color: Color) void {
            const colored_fmt = color.dye(fmt);
            self.print(colored_fmt, args);
        }

        pub fn printWithLevel(self: *Self, comptime fmt: []const u8, args: anytype, comptime level: Level) void {
            self.print(level.fmt(fmt ++ "\n"), args);
        }

        pub fn err(self: *Self, comptime fmt: []const u8, args: anytype) void {
            self.printWithLevel(fmt, args, Level.Error);
        }

        pub fn warn(self: *Self, comptime fmt: []const u8, args: anytype) void {
            self.printWithLevel(fmt, args, Level.Warn);
        }

        pub fn info(self: *Self, comptime fmt: []const u8, args: anytype) void {
            self.printWithLevel(fmt, args, Level.Info);
        }

        pub fn debug(self: *Self, comptime fmt: []const u8, args: anytype) void {
            self.printWithLevel(fmt, args, Level.Debug);
        }

        pub fn trace(self: *Self, comptime fmt: []const u8, args: anytype) void {
            self.printWithLevel(fmt, args, Level.Trace);
        }
    };
    return stdout;
}
