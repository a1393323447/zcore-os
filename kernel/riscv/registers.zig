//! RISC-V registers

/// hart (core) id registers
pub const mhartid = struct {
    pub inline fn read() usize {
        return asm (
            \\ csrr %[ret], mhartid
            : [ret] "=r" (-> usize),
        );
    }
};

/// Machine Status Register, mstatus
pub const mstatus = struct {
    // Machine Status Register bit
    const MPP_MASK: usize = 3 << 11;
    const MIE: usize = 1 << 3;

    pub const MPP = enum(usize) {
        Machine = 3,
        Supervisor = 1,
        User = 0,
    };

    inline fn _read() usize {
        return asm (
            \\ csrr %[ret], mstatus 
            : [ret] "=r" (-> usize),
        );
    }

    inline fn _write(bits: usize) void {
        asm volatile (
            \\ csrw mstatus, %[bits]
            :
            : [bits] "r" (bits),
        );
    }

    inline fn set_mpp(mpp: MPP) void {
        var value = _read();
        value &= !MPP_MASK;
        value |= mpp << 11;
        _write(value);
    }

    inline fn set_mie() void {
        asm volatile (
            \\ csrs mstatus, %[MIE]
            :
            : [MIE] "i" (MIE),
        );
    }
};

/// machine exception program counter, holds the
/// instruction address to which a return from
/// exception will go.
pub const mepc = struct {
    pub fn write(x: usize) void {
        asm volatile (
            \\ csrw mepc, %[x]
            :
            : [x] "r" (x),
        );
    }
};

/// Supervisor Status Register, sstatus
pub const sstatus = struct {
    // Supervisor Status Register bit
    const SPP_MASK: usize = 1 << 8; // Previous mode, 1=Supervisor, 0=user
    const SPIE: usize = 1 << 5; // Supervisor Previous Interrupt Enable
    const SIE: usize = 1 << 1; // Supervisor Interrupt Enable

    pub const Sstatus = packed struct {
        bits: usize,

        const Self = @This();
        pub inline fn sie(self: Self) bool {
            return self.bits & SIE != 0;
        }

        pub inline fn spp(self: Self) SPP {
            return switch (self.bits & SPP_MASK) {
                0 => SPP.User,
                _ => SPP.Supervisor,
            };
        }

        pub inline fn restore(self: Self) void {
            _write(self.bits);
        }
    };

    pub const SPP = enum(usize) {
        Supervisor = 1,
        User = 0,
    };

    pub inline fn set_sie() void {
        _set(SIE);
    }

    pub inline fn clear_sie() void {
        _clear(SIE);
    }

    pub inline fn set_spie() void {
        _set(SPIE);
    }

    pub inline fn set_spp(spp: SPP) void {
        switch (spp) {
            SPP.Supervisor => _set(SPP_MASK),
            SPP.User => _clear(SPP_MASK),
        }
    }

    pub inline fn read() Sstatus {
        var bits: usize = asm (
            \\ csrr %[ret], sstatus
            : [ret] "=r" (-> usize),
        );

        return Sstatus{ .bits = bits };
    }

    inline fn _write(bits: usize) void {
        asm volatile (
            \\ csrw sstatus, %[bits]
            :
            : [bits] "r" (bits),
        );
    }

    inline fn _set(bits: usize) void {
        asm volatile (
            \\ csrs sstatus, %[bits]
            :
            : [bits] "r" (bits),
        );
    }

    inline fn _clear(bits: usize) void {
        asm volatile (
            \\ csrc sstatus, %[bits]
            :
            : [bits] "r" (bits),
        );
    }
};

const TMode = enum(usize) {
    Diret = 0,
    Vectored = 1,
};

/// Supervisor Trap-Vector Base Address
/// low two bits are mode.
pub const stvec = struct {
    pub const TrapMode = TMode;

    pub inline fn write(addr: usize, mode: TrapMode) void {
        asm volatile (
            \\ csrw stvec, %[mode_bit]
            :
            : [mode_bit] "r" (addr + @enumToInt(mode)),
        );
    }
};

/// Machine-mode interrupt vector
pub const mtvec = struct {
    pub const TrapMode = TMode;

    pub inline fn write(addr: usize, mode: TrapMode) void {
        asm volatile (
            \\ csrw mtvec, %[mode_bit]
            :
            : [mode_bit] "r" (addr + @enumToInt(mode)),
        );
    }
};

/// mscratch register
pub const mscratch = struct {
    pub inline fn write(bits: usize) void {
        asm volatile (
            \\ csrw mscratch, %[bits]
            :
            : [bits] "r" (bits),
        );
    }
};

/// Supervisor Trap Cause
pub const scause = struct {
    pub inline fn read() Scause {
        var bits = asm (
            \\ csrr %[ret], scause
            : [ret] "=r" (-> usize),
        );

        return Scause{ .bits = bits };
    }

    pub const Scause = struct {
        bits: usize,

        const Self = @This();

        const bit: usize = 1 << (@sizeOf(usize) * 8 - 1);

        pub inline fn code(self: Self) usize {
            return self.bits & ~bit;
        }

        pub inline fn cause(self: Self) Trap {
            if (self.is_interrupt()) {
                return Trap{ .interrupt = Interrupt.from(self.code()) };
            } else {
                return Trap{ .exception = Exception.from(self.code()) };
            }
        }

        pub inline fn is_interrupt(self: Self) bool {
            return self.bits & bit != 0;
        }

        pub inline fn is_exception(self: Self) bool {
            return !self.is_interrupt();
        }
    };

    pub const Trap = union(enum) {
        interrupt: Interrupt,
        exception: Exception,
    };

    pub const Interrupt = enum {
        UserSoft,
        SupervisorSoft,
        UserTimer,
        SupervisorTimer,
        UserExternal,
        SupervisorExternal,
        Unknown,

        const Self = @This();

        pub inline fn from(nr: usize) Self {
            return switch (nr) {
                0 => Interrupt.UserSoft,
                1 => Interrupt.SupervisorSoft,
                4 => Interrupt.UserTimer,
                5 => Interrupt.SupervisorTimer,
                8 => Interrupt.UserExternal,
                9 => Interrupt.SupervisorExternal,
                else => Interrupt.Unknown,
            };
        }
    };

    pub const Exception = enum {
        InstructionMisaligned,
        InstructionFault,
        IllegalInstruction,
        Breakpoint,
        LoadFault,
        StoreMisaligned,
        StoreFault,
        UserEnvCall,
        InstructionPageFault,
        LoadPageFault,
        StorePageFault,
        Unknown,

        const Self = @This();

        pub inline fn from(nr: usize) Self {
            return switch (nr) {
                0 => Exception.InstructionMisaligned,
                1 => Exception.InstructionFault,
                2 => Exception.IllegalInstruction,
                3 => Exception.Breakpoint,
                5 => Exception.LoadFault,
                6 => Exception.StoreMisaligned,
                7 => Exception.StoreFault,
                8 => Exception.UserEnvCall,
                12 => Exception.InstructionPageFault,
                13 => Exception.LoadPageFault,
                15 => Exception.StorePageFault,
                else => Exception.Unknown,
            };
        }
    };
};

pub const stval = struct {
    pub inline fn read() usize {
        return asm (
            \\ csrr %[ret], stval
            : [ret] "=r" (-> usize),
        );
    }
};
