import { defineConfig } from 'vitest/config';

const testDb = process.env.TEST_DATABASE_URL ?? 'postgresql://rpo:rpo@localhost:5432/rpo_test';

export default defineConfig({
  test: {
    env: { DATABASE_URL: testDb },
    globalSetup: ['test/global-setup.ts'],
    fileParallelism: false,
  },
});
