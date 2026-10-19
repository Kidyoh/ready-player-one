import { buildApp } from './app.js';

const secret = process.env.JWT_SECRET;
if (!secret) throw new Error('JWT_SECRET is required');

const app = await buildApp({ jwtSecret: secret, logger: true });
await app.listen({ port: Number(process.env.PORT ?? 8080), host: '0.0.0.0' });
