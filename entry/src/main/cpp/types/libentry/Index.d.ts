export const run: (cwd: string, stdin: string, stdout: string, stderr: string, benchmark: string, args: string[], core: number, outputUnbuffered: boolean) => number;
export const clock: (core: number) => number;
export const info: () => string;
export const cpuInfo: () => string;
