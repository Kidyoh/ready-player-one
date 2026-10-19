import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../db.js';
import { characterSheet } from '../serialize.js';
import { dayKey } from '../game.js';

/** Avatar keys the app knows how to draw. */
export const AVATARS = ['sun', 'cactus', 'oasis', 'dune', 'dusk', 'ember'] as const;

const patchBody = z
  .object({
    displayName: z.string().trim().min(1).max(40),
    avatar: z.enum(AVATARS),
  })
  .partial();

/** XP per UTC day for the last 7 days, oldest first, for the weekly chart and streak dots. */
async function lastSevenDays(userId: string, now = new Date()) {
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(now);
    d.setUTCDate(d.getUTCDate() - (6 - i));
    return dayKey(d);
  });
  const since = new Date(`${days[0]}T00:00:00Z`);
  const activities = await prisma.activity.findMany({
    where: { userId, createdAt: { gte: since } },
    select: { createdAt: true, xp: true },
  });
  const totals = new Map(days.map((d) => [d, 0]));
  for (const a of activities) {
    const key = dayKey(a.createdAt);
    totals.set(key, (totals.get(key) ?? 0) + a.xp);
  }
  return days.map((day) => ({ day, xp: totals.get(day) ?? 0 }));
}

async function sheetFor(userId: string) {
  const user = await prisma.user.findUniqueOrThrow({ where: { id: userId }, include: { skills: true } });
  return { ...characterSheet(user, user.skills), week: await lastSevenDays(userId) };
}

export async function meRoutes(app: FastifyInstance) {
  app.addHook('onRequest', app.authenticate);

  app.get('/', async (req) => sheetFor(req.user.sub));

  app.patch('/', async (req) => {
    const body = patchBody.parse(req.body);
    await prisma.user.update({ where: { id: req.user.sub }, data: body });
    return sheetFor(req.user.sub);
  });
}
