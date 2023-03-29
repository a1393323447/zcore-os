    .section .text.entry
    .globl _entry
_entry:
    la sp, boot_stack_top
    call _kmain

    .section .bss.stack
    .globl boot_stack_lower_bound
boot_stack_lower_bound:
    .space 4096 * 16
    .globl boot_stack_top
boot_stack_top: