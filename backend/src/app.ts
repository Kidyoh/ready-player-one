import Fastify, { type FastifyReply, type FastifyRequest } from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import { ZodError } from 'zod';
import { HttpError } from './errors.js';
import { authRoutes } from './routes/auth.js';
import { meRoutes } from './routes/me.js';
import { activityRoutes } from './routes/activities.js';
import { questRoutes } from './routes/quests.js';
import { partyRoutes } from './routes/party.js';
import { integrationRoutes } from './routes/integrations.js';
import { GitHubClient } from './integrations/github.js';
import { TokenBox } from './crypto.js';

declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: { sub: string };
    user: { sub: string };
  }
}

declare module 'fastify' {
  interface FastifyInstance {
    authenticate: (req: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
}

export interface AppOptions {
  jwtSecret: string;
  /** Encrypts third-party tokens at rest. Falls back to the JWT secret in development. */
  tokenSecret?: string;
  github?: GitHubClient;
  logger?: boolean;
}

export async function buildApp({ jwtSecret, tokenSecret, github = new GitHubClient(), logger = false }: AppOptions) {
  const app = Fastify({ logger });

  await app.register(cors, { origin: true });
  await app.register(jwt, { secret: jwtSecret, sign: { expiresIn: '30d' } });

  app.decorate('authenticate', async (req: FastifyRequest, reply: FastifyReply) => {
    try {
      await req.jwtVerify();
    } catch {
      reply.code(401).send({ error: 'Unauthorized' });
    }
  });

  app.setErrorHandler((err, _req, reply) => {
    if (err instanceof ZodError) {
      return reply.code(400).send({ error: 'Invalid input', details: err.flatten().fieldErrors });
    }
    if (err instanceof HttpError) {
      return reply.code(err.statusCode).send({ error: err.message });
    }
    app.log.error(err);
    return reply.code(500).send({ error: 'Internal server error' });
  });

  app.get('/health', async () => ({ ok: true }));
  await app.register(authRoutes, { prefix: '/auth' });
  await app.register(meRoutes, { prefix: '/me' });
  await app.register(activityRoutes, { prefix: '/activities' });
  await app.register(questRoutes, { prefix: '/quests' });
  await app.register(partyRoutes, { prefix: '/party' });
  await app.register(integrationRoutes, {
    prefix: '/integrations',
    github,
    tokenBox: new TokenBox(tokenSecret ?? jwtSecret),
  });

  return app;
}
