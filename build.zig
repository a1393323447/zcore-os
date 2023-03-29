const std = @import("std");
const Mode = std.builtin.Mode;
const CodeModel = std.builtin.CodeModel;

const Step = std.build.Step;
const Module = std.build.Module;
const FileSource = std.build.FileSource;
const TestOptions = std.build.TestOptions;
const CompileStep = std.build.CompileStep;
const CreateModuleOptions = std.build.CreateModuleOptions;

const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;
const Cpu = Target.Cpu;
const CpuModel = Target.Cpu.Model;
const Os = Target.Os;
const Abi = Target.Abi;
const ObjectFormat = Target.ObjectFormat;

const user_linker_script_path = "user/linker.ld";
const kernel_linker_script_path = "kernel/linker.ld";

const riscv64 = CrossTarget.fromTarget(Target{
    .cpu = Cpu.baseline(Cpu.Arch.riscv64),
    .os = Os{ .tag = Os.Tag.freestanding, .version_range = Os.VersionRange{ .none = {} } },
    .abi = Abi.eabi,
    .ofmt = ObjectFormat.elf,
});

// for debug option
var is_debug: bool = false;

pub inline fn optimize(debug: bool) Mode {
    return if (debug) Mode.Debug else Mode.ReleaseSafe;
}

pub fn build(b: *std.build.Builder) void {
    init_options(b);
    // create shared module
    // it would be added in complie step
    const shared = create_shared_module(b);
    // zig build check: for checking syntax
    set_checking(b, shared);
    // zig build img: for building zcore-os.bin
    set_build_img(b, shared);
}

fn init_options(b: *std.build.Builder) void {
    is_debug = b.option(bool, "debug", "Enable debug mode") orelse false;
}

fn create_shared_module(b: *std.build.Builder) *Module {
    const shared = b.addModule("shared", CreateModuleOptions{
        .source_file = FileSource.relative("shared/lib.zig"),
    });

    return shared;
}

fn set_build_img(b: *std.build.Builder, shared: *Module) void {
    const build_user_apps_step = build_user_apps(b, shared);

    const build_kernel_step = build_kernel(b, shared);
    build_kernel_step.dependOn(build_user_apps_step);

    const build_img = b.step("img", "Build zcore-os.bin");
    build_img.dependOn(build_kernel_step);
}

fn set_checking(b: *std.build.Builder, shared: *Module) void {
    // for checking syntax
    const do_check = b.step("check", "Check File");

    const check_kernel = b.addTest(TestOptions{
        .root_source_file = FileSource.relative("kernel/check.zig"),
    });
    check_kernel.addModule("shared", shared);
    const asm_files = [_][]const u8{
        "kernel/entry.S",
        "kernel/trap/trap.S",
        "kernel/link_app.S",
        // TODO link_app.S
    };
    config_compile_step(check_kernel, kernel_linker_script_path, &asm_files);

    do_check.dependOn(&check_kernel.step);
}

fn build_kernel(b: *std.build.Builder, shared: *Module) *Step {
    const kernel = b.addExecutable(std.build.ExecutableOptions{
        .name = "zcore-os",
        .root_source_file = std.build.FileSource.relative("kernel/main.zig"),
    });
    kernel.addModule("shared", shared);

    const asm_files = [_][]const u8{
        "kernel/entry.S",
        "kernel/trap/trap.S",
        "kernel/link_app.S",
        // TODO link_app.S
    };
    config_compile_step(kernel, kernel_linker_script_path, &asm_files);

    // for zig build cmd
    kernel.install();

    // emit bin file
    const emit_bin_file_step = emit_bin(b, kernel, "zcore-os.bin");

    return emit_bin_file_step;
}

fn build_user_apps(b: *std.build.Builder, shared: *Module) *Step {
    const build_apps_step = b.step("user", "Build all user apps in dir 'user/bin/' .");
    const app_names = comptime [_][]const u8{
        "hello_world",
        "store_fault",
        "power",
    };
    inline for (app_names) |app_name| {
        const build_app_step = build_user_app(b, shared, app_name);
        build_apps_step.dependOn(build_app_step);
    }

    return build_apps_step;
}

fn build_user_app(b: *std.build.Builder, shared: *Module, comptime app_name: []const u8) *Step {
    const asm_files = [_][]const u8{};

    const lib = b.addObject(.{
        .name = "lib",
        .root_source_file = std.build.FileSource.relative("user/lib.zig"),
        .target = riscv64,
        .optimize = optimize(is_debug),
    });

    config_compile_step(lib, null, &asm_files);

    lib.setMainPkgPath("user");
    lib.addModule("shared", shared);

    const user_app = b.addExecutable(std.build.ExecutableOptions{
        .name = app_name,
        .root_source_file = std.build.FileSource.relative("user/bin/" ++ app_name ++ ".zig"),
    });

    user_app.setMainPkgPath("user");
    user_app.addModule("shared", shared);
    user_app.addObject(lib);

    config_compile_step(user_app, user_linker_script_path, &asm_files);

    user_app.install();

    // emit bin file
    const emit_bin_file_step = emit_bin(b, user_app, app_name ++ ".bin");

    return emit_bin_file_step;
}

fn config_compile_step(step: *CompileStep, comptime linker_script_path: ?[]const u8, comptime asm_file_paths: []const []const u8) void {
    // set target
    step.target = riscv64;
    // set opt level
    step.optimize = optimize(is_debug);
    // strip debug info if not in debug mode
    step.strip = !is_debug;

    // disable stack protector
    // stack protector unavailable without libC
    step.stack_protector = false;

    // https://github.com/ziglang/zig/issues/5558
    step.code_model = CodeModel.medium;

    for (asm_file_paths) |path| {
        step.addAssemblyFile(path);
    }

    if (linker_script_path) |path| {
        const linker_script_source = FileSource.relative(path);
        step.setLinkerScriptPath(linker_script_source);
    }
}

fn emit_bin(b: *std.build.Builder, source_exe: *CompileStep, comptime install_name: []const u8) *Step {
    const objcopy = source_exe.addObjCopy(std.build.ObjCopyStep.Options{
        .format = std.build.ObjCopyStep.RawFormat.bin,
    });
    const copy_to_bin = b.addInstallBinFile(objcopy.getOutputSource(), install_name);
    return &copy_to_bin.step;
}
