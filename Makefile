GDB = gdb-multiarch
REMOTE = localhost:1234

BIOS_PATH = boot/rustsbi-qemu.bin

BIN_PATH = zig-out/bin
EXE = zcore-os
IMG = $(EXE).bin

# kernel loaded adderss
START_ADDR = 0x80200000

QEMU_RUN_ARGS = -machine virt -bios $(BIOS_PATH) -nographic
QEMU_RUN_ARGS += -device loader,file=$(BIN_PATH)/$(IMG),addr=$(START_ADDR)
QEMU_DEBUG_ARGS = -s -S

# check .zig file syntax
check:
	zig build check

# build zcore-os.bin in release mode
build:
	zig build user
	zig build img

# build zcore-os.bin in debug mode
build-debug:
	zig build user -Ddebug
	zig build img -Ddebug
	zig build -Ddebug

# run zcore os in qemu
run: build
	qemu-system-riscv64 $(QEMU_RUN_ARGS)

run-debug: build-debug
	qemu-system-riscv64 $(QEMU_RUN_ARGS) $(QEMU_DEBUG_ARGS)

# using gdb to remote debug zcore os
# set a breakpoint at 0x80200000 by default
debug: build-debug
	qemu-system-riscv64 $(QEMU_RUN_ARGS) $(QEMU_DEBUG_ARGS) &
	$(GDB) \
	-ex 'file $(BIN_PATH)/$(EXE)' \
	-ex 'set arch riscv:rv64' \
	-ex 'target remote $(REMOTE)' \
	-ex 'b *$(START_ADDR)'

# clean cache and output files
clean:
	rm -rf zig-out
	rm -rf zig-cache