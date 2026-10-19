import type { FastifyInstance } from 'fastify';
import { randomInt } from 'node:crypto';
import { z } from 'zod';
import { prisma } from '../db.js';
import { badRequest, conflict, notFound } from '../errors.js';
import { publicPlayer } from '../serialize.js';

// No 0/O/1/I so codes are easy to read aloud.
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function inviteCode() {
  return Array.from({ length: 6 }, () => CODE_ALPHABET[randomInt(CODE_ALPHABET.length)]).join('');
}

async function partyView(partyId: string) {
  const party = await prisma.party.findUniqueOrThrow({
    where: { id: partyId },
    include: { members: { include: { user: true }, orderBy: { joinedAt: 'asc' } } },
  });
  return {
    id: party.id,
    name: party.name,
    inviteCode: party.inviteCode,
    members: party.members
      .map((m) => ({ ...publicPlayer(m.user), isLeader: m.isLeader }))
      .sort((a, b) => b.totalXp - a.totalXp),
  };
}

export async function partyRoutes(app: FastifyInstance) {
  app.addHook('onRequest', app.authenticate);

  app.get('/', async (req) => {
    const membership = await prisma.partyMember.findUnique({ where: { userId: req.user.sub } });
    return { party: membership ? await partyView(membership.partyId) : null };
  });

  app.post('/', async (req, reply) => {
    const { name } = z.object({ name: z.string().trim().min(1).max(40) }).parse(req.body);
    const userId = req.user.sub;
    if (await prisma.partyMember.findUnique({ where: { userId } })) throw conflict('Leave your current party first');

    const party = await prisma.$transaction(async (tx) => {
      const created = await tx.party.create({
        data: { name, inviteCode: inviteCode(), members: { create: { userId, isLeader: true } } },
      });
      await tx.event.create({ data: { userId, partyId: created.id, type: 'PARTY_JOINED', message: `The party "${name}" was formed` } });
      return created;
    });
    return reply.code(201).send({ party: await partyView(party.id) });
  });

  app.post('/join', async (req) => {
    const { code } = z.object({ code: z.string().trim().toUpperCase().length(6) }).parse(req.body);
    const userId = req.user.sub;
    if (await prisma.partyMember.findUnique({ where: { userId } })) throw conflict('Leave your current party first');
    const party = await prisma.party.findUnique({ where: { inviteCode: code } });
    if (!party) throw notFound('Party');

    await prisma.$transaction(async (tx) => {
      const user = await tx.user.findUniqueOrThrow({ where: { id: userId } });
      await tx.partyMember.create({ data: { userId, partyId: party.id } });
      await tx.event.create({ data: { userId, partyId: party.id, type: 'PARTY_JOINED', message: `${user.displayName} joined the party` } });
    });
    return { party: await partyView(party.id) };
  });

  app.post('/leave', async (req) => {
    const userId = req.user.sub;
    const membership = await prisma.partyMember.findUnique({ where: { userId } });
    if (!membership) throw badRequest('You are not in a party');

    await prisma.$transaction(async (tx) => {
      await tx.partyMember.delete({ where: { userId } });
      const remaining = await tx.partyMember.findMany({ where: { partyId: membership.partyId }, orderBy: { joinedAt: 'asc' } });
      if (remaining.length === 0) {
        await tx.party.delete({ where: { id: membership.partyId } });
      } else if (membership.isLeader) {
        await tx.partyMember.update({ where: { userId: remaining[0].userId }, data: { isLeader: true } });
      }
    });
    return { party: null };
  });

  app.get('/feed', async (req) => {
    const { limit } = z.object({ limit: z.coerce.number().int().min(1).max(100).default(50) }).parse(req.query);
    const userId = req.user.sub;
    const membership = await prisma.partyMember.findUnique({ where: { userId } });
    if (!membership) return [];
    const events = await prisma.event.findMany({
      where: { partyId: membership.partyId },
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: {
        user: { select: { id: true, displayName: true, avatar: true } },
        cheers: { select: { userId: true } },
      },
    });
    return events.map(({ cheers, ...e }) => ({
      ...e,
      cheers: cheers.length,
      cheeredByMe: cheers.some((c) => c.userId === userId),
    }));
  });

  /** Toggles a cheer (kudos) on a party-mate's feed event. */
  app.post('/feed/:eventId/cheer', async (req) => {
    const { eventId } = z.object({ eventId: z.string() }).parse(req.params);
    const userId = req.user.sub;
    const membership = await prisma.partyMember.findUnique({ where: { userId } });
    const event = await prisma.event.findUnique({ where: { id: eventId } });
    if (!membership || !event || event.partyId !== membership.partyId) throw notFound('Event');
    if (event.userId === userId) throw badRequest("You can't cheer for yourself");

    const key = { eventId_userId: { eventId, userId } };
    const existing = await prisma.cheer.findUnique({ where: key });
    if (existing) await prisma.cheer.delete({ where: key });
    else await prisma.cheer.create({ data: { eventId, userId } });
    return { cheered: !existing, cheers: await prisma.cheer.count({ where: { eventId } }) };
  });
}
