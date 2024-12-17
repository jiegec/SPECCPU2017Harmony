import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';

export function readWholeFile(path: string): ArrayBuffer {
  let size = fs.statSync(path).size;
  let file = fs.openSync(path, fs.OpenMode.READ_ONLY);
  let res = new Uint8Array(size);

  let buf = new ArrayBuffer(4096);
  let bytesRead: number = 0;
  while (bytesRead < size) {
    let length: number = fs.readSync(file.fd, buf);
    if (length > 0) {
      res.set(new Uint8Array(buf, 0, length), bytesRead);
      bytesRead += length;
    }
  }
  fs.closeSync(file);
  return res;
}

export function isEqual(a: ArrayBuffer, b: ArrayBuffer): boolean {
  if (a.byteLength != b.byteLength) {
    return false;
  }

  let aa = new Int8Array(a);
  let bb = new Int8Array(b);
  for (let i = 0; i < a.byteLength; i++) {
    if (aa[i] !== bb[i]) {
      return false;
    }
  }
  return true;
}


export interface CompareOptions {
  // relative error tolerance
  relativeTolerance?: number;
}

// mimic specdiff, allowing fp tolerance
export function isEqualFp(a: ArrayBuffer, b: ArrayBuffer, options: CompareOptions): boolean {
  // decode utf-8
  let decoder = new util.TextDecoder('utf-8');
  let aStr: string = decoder.decodeToString(new Uint8Array(a));
  let bStr: string = decoder.decodeToString(new Uint8Array(b));

  // compare each line
  let aLines: string[] = aStr.split("\n");
  let bLines: string[] = bStr.split("\n");
  if (aLines.length !== bLines.length) {
    return false;
  }

  for (let i = 0;i < aLines.length;i++) {
    let aLine: string = aLines[i];
    let bLine: string = bLines[i];

    let aParts: string[] = aLine.split(" ");
    let bParts: string[] = bLine.split(" ");
    if (aParts.length !== bParts.length) {
      return false;
    }

    for (let j = 0;j < aLines.length;j++) {
      let aPart: string = aParts[j];
      let bPart: string = bParts[j];

      let aFloat: number = parseFloat(aPart);
      let bFloat: number = parseFloat(bPart);
      if (!isNaN(aFloat) && !isNaN(bFloat)) {
        // fp
        // check relative error
        if (Math.abs(aFloat - bFloat) / aFloat > (options.relativeTolerance ?? 0.0)) {
          return false;
        }
      } else if (aPart !== bPart) {
        return false;
      }
    }
  }

  return true;
}
