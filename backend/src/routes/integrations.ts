import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../db.js';
import type { TokenBox } from '../crypto.js';
import type { GitHubClient } from '../integrations/github.js';
import { importHealth, syncGitHub } from '../integrations/sync.js';

export interface IntegrationDeps {
  github: GitHubClient;
  tokenBox: TokenBox;
}

const healthBody = z.object({
  device: z.string().trim().max(60).optional(),
  sessions: z
    .array(
      z.object({
        id: z.string().min(1).max(200),
        kind: z.enum(['WORKOUT', 'MINDFUL']),
        title: z.string().trim().min(1).max(80),
        start: z.string().datetime(),
        end: z.string().datetime(),
      }),
    )
    .max(500),
});

export async function integrationRoutes(app: FastifyInstance, { github, tokenBox }: IntegrationDeps) {
  app.addHook('onRequest', app.authenticate);

  app.get('/', async (req) => {
    const rows = await prisma.integration.findMany({ where: { userId: req.user.sub } });
    const view = (provider: 'GITHUB' | 'HEALTH') => {
      const row = rows.find((r) => r.provider === provider);
      return { connected: Boolean(row), login: row?.externalLogin ?? null, lastSyncedAt: row?.lastSyncedAt ?? null };
    };
    return { github: { ...view('GITHUB'), deviceFlow: github.deviceFlowEnabled }, health: view('HEALTH') };
  });

  async function connectGitHub(userId: string, token: string) {
    const login = await github.viewerLogin(token);
    await prisma.integration.upsert({
      where: { userId_provider: { userId, provider: 'GITHUB' } },
      create: { userId, provider: 'GITHUB', externalLogin: login, accessTokenEnc: tokenBox.seal(token) },
      update: { externalLogin: login, accessTokenEnc: tokenBox.seal(token) },
    });
    return { login, sync: await syncGitHub(userId, github, tokenBox) };
  }

  /** Personal access token path: works without registering an OAuth app. */
  app.post('/github/token', async (req) => {
    const { token } = z.object({ token: z.string().trim().min(10).max(255) }).parse(req.body);
    return { status: 'connected', ...(await connectGitHub(req.user.sub, token)) };
  });

  app.post('/github/device/start', async () => github.startDeviceFlow());

  app.post('/github/device/poll', async (req) => {
    const { deviceCode } = z.object({ deviceCode: z.string().min(1).max(200) }).parse(req.body);
    const result = await github.pollDeviceFlow(deviceCode);
    if (result.status !== 'authorized') return result;
    return { status: 'connected', ...(await connectGitHub(req.user.sub, result.accessToken)) };
  });

  app.post('/github/sync', async (req) => syncGitHub(req.user.sub, github, tokenBox));

  app.delete('/github', async (req, reply) => {
    // Imported activities and their XP stay: the work really happened.
    await prisma.integration.deleteMany({ where: { userId: req.user.sub, provider: 'GITHUB' } });
    return reply.code(204).send();
  });

  app.post('/health/import', async (req) => {
    const body = healthBody.parse(req.body);
    return importHealth(
      req.user.sub,
      body.sessions.map((s) => ({ ...s, start: new Date(s.start), end: new Date(s.end) })),
      body.device,
    );
  });

  app.delete('/health', async (req, reply) => {
    await prisma.integration.deleteMany({ where: { userId: req.user.sub, provider: 'HEALTH' } });
    return reply.code(204).send();
  });
}
