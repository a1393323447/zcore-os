const SBI_SET_TIMER: usize = 0;
const SBI_CONSOLE_PUTCHAR: usize = 1;
const SBI_CONSOLE_GETCHAR: usize = 2;
const SBI_CLEAR_IPI: usize = 3;
const SBI_SEND_IPI: usize = 4;
const SBI_REMOTE_FENCE_I: usize = 5;
const SBI_REMOTE_SFENCE_VMA: usize = 6;
const SBI_REMOTE_SFENCE_VMA_ASID: usize = 7;
const SBI_SHUTDOWN: usize = 8;

pub fn sbi_call(which: usize, arg0: usize, arg1: usize, arg2: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> usize),
        : [arg0] "{x10}" (arg0),
          [arg1] "{x11}" (arg1),
          [arg2] "{x12}" (arg2),
          [which] "{x17}" (which),
    );
}

pub fn console_putchar(c: usize) void {
    _ = sbi_call(SBI_CONSOLE_PUTCHAR, c, 0, 0);
}
