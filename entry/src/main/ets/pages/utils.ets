import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

export function readWholeFile(path: string): ArrayBuffer {
  let size = fs.statSync(path).size;
  hilog.info(0x0000, 'mainTag', 'File %{public}s has %{public}d bytes', path, size);
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

function isEqualBinary(a: ArrayBuffer, b: ArrayBuffer): boolean {
  if (a.byteLength != b.byteLength) {
    hilog.info(0x0000, 'mainTag', 'Length mismatch: %{public}d vs %{public}d', a.byteLength, b.byteLength);
    return false;
  }

  let aa = new Int8Array(a);
  let bb = new Int8Array(b);
  for (let i = 0; i < a.byteLength; i++) {
    if (aa[i] !== bb[i]) {
      hilog.info(0x0000, 'mainTag', 'Byte mismatch: %{public}d vs %{public}d', aa[i], bb[i]);
      return false;
    }
  }
  return true;
}


export interface CompareOptions {
  // relative error tolerance
  // --reltol
  relativeTolerance?: number;

  // skip the first occurrences of relative error violation
  // --skipreltol
  skipRelativeTolerance?: number;

  // absolute error tolerance
  // --abstol
  absoluteTolerance?: number;

  // collapse whitespace
  // --cw
  collapseWhitespace?: boolean;
}

// mimic specdiff, allowing fp tolerance
export function isEqual(a: ArrayBuffer, b: ArrayBuffer, options?: CompareOptions): boolean {
  // fallback to more efficient implementation
  if (options === null || options === undefined) {
    return isEqualBinary(a, b);
  }

  // decode utf-8
  let decoder = new util.TextDecoder('utf-8');
  let aStr: string = decoder.decodeToString(new Uint8Array(a));
  let bStr: string = decoder.decodeToString(new Uint8Array(b));
  hilog.info(0x0000, 'mainTag', 'Got a: %{public}s', aStr);
  hilog.info(0x0000, 'mainTag', 'Got b: %{public}s', bStr);

  // compare each line
  let aLines: string[] = aStr.split("\n");
  let bLines: string[] = bStr.split("\n");
  if (aLines.length !== bLines.length) {
    hilog.info(0x0000, 'mainTag', 'Number of lines mismatch: %{public}d vs %{public}d', aLines.length, bLines.length);
    return false;
  }

  let skippedRelativeTolerance: number = 0;

  for (let i = 0;i < aLines.length;i++) {
    let aLine: string = aLines[i];
    let bLine: string = bLines[i];

    let aParts: string[] = aLine.split(" ");
    let bParts: string[] = bLine.split(" ");
    if (options.collapseWhitespace) {
      // drop empty strings
      aParts = aParts.filter((part) => {
          return part.length > 0;
      });
      bParts = bParts.filter((part) => {
          return part.length > 0;
      });
    }

    if (aParts.length !== bParts.length) {
      hilog.info(0x0000, 'mainTag', 'Number of parts mismatch: %{public}d vs %{public}d', aParts.length, bParts.length);
      return false;
    }

    for (let j = 0;j < aParts.length;j++) {
      let aPart: string = aParts[j];
      let bPart: string = bParts[j];

      let aFloat: number = parseFloat(aPart);
      let bFloat: number = parseFloat(bPart);
      if (!isNaN(aFloat) && !isNaN(bFloat)) {
        // fp
        // either one within error is okay
        if ((options!.relativeTolerance !== null && options!.relativeTolerance !== undefined) || (options!.absoluteTolerance !== null && options!.absoluteTolerance !== undefined)) {
          // check relative error
          let relativePass: boolean = false;
          if (options!.relativeTolerance !== null && options!.relativeTolerance !== undefined) {
            relativePass = true;
            if (Math.abs(aFloat - bFloat) / aFloat > options!.relativeTolerance!) {
              // handle --skipreltol
              if (options!.skipRelativeTolerance !== null && options!.skipRelativeTolerance !== undefined) {
                skippedRelativeTolerance += 1;
                if (skippedRelativeTolerance > options!.skipRelativeTolerance) {
                  relativePass = true;
                }
              } else {
                relativePass = false;
              }
            }
          }

          // check absolute error
          let absolutePass: boolean = false;
          if (options!.absoluteTolerance !== null && options!.absoluteTolerance !== undefined) {
            absolutePass = true;
            if (Math.abs(aFloat - bFloat) > options!.absoluteTolerance!) {
              absolutePass = false;
            }
          }

          if (!relativePass && !absolutePass) {
            hilog.info(0x0000, 'mainTag', 'Relative/absolute tolerance violated: %{public}s vs %{public}s from %{public}s and %{public}s', aFloat.toString(), bFloat.toString(), aLine, bLine);
            return false;
          }
        }
      } else if (aPart !== bPart) {
        hilog.info(0x0000, 'mainTag', 'Part mismatch: %{public}s vs %{public}s', aPart, bPart);
        return false;
      }
    }
  }

  return true;
}
