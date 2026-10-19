import { describe, expect, it } from 'vitest';
import { activityXp, generateQuest, levelForXp, levelProgress, nextStreak, streakMultiplier, titleForLevel, xpForLevel } from '../src/game.js';

describe('levels', () => {
  it('follows the triangular curve', () => {
    expect([1, 2, 3, 4, 5].map(xpForLevel)).toEqual([0, 100, 300, 600, 1000]);
  });

  it('maps xp to level exactly at boundaries', () => {
    expect(levelForXp(0)).toBe(1);
    expect(levelForXp(99)).toBe(1);
    expect(levelForXp(100)).toBe(2);
    expect(levelForXp(299)).toBe(2);
    expect(levelForXp(300)).toBe(3);
    for (let l = 1; l < 200; l++) {
      expect(levelForXp(xpForLevel(l))).toBe(l);
      expect(levelForXp(xpForLevel(l + 1) - 1)).toBe(l);
    }
  });

  it('reports progress within the level', () => {
    expect(levelProgress(350)).toEqual({ level: 3, xp: 350, xpIntoLevel: 50, xpForNextLevel: 300 });
  });

  it('names levels', () => {
    expect(titleForLevel(1)).toBe('Wanderer');
    expect(titleForLevel(10)).toBe('Veteran');
    expect(titleForLevel(99)).toBe('Legend');
  });
});

describe('xp', () => {
  it('scales with minutes and category', () => {
    expect(activityXp('READING', 30, 1)).toBe(60);
    expect(activityXp('WORKOUT', 30, 1)).toBe(90);
  });

  it('applies a capped streak bonus', () => {
    expect(streakMultiplier(1)).toBe(1);
    expect(streakMultiplier(3)).toBeCloseTo(1.2);
    expect(streakMultiplier(50)).toBeCloseTo(1.5);
    expect(activityXp('READING', 30, 6)).toBe(90);
  });

  it('caps counted minutes and has a floor', () => {
    expect(activityXp('CODING', 1000, 1)).toBe(activityXp('CODING', 240, 1));
    expect(activityXp('CODING', 1, 1)).toBe(5);
  });
});

describe('streaks', () => {
  it('starts, continues, holds and resets', () => {
    expect(nextStreak(null, '2026-10-19', 0)).toBe(1);
    expect(nextStreak('2026-10-18', '2026-10-19', 4)).toBe(5);
    expect(nextStreak('2026-10-19', '2026-10-19', 4)).toBe(4);
    expect(nextStreak('2026-10-16', '2026-10-19', 4)).toBe(1);
  });

  it('handles month and year boundaries', () => {
    expect(nextStreak('2026-02-28', '2026-03-01', 2)).toBe(3);
    expect(nextStreak('2025-12-31', '2026-01-01', 2)).toBe(3);
  });
});

describe('quest generation', () => {
  it('creates one step per session plus a boss step', () => {
    const q = generateQuest({ goal: 'Run a 5k', category: 'WORKOUT', weeks: 2, sessionsPerWeek: 3, minutesPerSession: 30 });
    expect(q.steps).toHaveLength(7);
    expect(q.steps[0]).toEqual({ title: 'Week 1 · 30 min of training', targetMinutes: 30 });
    expect(q.steps.at(-1)).toEqual({ title: 'Boss: Run a 5k', targetMinutes: 0 });
    expect(q.rewardXp).toBe(90 + 100);
    expect(q.durationDays).toBe(14);
  });
});
