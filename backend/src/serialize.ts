import type { Skill, User } from '@prisma/client';
import { CATEGORIES, levelProgress, STAT_NAMES, titleForLevel } from './game.js';

/** Public view of a player, safe to show to party members. */
export function publicPlayer(user: Pick<User, 'id' | 'displayName' | 'avatar' | 'totalXp' | 'currentStreak'>) {
  const progress = levelProgress(user.totalXp);
  return {
    id: user.id,
    displayName: user.displayName,
    avatar: user.avatar,
    level: progress.level,
    title: titleForLevel(progress.level),
    totalXp: user.totalXp,
    currentStreak: user.currentStreak,
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
