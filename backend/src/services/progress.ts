import type { Prisma, Category, EventType } from '@prisma/client';
import { activityXp, dayKey, levelForXp, nextStreak, STAT_NAMES } from '../game.js';
import { notFound, badRequest, forbidden } from '../errors.js';

type Tx = Prisma.TransactionClient;

async function partyIdOf(tx: Tx, userId: string): Promise<string | null> {
  const m = await tx.partyMember.findUnique({ where: { userId } });
  return m?.partyId ?? null;
}

async function emit(tx: Tx, userId: string, type: EventType, message: string, xp = 0) {
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
}

export async function logActivity(tx: Tx, userId: string, input: LogInput, now = new Date()) {
  const user = await tx.user.findUniqueOrThrow({ where: { id: userId } });
  const today = dayKey(now);
  const streak = nextStreak(user.lastActiveDay, today, user.currentStreak);
  const xp = activityXp(input.category, input.minutes, streak);

  await tx.user.update({
    where: { id: userId },
    data: { currentStreak: streak, longestStreak: Math.max(user.longestStreak, streak), lastActiveDay: today },
  });

  const activity = await tx.activity.create({
    data: { userId, category: input.category, title: input.title, minutes: input.minutes, note: input.note, xp, createdAt: now },
  });
  await emit(
    tx,
    userId,
    'ACTIVITY_LOGGED',
    `${user.displayName} logged ${input.minutes} min: ${input.title} (+${xp} ${STAT_NAMES[input.category]})`,
    xp,
  );
  await grantXp(tx, userId, input.category, xp);
  const quest = await autoAdvanceQuest(tx, userId, input.category, input.minutes, activity.id);

  // Compare before/after so a quest reward that crosses a level boundary is reported too.
  const { totalXp } = await tx.user.findUniqueOrThrow({ where: { id: userId }, select: { totalXp: true } });
  const newLevel = levelForXp(totalXp);
  const levelUp = newLevel > levelForXp(user.totalXp) ? newLevel : null;

  return { activity, xpGained: xp, streak, levelUp, quest };
}

/** Deletes an activity and takes its XP back. A quest step it completed is reopened if the quest is still active. */
export async function deleteActivity(tx: Tx, userId: string, activityId: string) {
  const activity = await tx.activity.findUnique({ where: { id: activityId }, include: { questStep: { include: { quest: true } } } });
  if (!activity) throw notFound('Activity');
  if (activity.userId !== userId) throw forbidden();

  const step = activity.questStep;
  if (step && step.quest.status === 'ACTIVE') {
    await tx.questStep.update({ where: { id: step.id }, data: { completedAt: null, completedById: null, activityId: null } });
  }
  await tx.activity.delete({ where: { id: activityId } });
  await grantXp(tx, userId, activity.category, -activity.xp);
}
