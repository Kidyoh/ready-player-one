import { execSync } from 'node:child_process';

// Brings the test database to the latest migration. Tests use unique emails, so no wipe is needed.
export default function setup() {
  const url = process.env.TEST_DATABASE_URL ?? 'postgresql://rpo:rpo@localhost:5432/rpo_test';
  execSync('npx prisma migrate deploy', { env: { ...process.env, DATABASE_URL: url }, stdio: 'ignore' });
}
