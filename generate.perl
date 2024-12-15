# enable -flto
$enable_lto = 1;

sub add_target {
    $target = $_[0];
    print(FH "add_library(", $target, " SHARED ", (join " ", @sources) , ")\n");

    # add more flags
    $bench_flags = $bench_flags . " " . $bench_cxxflags;
    $bench_flags = $bench_flags . " -march=armv8-a+sve -DSPEC -DSPEC_LP64 -DSPEC_LINUX -DSPEC_LINUX_AARCH64 -DSPEC_NO_USE_STDIO_PTR -DSPEC_NO_USE_STDIO_BASE -O3";
    if ($target != "502.gcc_r" and $enable_lto) {
        # -flto miscompiles for 502.gcc_r
        $bench_flags = $bench_flags . " -flto";
    }
    if ($target != "548.exchange2_r") {
        # flang does not support -Wno-error and -fcommon
        $bench_flags = $bench_flags . " -Wno-error=format-security -Wno-error=reserved-user-defined-literal -fcommon";
    }

    # convert -I flags to target_include_directories
    for $flag (split(" ", $bench_flags)) {
        if ((rindex $flag, "-I", 0) == 0) {
            print(FH "target_include_directories(", $target, " PRIVATE ", substr($flag, 2, length($flag)), ")\n");
        }
    }

    print(FH "target_compile_options(", $target, " PRIVATE ", $bench_flags, ")\n");
}

for $benchmark ("500.perlbench_r", "502.gcc_r", "505.mcf_r", "520.omnetpp_r", "523.xalancbmk_r", "525.x264_r", "531.deepsjeng_r", "541.leela_r", "548.exchange2_r", "557.xz_r") {
    require "./benchspec/CPU/" . $benchmark . "/Spec/object.pm";
    mkdir("entry/src/main/cpp/" . $benchmark);
    system("cp -arv ./benchspec/CPU/" . $benchmark . "/src/* entry/src/main/cpp/" . $benchmark . "/");
    open(FH, '>', "entry/src/main/cpp/" . $benchmark . "/CMakeLists.txt") or die $!;
    if ($benchmark == "525.x264_r") {
        @sources = @{%sources{"x264_r"}};
        add_target("525.x264_r");
        
        @sources = @{%sources{"ldecod_r"}};
        add_target("ldecod_r");
    } else {
        add_target($benchmark);
    }

    # zip inputs
    system("rm -rf tmp");
    system("mkdir -p tmp");
    system("cp -rv ./benchspec/CPU/" . $benchmark . "/data/all/input/* ./benchspec/CPU/" . $benchmark . "/data/refrate/input/* tmp/");
    system("rm -f entry/src/main/resources/rawfile/" . $benchmark . ".zip");
    system("cd tmp && zip -r ../entry/src/main/resources/rawfile/" . $benchmark . ".zip *");
    system("rm -rf tmp");
}

# patch code
# fix compilation
system("sed -i '1s;^;#include <fcntl.h>\\n;' entry/src/main/cpp/500.perlbench_r/perlio.c");
system("sed -i 's/#if defined __FreeBSD__/#include <stdio.h>\\n#if 1/' entry/src/main/cpp/520.omnetpp_r/simulator/platdep/platmisc.h");
