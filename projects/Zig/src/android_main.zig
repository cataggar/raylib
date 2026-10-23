const program = @import("program");

export fn main(argc: c_int, argv: [*c][*c]u8) callconv(.c) c_int {
    _ = argc;
    _ = argv;
    program.main();
    return 0;
}
