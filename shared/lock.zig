const atomic = @import("std").atomic;

pub const SpinLock = struct {
    locked: atomic.Atomic(usize),

    const Self = @This();

    pub fn init() Self {
        return Self{
            .locked = atomic.Atomic(usize).init(0),
        };
    }

    pub fn acquire(self: *Self) void {
        while (true) {
            const res = self.locked.compareAndSwap(
            0, 1, atomic.Ordering.SeqCst, atomic.Ordering.SeqCst);
            if (res) |_| {
                break;
            }
        }
    }

    pub fn release(self: *Self) void {
        self.locked.storeUnchecked(0);
    }

    pub fn holding(self: *Self) bool {
        return self.locked.loadUnchecked() == 1;
    }
};
