# enable -flto
$enable_lto = 1;

sub add_target {
    $target = $_[0];
    # drop trailing '*'
    foreach my $source (@sources)
    {
        $source =~ s{\*$}{};
    }
    print(FH "add_library(", $target, " SHARED ", (join " ", @sources) , ")\n");

    # add more flags
    $bench_flags = $bench_flags . " -march=armv8-a+sve -O3";
    $bench_flags = $bench_flags . " -DSPEC -DSPEC_LP64 -DSPEC_LINUX -DSPEC_LINUX_AARCH64 -DSPEC_NO_USE_STDIO_PTR -DSPEC_NO_USE_STDIO_BASE -DSPEC_NO_ISFINITE";
    if ($target != "502.gcc_r" and $target != "503.bwaves_r" and $target != "507.cactuBSSN_r" and $target != "510.parest_r" and $target != "521.wrf_r" and $target != "526.blender_r" and $target != "527.cam4_r" and $enable_lto) {
        # -flto miscompiles for 502.gcc_r
        # -flto optimizes main function away for 503.bwaves_r
        # -flto incompatible llvm version for 507.cactuBSSN_r
        # -flto ICE for 510.parest_r
        # -flto too slow for 521.wrf_r
        # -flto too slow for 526.blender_r
        # -flto too slow for 527.cam4_r
        $bench_flags = $bench_flags . " -flto";
    }
    if ($target != "503.bwaves_r" and $target != "507.cactuBSSN_r" and $target != "521.wrf_r" and $target != "527.cam4_r" and $target != "548.exchange2_r" and $target != "549.fotonik3d_r" and $target != "554.nab_r") {
        # flang does not support -Wno-error and -fcommon
        $bench_flags = $bench_flags . " -Wno-error=format-security -Wno-error=reserved-user-defined-literal -fcommon";
    }
    if ($target == "521.wrf_r") {
        $bench_cflags = $bench_cflags . " -DSPEC_CASE_FLAG";
        # fix crash due to little endian
        $bench_fflags = $bench_fflags . " -fconvert=big-endian";
    }
    if ($target == "527.cam4_r") {
        $bench_cflags = $bench_cflags . " -DSPEC_CASE_FLAG";
    }
    if ($target == "554.roms_r") {
        # fix compilation
        $bench_flags = $bench_flags . " -DNDEBUG";
    }

    # convert -I flags to target_include_directories
    for $flag (split(" ", ($bench_flags . " " . $bench_cflags . " " . $bench_cxxflags . " " . $bench_fflags . " " . $bench_fppflags))) {
        if ((rindex $flag, "-I", 0) == 0) {
            print(FH "target_include_directories(", $target, " PRIVATE ", substr($flag, 2, length($flag)), ")\n");
        }
    }

    # drop unwanted preprocessor flags
    $bench_fppflags =~ s{-w -m literal-single.pm -m c-comment.pm}{};
    $bench_fppflags =~ s{-w -m literal.pm}{};

    # handle symbol interposition
    $bench_cflags = $bench_cflags . " -fvisibility=protected";
    $bench_cxxflags = $bench_cxxflags . " -fvisibility=protected";

    # set flags for each language
    $bench_cflags = $bench_cflags . " " . $bench_flags;
    $bench_cxxflags = $bench_cxxflags . " " . $bench_flags;
    $bench_fflags = $bench_fflags . " " . $bench_fppflags . " " . $bench_flags;

    print(FH "target_compile_options(", $target, " PRIVATE\n\t\$<\$<COMPILE_LANGUAGE:C>:", $bench_cflags, ">\n\t\$<\$<COMPILE_LANGUAGE:CXX>:", $bench_cxxflags, ">\n\t\$<\$<COMPILE_LANGUAGE:Fortran>:", $bench_fflags, ">)\n");
}

for $benchmark ("500.perlbench_r", "502.gcc_r", "505.mcf_r", "520.omnetpp_r", "523.xalancbmk_r", "525.x264_r", "531.deepsjeng_r", "541.leela_r", "548.exchange2_r", "557.xz_r", "503.bwaves_r", "507.cactuBSSN_r", "508.namd_r", "510.parest_r", "511.povray_r", "519.lbm_r", "521.wrf_r", "526.blender_r", "527.cam4_r", "538.imagick_r", "544.nab_r", "549.fotonik3d_r", "554.roms_r") {
    $bench_flags = $bench_cflags = $bench_cxxflags = $bench_fflags = $bench_fppflags = "";
    require "./benchspec/CPU/" . $benchmark . "/Spec/object.pm";
    mkdir("entry/src/main/cpp/" . $benchmark);
    system("cp -arv ./benchspec/CPU/" . $benchmark . "/src/* entry/src/main/cpp/" . $benchmark . "/");
    open(FH, '>', "entry/src/main/cpp/" . $benchmark . "/CMakeLists.txt") or die $!;
    if ($benchmark == "511.povray_r") {
        @sources = @{%sources{"povray_r"}};
        add_target("511.povray_r");
    } elsif ($benchmark == "521.wrf_r") {
        @sources = @{%sources{"wrf_r"}};
        add_target("521.wrf_r");
    } elsif ($benchmark == "525.x264_r") {
        @sources = @{%sources{"x264_r"}};
        add_target("525.x264_r");
        
        @sources = @{%sources{"ldecod_r"}};
        add_target("ldecod_r");

        @sources = @{%sources{"imagevalidate_525"}};
        add_target("imagevalidate_525");
    } elsif ($benchmark == "526.blender_r") {
        @sources = @{%sources{"blender_r"}};
        add_target("526.blender_r");
    } elsif ($benchmark == "527.cam4_r") {
        @sources = @{%sources{"cam4_r"}};
        add_target("527.cam4_r");
    } elsif ($benchmark == "538.imagick_r") {
        @sources = @{%sources{"imagick_r"}};
        add_target("538.imagick_r");
    } else {
        add_target($benchmark);
    }

    if ($benchmark == "549.fotonik3d_r") {
        # extract OBJ.dat.xz for input
        system("xz -d -k ./benchspec/CPU/549.fotonik3d_r/data/refrate/input/OBJ.dat.xz");
    }

    # zip inputs
    system("rm -rf tmp");
    system("mkdir -p tmp/input tmp/output");
    system("cp -rv ./benchspec/CPU/" . $benchmark . "/data/all/input/* ./benchspec/CPU/" . $benchmark . "/data/refrate/input/* tmp/input/");
    system("cp -rv ./benchspec/CPU/" . $benchmark . "/data/refrate/output/* tmp/output/");
    system("rm -f entry/src/main/resources/rawfile/" . $benchmark . ".zip");
    system("cd tmp && zip -r ../entry/src/main/resources/rawfile/" . $benchmark . ".zip *");
    system("rm -rf tmp");
}

# patch code
# fix compilation
system("sed -i '1s;^;#include <fcntl.h>\\n;' entry/src/main/cpp/500.perlbench_r/perlio.c");
system("sed -i 's/__linux__/__nonexistent__/' entry/src/main/cpp/510.parest_r/source/base/utilities.cc");
system("sed -i 's/#if defined __FreeBSD__/#include <stdio.h>\\n#if 1/' entry/src/main/cpp/520.omnetpp_r/simulator/platdep/platmisc.h");
system("sed -i 's/#if defined.* && !defined.*/#if 0/' entry/src/main/cpp/521.wrf_r/netcdf/include/ncfortran.h");
system("sed -i '1s/^/# define rindex(X,Y) strrchr(X,Y)\\n/' entry/src/main/cpp/521.wrf_r/misc.c");
system("sed -i '1s/^/# define rindex(X,Y) strrchr(X,Y)\\n/' entry/src/main/cpp/521.wrf_r/type.c");
system("sed -i '1s/^/# define rindex(X,Y) strrchr(X,Y)\\n/' entry/src/main/cpp/521.wrf_r/reg_parse.c");
system("sed -i 's/^#ifdef\$/#ifdef SPEC/' entry/src/main/cpp/527.cam4_r/ESMF_AlarmMod.F90");
system("sed -i 's/#if defined.* && !defined.*/#if 0/' entry/src/main/cpp/527.cam4_r/netcdf/include/ncfortran.h");
