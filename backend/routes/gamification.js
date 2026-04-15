import express from 'express';
import mongoose from 'mongoose';
import { GamificationPoints, Badge, Achievement, UserStreak } from '../models/Gamification.js';
import Friend from '../models/Friend.js';
import User from '../models/User.js';
import { authenticateToken } from '../middleware/authMiddleware.js';
import { getUserSocialStats } from '../utils/socialStats.js';

const router = express.Router();

function toISOStringOrNil(value) {
  return value ? new Date(value).toISOString() : null;
}

function serializeBadge(badge, index) {
  return {
    id: index + 1,
    name: badge.name,
    description: badge.description ?? null,
    icon_url: badge.icon ?? null,
    earned: true,
    earned_at: toISOStringOrNil(badge.earnedAt)
  };
}

function serializeAchievement(achievement, index) {
  return {
    id: index + 1,
    title: achievement.name,
    description: achievement.description ?? null,
    icon_url: null,
    earned: true,
    earned_at: toISOStringOrNil(achievement.earnedAt),
    progress: achievement.points ?? null
  };
}

function serializeStreak(streak, index) {
  return {
    id: index + 1,
    userId: 1,
    streak_type: streak.streakType,
    current_streak: streak.currentDays,
    best_streak: streak.longestDays,
    last_updated: toISOStringOrNil(streak.lastActiveDate ?? streak.updatedAt ?? streak.createdAt),
    is_active: Boolean(streak.lastActiveDate)
  };
}

async function getFriendScopedUserIds(userId) {
  const friendships = await Friend.find({
    $or: [
      { userId, status: 'accepted' },
      { friendId: userId, status: 'accepted' }
    ]
  }).lean();

  const userIds = new Set([userId.toString()]);
  friendships.forEach(friendship => {
    const friendUserId =
      friendship.userId.toString() === userId.toString()
        ? friendship.friendId.toString()
        : friendship.userId.toString();
    userIds.add(friendUserId);
  });

  return Array.from(userIds);
}

function getScopeStartDate(scope) {
  const now = new Date();

  if (scope === 'monthly') {
    return new Date(now.getFullYear(), now.getMonth(), 1);
  }

  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

/**
 * Get user's gamification stats (badges, achievements, streaks)
 * GET /api/gamification/stats
 */
router.get('/stats', authenticateToken, async (req, res) => {
  try {
    const userId = req.user._id;

    const [badges, achievements, streak, pointsAgg] = await Promise.all([
      Badge.find({ userId }).sort({ earnedAt: -1 }),
      Achievement.find({ userId }).sort({ earnedAt: -1 }),
      UserStreak.findOne({ userId }).sort({ createdAt: -1 }),
      GamificationPoints.aggregate([
        { $match: { userId } },
        { $group: { _id: null, totalPoints: { $sum: '$points' } } }
      ])
    ]);

    const serializedBadges = badges.map(serializeBadge);
    const serializedAchievements = achievements.map(serializeAchievement);
    const serializedStreaks = streak ? [serializeStreak(streak, 0)] : [];
    const totalPoints = pointsAgg.length > 0 ? pointsAgg[0].totalPoints : 0;

    res.json({
      stats: {
        total_points: totalPoints,
        action_count: badges.length + achievements.length + serializedStreaks.length,
        rank: null,
        badges: {
          earned: serializedBadges.length,
          details: serializedBadges
        },
        achievements: {
          earned: serializedAchievements.length,
          details: serializedAchievements
        },
        streaks: {
          active: serializedStreaks.filter(item => item.is_active).length,
          details: serializedStreaks
        }
      }
    });
  } catch (error) {
    console.error('Get gamification stats error:', error);
    res.status(500).json({ message: 'Error fetching gamification stats' });
  }
});

/**
 * Get leaderboard (friends or global)
 * GET /api/gamification/leaderboard?scope=daily|monthly&type=friends|global
 */
router.get('/leaderboard', authenticateToken, async (req, res) => {
  try {
    const { limit = 50, offset = 0, scope = 'daily', type = 'friends' } = req.query;
    const userId = req.user._id;
    const safeLimit = parseInt(limit, 10) || 50;
    const safeOffset = parseInt(offset, 10) || 0;
    const safeScope = scope === 'monthly' ? 'monthly' : 'daily';

    // For friends board: include only the user + accepted friends
    // For global board: include everyone
    let userIdFilter;
    if (type === 'global') {
      userIdFilter = null; // No userId filter — all users
    } else {
      const scopedUserIds = await getFriendScopedUserIds(userId);
      userIdFilter = scopedUserIds.map(id => new mongoose.Types.ObjectId(id));
    }

    const startDate = getScopeStartDate(safeScope);

    let leaderboard;

    if (type === 'global') {
      const rankedUsers = await GamificationPoints.aggregate([
        {
          $match: {
            createdAt: { $gte: startDate }
          }
        },
        { $group: { _id: '$userId', totalPoints: { $sum: '$points' } } },
        { $sort: { totalPoints: -1 } },
        { $skip: safeOffset },
        { $limit: safeLimit },
        {
          $lookup: {
            from: 'users',
            localField: '_id',
            foreignField: '_id',
            as: 'user'
          }
        },
        { $unwind: '$user' }
      ]);

      const enriched = await Promise.all(
        rankedUsers.map(async (row) => {
          const stats = await getUserSocialStats(row._id, { startDate });
          return {
            username: row.user.name,
            email: row.user.email,
            profile_picture: row.user.profilePictureURL,
            totalPoints: row.totalPoints,
            badgeCount: 0,
            achievementCount: 0,
            isCurrentUser: row._id.toString() === userId.toString(),
            totalWorkoutsCompleted: stats.totalWorkoutsCompleted,
            totalMealsLogged: stats.totalMealsLogged,
            totalCaloriesBurned: stats.totalCaloriesBurned
          };
        })
      );

      leaderboard = enriched;
    } else {
      const scopedUsers = await User.find({
        _id: { $in: userIdFilter }
      }).select('name email profilePictureURL');

      const enriched = await Promise.all(
        scopedUsers.map(async (userDoc) => {
          const stats = await getUserSocialStats(userDoc._id, { startDate });
          return {
            username: userDoc.name,
            email: userDoc.email,
            profile_picture: userDoc.profilePictureURL,
            totalPoints: stats.totalPoints,
            badgeCount: 0,
            achievementCount: 0,
            isCurrentUser: userDoc._id.toString() === userId.toString(),
            totalWorkoutsCompleted: stats.totalWorkoutsCompleted,
            totalMealsLogged: stats.totalMealsLogged,
            totalCaloriesBurned: stats.totalCaloriesBurned
          };
        })
      );

      leaderboard = enriched
        .sort((a, b) => {
          if (b.totalPoints !== a.totalPoints) return b.totalPoints - a.totalPoints;
          if (b.totalCaloriesBurned !== a.totalCaloriesBurned) return b.totalCaloriesBurned - a.totalCaloriesBurned;
          if (b.totalWorkoutsCompleted !== a.totalWorkoutsCompleted) return b.totalWorkoutsCompleted - a.totalWorkoutsCompleted;
          return a.username.localeCompare(b.username);
        })
        .slice(safeOffset, safeOffset + safeLimit);
    }

    res.json({
      leaderboard: leaderboard.map((row, index) => ({
        id: safeOffset + index + 1,
        username: row.username,
        email: row.email ?? null,
        profile_picture: row.profile_picture ?? null,
        total_points: row.totalPoints,
        badge_count: row.badgeCount,
        achievement_count: row.achievementCount,
        total_workouts_completed: row.totalWorkoutsCompleted ?? 0,
        total_meals_logged: row.totalMealsLogged ?? 0,
        total_calories_burned: row.totalCaloriesBurned ?? 0,
        rank: safeOffset + index + 1,
        is_current_user: row.isCurrentUser
      })),
      count: leaderboard.length,
      scope: safeScope,
      type: type === 'global' ? 'global' : 'friends'
    });
  } catch (error) {
    console.error('Get leaderboard error:', error);
    res.status(500).json({ message: 'Error fetching leaderboard' });
  }
});

/**
 * Record XP event for leaderboard updates
 * POST /api/gamification/events
 */
router.post('/events', authenticateToken, async (req, res) => {
  try {
    const { actionType, points } = req.body;
    const safePoints = Number(points);

    if (!actionType || !Number.isFinite(safePoints) || safePoints <= 0) {
      return res.status(400).json({ message: 'Valid actionType and positive points are required' });
    }

    const event = await GamificationPoints.create({
      userId: req.user._id,
      actionType,
      points: safePoints
    });

    const totals = await GamificationPoints.aggregate([
      { $match: { userId: req.user._id } },
      { $group: { _id: null, totalPoints: { $sum: '$points' } } }
    ]);

    res.status(201).json({
      message: 'Gamification event recorded',
      eventId: event._id.toString(),
      total_points: totals[0]?.totalPoints || safePoints
    });
  } catch (error) {
    console.error('Record gamification event error:', error);
    res.status(500).json({ message: 'Error recording gamification event' });
  }
});

/**
 * Get user's badges
 * GET /api/gamification/badges
 */
router.get('/badges', authenticateToken, async (req, res) => {
  try {
    const userId = req.user._id;

    const badges = await Badge.find({ userId }).sort({ earnedAt: -1 });

    res.json({
      badges: badges.map(serializeBadge),
      count: badges.length
    });
  } catch (error) {
    console.error('Get badges error:', error);
    res.status(500).json({ message: 'Error fetching badges' });
  }
});

/**
 * Get user's achievements
 * GET /api/gamification/achievements
 */
router.get('/achievements', authenticateToken, async (req, res) => {
  try {
    const userId = req.user._id;

    const achievements = await Achievement.find({ userId }).sort({ earnedAt: -1 });

    res.json({
      achievements: achievements.map(serializeAchievement),
      count: achievements.length
    });
  } catch (error) {
    console.error('Get achievements error:', error);
    res.status(500).json({ message: 'Error fetching achievements' });
  }
});

/**
 * Get user's streaks
 * GET /api/gamification/streaks
 */
router.get('/streaks', authenticateToken, async (req, res) => {
  try {
    const userId = req.user._id;

    const streak = await UserStreak.findOne({ userId }).sort({ createdAt: -1 });

    res.json({
      streaks: streak ? [serializeStreak(streak, 0)] : []
    });
  } catch (error) {
    console.error('Get streaks error:', error);
    res.status(500).json({ message: 'Error fetching streaks' });
  }
});

export default router;
