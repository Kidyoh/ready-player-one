import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';
import { prisma } from '../src/db.js';

let app: FastifyInstance;

beforeAll(async () => {
  app = await buildApp({ jwtSecret: 'test-secret' });
});

afterAll(async () => {
  await app.close();
  await prisma.$disconnect();
});

let counter = 0;
async function signUp(name = 'Hero') {
  counter++;
  const res = await app.inject({
    method: 'POST',
    url: '/auth/register',
    payload: { email: `${name.toLowerCase()}${counter}-${Date.now()}@test.dev`, password: 'password123', displayName: name },
  });
  expect(res.statusCode).toBe(201);
  const { token, user } = res.json();
  const call = (method: 'GET' | 'POST' | 'PATCH' | 'DELETE', url: string, payload?: object) =>
    app.inject({ method, url, payload, headers: { authorization: `Bearer ${token}` } });
  return { token, user, call };
}

describe('auth', () => {
  it('registers, logs in and rejects bad passwords', async () => {
    const email = `login-${Date.now()}@test.dev`;
    await app.inject({ method: 'POST', url: '/auth/register', payload: { email, password: 'password123', displayName: 'A' } });

    const dupe = await app.inject({ method: 'POST', url: '/auth/register', payload: { email, password: 'password123', displayName: 'B' } });
    expect(dupe.statusCode).toBe(409);

    const ok = await app.inject({ method: 'POST', url: '/auth/login', payload: { email: email.toUpperCase(), password: 'password123' } });
    expect(ok.statusCode).toBe(200);
    expect(ok.json().user.level).toBe(1);

    const bad = await app.inject({ method: 'POST', url: '/auth/login', payload: { email, password: 'nope' } });
    expect(bad.statusCode).toBe(401);
  });

  it('protects routes', async () => {
    expect((await app.inject({ method: 'GET', url: '/me' })).statusCode).toBe(401);
  });

  it('validates input', async () => {
    const res = await app.inject({ method: 'POST', url: '/auth/register', payload: { email: 'x', password: '1', displayName: '' } });
    expect(res.statusCode).toBe(400);
  });
});

describe('activities and xp', () => {
  it('awards stat xp, levels up and can be undone', async () => {
    const p = await signUp();
    const res = await p.call('POST', '/activities', { category: 'WORKOUT', title: 'Leg day', minutes: 40 });
    expect(res.statusCode).toBe(201);
    const body = res.json();
    expect(body.xpGained).toBe(120);
    expect(body.levelUp).toBe(2);
    expect(body.streak).toBe(1);

    const me = (await p.call('GET', '/me')).json();
    expect(me.totalXp).toBe(120);
    expect(me.stats.find((s: { category: string }) => s.category === 'WORKOUT').xp).toBe(120);

    expect((await p.call('DELETE', `/activities/${body.activity.id}`)).statusCode).toBe(204);
    expect((await p.call('GET', '/me')).json().totalXp).toBe(0);
  });

  it("does not let players delete each other's activities", async () => {
    const a = await signUp();
    const b = await signUp();
    const { activity } = (await a.call('POST', '/activities', { category: 'READING', title: 'Dune', minutes: 20 })).json();
    expect((await b.call('DELETE', `/activities/${activity.id}`)).statusCode).toBe(403);
  });
});

describe('quests', () => {
  it('advances on matching activities and pays out on the boss step', async () => {
    const p = await signUp();
    const created = await p.call('POST', '/quests/from-goal', {
      goal: 'Finish a book',
      category: 'READING',
      weeks: 1,
      sessionsPerWeek: 2,
      minutesPerSession: 20,
    });
    expect(created.statusCode).toBe(201);
    const quest = created.json();
    expect(quest.steps).toHaveLength(3);

    // Too short and wrong category don't count.
    expect((await p.call('POST', '/activities', { category: 'READING', title: 'skim', minutes: 5 })).json().quest).toBeNull();
    expect((await p.call('POST', '/activities', { category: 'CODING', title: 'code', minutes: 60 })).json().quest).toBeNull();

    const first = (await p.call('POST', '/activities', { category: 'READING', title: 'ch 1', minutes: 25 })).json();
    expect(first.quest.questCompleted).toBe(false);
    await p.call('POST', '/activities', { category: 'READING', title: 'ch 2', minutes: 25 });

    const xpBefore = (await p.call('GET', '/me')).json().totalXp;
    const boss = quest.steps[2];
    const done = await p.call('POST', `/quests/${quest.id}/steps/${boss.id}/complete`);
    expect(done.statusCode).toBe(200);
    expect(done.json().result.questCompleted).toBe(true);
    expect(done.json().quest.status).toBe('COMPLETED');
    expect((await p.call('GET', '/me')).json().totalXp).toBe(xpBefore + quest.rewardXp);
  });

  it('hides quests from other players', async () => {
    const a = await signUp();
    const b = await signUp();
    const quest = (await a.call('POST', '/quests', { title: 'Secret', category: 'CODING', rewardXp: 50, steps: [{ title: 'x' }] })).json();
    expect((await b.call('GET', `/quests/${quest.id}`)).statusCode).toBe(404);
    expect((await b.call('POST', `/quests/${quest.id}/steps/${quest.steps[0].id}/complete`)).statusCode).toBe(404);
  });
});

describe('party', () => {
  it('forms a party, shares quests, rewards everyone and shows a feed', async () => {
    const leader = await signUp('Leader');
    const friend = await signUp('Friend');

    const party = (await leader.call('POST', '/party', { name: 'Dune Walkers' })).json().party;
    expect(party.inviteCode).toMatch(/^[A-Z2-9]{6}$/);

    const joined = await friend.call('POST', '/party/join', { code: party.inviteCode.toLowerCase() });
    expect(joined.statusCode).toBe(200);
    expect(joined.json().party.members).toHaveLength(2);
    expect((await friend.call('POST', '/party', { name: 'Another' })).statusCode).toBe(409);

    const quest = (
      await leader.call('POST', '/quests', {
        title: 'Party code sprint',
        category: 'CODING',
        rewardXp: 200,
        forParty: true,
        steps: [{ title: 'Ship it', targetMinutes: 30 }],
      })
    ).json();

    // The friend's activity completes the leader's party quest; both get the reward.
    const log = (await friend.call('POST', '/activities', { category: 'CODING', title: 'API', minutes: 45 })).json();
    expect(log.quest).toMatchObject({ questId: quest.id, questCompleted: true, rewardXp: 200 });
    expect((await leader.call('GET', '/me')).json().totalXp).toBe(200);
    expect((await friend.call('GET', '/me')).json().totalXp).toBe(log.xpGained + 200);

    const feed = (await leader.call('GET', '/party/feed')).json();
    const types = feed.map((e: { type: string }) => e.type);
    expect(types).toContain('QUEST_COMPLETED');
    expect(types).toContain('ACTIVITY_LOGGED');
    expect(types).toContain('PARTY_JOINED');

    // Leadership passes on when the leader leaves; the party disappears when empty.
    await leader.call('POST', '/party/leave');
    const after = (await friend.call('GET', '/party')).json().party;
    expect(after.members).toEqual([expect.objectContaining({ displayName: 'Friend', isLeader: true })]);
    await friend.call('POST', '/party/leave');
    expect((await friend.call('POST', '/party/join', { code: party.inviteCode })).statusCode).toBe(404);
  });
});
