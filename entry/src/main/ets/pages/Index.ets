import { hilog } from '@kit.PerformanceAnalysisKit';
import { zlib } from '@kit.BasicServicesKit';
import testNapi from 'libentry.so';
import fs from '@ohos.file.fs';
import { taskpool } from '@kit.ArkTS';
import { pasteboard } from '@kit.BasicServicesKit';
import { isEqual, readWholeFile, CompareOptions } from './utils.ets';
import { promptAction } from '@kit.ArkUI';
import { thermal } from '@kit.BasicServicesKit';
import { deviceInfo } from '@kit.BasicServicesKit';

interface ValidateConfig {
  // stdout validation, compare stdout and specified file under output folder
  // file validation, compare two files with the same file name under input and output folders
  // command validation, run custom command to validate the output
  type: "STDOUT" | "FILE" | "COMMAND";

  // stdout/file validation
  file?: string;

  // fp compare option for stdout/file validation
  compareOption?: CompareOptions;

  // command to run for validation
  command?: string;
}

interface BenchmarkConfig {
  // command argv
  args: string;

  // how to validate output
  validates: ValidateConfig[];
}

type Benchmark = string | BenchmarkConfig;


@Concurrent
function findCoreFreq(cores: number): number[] {
  // find core with maximum clock frequency
  let freqs: number[] = [];
  for (let i = 0; i < cores; i++) {
    let freq: number = testNapi.clock(i);
    freqs.push(freq);
  }
  return freqs;
}

@Concurrent
function worker(inputDir: string, outputDir: string, stdinFile: string, benchmark: string, args: string[], core: number,
  validates: ValidateConfig[]): number {
  hilog.info(0x0000, 'mainTag',
    'Enter worker: %{public}s, %{public}s, %{public}s, %{public}s, %{public}s, %{public}d, %{public}s', inputDir,
    outputDir, stdinFile, benchmark, JSON.stringify(args), core, JSON.stringify(validates));
  let ret: number = -1;
  try {
    // run benchmark
    let stdoutFile: string = inputDir + "/stdout.log";
    let stderrFile: string = inputDir + "/stderr.log";
    hilog.info(0x0000, 'mainTag',
      'Run command: %{public}s, %{public}s, %{public}s, %{public}s, %{public}s, %{public}s, %{public}d',
      inputDir, stdinFile, stdoutFile, stderrFile, benchmark, JSON.stringify(args), core);
    ret = testNapi.run(inputDir, stdinFile, stdoutFile, stderrFile, benchmark, args, core);
    hilog.info(0x0000, 'mainTag', 'Got stdout: %{public}s', fs.readTextSync(stdoutFile));
    hilog.info(0x0000, 'mainTag', 'Got stderr: %{public}s', fs.readTextSync(stderrFile));

    if (ret < 0) {
      return ret;
    }

    for (let validate of validates) {
      // validation
      if (validate.type === "STDOUT" || validate.type === "FILE") {
        // compare two files
        let expectedFile: string = outputDir + "/" + validate.file!;
        let actualFile: string = (validate.type === "STDOUT") ? stdoutFile : (inputDir + "/" + validate.file!);
        hilog.info(0x0000, 'mainTag', 'Validate %{public}s against %{public}s', actualFile, expectedFile);

        let actual: ArrayBuffer = readWholeFile(actualFile);
        let expected: ArrayBuffer = readWholeFile(expectedFile);
        if (isEqual(actual, expected, validate.compareOption)) {
          hilog.info(0x0000, 'mainTag', 'Validation passed: %{public}d bytes', actual.byteLength);
        } else {
          hilog.info(0x0000, 'mainTag', 'Validation failed');
          ret = -1;
          break;
        }
      } else if (validate.type === "COMMAND") {
        // run command, and then compare its stdout to file
        let parts = validate.command!.split(" ");
        let validator = parts[0];
        let validator_args = parts.slice(1);
        let stdoutFile: string = inputDir + "/validate-stdout.log";
        let stderrFile: string = inputDir + "/validate-stderr.log";
        hilog.info(0x0000, 'mainTag',
          'Run command: %{public}s, %{public}s, %{public}s, %{public}s, %{public}s, %{public}s, %{public}d',
          inputDir, "", stdoutFile, stderrFile, validator, JSON.stringify(validator_args), core);
        if (testNapi.run(inputDir, "", stdoutFile, stderrFile, validator, validator_args, core) < 0) {
          hilog.info(0x0000, 'mainTag', 'Failed to run validation command %{public}s', validate.command!);
          ret = -1;
          break;
        }
        hilog.info(0x0000, 'mainTag', 'Got stdout: %{public}s', fs.readTextSync(stdoutFile));
        hilog.info(0x0000, 'mainTag', 'Got stderr: %{public}s', fs.readTextSync(stderrFile));

        // compare stdout and expected
        let actualFile: string = stdoutFile;
        let expectedFile: string = outputDir + "/" + validate.file;

        hilog.info(0x0000, 'mainTag', 'Validate %{public}s against %{public}s', actualFile, expectedFile);
        let actual: ArrayBuffer = readWholeFile(actualFile);
        let expected: ArrayBuffer = readWholeFile(expectedFile);
        if (isEqual(actual, expected, validate.compareOption)) {
          hilog.info(0x0000, 'mainTag', 'Validation passed: %{public}d bytes', actual.byteLength);
        } else {
          hilog.info(0x0000, 'mainTag', 'Validation failed');
          ret = -1;
          break;
        }
      }
    }
  } catch (err) {
    hilog.info(0x0000, 'mainTag', 'Got error: %{public}s %{public}s', err.toString(), JSON.stringify(err));
    ret = -1;
  }
  return ret;
}

let int_rate = [
  "500.perlbench_r",
  "502.gcc_r",
  "505.mcf_r",
  "520.omnetpp_r",
  "523.xalancbmk_r",
  "525.x264_r",
  "531.deepsjeng_r",
  "541.leela_r",
  "548.exchange2_r",
  "557.xz_r",
];

let fp_rate = [
  "503.bwaves_r",
  "507.cactuBSSN_r",
  "508.namd_r",
  "510.parest_r",
  "511.povray_r",
  "519.lbm_r",
  "521.wrf_r",
  "526.blender_r",
  "527.cam4_r",
  "538.imagick_r",
  "544.nab_r",
  "549.fotonik3d_r",
  "554.roms_r",
];

@Entry
@Component
struct Index {
  @State log: string = '';
  @State running: boolean = false;
  @State core: number = 0;
  @State numCores: number = 0;
  @State partIds: string[] = [];

  onPageShow() {
    thermal.registerThermalLevelCallback((level: thermal.ThermalLevel) => {
      // https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-thermal-V5#thermallevel
      let levels = [
        "COOL",
        "NORMAL",
        "WARM",
        "HOT",
        "OVERHEATED",
        "WARNING",
        "EMERGENCY",
        "ESCAPE"
      ];
      this.log += "Thermal level is: " + levels[level] + "\n";
    });
    this.log += "Running on " + deviceInfo.marketName + "\n";

    // parse /proc/cpuinfo
    // let cpuinfo = fs.readTextSync("/proc/cpuinfo");
    let cpuinfo: string = testNapi.cpuInfo();
    this.log += "Reading /proc/cpuinfo:\n";
    this.log += cpuinfo + "\n";
    let lines: string[] = cpuinfo.split("\n");
    this.partIds = [];
    for (let line of lines) {
      if (line.startsWith("CPU part")) {
        let parts = line.split(":");
        let part = parts[1].trim();
        this.partIds.push(part);
      }
    }
    this.numCores = this.partIds.length;
    this.log += "Found " + this.numCores + " cores:\n";
    let core = 0;
    for (let partId of this.partIds) {
      this.log += "Core " + core + ": part id " + partId + "\n";
      core += 1;
    }
  }

  onPageHide() {
    thermal.unregisterThermalLevelCallback();
  }

  async runBenchmarks(filter: string[]) {
    if (this.running) {
      promptAction.showToast({
        message: 'Already running',
        duration: 2000
      });
      return;
    }
    this.running = true;

    try {
      this.log += testNapi.info() + "\n";

      let context = getContext(this);
      let benchmarks: Map<string, Benchmark[]> = new Map();
      // int rate
      benchmarks.set("500.perlbench_r", [
        {
          args: "-I./lib checkspam.pl 2500 5 25 11 150 1 1 1 1",
          validates: [{
            type: "STDOUT",
            file: "checkspam.2500.5.25.11.150.1.1.1.1.out",
          }],
        } as BenchmarkConfig,
        {
          args: "-I./lib diffmail.pl 4 800 10 17 19 300",
          validates: [{
            type: "STDOUT",
            file: "diffmail.4.800.10.17.19.300.out",
          }],
        } as BenchmarkConfig,
        {
          args: "-I./lib splitmail.pl 6400 12 26 16 100 0",
          validates: [{
            type: "STDOUT",
            file: "splitmail.6400.12.26.16.100.0.out",
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("502.gcc_r", [
        {
          args: "gcc-pp.c -O3 -finline-limit=0 -fif-conversion -fif-conversion2 -o gcc-pp.opts-O3_-finline-limit_0_-fif-conversion_-fif-conversion2.s",
          validates: [{
            type: "FILE",
            file: "gcc-pp.opts-O3_-finline-limit_0_-fif-conversion_-fif-conversion2.s",
          }],
        } as BenchmarkConfig,
        {
          args: "gcc-pp.c -O2 -finline-limit=36000 -fpic -o gcc-pp.opts-O2_-finline-limit_36000_-fpic.s",
          validates: [{
            type: "FILE",
            file: "gcc-pp.opts-O2_-finline-limit_36000_-fpic.s",
          }],
        } as BenchmarkConfig,
        {
          args: "gcc-smaller.c -O3 -fipa-pta -o gcc-smaller.opts-O3_-fipa-pta.s",
          validates: [{
            type: "FILE",
            file: "gcc-smaller.opts-O3_-fipa-pta.s",
          }],
        } as BenchmarkConfig,
        {
          args: "ref32.c -O5 -o ref32.opts-O5.s",
          validates: [{
            type: "FILE",
            file: "ref32.opts-O5.s",
          }],
        } as BenchmarkConfig,
        {
          args: "ref32.c -O3 -fselective-scheduling -fselective-scheduling2 -o ref32.opts-O3_-fselective-scheduling_-fselective-scheduling2.s",
          validates: [{
            type: "FILE",
            file: "ref32.opts-O3_-fselective-scheduling_-fselective-scheduling2.s",
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("505.mcf_r", [
        {
          args: "inp.in",
          validates: [{
            type: "STDOUT",
            file: "inp.out",
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("520.omnetpp_r", [
        {
          args: "-c General -r 0",
          validates: [{
            type: "FILE",
            file: "General-0.sca",
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("523.xalancbmk_r", [
        {
          args: "-v t5.xml xalanc.xsl",
          validates: [{
            type: "STDOUT",
            file: "ref-t5.out",
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("525.x264_r", [
        "--pass 1 --stats x264_stats.log --bitrate 1000 --frames 1000 -o BuckBunny_New.264 BuckBunny.yuv 1280x720",
        "--pass 2 --stats x264_stats.log --bitrate 1000 --dumpyuv 200 --frames 1000 -o BuckBunny_New.264 BuckBunny.yuv 1280x720",
        {
          args: "--seek 500 --dumpyuv 200 --frames 1250 -o BuckBunny_New.264 BuckBunny.yuv 1280x720",
          validates: [200, 400, 600, 700, 800, 900, 999, 1100, 1249].map((frame) => {
            return {
              type: "COMMAND",
              command: "imagevalidate_525 -avg -threshold 0.5 -maxthreshold 20 frame_" + frame +
                ".yuv ../compare/frame_" + frame + ".org.tga",
              file: "imagevalidate_frame_" + frame + ".out",
              compareOption: {
                relativeTolerance: 0.085,
              } as CompareOptions,
            } as ValidateConfig;
          }),
        }
      ]);
      benchmarks.set("531.deepsjeng_r", [
        {
          args: "ref.txt",
          validates: [{
            type: "STDOUT",
            file: "ref.out",
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("541.leela_r", [
        {
          args: "ref.sgf",
          validates: [{
            type: "STDOUT",
            file: "ref.out",
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("548.exchange2_r", [
        {
          args: "6",
          validates: [{
            type: "FILE",
            file: "s.txt",
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("557.xz_r", [
        {
          args: "cld.tar.xz 160 19cf30ae51eddcbefda78dd06014b4b96281456e078ca7c13e1c0c9e6aaea8dff3efb4ad6b0456697718cede6bd5454852652806a657bb56e07d61128434b474 59796407 61004416 6",
          validates: [{
            type: "STDOUT",
            file: "cld.tar-160-6.out",
          }],
        } as BenchmarkConfig,
        {
          args: "cpu2006docs.tar.xz 250 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 23047774 23513385 6e",
          validates: [{
            type: "STDOUT",
            file: "cpu2006docs.tar-250-6e.out",
          }],
        } as BenchmarkConfig,
        {
          args: "input.combined.xz 250 a841f68f38572a49d86226b7ff5baeb31bd19dc637a922a972b2e6d1257a890f6a544ecab967c313e370478c74f760eb229d4eef8a8d2836d233d3e9dd1430bf 40401484 41217675 7",
          validates: [{
            type: "STDOUT",
            file: "input.combined-250-7.out",
          }],
        } as BenchmarkConfig,
      ]);

      // fp rate
      benchmarks.set("503.bwaves_r", [1, 2, 3, 4].map((i) => {
        return {
          args: "bwaves_" + i + " < bwaves_" + i + ".in",
          validates: [{
            type: "STDOUT",
            file: "bwaves_" + i + ".out",
            compareOption: {
              absoluteTolerance: 1e-16,
              relativeTolerance: 0.015,
            }
          }],
        } as BenchmarkConfig;
      }));
      benchmarks.set("507.cactuBSSN_r", [
        {
          args: "spec_ref.par",
          validates: [{
            type: "STDOUT",
            file: "spec_ref.out",
          }, {
            type: "FILE",
            file: "gxx.xl",
            compareOption: {
              absoluteTolerance: 5e-13,
            }
          }, {
            type: "FILE",
            file: "gxy.xl",
            compareOption: {
              absoluteTolerance: 5e-13,
            }
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("508.namd_r", [
        {
          args: "--input apoa1.input --output apoa1.ref.output --iterations 65",
          validates: [{
            type: "FILE",
            file: "apoa1.ref.output",
            compareOption: {
              absoluteTolerance: 5e-05,
            }
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("510.parest_r", [
        {
          args: "ref.prm",
          validates: [{
            type: "FILE",
            file: "001-m00.vtk",
            compareOption: {
              absoluteTolerance: 0.001,
            }
          }, {
            type: "FILE",
            file: "002-m00.vtk",
            compareOption: {
              absoluteTolerance: 0.001,
            }
          }, {
            type: "FILE",
            file: "003-m00.vtk",
            compareOption: {
              absoluteTolerance: 0.001,
            }
          }, {
            type: "FILE",
            file: "004-m00.vtk",
            compareOption: {
              absoluteTolerance: 0.001,
            }
          }, {
            type: "FILE",
            file: "005-m00.vtk",
            compareOption: {
              absoluteTolerance: 0.001,
            }
          }, {
            type: "FILE",
            file: "006-m00.vtk",
            compareOption: {
              absoluteTolerance: 0.001,
            }
          }, {
            type: "FILE",
            file: "007-m00.vtk",
            compareOption: {
              absoluteTolerance: 0.001,
            }
          }, {
            type: "FILE",
            file: "log",
            compareOption: {
              absoluteTolerance: 0.001,
            }
          }, {
            type: "FILE",
            file: "me.prm",
            compareOption: {
              absoluteTolerance: 0.001,
            }
          }, {
            type: "FILE",
            file: "statistics",
            compareOption: {
              absoluteTolerance: 0.004,
            }
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("511.povray_r", [
        {
          args: "SPEC-benchmark-ref.ini",
          validates: [{
            type: "COMMAND",
            command: "imagevalidate_511 SPEC-benchmark.tga ../compare/SPEC-benchmark.org.tga",
            file: "imagevalidate_SPEC-benchmark.tga.out",
            compareOption: {
              relativeTolerance: 0.06,
            }
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("519.lbm_r", [
        {
          args: "3000 reference.dat 0 0 100_100_130_ldc.of",
          validates: [{
            type: "STDOUT",
            file: "lbm.out",
            compareOption: {
              absoluteTolerance: 1e-07,
            }
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("521.wrf_r", [
        {
          args: "",
          validates: [{
            type: "COMMAND",
            command: "diffwrf_521 wrfout_d01_2000-01-24_20_00_00 ../compare/wrf_reference_01",
            file: "diffwrf_output_01.txt",
            compareOption: {
              collapseWhitespace: true,
            }
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("526.blender_r", [
        {
          args: "sh3_no_char.blend --render-output sh3_no_char_ --threads 1 -b -F RAWTGA -s 849 -e 849 -a",
          validates: [{
            type: "COMMAND",
            command: "imagevalidate_526 -avg -threshold 0.75 -maxthreshold 0.01 sh3_no_char_0849.tga ../compare/sh3_no_char_0849.org.tga",
            file: "imagevalidate_sh3_no_char_0849.out",
            compareOption: {
              relativeTolerance: 0.05,
            }
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("527.cam4_r", [
        {
          args: "",
          validates: [{
            type: "COMMAND",
            command: "cam4_validate_527 10 0.0035 ../compare/h0_ctrl.nc h0.nc",
            file: "cam4_validate.txt",
            compareOption: {
              collapseWhitespace: true,
            }
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("538.imagick_r", [
        {
          args: "-limit disk 0 refrate_input.tga -edge 41 -resample 181% -emboss 31 -colorspace YUV -mean-shift 19x19+15% -resize 30% refrate_output.tga",
          validates: [{
            type: "COMMAND",
            command: "imagevalidate_538 -avg -threshold 0.95 -maxthreshold 0.001 refrate_output.tga ../compare/refrate_expected.tga",
            file: "refrate_validate.out",
            compareOption: {
              relativeTolerance: 0.01,
            }
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("544.nab_r", [
        {
          args: "1am0 1122214447 122",
          validates: [{
            type: "STDOUT",
            file: "1am0.out",
            compareOption: {
              relativeTolerance: 0.01,
              skipRelativeTolerance: 2
            }
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("549.fotonik3d_r", [
        {
          args: "",
          validates: [{
            type: "FILE",
            file: "pscyee.out",
            compareOption: {
              absoluteTolerance: 1e-27,
              relativeTolerance: 1e-10,
              // TODO: off-by-one --obiwan
            }
          }],
        } as BenchmarkConfig,
      ]);
      benchmarks.set("554.roms_r", [
        {
          args: "< ocean_benchmark2.in.x",
          validates: [{
            type: "STDOUT",
            file: "ocean_benchmark2.log",
            compareOption: {
              absoluteTolerance: 1e-07,
              relativeTolerance: 1e-07,
              // although not specified in Spec/object.pm,
              // we found that the only diff was whitespaces..
              collapseWhitespace: true,
            }
          }],
        } as BenchmarkConfig,
      ]);

      // from data/refrate/reftime
      let reftime: Map<string, number> = new Map();
      // int rate
      reftime.set("500.perlbench_r", 1592);
      reftime.set("502.gcc_r", 1416);
      reftime.set("505.mcf_r", 1616);
      reftime.set("520.omnetpp_r", 1312);
      reftime.set("523.xalancbmk_r", 1056);
      reftime.set("525.x264_r", 1751);
      reftime.set("531.deepsjeng_r", 1146);
      reftime.set("541.leela_r", 1656);
      reftime.set("548.exchange2_r", 2620);
      reftime.set("557.xz_r", 1080);

      // fp rate
      reftime.set("503.bwaves_r", 10028);
      reftime.set("507.cactuBSSN_r", 1266);
      reftime.set("508.namd_r", 950);
      reftime.set("510.parest_r", 2616);
      reftime.set("511.povray_r", 2335);
      reftime.set("519.lbm_r", 1054);
      reftime.set("521.wrf_r", 2240);
      reftime.set("526.blender_r", 1523);
      reftime.set("527.cam4_r", 1749);
      reftime.set("538.imagick_r", 2487);
      reftime.set("544.nab_r", 1683);
      reftime.set("549.fotonik3d_r", 3897);
      reftime.set("554.roms_r", 1589);

      let core = this.core;
      this.log += "Using core " + core + " with part id " + this.partIds[core] + "\n";

      let result: Map<string, number> = new Map();
      let failed: boolean = false;
      for (let benchmark of filter) {
        this.log += "Run benchmark " + benchmark + "\n";
        hilog.info(0x0000, 'mainTag', 'Extracting files for %{public}s', benchmark);
        let value = await context.resourceManager.getRawFileContent(benchmark + ".zip");
        // each benchmark has its own directory
        let filesDir = context.filesDir + "/" + benchmark;
        if (!await fs.access(filesDir)) {
          await fs.mkdir(filesDir);
        }

        // copy rawfile to files dir
        let filePath = filesDir + "/" + benchmark + ".zip";
        let file = await fs.open(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        await fs.write(file.fd, value.buffer);
        await fs.close(file);

        // extract to files dir
        let options: zlib.Options = {
          level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION
        };
        await zlib.decompressFile(filePath, filesDir, options);

        let inputDir = filesDir + "/input";
        let outputDir = filesDir + "/output";

        if (benchmark === "525.x264_r") {
          // generate BuckBunny.yuv
          hilog.info(0x0000, 'mainTag', 'Generating BuckBunny.yuv');
          this.log += 'Generating BuckBunny.yuv for 525.x264_r\n';
          let task: taskpool.Task =
            new taskpool.Task(worker, inputDir, outputDir, "", "ldecod_r", "-i BuckBunny.264 -o BuckBunny.yuv".split(" "),
              core, []);
          await taskpool.execute(task);
        }

        hilog.info(0x0000, 'mainTag', 'Got files under benchmark folder: %{public}s',
          JSON.stringify(fs.listFileSync(filesDir)));
        hilog.info(0x0000, 'mainTag', 'Got files under input folder: %{public}s',
          JSON.stringify(fs.listFileSync(inputDir)));
        hilog.info(0x0000, 'mainTag', 'Got files under output folder: %{public}s',
          JSON.stringify(fs.listFileSync(outputDir)));

        // run benchmark in background
        let totalTime: number = 0;
        let index: number = 0;
        for (let b of benchmarks.get(benchmark)!) {
          index += 1;
          let arg: string;
          let validates: ValidateConfig[] = [];
          if (typeof b === "string") {
            arg = b;
          } else {
            arg = (b as BenchmarkConfig).args;
            validates = (b as BenchmarkConfig).validates;
          }

          this.log += "Run benchmark " + benchmark + " #" + index + " with args " + arg + "\n";
          hilog.info(0x0000, 'mainTag', 'Run benchmark %{public}s #%{public}d with %{public}s', benchmark, index, arg);
          let args = arg.split(" ");
          let stdinFile = "";
          if (args.length >= 2 && args[args.length-2] === "<") {
            // handle input redirection
            stdinFile = args.pop()!;
            args.pop();
          }

          let task: taskpool.Task =
            new taskpool.Task(worker, inputDir, outputDir, stdinFile, benchmark, args, core, validates);
          let time: number = await taskpool.execute(task) as number;
          if (time < 0) {
            hilog.info(0x0000, 'mainTag', 'Failed benchmark %{public}s with args %{public}s', benchmark,
              arg);
            this.log += "Failed benchmark " + benchmark + " #" + index + " with args " + arg + "\n";
            failed = true;
            break;
          }

          hilog.info(0x0000, 'mainTag', 'Finished benchmark %{public}s with args %{public}s in %{public}ss', benchmark,
            arg, time.toString());
          this.log += "Finished benchmark " + benchmark + " #" + index + " with args " + arg + " in " + time + "s\n";

          if (validates.length > 0) {
            this.log += "Output validation passed for " + benchmark + " #" + index + "\n";
          }

          totalTime += time;
        }

        if (failed) {
          break;
        }

        let ratio: number = reftime.get(benchmark)!
        / totalTime;
        this.log += "Finished whole benchmark " + benchmark + " in " + totalTime + "s, ratio is " + ratio + "\n";
        hilog.info(0x0000, 'mainTag', 'Finished whole benchmark %{public}s in %{public}ss, ratio is %{public}s',
          benchmark,
          totalTime.toString(), ratio.toString());
        result.set(benchmark, totalTime);
      }

      if (failed) {
        this.log += "Aborted due to failure\n";
      } else {
        // print summary
        this.log += "Summary:\n";
        let ratios: number[] = [];
        let geomean = 1.0;
        this.log += "=================================================================================\n";
        for (let benchmark of result.keys()) {
          let time: number = result.get(benchmark)!;
          let timeString: string = time.toPrecision(3);
          // keep integral part if >= 1000
          if (time >= 1000) {
            timeString = Math.round(time).toString();
          }
          
          let ratio: number = reftime.get(benchmark)!
          / result.get(benchmark)!;
          this.log += benchmark + " 1 " + timeString + " " + ratio.toPrecision(3) + " *\n";
          ratios.push(ratio);
          geomean *= ratio;
        }
        this.log += "Est. SPECrate(R)2017_int/fp_base " + Math.pow(geomean, 1 / result.size).toPrecision(3) + "\n";
      }
    } catch (err) {
      hilog.info(0x0000, 'mainTag', 'Got error: %{public}s %{public}s', err.toString(), JSON.stringify(err));
      this.log += "Got exception: " + err.toString() + "\n";
    }
    this.running = false;
  }

  @Builder
  benchmarkMenu() {
    Menu() {
      MenuItem({ content: "int rate-1" })
        .onClick(() => {
          this.runBenchmarks(int_rate);
        })
      ForEach(int_rate, (item: string) => {
        MenuItem({ content: item })
          .onClick(() => {
            this.runBenchmarks([item]);
          })
      })
      MenuItem({ content: "fp rate-1" })
        .onClick(() => {
          this.runBenchmarks(fp_rate);
        })
      ForEach(fp_rate, (item: string) => {
        MenuItem({ content: item })
          .onClick(() => {
            this.runBenchmarks([item]);
          })
      })
      MenuItem({ content: "int rate-1 + fp rate-1" })
        .onClick(() => {
          this.runBenchmarks(int_rate);
          this.runBenchmarks(fp_rate);
        })
    }
  }

  @Builder
  coreMenu() {
    Menu() {
      // https://stackoverflow.com/questions/3895478/does-javascript-have-a-method-like-range-to-generate-a-range-within-the-supp
      ForEach(Array.from({length: this.numCores}, (x: object, i: number) => i), (core: number) => {
        MenuItem({ content: "Core " + core })
          .onClick(() => {
            this.core = core;
          })
      })
    }
  }

  build() {
    Scroll() {
      Column() {
        Text(this.log)
          .fontSize(10)
          .fontFamily('monospace')
          .width('100%')

        Text("Find Fastest Core")
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .onClick(async () => {
            this.log += "Finding fastest core\n";
            let task: taskpool.Task = new taskpool.Task(findCoreFreq, this.numCores);
            let freqs: number[] = await taskpool.execute(task) as number[];

            // find core with maximum clock frequency
            let core = 0;
            let max_freq = 0;
            for (let i = 0; i < this.numCores; i++) {
              let freq: number = freqs[i];
              this.log += "Core " + i + " frequency is " + freq.toFixed(2) + " GHz\n";
              if (freq > max_freq) {
                max_freq = freq;
                core = i;
              }
            }
            hilog.info(0x0000, 'mainTag', 'Fastest core is %{public}d', core);
            this.log += "Found fastest core is " + core + "\n";
            this.core = core;
          })
        Text("Run Benchmarks")
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .bindMenu(this.benchmarkMenu)
        Text("Select Core (Currently " + this.core + ")")
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .bindMenu(this.coreMenu)
        Text("Copy Result")
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .onClick(() => {
            let pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.log);
            let systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
            systemPasteboard.setData(pasteData, (err, data) => {
              if (err) {
                hilog.info(0x0000, 'mainTag', 'Failed to set pastboard: %{public}s', JSON.stringify(err));
                return;
              }
            });
          })
      }.width('100%')
    }
  }
}
