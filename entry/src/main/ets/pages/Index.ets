import { hilog } from '@kit.PerformanceAnalysisKit';
import { zlib } from '@kit.BasicServicesKit';
import testNapi from 'libentry.so';
import fs from '@ohos.file.fs';
import { taskpool } from '@kit.ArkTS';
import { pasteboard } from '@kit.BasicServicesKit';

@Concurrent
function findBestCore(): number {
  // find core with maximum clock frequency
  let core = 0;
  let max_freq = 0;
  for (let i = 0; i < 12; i++) {
    let freq: number = testNapi.clock(i);
    if (freq > max_freq) {
      max_freq = freq;
      core = i;
    }
  }
  hilog.info(0x0000, 'mainTag', 'Fastest core is %{public}d', core);

  return core;
}

@Concurrent
function worker(filesDir: string, benchmark: string, args: string, core: number): number {
  // run benchmark
  let log: string = filesDir + "/output.log";
  return testNapi.run(filesDir, log, benchmark, args.split(" "), core);
}

@Entry
@Component
struct Index {
  @State log: string = '';

  async runBenchmarks(filter: string) {
    let context = getContext(this);
    let benchmarks: Map<string, string[]> = new Map();
    benchmarks.set("500.perlbench_r", [
      "-I./lib checkspam.pl 2500 5 25 11 150 1 1 1 1",
      "-I./lib diffmail.pl 4 800 10 17 19 300",
      "-I./lib splitmail.pl 6400 12 26 16 100 0"
    ]);
    benchmarks.set("502.gcc_r", [
      "gcc-pp.c -O3 -finline-limit=0 -fif-conversion -fif-conversion2 -o gcc-pp.opts-O3_-finline-limit_0_-fif-conversion_-fif-conversion2.s",
      "gcc-pp.c -O2 -finline-limit=36000 -fpic -o gcc-pp.opts-O2_-finline-limit_36000_-fpic.s",
      "gcc-smaller.c -O3 -fipa-pta -o gcc-smaller.opts-O3_-fipa-pta.s",
      "ref32.c -O5 -o ref32.opts-O5.s",
      "ref32.c -O3 -fselective-scheduling -fselective-scheduling2 -o ref32.opts-O3_-fselective-scheduling_-fselective-scheduling2.s"
    ]);
    benchmarks.set("505.mcf_r", [
      "inp.in"
    ]);
    benchmarks.set("520.omnetpp_r", [
      "-c General -r 0"
    ]);
    benchmarks.set("523.xalancbmk_r", [
      "-v t5.xml xalanc.xsl"
    ]);
    benchmarks.set("525.x264_r", [
      "--pass 1 --stats x264_stats.log --bitrate 1000 --frames 1000 -o BuckBunny_New.264 BuckBunny.yuv 1280x720",
      "--pass 2 --stats x264_stats.log --bitrate 1000 --dumpyuv 200 --frames 1000 -o BuckBunny_New.264 BuckBunny.yuv 1280x720",
      "--seek 500 --dumpyuv 200 --frames 1250 -o BuckBunny_New.264 BuckBunny.yuv 1280x720"
    ]);
    benchmarks.set("531.deepsjeng_r", [
      "ref.txt"
    ]);
    benchmarks.set("541.leela_r", [
      "ref.sgf"
    ]);
    benchmarks.set("548.exchange2_r", [
      "6",
    ]);
    benchmarks.set("557.xz_r", [
      "cld.tar.xz 160 19cf30ae51eddcbefda78dd06014b4b96281456e078ca7c13e1c0c9e6aaea8dff3efb4ad6b0456697718cede6bd5454852652806a657bb56e07d61128434b474 59796407 61004416 6",
      "cpu2006docs.tar.xz 250 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 23047774 23513385 6e",
      "input.combined.xz 250 a841f68f38572a49d86226b7ff5baeb31bd19dc637a922a972b2e6d1257a890f6a544ecab967c313e370478c74f760eb229d4eef8a8d2836d233d3e9dd1430bf 40401484 41217675 7"
    ]);

    // from data/refrate/reftime
    let reftime: Map<string, number> = new Map();
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

    let task: taskpool.Task = new taskpool.Task(findBestCore);
    let core = await taskpool.execute(task);
    this.log += "Found fastest core is " + core + "\n";

    let result: Map<string, number> = new Map();
    let filtered: string[] = Array.from(benchmarks.keys());
    for (let benchmark of benchmarks.keys()) {
      if (benchmark === filter) {
        filtered = [filter];
        break;
      }
    }

    for (let benchmark of filtered) {
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

      if (benchmark === "525.x264_r") {
        // generate BuckBunny.yuv
        hilog.info(0x0000, 'mainTag', 'Generating BuckBunny.yuv');
        let task: taskpool.Task =
          new taskpool.Task(worker, filesDir, "ldecod_r", "-i BuckBunny.264 -o BuckBunny.yuv", core);
        await taskpool.execute(task);
      }

      hilog.info(0x0000, 'mainTag', 'Got files: %{public}s', JSON.stringify(fs.listFileSync(filesDir)));
      // run benchmark in background
      let totalTime: number = 0;
      for (let arg of benchmarks.get(benchmark)!) {
        this.log += "Run benchmark " + benchmark + " with args " + arg + "\n";
        hilog.info(0x0000, 'mainTag', 'Run benchmark %{public}s with %{public}s', benchmark, arg);
        let task: taskpool.Task = new taskpool.Task(worker, filesDir, benchmark, arg, core);
        let time: number = await taskpool.execute(task) as number;
        hilog.info(0x0000, 'mainTag', 'Finished benchmark %{public}s with args %{public}s in %{public}ss', benchmark,
          arg, time.toString());
        this.log += "Finished benchmark " + benchmark + " with args " + arg + " in " + time + "s\n";

        totalTime += time;
      }
      let ratio: number = reftime.get(benchmark)!
      / totalTime;
      this.log += "Finished whole benchmark " + benchmark + " in " + totalTime + "s, ratio is " + ratio;
      hilog.info(0x0000, 'mainTag', 'Finished whole benchmark %{public}s in %{public}ss, ratio is %{public}s', benchmark,
        totalTime.toString(), ratio.toString());
      result.set(benchmark, totalTime);
    }

    // print summary
    this.log += "Summary:\n";
    let ratios: number[] = [];
    let geomean = 1.0;
    this.log += "=================================================================================\n";
    for (let benchmark of result.keys()) {
      let ratio: number = reftime.get(benchmark)!
      / result.get(benchmark)!;
      this.log += benchmark + " 1 " + result.get(benchmark) + " " + ratio + " *\n";
      ratios.push(ratio);
      geomean *= ratio;
    }
    this.log += "Est. SPECrate(R)2017_int_base " + Math.pow(geomean, 1 / result.size) + "\n";
  }

  @Builder
  benchmarkMenu() {
    Menu() {
      MenuItem({ content: "Run All" })
        .onClick(() => {
          this.runBenchmarks("");
        })
      MenuItem({ content: "502.gcc_r" })
        .onClick(() => {
          this.runBenchmarks("502.gcc_r");
        })
      MenuItem({ content: "548.exchange2_r" })
        .onClick(() => {
          this.runBenchmarks("548.exchange2_r");
        })
    }
  }

  build() {
    Row() {
      Column() {
        Scroll() {
          Text(this.log)
            .fontSize(10)
            .fontFamily('monospace')
            .width('100%')
        }

        Text("Run Benchmarks")
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .bindMenu(this.benchmarkMenu)
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
      }
      .width('100%')
    }
    .height('90%')
  }
}
