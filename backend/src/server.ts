import { buildApp } from './app.js';
import { GitHubClient } from './integrations/github.js';

const secret = process.env.JWT_SECRET;
if (!secret) throw new Error('JWT_SECRET is required');

const app = await buildApp({
  jwtSecret: secret,
  tokenSecret: process.env.TOKEN_ENCRYPTION_KEY,
  // Optional: the client ID of a GitHub OAuth app with device flow enabled.
  github: new GitHubClient(fetch, process.env.GITHUB_CLIENT_ID || undefined),
  logger: true,
});
await app.listen({ port: Number(process.env.PORT ?? 8080), host: '0.0.0.0' });
