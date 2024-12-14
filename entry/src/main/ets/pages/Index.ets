import { hilog } from '@kit.PerformanceAnalysisKit';
import { zlib } from '@kit.BasicServicesKit';
import testNapi from 'libentry.so';
import fs from '@ohos.file.fs';
import { taskpool } from '@kit.ArkTS';

@Concurrent
function findBestCore() {
  // find core with maximum clock frequency
  let core = 0;
  let max_freq = 0;
  for (let i = 0;i < 12;i++) {
    let freq = testNapi.clock(i);
    if (freq > max_freq) {
      max_freq = freq;
      core = i;
    }
  }
  hilog.info(0x0000, 'mainTag', 'Fastest core is %{public}d', core);

  return core;
}

@Concurrent
function worker(filesDir: string, benchmark: string, args: string, core: number) {
  // run benchmark
  let log: string = filesDir + "/output.log";
  return testNapi.run(filesDir, log, benchmark, args.split(" "), core);
}

async function runBenchmarks(context: Context) {
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

  let task: taskpool.Task = new taskpool.Task(findBestCore);
  let core = await taskpool.execute(task);

  for (let benchmark of benchmarks.keys()) {
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
    hilog.info(0x0000, 'mainTag', 'Got files: %{public}s', JSON.stringify(fs.listFileSync(filesDir)));

    // run benchmark in background
    for (let arg of benchmarks.get(benchmark)!) {
      hilog.info(0x0000, 'mainTag', 'Run benchmark %{public}s with %{public}s', benchmark, arg);
      let task: taskpool.Task = new taskpool.Task(worker, filesDir, benchmark, arg, core);
      await taskpool.execute(task);
    }
  }
}

@Entry
@Component
struct Index {
  @State message: string = 'Hello World'

  build() {
    Row() {
      Column() {
        Text(this.message)
          .fontSize(50)
          .fontWeight(FontWeight.Bold)
          .onClick(() => {
            runBenchmarks(getContext(this));
          })
      }
      .width('100%')
    }
    .height('100%')
  }
}
