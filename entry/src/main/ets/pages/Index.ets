import { hilog } from '@kit.PerformanceAnalysisKit';
import testNapi from 'libentry.so'
import fs from '@ohos.file.fs';

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
            let file: string = getContext(this).filesDir + "/output.log";
            testNapi.run(file, "500.perlbench_r", []);
            hilog.info(0x0000, 'testTag', 'Test NAPI %{public}s', fs.readTextSync(file));
          })
      }
      .width('100%')
    }
    .height('100%')
  }
}
