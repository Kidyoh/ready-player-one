// Pure game rules: XP, levels, streaks and quest generation.
// Nothing in here touches the database so it can be unit-tested directly.

export const CATEGORIES = ['WORKOUT', 'READING', 'CODING', 'MINDFUL'] as const;
export type Category = (typeof CATEGORIES)[number];

export const STAT_NAMES: Record<Category, string> = {
  WORKOUT: 'Strength',
  READING: 'Intellect',
  CODING: 'Craft',
  MINDFUL: 'Spirit',
};

const XP_PER_MINUTE: Record<Category, number> = {
  WORKOUT: 3,
  READING: 2,
  CODING: 2,
  MINDFUL: 2,
};

/** Minutes beyond this in one log earn nothing, to keep a 10h entry from breaking the curve. */
export const MAX_COUNTED_MINUTES = 240;
export const MIN_ACTIVITY_XP = 5;
const MAX_STREAK_BONUS_DAYS = 5;

/** 1.0 on day one of a streak, +10% per consecutive day, capped at +50%. */
export function streakMultiplier(streak: number): number {
  const bonusDays = Math.min(Math.max(streak - 1, 0), MAX_STREAK_BONUS_DAYS);
  return 1 + bonusDays * 0.1;
}

export function activityXp(category: Category, minutes: number, streak: number): number {
  const counted = Math.min(Math.max(minutes, 0), MAX_COUNTED_MINUTES);
  const raw = counted * XP_PER_MINUTE[category] * streakMultiplier(streak);
  return Math.max(MIN_ACTIVITY_XP, Math.round(raw));
}

/** Total XP needed to reach `level`: 0, 100, 300, 600, 1000, ... */
export function xpForLevel(level: number): number {
  return 50 * level * (level - 1);
}

export function levelForXp(xp: number): number {
  let level = Math.floor((1 + Math.sqrt(1 + (0.08 * Math.max(xp, 0)))) / 2);
  // Guard against floating point drift at exact boundaries.
  while (xpForLevel(level + 1) <= xp) level++;
  while (level > 1 && xpForLevel(level) > xp) level--;
  return Math.max(level, 1);
}

export interface LevelProgress {
  level: number;
  xp: number;
  xpIntoLevel: number;
  xpForNextLevel: number;
}

export function levelProgress(xp: number): LevelProgress {
  const level = levelForXp(xp);
  const floor = xpForLevel(level);
  return {
    level,
    xp,
    xpIntoLevel: xp - floor,
    xpForNextLevel: xpForLevel(level + 1) - floor,
  };
}

const TITLES: Array<[number, string]> = [
  [1, 'Wanderer'],
  [3, 'Apprentice'],
  [6, 'Adventurer'],
  [10, 'Veteran'],
  [15, 'Champion'],
  [25, 'Legend'],
];

export function titleForLevel(level: number): string {
  let title = TITLES[0][1];
  for (const [min, name] of TITLES) if (level >= min) title = name;
  return title;
}

/** UTC calendar day as YYYY-MM-DD. */
export function dayKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function previousDay(day: string): string {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() - 1);
  return dayKey(d);
}

/** Streak after logging something on `today`, given the last active day. */
export function nextStreak(lastActiveDay: string | null, today: string, current: number): number {
  if (lastActiveDay === today) return Math.max(current, 1);
  if (lastActiveDay && previousDay(today) === lastActiveDay) return current + 1;
  return 1;
}

export interface GoalInput {
  goal: string;
  category: Category;
  weeks: number;
  sessionsPerWeek: number;
  minutesPerSession: number;
}

export interface GeneratedQuest {
  title: string;
  rewardXp: number;
  durationDays: number;
  steps: Array<{ title: string; targetMinutes: number }>;
}

const VERBS: Record<Category, string> = {
  WORKOUT: 'training',
  READING: 'reading',
  CODING: 'coding',
  MINDFUL: 'mindfulness',
};

/**
 * Turns a real goal into a quest line: one step per planned session, ending in a "boss" step
 * the player marks done themselves once the goal is actually met.
 */
export function generateQuest(input: GoalInput): GeneratedQuest {
  const steps: GeneratedQuest['steps'] = [];
  for (let week = 1; week <= input.weeks; week++) {
    for (let session = 1; session <= input.sessionsPerWeek; session++) {
      steps.push({
        title: `Week ${week} · ${input.minutesPerSession} min of ${VERBS[input.category]}`,
        targetMinutes: input.minutesPerSession,
      });
    }
  }
  steps.push({ title: `Boss: ${input.goal}`, targetMinutes: 0 });

  const plannedMinutes = input.weeks * input.sessionsPerWeek * input.minutesPerSession;
  return {
    title: input.goal,
    rewardXp: Math.round(plannedMinutes * 0.5) + 50 * input.weeks,
    durationDays: input.weeks * 7,
    steps,
  };
}
