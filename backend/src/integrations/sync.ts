import type { Category, Prisma } from '@prisma/client';
import { prisma } from '../db.js';
import { emit, growActivity, logActivity } from '../services/progress.js';
import { type GitHubClient, minutesForContributions } from './github.js';
import type { TokenBox } from '../crypto.js';
import { badRequest } from '../errors.js';

/** On first connect we pull a week of history so the player gets an immediate payoff, but no more. */
export const BACKFILL_DAYS = 7;
const DAY_MS = 24 * 60 * 60 * 1000;

export interface SyncSummary {
  imported: number;
  updated: number;
  xpGained: number;
  levelUp: number | null;
  questsAdvanced: string[];
}

function emptySummary(): SyncSummary {
  return { imported: 0, updated: 0, xpGained: 0, levelUp: null, questsAdvanced: [] };
}

type Tx = Prisma.TransactionClient;

async function importOne(
  tx: Tx,
  userId: string,
  summary: SyncSummary,
  item: { source: 'GITHUB' | 'HEALTH'; externalId: string; category: Category; title: string; minutes: number; at: Date },
) {
  const existing = await tx.activity.findUnique({
    where: { userId_source_externalId: { userId, source: item.source, externalId: item.externalId } },
  });
  if (existing) {
    const delta = await growActivity(tx, userId, existing.id, item.minutes);
    if (delta > 0) {
      summary.updated++;
      summary.xpGained += delta;
    }
    return;
  }
  const result = await logActivity(tx, userId, { ...item, quiet: true }, item.at);
  summary.imported++;
  summary.xpGained += result.xpGained;
  if (result.levelUp) summary.levelUp = Math.max(summary.levelUp ?? 0, result.levelUp);
  if (result.quest) summary.questsAdvanced.push(result.quest.questTitle);
}

/** One feed line per sync, however many days or sessions it brought in. */
async function announce(tx: Tx, userId: string, summary: SyncSummary, from: string) {
  if (summary.xpGained <= 0) return;
  const { displayName } = await tx.user.findUniqueOrThrow({ where: { id: userId }, select: { displayName: true } });
  const what = summary.imported > 0 ? `${summary.imported} new ${summary.imported === 1 ? 'entry' : 'entries'}` : 'updates';
  await emit(tx, userId, 'ACTIVITY_LOGGED', `${displayName} synced ${what} from ${from} (+${summary.xpGained} XP)`, summary.xpGained);
}

/** Earliest instant we import from: a week before connecting, or a couple of days before the last sync. */
function windowStart(connectedAt: Date, lastSyncedAt: Date | null, now: Date): Date {
  const backfill = connectedAt.getTime() - BACKFILL_DAYS * DAY_MS;
  // Re-scan two days so contributions that land late (timezones, delayed pushes) still count.
  const resume = lastSyncedAt ? lastSyncedAt.getTime() - 2 * DAY_MS : backfill;
  return new Date(Math.max(backfill, resume, now.getTime() - 30 * DAY_MS));
}

export async function syncGitHub(userId: string, github: GitHubClient, box: TokenBox, now = new Date()): Promise<SyncSummary> {
  const integration = await prisma.integration.findUnique({ where: { userId_provider: { userId, provider: 'GITHUB' } } });
  if (!integration?.accessTokenEnc) throw badRequest('GitHub is not connected');

  const from = windowStart(integration.connectedAt, integration.lastSyncedAt, now);
  const days = await github.contributions(box.open(integration.accessTokenEnc), from, now);
  const fromDay = from.toISOString().slice(0, 10);

  const summary = emptySummary();
  await prisma.$transaction(async (tx) => {
    for (const day of days.filter((d) => d.count > 0 && d.date >= fromDay).sort((a, b) => a.date.localeCompare(b.date))) {
      await importOne(tx, userId, summary, {
        source: 'GITHUB',
        externalId: day.date,
        category: 'CODING',
        title: `${day.count} GitHub contribution${day.count === 1 ? '' : 's'}`,
        minutes: minutesForContributions(day.count),
        at: new Date(`${day.date}T12:00:00Z`),
      });
    }
    await tx.integration.update({
      where: { userId_provider: { userId, provider: 'GITHUB' } },
      data: { lastSyncedAt: now },
    });
    await announce(tx, userId, summary, 'GitHub');
  });
  return summary;
}

export interface HealthSession {
  id: string;
  kind: 'WORKOUT' | 'MINDFUL';
  title: string;
  start: Date;
  end: Date;
}

/** Imports exercise and mindfulness sessions the phone read from Health Connect / Apple Health. */
export async function importHealth(userId: string, sessions: HealthSession[], device: string | undefined, now = new Date()) {
  const integration = await prisma.integration.upsert({
    where: { userId_provider: { userId, provider: 'HEALTH' } },
    create: { userId, provider: 'HEALTH', externalLogin: device },
    update: device ? { externalLogin: device } : {},
  });
  const earliest = Math.max(integration.connectedAt.getTime() - BACKFILL_DAYS * DAY_MS, now.getTime() - 30 * DAY_MS);

  const summary = emptySummary();
  const usable = sessions
    .filter((s) => s.start.getTime() >= earliest && s.end.getTime() <= now.getTime() + 5 * 60 * 1000 && s.end > s.start)
    .sort((a, b) => a.start.getTime() - b.start.getTime());

  await prisma.$transaction(async (tx) => {
    for (const s of usable) {
      const minutes = Math.round((s.end.getTime() - s.start.getTime()) / 60000);
      if (minutes < 1) continue;
      await importOne(tx, userId, summary, {
        source: 'HEALTH',
        externalId: s.id,
        category: s.kind === 'MINDFUL' ? 'MINDFUL' : 'WORKOUT',
        title: s.title,
        minutes: Math.min(minutes, 24 * 60),
        at: s.start,
      });
    }
    await tx.integration.update({ where: { userId_provider: { userId, provider: 'HEALTH' } }, data: { lastSyncedAt: now } });
    await announce(tx, userId, summary, device ?? 'Health');
  });
  return summary;
}
