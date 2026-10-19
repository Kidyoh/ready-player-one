import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../db.js';
import { characterSheet } from '../serialize.js';

/** Avatar keys the app knows how to draw. */
export const AVATARS = ['sun', 'cactus', 'pyramid', 'camel', 'skull', 'palm'] as const;

const patchBody = z
  .object({
    displayName: z.string().trim().min(1).max(40),
    avatar: z.enum(AVATARS),
  })
  .partial();

export async function meRoutes(app: FastifyInstance) {
  app.addHook('onRequest', app.authenticate);

  app.get('/', async (req) => {
    const user = await prisma.user.findUniqueOrThrow({ where: { id: req.user.sub }, include: { skills: true } });
    return characterSheet(user, user.skills);
  });

  app.patch('/', async (req) => {
    const body = patchBody.parse(req.body);
    const user = await prisma.user.update({ where: { id: req.user.sub }, data: body, include: { skills: true } });
    return characterSheet(user, user.skills);
  });
}
