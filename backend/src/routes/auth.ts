import type { FastifyInstance } from 'fastify';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '../db.js';
import { conflict, HttpError } from '../errors.js';
import { characterSheet } from '../serialize.js';
import { AVATARS } from './me.js';

const registerBody = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(8).max(200),
  displayName: z.string().trim().min(1).max(40),
  avatar: z.enum(AVATARS).optional(),
});

const loginBody = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(1),
});

export async function authRoutes(app: FastifyInstance) {
  app.post('/register', async (req, reply) => {
    const body = registerBody.parse(req.body);
    const existing = await prisma.user.findUnique({ where: { email: body.email } });
    if (existing) throw conflict('Email already registered');

    const user = await prisma.user.create({
      data: {
        email: body.email,
        displayName: body.displayName,
        avatar: body.avatar,
        passwordHash: await bcrypt.hash(body.password, 10),
      },
    });
    const token = app.jwt.sign({ sub: user.id });
    return reply.code(201).send({ token, user: characterSheet(user, []) });
  });

  app.post('/login', async (req) => {
    const body = loginBody.parse(req.body);
    const user = await prisma.user.findUnique({ where: { email: body.email }, include: { skills: true } });
    if (!user || !(await bcrypt.compare(body.password, user.passwordHash))) {
      throw new HttpError(401, 'Wrong email or password');
    }
    const token = app.jwt.sign({ sub: user.id });
    return { token, user: characterSheet(user, user.skills) };
  });
}
