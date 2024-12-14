import { hilog } from '@kit.PerformanceAnalysisKit';
import { zlib } from '@kit.BasicServicesKit';
import testNapi from 'libentry.so';
import fs from '@ohos.file.fs';
import { taskpool } from '@kit.ArkTS';

@Concurrent
function worker(filesDir: string, benchmark: string) {
  // run benchmark
  let log: string = filesDir + "/output.log";

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

  testNapi.run(filesDir, log, benchmark, "-I./lib checkspam.pl 2500 5 25 11 150 1 1 1 1".split(" "), core);
  hilog.info(0x0000, 'mainTag', 'Got output: %{public}s', fs.readTextSync(log));
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
            let benchmark = "500.perlbench_r";
            getContext().resourceManager.getRawFileContent(benchmark + ".zip", (err, value) => {
              // each benchmark has its own directory
              let filesDir = getContext(this).filesDir + "/" + benchmark;
              if (!fs.accessSync(filesDir)) {
                fs.mkdirSync(filesDir);
              }

              // copy rawfile to files dir
              let filePath = filesDir + "/" + benchmark + ".zip";
              let file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
              fs.writeSync(file.fd, value.buffer);
              fs.closeSync(file);

              // extract to files dir
              let options: zlib.Options = {
                level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION
              };
              zlib.decompressFile(filePath, filesDir, options, (err) => {
                hilog.info(0x0000, 'mainTag', 'Got files: %{public}s', JSON.stringify(fs.listFileSync(filesDir)));

                // run benchmark in background
                let task: taskpool.Task = new taskpool.Task(worker, filesDir, benchmark);
                taskpool.execute(task);
              });
            });
          })
      }
      .width('100%')
    }
    .height('100%')
  }
}
