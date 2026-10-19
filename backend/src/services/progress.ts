import type { Prisma, Category, EventType, ActivitySource } from '@prisma/client';
import { activityXp, dayKey, levelForXp, nextStreak, STAT_NAMES } from '../game.js';
import { notFound, badRequest, forbidden } from '../errors.js';

type Tx = Prisma.TransactionClient;

async function partyIdOf(tx: Tx, userId: string): Promise<string | null> {
  const m = await tx.partyMember.findUnique({ where: { userId } });
  return m?.partyId ?? null;
}

export async function emit(tx: Tx, userId: string, type: EventType, message: string, xp = 0) {
  const partyId = await partyIdOf(tx, userId);
  await tx.event.create({ data: { userId, partyId, type, message, xp } });
}

/**
 * Adds (or with a negative amount, removes) XP from a user's stat and total.
 * Emits a LEVEL_UP event when the overall level goes up. Returns the new level if it changed.
 */
export async function grantXp(tx: Tx, userId: string, category: Category, amount: number) {
  const before = await tx.user.findUniqueOrThrow({ where: { id: userId }, select: { totalXp: true, displayName: true } });
  await tx.skill.upsert({
    where: { userId_category: { userId, category } },
    create: { userId, category, xp: Math.max(amount, 0) },
    update: { xp: { increment: amount } },
  });
  const after = await tx.user.update({
    where: { id: userId },
    data: { totalXp: Math.max(before.totalXp + amount, 0) },
    select: { totalXp: true },
  });
  const oldLevel = levelForXp(before.totalXp);
  const newLevel = levelForXp(after.totalXp);
  if (newLevel > oldLevel) {
    await emit(tx, userId, 'LEVEL_UP', `${before.displayName} reached level ${newLevel}!`);
    return newLevel;
  }
  return null;
}

/** Quests a user can progress: their own, plus their party's shared quests. */
async function visibleQuestFilter(tx: Tx, userId: string): Promise<Prisma.QuestWhereInput> {
  const partyId = await partyIdOf(tx, userId);
  return partyId ? { OR: [{ ownerId: userId }, { partyId }] } : { ownerId: userId };
}

export async function assertCanAccessQuest(tx: Tx, userId: string, questId: string) {
  const quest = await tx.quest.findFirst({
    where: { AND: [{ id: questId }, await visibleQuestFilter(tx, userId)] },
  });
  if (!quest) throw notFound('Quest');
  return quest;
}

export interface StepResult {
  questId: string;
  questTitle: string;
  stepTitle: string;
  questCompleted: boolean;
  rewardXp: number;
}

/** Marks a step done and, if it was the last one, completes the quest and pays out the reward. */
export async function completeStep(
  tx: Tx,
  userId: string,
  stepId: string,
  activityId: string | null,
): Promise<StepResult> {
  const step = await tx.questStep.findUnique({ where: { id: stepId }, include: { quest: true } });
  if (!step) throw notFound('Step');
  const quest = await assertCanAccessQuest(tx, userId, step.questId);
  if (quest.status !== 'ACTIVE') throw badRequest('Quest is not active');
  if (step.completedAt) throw badRequest('Step already completed');

  await tx.questStep.update({
    where: { id: stepId },
    data: { completedAt: new Date(), completedById: userId, activityId },
  });
  await emit(tx, userId, 'QUEST_STEP_DONE', `Cleared "${step.title}" in ${quest.title}`);

  const remaining = await tx.questStep.count({ where: { questId: quest.id, completedAt: null } });
  if (remaining > 0) {
    return { questId: quest.id, questTitle: quest.title, stepTitle: step.title, questCompleted: false, rewardXp: 0 };
  }

  await tx.quest.update({ where: { id: quest.id }, data: { status: 'COMPLETED', completedAt: new Date() } });
  // Party quests reward everyone currently in the party; solo quests reward the owner.
  const recipients = quest.partyId
    ? (await tx.partyMember.findMany({ where: { partyId: quest.partyId } })).map((m) => m.userId)
    : [quest.ownerId];
  for (const id of recipients) {
    await grantXp(tx, id, quest.category, quest.rewardXp);
  }
  await emit(tx, userId, 'QUEST_COMPLETED', `Quest complete: ${quest.title}`, quest.rewardXp);
  return { questId: quest.id, questTitle: quest.title, stepTitle: step.title, questCompleted: true, rewardXp: quest.rewardXp };
}

/**
 * Finds the oldest active quest of this category whose next open step this activity satisfies.
 * Boss steps (targetMinutes 0) are never auto-completed.
 */
async function autoAdvanceQuest(tx: Tx, userId: string, category: Category, minutes: number, activityId: string) {
  const quests = await tx.quest.findMany({
    where: { AND: [await visibleQuestFilter(tx, userId), { status: 'ACTIVE', category }] },
    orderBy: { createdAt: 'asc' },
    include: { steps: { where: { completedAt: null }, orderBy: { position: 'asc' }, take: 1 } },
  });
  for (const q of quests) {
    const next = q.steps[0];
    if (next && next.targetMinutes > 0 && minutes >= next.targetMinutes) {
      return completeStep(tx, userId, next.id, activityId);
    }
  }
  return null;
}

export interface LogInput {
  category: Category;
  title: string;
  minutes: number;
  note?: string;
  /** Set for synced activities; (source, externalId) is unique per user. */
  source?: ActivitySource;
  externalId?: string;
  /** Skip the per-activity feed event; syncs post one summary instead of flooding the party feed. */
  quiet?: boolean;
}

export async function logActivity(tx: Tx, userId: string, input: LogInput, at = new Date()) {
  const user = await tx.user.findUniqueOrThrow({ where: { id: userId } });
  const day = dayKey(at);

  // Synced activities can be back-dated. Only a day on or after the last active day moves the streak,
  // so importing last week's workouts never rewinds it.
  const advancesStreak = !user.lastActiveDay || day >= user.lastActiveDay;
  const streak = advancesStreak ? nextStreak(user.lastActiveDay, day, user.currentStreak) : 1;
  const xp = activityXp(input.category, input.minutes, streak);
  if (advancesStreak) {
    await tx.user.update({
      where: { id: userId },
      data: { currentStreak: streak, longestStreak: Math.max(user.longestStreak, streak), lastActiveDay: day },
    });
  }

  const activity = await tx.activity.create({
    data: {
      userId,
      category: input.category,
      title: input.title,
      minutes: input.minutes,
      note: input.note,
      xp,
      source: input.source,
      externalId: input.externalId,
      createdAt: at,
    },
  });
  if (!input.quiet) {
    await emit(
      tx,
      userId,
      'ACTIVITY_LOGGED',
      `${user.displayName} logged ${input.minutes} min: ${input.title} (+${xp} ${STAT_NAMES[input.category]})`,
      xp,
    );
  }
  await grantXp(tx, userId, input.category, xp);
  const quest = await autoAdvanceQuest(tx, userId, input.category, input.minutes, activity.id);

  // Compare before/after so a quest reward that crosses a level boundary is reported too.
  const { totalXp } = await tx.user.findUniqueOrThrow({ where: { id: userId }, select: { totalXp: true } });
  const newLevel = levelForXp(totalXp);
  const levelUp = newLevel > levelForXp(user.totalXp) ? newLevel : null;

  return { activity, xpGained: xp, streak: advancesStreak ? streak : user.currentStreak, levelUp, quest };
}

/**
 * Grows an already-synced activity (e.g. more commits landed on the same day) and pays the XP difference.
 * Never shrinks one, so a flaky upstream response can't take XP away.
 */
export async function growActivity(tx: Tx, userId: string, activityId: string, minutes: number) {
  const activity = await tx.activity.findUniqueOrThrow({ where: { id: activityId } });
  if (minutes <= activity.minutes) return 0;
  const xp = Math.max(activity.xp, activityXp(activity.category, minutes, 1));
  const delta = xp - activity.xp;
  await tx.activity.update({ where: { id: activityId }, data: { minutes, xp } });
  if (delta > 0) await grantXp(tx, userId, activity.category, delta);
  return delta;
}

/** Deletes an activity and takes its XP back. A quest step it completed is reopened if the quest is still active. */
export async function deleteActivity(tx: Tx, userId: string, activityId: string) {
  const activity = await tx.activity.findUnique({ where: { id: activityId }, include: { questStep: { include: { quest: true } } } });
  if (!activity) throw notFound('Activity');
  if (activity.userId !== userId) throw forbidden();
  // A synced entry would just come back on the next sync; disconnecting is the way to stop it.
  if (activity.source !== 'MANUAL') throw badRequest('Synced activities are managed by their integration');

  const step = activity.questStep;
  if (step && step.quest.status === 'ACTIVE') {
    await tx.questStep.update({ where: { id: step.id }, data: { completedAt: null, completedById: null, activityId: null } });
  }
  await tx.activity.delete({ where: { id: activityId } });
  await grantXp(tx, userId, activity.category, -activity.xp);
}
