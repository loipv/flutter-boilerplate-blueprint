import { defineConfig } from 'vitest/config';

// The rules test files share one emulator, so they run one at a time.
export default defineConfig({
  test: { fileParallelism: false },
});
