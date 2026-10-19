import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';
import { prisma } from '../src/db.js';
import { TokenBox } from '../src/crypto.js';
import { GitHubClient, minutesForContributions } from '../src/integrations/github.js';

/** A stand-in for github.com: contributions per token, and a device flow that approves on the 2nd poll. */
class FakeGitHub {
  contributions = new Map<string, Array<{ date: string; contributionCount: number }>>();
  polls = 0;

  fetch = async (url: string, init?: RequestInit): Promise<Response> => {
    const auth = new Headers(init?.headers).get('authorization')?.replace('Bearer ', '');
    const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status });
    if (url.endsWith('/login/device/code')) {
      return json({ device_code: 'dev-123', user_code: 'ABCD-1234', verification_uri: 'https://github.com/login/device', interval: 5, expires_in: 900 });
    }
    if (url.endsWith('/login/oauth/access_token')) {
      this.polls++;
      return json(this.polls < 2 ? { error: 'authorization_pending' } : { access_token: 'tok-device-user' });
    }
    if (!auth || !this.contributions.has(auth)) return json({ message: 'Bad credentials' }, 401);
    if (url.endsWith('/user')) return json({ login: `octo-${auth}` });
    if (url.endsWith('/graphql')) {
      const days = this.contributions.get(auth)!;
      return json({ data: { viewer: { contributionsCollection: { contributionCalendar: { weeks: [{ contributionDays: days }] } } } } });
    }
    return json({}, 404);
  };
}

const fake = new FakeGitHub();
let app: FastifyInstance;

beforeAll(async () => {
  app = await buildApp({ jwtSecret: 'test-secret', github: new GitHubClient(fake.fetch, 'client-id') });
});

afterAll(async () => {
  await app.close();
  await prisma.$disconnect();
});

let n = 0;
async function signUp(name = 'Coder') {
  n++;
  const res = await app.inject({
    method: 'POST',
    url: '/auth/register',
    payload: { email: `${name.toLowerCase()}-int${n}-${Date.now()}@test.dev`, password: 'password123', displayName: name },
  });
  const { token, user } = res.json();
  const call = (method: 'GET' | 'POST' | 'DELETE', url: string, payload?: object) =>
    app.inject({ method, url, payload, headers: { authorization: `Bearer ${token}` } });
  return { user, call };
}

const daysAgo = (d: number) => new Date(Date.now() - d * 86400000).toISOString().slice(0, 10);

describe('token box', () => {
  it('round-trips and detects tampering', () => {
    const box = new TokenBox('k');
    const sealed = box.seal('ghp_secret');
    expect(sealed).not.toContain('ghp_secret');
    expect(box.open(sealed)).toBe('ghp_secret');
    const [iv, tag, data] = sealed.split('.');
    expect(() => box.open([iv, tag, data.slice(0, -2) + 'AA'].join('.'))).toThrow();
    expect(() => new TokenBox('other').open(sealed)).toThrow();
  });
});

describe('github', () => {
  it('connects with a token, backfills a week, dedupes and grows on resync', async () => {
    const p = await signUp();
    fake.contributions.set('tok-alpha-123', [
      { date: daysAgo(20), contributionCount: 9 }, // older than the backfill window
      { date: daysAgo(3), contributionCount: 2 },
      { date: daysAgo(1), contributionCount: 0 },
      { date: daysAgo(0), contributionCount: 2 },
    ]);

    const res = await p.call('POST', '/integrations/github/token', { token: 'tok-alpha-123' });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.login).toBe('octo-tok-alpha-123');
    expect(body.sync.imported).toBe(2);

    const acts = (await p.call('GET', '/activities')).json();
    expect(acts.map((a: { minutes: number }) => a.minutes)).toEqual([minutesForContributions(2), 20]);
    expect(acts.every((a: { source: string; category: string }) => a.source === 'GITHUB' && a.category === 'CODING')).toBe(true);

    // The stored token is encrypted.
    const row = await prisma.integration.findUniqueOrThrow({ where: { userId_provider: { userId: p.user.id, provider: 'GITHUB' } } });
    expect(row.accessTokenEnc).not.toContain('tok-alpha-123');

    // Same data again: nothing new.
    const again = (await p.call('POST', '/integrations/github/sync')).json();
    expect(again).toMatchObject({ imported: 0, updated: 0, xpGained: 0 });

    // More contributions land today: that activity grows instead of duplicating.
    const before = (await p.call('GET', '/me')).json().totalXp;
    fake.contributions.get('tok-alpha-123')![3].contributionCount = 5;
    const grown = (await p.call('POST', '/integrations/github/sync')).json();
    expect(grown.updated).toBe(1);
    expect(grown.xpGained).toBeGreaterThan(0);
    expect((await p.call('GET', '/me')).json().totalXp).toBe(before + grown.xpGained);

    // The whole sync shows up as one feed line, not one per day.
    const events = await prisma.event.findMany({ where: { userId: p.user.id, type: 'ACTIVITY_LOGGED' }, orderBy: { createdAt: 'asc' } });
    expect(events.map((e) => e.message)).toEqual([
      expect.stringContaining('synced 2 new entries from GitHub'),
      expect.stringContaining('synced updates from GitHub'),
    ]);

    const status = (await p.call('GET', '/integrations')).json();
    expect(status.github).toMatchObject({ connected: true, login: 'octo-tok-alpha-123', deviceFlow: true });

    // Synced activities can't be deleted (they'd come straight back).
    expect((await p.call('DELETE', `/activities/${acts[0].id}`)).statusCode).toBe(400);
  });

  it('rejects a bad token', async () => {
    const p = await signUp();
    const res = await p.call('POST', '/integrations/github/token', { token: 'not-a-real-token' });
    expect(res.statusCode).toBe(400);
  });

  it('connects through the device flow', async () => {
    const p = await signUp();
    fake.contributions.set('tok-device-user', [{ date: daysAgo(0), contributionCount: 4 }]);
    const start = (await p.call('POST', '/integrations/github/device/start')).json();
    expect(start).toMatchObject({ userCode: 'ABCD-1234', deviceCode: 'dev-123' });

    fake.polls = 0;
    expect((await p.call('POST', '/integrations/github/device/poll', { deviceCode: 'dev-123' })).json()).toEqual({ status: 'pending' });
    const done = (await p.call('POST', '/integrations/github/device/poll', { deviceCode: 'dev-123' })).json();
    expect(done).toMatchObject({ status: 'connected', login: 'octo-tok-device-user', sync: { imported: 1 } });
  });

  it('advances a coding quest from synced contributions', async () => {
    const p = await signUp();
    await p.call('POST', '/quests', { title: 'Ship v1', category: 'CODING', rewardXp: 100, steps: [{ title: 'Code 30 min', targetMinutes: 30 }, { title: 'Boss' }] });
    fake.contributions.set('tok-quest-123', [{ date: daysAgo(0), contributionCount: 6 }]);
    const res = (await p.call('POST', '/integrations/github/token', { token: 'tok-quest-123' })).json();
    expect(res.sync.questsAdvanced).toEqual(['Ship v1']);
  });
});

describe('health', () => {
  const at = (minsAgo: number) => new Date(Date.now() - minsAgo * 60000).toISOString();

  it('imports workouts and mindfulness, ignores stale or bogus sessions, dedupes', async () => {
    const p = await signUp('Runner');
    const sessions = [
      { id: 'hc-1', kind: 'WORKOUT', title: 'Running', start: at(120), end: at(80) },
      { id: 'hc-2', kind: 'MINDFUL', title: 'Meditation', start: at(30), end: at(20) },
      { id: 'hc-old', kind: 'WORKOUT', title: 'Ancient hike', start: at(60 * 24 * 20), end: at(60 * 24 * 20 - 60) },
      { id: 'hc-neg', kind: 'WORKOUT', title: 'Backwards', start: at(10), end: at(20) },
    ];
    const res = await p.call('POST', '/integrations/health/import', { device: 'Pixel 9', sessions });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ imported: 2, xpGained: 40 * 3 + 10 * 2 });

    const again = (await p.call('POST', '/integrations/health/import', { sessions })).json();
    expect(again.imported).toBe(0);

    const me = (await p.call('GET', '/me')).json();
    expect(me.stats.find((s: { category: string }) => s.category === 'MINDFUL').xp).toBe(20);
    expect((await p.call('GET', '/integrations')).json().health).toMatchObject({ connected: true, login: 'Pixel 9' });
  });

  it("doesn't rewind a streak when importing older sessions", async () => {
    const p = await signUp();
    await p.call('POST', '/activities', { category: 'READING', title: 'today', minutes: 10 });
    const res = (
      await p.call('POST', '/integrations/health/import', {
        sessions: [{ id: 'y', kind: 'WORKOUT', title: 'Older run', start: at(60 * 24 * 3), end: at(60 * 24 * 3 - 30) }],
      })
    ).json();
    expect(res.imported).toBe(1);
    expect((await p.call('GET', '/me')).json().currentStreak).toBe(1);
  });
});

describe('cheers and weekly summary', () => {
  it('lets party members cheer each other but not themselves', async () => {
    const a = await signUp('A');
    const b = await signUp('B');
    const party = (await a.call('POST', '/party', { name: 'Cheer squad' })).json().party;
    await b.call('POST', '/party/join', { code: party.inviteCode });
    await a.call('POST', '/activities', { category: 'WORKOUT', title: 'Swim', minutes: 30 });

    const feed = (await b.call('GET', '/party/feed')).json();
    const swim = feed.find((e: { message: string }) => e.message.includes('Swim'));
    expect(swim).toMatchObject({ cheers: 0, cheeredByMe: false });

    expect((await b.call('POST', `/party/feed/${swim.id}/cheer`)).json()).toEqual({ cheered: true, cheers: 1 });
    expect((await a.call('POST', `/party/feed/${swim.id}/cheer`)).statusCode).toBe(400);
    expect((await b.call('GET', '/party/feed')).json().find((e: { id: string }) => e.id === swim.id)).toMatchObject({ cheers: 1, cheeredByMe: true });
    expect((await b.call('POST', `/party/feed/${swim.id}/cheer`)).json()).toEqual({ cheered: false, cheers: 0 });

    const outsider = await signUp('Outsider');
    expect((await outsider.call('POST', `/party/feed/${swim.id}/cheer`)).statusCode).toBe(404);
  });

  it('returns the last seven days of XP', async () => {
    const p = await signUp();
    await p.call('POST', '/activities', { category: 'CODING', title: 'x', minutes: 10 });
    const week = (await p.call('GET', '/me')).json().week;
    expect(week).toHaveLength(7);
    expect(week[6]).toEqual({ day: daysAgo(0), xp: 20 });
  });
});
