for my $benchmark ("500.perlbench_r", "502.gcc_r") {
    require "./benchspec/CPU/" . $benchmark . "/Spec/object.pm";
    mkdir("entry/src/main/cpp/" . $benchmark);
    system("cp -rv ./benchspec/CPU/" . $benchmark . "/src/* entry/src/main/cpp/" . $benchmark . "/");
    open(FH, '>', "entry/src/main/cpp/" . $benchmark . "/CMakeLists.txt") or die $!;
    print(FH "add_library(", $benchmark, " SHARED ", (join " ", @sources) , ")\n");

    # add more flags
    $bench_flags = $bench_flags . " -Wno-error=format-security" . " -DSPEC" . " -DSPEC_LP64" . " -DSPEC_LINUX_AARCH64" . " -DSPEC_NO_USE_STDIO_PTR" . " -DSPEC_NO_USE_STDIO_BASE";

    # convert -I flags to target_include_directories
    for my $flag (split(" ", $bench_flags)) {
        if ((rindex $flag, "-I", 0) == 0) {
            print(FH "target_include_directories(", $benchmark, " PRIVATE ", substr($flag, 2, length($flag)), ")\n");
        }
    }

    print(FH "target_compile_options(", $benchmark, " PRIVATE ", $bench_flags, ")\n");
}

# patch code
system("sed -i '1s;^;#include <fcntl.h>\\n;' entry/src/main/cpp/500.perlbench_r/perlio.c");
system("sed -i 's/exit(\\(.*\\))/return \\1/' entry/src/main/cpp/500.perlbench_r/perlmain.c");
