import type { Skill, User } from '@prisma/client';
import { CATEGORIES, dayKey, levelProgress, STAT_NAMES, titleForLevel } from './game.js';

/** The stored streak only updates when something is logged, so a lapsed one still reads high until then. */
export function liveStreak(user: Pick<User, 'currentStreak' | 'lastActiveDay'>, now = new Date()): number {
  if (!user.lastActiveDay) return 0;
  const yesterday = new Date(now);
  yesterday.setUTCDate(yesterday.getUTCDate() - 1);
  return user.lastActiveDay >= dayKey(yesterday) ? user.currentStreak : 0;
}

/** Public view of a player, safe to show to party members. */
export function publicPlayer(user: Pick<User, 'id' | 'displayName' | 'avatar' | 'totalXp' | 'currentStreak' | 'lastActiveDay'>) {
  const progress = levelProgress(user.totalXp);
  return {
    id: user.id,
    displayName: user.displayName,
    avatar: user.avatar,
    level: progress.level,
    title: titleForLevel(progress.level),
    totalXp: user.totalXp,
    currentStreak: liveStreak(user),
  };
}

/** Full character sheet for the signed-in player. */
export function characterSheet(user: User, skills: Skill[]) {
  const byCategory = new Map(skills.map((s) => [s.category, s.xp]));
  return {
    ...publicPlayer(user),
    email: user.email,
    longestStreak: user.longestStreak,
    progress: levelProgress(user.totalXp),
    stats: CATEGORIES.map((category) => {
      const xp = byCategory.get(category) ?? 0;
      return { category, name: STAT_NAMES[category], ...levelProgress(xp) };
    }),
  };
}
