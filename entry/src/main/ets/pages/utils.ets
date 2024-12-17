import fs from '@ohos.file.fs';

export function readWholeFile(path: string): ArrayBuffer {
  let size = fs.statSync(path).size;
  let file = fs.openSync(path, fs.OpenMode.READ_ONLY);
  let res = new Uint8Array(size);

  let buf = new ArrayBuffer(4096);
  let bytesRead: number = 0;
  while (bytesRead < size) {
    let length: number = fs.readSync(file.fd, buf);
    res.set(new Uint8Array(buf), bytesRead);
    bytesRead += length;
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
