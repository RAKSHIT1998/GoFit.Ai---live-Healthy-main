import express from 'express';
import { GamificationPoints, Badge, Achievement, UserStreak } from '../models/Gamification.js';
import User from '../models/User.js';
import { authenticateToken } from '../middleware/authMiddleware.js';

const router = express.Router();

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

    res.json({
      badges: {
        total: badges.length,
        recent: badges.slice(0, 5),
        all: badges
      },
      achievements: {
        total: achievements.length,
        recent: achievements.slice(0, 5),
        all: achievements
      },
      streaks: {
        current: streak || null
      },
      points: pointsAgg.length > 0 ? pointsAgg[0].totalPoints : 0
    });
  } catch (error) {
    console.error('Get gamification stats error:', error);
    res.status(500).json({ message: 'Error fetching gamification stats' });
  }
});

/**
 * Get global leaderboard
 * GET /api/gamification/leaderboard
 */
router.get('/leaderboard', authenticateToken, async (req, res) => {
  try {
    const { limit = 50, type = 'points' } = req.query;
    const userId = req.user._id;

    // Aggregate points per user
    const leaderboard = await GamificationPoints.aggregate([
      { $group: { _id: '$userId', totalPoints: { $sum: '$points' } } },
      { $sort: { totalPoints: -1 } },
      { $limit: parseInt(limit) },
      {
        $lookup: {
          from: 'users',
          localField: '_id',
          foreignField: '_id',
          as: 'user'
        }
      },
      { $unwind: '$user' },
      {
        $project: {
          _id: 0,
          id: '$_id',
          name: '$user.name',
          profilePictureURL: '$user.profilePictureURL',
          totalPoints: 1,
          isMe: { $eq: ['$_id', userId] }
        }
      }
    ]);

    res.json({
      leaderboard: leaderboard.map((row, index) => ({
        ...row,
        rank: index + 1
      })),
      type
    });
  } catch (error) {
    console.error('Get leaderboard error:', error);
    res.status(500).json({ message: 'Error fetching leaderboard' });
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
      badges,
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
      achievements,
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
      current_streak: streak || null
    });
  } catch (error) {
    console.error('Get streaks error:', error);
    res.status(500).json({ message: 'Error fetching streaks' });
  }
});

export default router;
