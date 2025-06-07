# enable -flto
$enable_lto = 1;

sub add_target {
    $target = $_[0];
    # drop trailing '*'
    foreach my $source (@sources)
    {
        $source =~ s{\*$}{};
    }
    @additional_sources = ();
    if ($target eq "diffwrf_521") {
        # add missing sources due to split module folder
        @additional_sources = ("module_cam_shr_const_mod.F90", "module_cam_shr_kind_mod.F90", "module_gfs_machine.F90", "module_gfs_physcons.F90", "ESMF_Fraction.F90");
    }
    print(FH "add_library(", $target, " SHARED ", (join " ", @sources) , " ", (join " ", @additional_sources), ")\n");
    print(FH "set_target_properties(", $target, " PROPERTIES C_COMPILER_LAUNCHER \"\${CMAKE_CURRENT_SOURCE_DIR}/../wrapper\")\n");
    print(FH "set_target_properties(", $target, " PROPERTIES C_LINKER_LAUNCHER \"\${CMAKE_CURRENT_SOURCE_DIR}/../wrapper\")\n");
    print(FH "set_target_properties(", $target, " PROPERTIES CXX_COMPILER_LAUNCHER \"\${CMAKE_CURRENT_SOURCE_DIR}/../wrapper\")\n");
    print(FH "set_target_properties(", $target, " PROPERTIES CXX_LINKER_LAUNCHER \"\${CMAKE_CURRENT_SOURCE_DIR}/../wrapper\")\n");
    print(FH "set_target_properties(", $target, " PROPERTIES Fortran_COMPILER_LAUNCHER \"\${CMAKE_CURRENT_SOURCE_DIR}/../wrapper\")\n");
    print(FH "set_target_properties(", $target, " PROPERTIES Fortran_LINKER_LAUNCHER \"\${CMAKE_CURRENT_SOURCE_DIR}/../wrapper\")\n");

    # general flags
    $bench_flags = $bench_flags . " -O3 -flto";
    $bench_flags = $bench_flags . " -DSPEC -DSPEC_LP64 -DSPEC_LINUX -DSPEC_LINUX_AARCH64 -DSPEC_NO_USE_STDIO_PTR -DSPEC_NO_USE_STDIO_BASE -DSPEC_NO_ISFINITE";
    # for 500.perlbench_r, 502.gcc_r and 525.x264_r
    $bench_cflags = $bench_cflags . " -fno-strict-aliasing -fno-unsafe-math-optimizations -fno-finite-math-only -fgnu89-inline -fcommon";
    # for 521.wrf_r and 527.cam4_r
    $bench_fflags = $bench_fflags . " -fallow-argument-mismatch -Wno-error=implicit-int";
    # for 510.parest_r
    $bench_cxxflags = $bench_cxxflags . " -std=c++03";

    # benchmark specific flags
    if ($target eq "521.wrf_r") {
        $bench_cflags = $bench_cflags . " -DSPEC_CASE_FLAG";
        # fix crash due to little endian
        $bench_fflags = $bench_fflags . " -fconvert=big-endian";
    }
    if ($target eq "527.cam4_r") {
        $bench_cflags = $bench_cflags . " -DSPEC_CASE_FLAG";
    }
    if ($target eq "554.roms_r") {
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

    # set flags for each language
    $bench_cflags = $bench_cflags . " " . $bench_flags;
    $bench_cxxflags = $bench_cxxflags . " " . $bench_flags;
    $bench_fflags = $bench_fflags . " " . $bench_fppflags . " " . $bench_flags;

    print(FH "target_compile_options(", $target, " PRIVATE\n\t\$<\$<COMPILE_LANGUAGE:C>:", $bench_cflags, ">\n\t\$<\$<COMPILE_LANGUAGE:CXX>:", $bench_cxxflags, ">\n\t\$<\$<COMPILE_LANGUAGE:Fortran>:", $bench_fflags, ">)\n");

    # handle same fortran source in multiple targets in 521.wrf_r
    # https://stackoverflow.com/questions/73036890/cmake-multiple-version-of-fortran-mod-files
    print(FH "set_target_properties(", $target, " PROPERTIES Fortran_MODULE_DIRECTORY \${CMAKE_CURRENT_BINARY_DIR}/", $target, ")\n");
    print(FH "target_include_directories(", $target, " PUBLIC \${CMAKE_CURRENT_BINARY_DIR}/", $target, ")\n");
}

for $benchmark ("500.perlbench_r", "502.gcc_r", "505.mcf_r", "520.omnetpp_r", "523.xalancbmk_r", "525.x264_r", "531.deepsjeng_r", "541.leela_r", "548.exchange2_r", "557.xz_r", "503.bwaves_r", "507.cactuBSSN_r", "508.namd_r", "510.parest_r", "511.povray_r", "519.lbm_r", "521.wrf_r", "526.blender_r", "527.cam4_r", "538.imagick_r", "544.nab_r", "549.fotonik3d_r", "554.roms_r") {
    $bench_flags = $bench_cflags = $bench_cxxflags = $bench_fflags = $bench_fppflags = "";
    require "./benchspec/CPU/" . $benchmark . "/Spec/object.pm";
    mkdir("entry/src/main/cpp/" . $benchmark);
    system("cp -arv ./benchspec/CPU/" . $benchmark . "/src/* entry/src/main/cpp/" . $benchmark . "/");
    open(FH, '>', "entry/src/main/cpp/" . $benchmark . "/CMakeLists.txt") or die $!;
    if ($benchmark eq "511.povray_r") {
        @sources = @{%sources{"povray_r"}};
        add_target("511.povray_r");

        @sources = @{%sources{"imagevalidate_511"}};
        add_target("imagevalidate_511");
    } elsif ($benchmark eq "521.wrf_r") {
        @sources = @{%sources{"wrf_r"}};
        add_target("521.wrf_r");

        @sources = @{%sources{"diffwrf_521"}};
        add_target("diffwrf_521");
    } elsif ($benchmark eq "525.x264_r") {
        @sources = @{%sources{"x264_r"}};
        add_target("525.x264_r");

        @sources = @{%sources{"ldecod_r"}};
        add_target("ldecod_r");

        @sources = @{%sources{"imagevalidate_525"}};
        add_target("imagevalidate_525");
    } elsif ($benchmark eq "526.blender_r") {
        @sources = @{%sources{"blender_r"}};
        add_target("526.blender_r");

        @sources = @{%sources{"imagevalidate_526"}};
        add_target("imagevalidate_526");
    } elsif ($benchmark eq "527.cam4_r") {
        @sources = @{%sources{"cam4_r"}};
        add_target("527.cam4_r");

        @sources = @{%sources{"cam4_validate_527"}};
        add_target("cam4_validate_527");
    } elsif ($benchmark eq "538.imagick_r") {
        @sources = @{%sources{"imagick_r"}};
        add_target("538.imagick_r");

        @sources = @{%sources{"imagevalidate_538"}};
        add_target("imagevalidate_538");
    } else {
        add_target($benchmark);
    }

    if ($benchmark eq "549.fotonik3d_r") {
        # extract OBJ.dat.xz for input
        system("xz -d -k ./benchspec/CPU/549.fotonik3d_r/data/refrate/input/OBJ.dat.xz");
    }

    # zip inputs
    system("rm -rf tmp");
    system("mkdir -p tmp/input tmp/output tmp/compare");
    system("cp -rv ./benchspec/CPU/" . $benchmark . "/data/all/input/* ./benchspec/CPU/" . $benchmark . "/data/refrate/input/* tmp/input/");
    system("cp -rv ./benchspec/CPU/" . $benchmark . "/data/refrate/output/* tmp/output/");
    system("cp -rv ./benchspec/CPU/" . $benchmark . "/data/refrate/compare/* tmp/compare/");
    system("rm -f entry/src/main/resources/rawfile/" . $benchmark . ".zip");
    system("cd tmp && zip -r ../entry/src/main/resources/rawfile/" . $benchmark . ".zip *");
    system("rm -rf tmp");
}

# patch code
# fix compilation
# fix missing include
system("sed -i '1s;^;#include <fcntl.h>\\n;' entry/src/main/cpp/500.perlbench_r/perlio.c");
system("sed -i 's/#if defined __FreeBSD__/#include <stdio.h>\\n#if 0/' entry/src/main/cpp/520.omnetpp_r/simulator/platdep/platmisc.h");
# fix stat64 -> stat
system("sed -i 's/defined __FreeBSD__/defined __MUSL__/' entry/src/main/cpp/520.omnetpp_r/simulator/platdep/platmisc.h");
# we don't have backtrace()
system("sed -i 's/defined(SPEC_LINUX)/0/' entry/src/main/cpp/526.blender_r/spec_backtrace.c");
# fix missing ifdef condition
system("sed -i 's/^#ifdef\$/#ifdef SPEC/' entry/src/main/cpp/527.cam4_r/ESMF_AlarmMod.F90");
# fix missing rindex
system("sed -i '1s/^/# define rindex(X,Y) strrchr(X,Y)\\n/' entry/src/main/cpp/521.wrf_r/misc.c");
system("sed -i '1s/^/# define rindex(X,Y) strrchr(X,Y)\\n/' entry/src/main/cpp/521.wrf_r/type.c");
system("sed -i '1s/^/# define rindex(X,Y) strrchr(X,Y)\\n/' entry/src/main/cpp/521.wrf_r/reg_parse.c");
# avoid line truncation
system("sed -i 's/__FILE__/\"input_wrf.F90\"/' entry/src/main/cpp/521.wrf_r/input_wrf.F90");
system("sed -i 's/__FILE__/\"output_wrf.F90\"/' entry/src/main/cpp/521.wrf_r/output_wrf.F90");
system("sed -i 's/__FILE__/\"time_manager.F90\"/' entry/src/main/cpp/527.cam4_r/time_manager.F90");
system("sed -i 's/__FILE__/\"phys_buffer.F90\"/' entry/src/main/cpp/527.cam4_r/phys_buffer.F90");
system("sed -i 's/__FILE__/\"cam_history_support.F90\"/' entry/src/main/cpp/527.cam4_r/cam_history_support.F90");
