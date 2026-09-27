// Entry point for the OpenRiichiTests executable (see meson.build).
// Run with: meson test -C build
public static int main(string[] args)
{
    // Report every failing test instead of bailing out on the first one.
    string[] test_args = args;
    test_args += "--keep-going";
    unowned string[] init_args = test_args;
    Test.init(ref init_args);

    register_scoring_tests();
    register_point_calc_tests();

    return Test.run();
}
