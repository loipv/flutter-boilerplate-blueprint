import { defineConfig } from 'vitest/config';

// Tests live in test/, outside tsconfig's `include: ["src"]`, so `npm run build`
// never compiles them into lib/. They share one Firestore emulator, so they run
// one file at a time.
export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    fileParallelism: false,
  },
});
