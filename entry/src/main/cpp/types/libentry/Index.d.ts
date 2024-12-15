export const run: (cwd: string, log: string, benchmark: string, args: string[], core: number) => number;
export const clock: (core: number) => number;
export const info: () => string;