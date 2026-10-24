const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Windows 交叉编译时用它指明 SDL3 开发包的位置；Linux 本地构建走 pkg-config。
    const sdl_include = b.option([]const u8, "sdl-include", "Path containing the SDL3/ and SDL3_ttf/ headers");
    const sdl_lib = b.option([]const u8, "sdl-lib", "Path containing the SDL3 import/static libraries");
    const sdl_bin = b.option([]const u8, "sdl-bin", "Path containing SDL3.dll and SDL3_ttf.dll (installed next to the exe)");

    const exe = b.addExecutable(.{
        .name = "complexweeper",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    if (sdl_include) |p| exe.addIncludePath(.{ .cwd_relative = p });
    if (sdl_lib) |p| exe.addLibraryPath(.{ .cwd_relative = p });
    exe.linkSystemLibrary("SDL3");
    exe.linkSystemLibrary("SDL3_ttf");
    b.installArtifact(exe);

    if (sdl_bin) |p| {
        for ([_][]const u8{ "SDL3.dll", "SDL3_ttf.dll" }) |dll| {
            const install = b.addInstallBinFile(.{ .cwd_relative = b.pathJoin(&.{ p, dll }) }, dll);
            b.getInstallStep().dependOn(&install.step);
        }
    }

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run Complexweeper");
    run_step.dependOn(&run_cmd.step);
}
