import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../db.js';
import { CATEGORIES } from '../game.js';
import { deleteActivity, logActivity } from '../services/progress.js';

const logBody = z.object({
  category: z.enum(CATEGORIES),
  title: z.string().trim().min(1).max(80),
  minutes: z.number().int().min(1).max(24 * 60),
  note: z.string().trim().max(1000).optional(),
});

const listQuery = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(30),
  before: z.string().datetime().optional(),
  category: z.enum(CATEGORIES).optional(),
});

export async function activityRoutes(app: FastifyInstance) {
  app.addHook('onRequest', app.authenticate);

  app.get('/', async (req) => {
    const q = listQuery.parse(req.query);
    return prisma.activity.findMany({
      where: {
        userId: req.user.sub,
        category: q.category,
        createdAt: q.before ? { lt: new Date(q.before) } : undefined,
      },
      orderBy: { createdAt: 'desc' },
      take: q.limit,
    });
  });

  app.post('/', async (req, reply) => {
    const body = logBody.parse(req.body);
    const result = await prisma.$transaction((tx) => logActivity(tx, req.user.sub, body));
    return reply.code(201).send(result);
  });

  app.delete('/:id', async (req, reply) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    await prisma.$transaction((tx) => deleteActivity(tx, req.user.sub, id));
    return reply.code(204).send();
  });
}
