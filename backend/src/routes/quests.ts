import type { FastifyInstance } from 'fastify';
import type { Prisma } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../db.js';
import { badRequest, forbidden } from '../errors.js';
import { CATEGORIES, generateQuest } from '../game.js';
import { assertCanAccessQuest, completeStep } from '../services/progress.js';

const fromGoalBody = z.object({
  goal: z.string().trim().min(1).max(100),
  category: z.enum(CATEGORIES),
  weeks: z.number().int().min(1).max(12),
  sessionsPerWeek: z.number().int().min(1).max(7),
  minutesPerSession: z.number().int().min(5).max(240),
  forParty: z.boolean().default(false),
});

const customBody = z.object({
  title: z.string().trim().min(1).max(100),
  category: z.enum(CATEGORIES),
  rewardXp: z.number().int().min(10).max(5000),
  dueAt: z.string().datetime().optional(),
  steps: z
    .array(z.object({ title: z.string().trim().min(1).max(100), targetMinutes: z.number().int().min(0).max(240).default(0) }))
    .min(1)
    .max(60),
  forParty: z.boolean().default(false),
});

const questInclude = {
  steps: {
    orderBy: { position: 'asc' },
    include: { completedBy: { select: { id: true, displayName: true, avatar: true } } },
  },
  owner: { select: { id: true, displayName: true, avatar: true } },
} satisfies Prisma.QuestInclude;

async function partyFor(userId: string, forParty: boolean) {
  if (!forParty) return null;
  const membership = await prisma.partyMember.findUnique({ where: { userId } });
  if (!membership) throw badRequest('Join a party before creating a party quest');
  return membership.partyId;
}

async function createQuest(
  userId: string,
  partyId: string | null,
  data: { title: string; goal?: string; category: (typeof CATEGORIES)[number]; rewardXp: number; dueAt?: Date },
  steps: Array<{ title: string; targetMinutes: number }>,
) {
  return prisma.$transaction(async (tx) => {
    const quest = await tx.quest.create({
      data: {
        ...data,
        ownerId: userId,
        partyId,
        steps: { create: steps.map((s, i) => ({ ...s, position: i })) },
      },
      include: questInclude,
    });
    const membership = await tx.partyMember.findUnique({ where: { userId } });
    await tx.event.create({
      data: {
        userId,
        partyId: membership?.partyId,
        type: 'QUEST_STARTED',
        message: `${quest.owner.displayName} started a quest: ${quest.title}`,
      },
    });
    return quest;
  });
}

export async function questRoutes(app: FastifyInstance) {
  app.addHook('onRequest', app.authenticate);

  app.get('/', async (req) => {
    const { status } = z.object({ status: z.enum(['ACTIVE', 'COMPLETED', 'ABANDONED']).optional() }).parse(req.query);
    const userId = req.user.sub;
    const membership = await prisma.partyMember.findUnique({ where: { userId } });
    return prisma.quest.findMany({
      where: {
        status,
        OR: membership ? [{ ownerId: userId }, { partyId: membership.partyId }] : [{ ownerId: userId }],
      },
      orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
      include: questInclude,
    });
  });

  app.get('/:id', async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    await assertCanAccessQuest(prisma, req.user.sub, id);
    return prisma.quest.findUniqueOrThrow({ where: { id }, include: questInclude });
  });

  /** Preview what a goal would become without saving it. */
  app.post('/preview', async (req) => {
    const body = fromGoalBody.parse(req.body);
    return generateQuest(body);
  });

  app.post('/from-goal', async (req, reply) => {
    const body = fromGoalBody.parse(req.body);
    const partyId = await partyFor(req.user.sub, body.forParty);
    const plan = generateQuest(body);
    const dueAt = new Date(Date.now() + plan.durationDays * 24 * 60 * 60 * 1000);
    const quest = await createQuest(
      req.user.sub,
      partyId,
      { title: plan.title, goal: body.goal, category: body.category, rewardXp: plan.rewardXp, dueAt },
      plan.steps,
    );
    return reply.code(201).send(quest);
  });

  app.post('/', async (req, reply) => {
    const body = customBody.parse(req.body);
    const partyId = await partyFor(req.user.sub, body.forParty);
    const quest = await createQuest(
      req.user.sub,
      partyId,
      { title: body.title, category: body.category, rewardXp: body.rewardXp, dueAt: body.dueAt ? new Date(body.dueAt) : undefined },
      body.steps,
    );
    return reply.code(201).send(quest);
  });

  app.post('/:id/steps/:stepId/complete', async (req) => {
    const { id, stepId } = z.object({ id: z.string(), stepId: z.string() }).parse(req.params);
    const result = await prisma.$transaction(async (tx) => {
      const step = await tx.questStep.findUnique({ where: { id: stepId } });
      if (!step || step.questId !== id) throw badRequest('Step does not belong to this quest');
      return completeStep(tx, req.user.sub, stepId, null);
    });
    const quest = await prisma.quest.findUniqueOrThrow({ where: { id }, include: questInclude });
    return { result, quest };
  });

  app.post('/:id/abandon', async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const quest = await assertCanAccessQuest(prisma, req.user.sub, id);
    if (quest.ownerId !== req.user.sub) throw forbidden('Only the quest owner can abandon it');
    if (quest.status !== 'ACTIVE') throw badRequest('Quest is not active');
    return prisma.quest.update({ where: { id }, data: { status: 'ABANDONED' }, include: questInclude });
  });
}
