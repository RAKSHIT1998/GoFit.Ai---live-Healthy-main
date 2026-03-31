import express from 'express';
import ActivityLog from '../models/ActivityLog.js';
import Meal from '../models/Meal.js';
import Workout from '../models/Workout.js';
import WeightLog from '../models/WeightLog.js';
import Friend from '../models/Friend.js';
import { GamificationPoints } from '../models/Gamification.js';
import { authenticateToken } from '../middleware/authMiddleware.js';

const router = express.Router();

function isoString(value) {
  return value ? new Date(value).toISOString() : new Date().toISOString();
}

function buildActivityDescription(log) {
  const metadata = log.metadata || {};

  switch (log.type) {
    case 'meal':
      if (metadata.calories) {
        return `${Math.round(metadata.calories)} kcal meal logged`;
      }
      return 'Meal shared with friends';
    case 'workout':
      if (metadata.duration) {
        return `${Math.round(metadata.duration)} min workout completed`;
      }
      return 'Workout shared with friends';
    case 'weight':
      if (metadata.weightKg) {
        return `Weight update: ${Number(metadata.weightKg).toFixed(1)} kg`;
      }
      return 'Weight update shared';
    case 'water':
      if (metadata.amountLiters) {
        return `Hydration update: ${Number(metadata.amountLiters).toFixed(1)} L`;
      }
      return 'Hydration update shared';
    default:
      return metadata.summary || null;
  }
}

function serializeSharedActivityLog(log) {
  const user = log.userId && typeof log.userId === 'object' ? log.userId : null;
  const sharedWith = Array.isArray(log.sharedWith)
    ? log.sharedWith.map(id => id?.toString()).filter(Boolean)
    : [];

  return {
    id: log._id.toString(),
    userId: user?._id?.toString?.() || log.userId?.toString?.() || '',
    username: user?.name || null,
    type: log.type,
    title: log.title || null,
    description: buildActivityDescription(log),
    visibility: log.visibility,
    shared_with: sharedWith,
    created_at: isoString(log.createdAt),
    updated_at: log.updatedAt ? isoString(log.updatedAt) : null
  };
}

function serializeActivityFeedItem(log, currentUserId) {
  const activity = serializeSharedActivityLog(log);
  const isOwnActivity = activity.userId === currentUserId.toString();

  return {
    id: activity.id,
    activity,
    friendUsername: activity.username || (isOwnActivity ? 'You' : 'Friend'),
    timestamp: activity.created_at,
    isOwnActivity,
    total_likes: 0,
    total_comments: 0,
    is_liked: false
  };
}

/**
 * Share a meal log with friends
 * POST /api/logs/meal/share
 */
router.post('/meal/share', authenticateToken, async (req, res) => {
  try {
    const { mealId, visibility, sharedWith } = req.body;
    const userId = req.user._id;

    if (!mealId || !visibility) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    const validVisibility = ['private', 'friends_only', 'public'];
    if (!validVisibility.includes(visibility)) {
      return res.status(400).json({ message: 'Invalid visibility setting' });
    }

    // Verify meal belongs to user
    const meal = await Meal.findOne({ _id: mealId, userId });
    if (!meal) {
      return res.status(404).json({ message: 'Meal not found' });
    }

    const createdLog = await ActivityLog.create({
      userId,
      type: 'meal',
      title: meal.mealName || meal.mealType || 'Meal',
      referenceId: mealId,
      visibility,
      sharedWith: sharedWith || [],
      metadata: {
        calories: meal.totalCalories || 0,
        protein: meal.totalProtein || 0,
        carbs: meal.totalCarbs || 0,
        fats: meal.totalFat || 0
      }
    });

    // Award points for sharing
    await GamificationPoints.create({
      userId,
      actionType: 'share_log',
      points: 10
    });

    const log = await ActivityLog.findById(createdLog._id)
      .populate('userId', 'name profilePictureURL');

    res.json({
      message: 'Meal shared successfully',
      log: serializeSharedActivityLog(log)
    });
  } catch (error) {
    console.error('Share meal error:', error);
    res.status(500).json({ message: 'Error sharing meal' });
  }
});

/**
 * Share a workout log with friends
 * POST /api/logs/workout/share
 */
router.post('/workout/share', authenticateToken, async (req, res) => {
  try {
    const { workoutId, visibility, sharedWith } = req.body;
    const userId = req.user._id;

    if (!workoutId || !visibility) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    const validVisibility = ['private', 'friends_only', 'public'];
    if (!validVisibility.includes(visibility)) {
      return res.status(400).json({ message: 'Invalid visibility setting' });
    }

    // Verify workout belongs to user
    const workout = await Workout.findOne({ _id: workoutId, userId });
    if (!workout) {
      return res.status(404).json({ message: 'Workout not found' });
    }

    const createdLog = await ActivityLog.create({
      userId,
      type: 'workout',
      title: workout.exerciseName || workout.name || 'Workout',
      referenceId: workoutId,
      visibility,
      sharedWith: sharedWith || [],
      metadata: {
        duration: workout.duration,
        caloriesBurned: workout.caloriesBurned,
        intensity: workout.intensity
      }
    });

    // Award points for sharing
    await GamificationPoints.create({
      userId,
      actionType: 'share_log',
      points: 10
    });

    const log = await ActivityLog.findById(createdLog._id)
      .populate('userId', 'name profilePictureURL');

    res.json({
      message: 'Workout shared successfully',
      log: serializeSharedActivityLog(log)
    });
  } catch (error) {
    console.error('Share workout error:', error);
    res.status(500).json({ message: 'Error sharing workout' });
  }
});

/**
 * Share a weight log with friends
 * POST /api/logs/weight/share
 */
router.post('/weight/share', authenticateToken, async (req, res) => {
  try {
    const { weightLogId, visibility, sharedWith } = req.body;
    const userId = req.user._id;

    if (!weightLogId || !visibility) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    const validVisibility = ['private', 'friends_only', 'public'];
    if (!validVisibility.includes(visibility)) {
      return res.status(400).json({ message: 'Invalid visibility setting' });
    }

    const weightLog = await WeightLog.findOne({ _id: weightLogId, userId });
    if (!weightLog) {
      return res.status(404).json({ message: 'Weight log not found' });
    }

    const createdLog = await ActivityLog.create({
      userId,
      type: 'weight',
      title: 'Weight Check-In',
      referenceId: weightLogId,
      visibility,
      sharedWith: sharedWith || [],
      metadata: {
        weightKg: weightLog.weightKg,
        summary: weightLog.notes || 'Weight update shared',
        note: weightLog.notes || null,
        loggedAt: weightLog.timestamp
      }
    });

    await GamificationPoints.create({
      userId,
      actionType: 'log_weight',
      points: 12
    });

    await GamificationPoints.create({
      userId,
      actionType: 'share_log',
      points: 10
    });

    const log = await ActivityLog.findById(createdLog._id)
      .populate('userId', 'name profilePictureURL');

    res.json({
      message: 'Weight shared successfully',
      log: serializeSharedActivityLog(log)
    });
  } catch (error) {
    console.error('Share weight error:', error);
    res.status(500).json({ message: 'Error sharing weight log' });
  }
});

/**
 * Get shared logs from friends
 * GET /api/logs/friends
 */
router.get('/friends', authenticateToken, async (req, res) => {
  try {
    const userId = req.user._id;

    // Get accepted friends
    const friendships = await Friend.find({
      $or: [
        { userId, status: 'accepted' },
        { friendId: userId, status: 'accepted' }
      ]
    });

    const friendIds = friendships.map(f =>
      f.userId.toString() === userId.toString() ? f.friendId : f.userId
    );

    const logs = await ActivityLog.find({
      userId: { $in: friendIds },
      visibility: { $in: ['friends_only', 'public'] }
    })
    .populate('userId', 'name profilePictureURL')
    .sort({ createdAt: -1 })
    .limit(50);

    res.json({ logs: logs.map(serializeSharedActivityLog) });
  } catch (error) {
    console.error('Get friends logs error:', error);
    res.status(500).json({ message: 'Error fetching shared logs' });
  }
});

/**
 * Get activity feed (own + friends activities)
 * GET /api/logs/feed
 */
router.get('/feed', authenticateToken, async (req, res) => {
  try {
    const userId = req.user._id;

    // Get accepted friends
    const friendships = await Friend.find({
      $or: [
        { userId, status: 'accepted' },
        { friendId: userId, status: 'accepted' }
      ]
    });

    const friendIds = friendships.map(f =>
      f.userId.toString() === userId.toString() ? f.friendId : f.userId
    );

    const feed = await ActivityLog.find({
      $or: [
        { userId }, // Own activities
        { userId: { $in: friendIds }, visibility: 'public' },
        { userId: { $in: friendIds }, visibility: 'friends_only' }
      ]
    })
    .populate('userId', 'name profilePictureURL')
    .sort({ createdAt: -1 })
    .limit(100);

    res.json({ feed: feed.map(item => serializeActivityFeedItem(item, userId)) });
  } catch (error) {
    console.error('Get activity feed error:', error);
    res.status(500).json({ message: 'Error fetching activity feed' });
  }
});

/**
 * Update log visibility settings
 * POST /api/logs/:logId/visibility
 */
router.post('/:logId/visibility', authenticateToken, async (req, res) => {
  try {
    const { logId } = req.params;
    const { visibility, sharedWith } = req.body;
    const userId = req.user._id;

    if (!visibility) {
      return res.status(400).json({ message: 'Visibility is required' });
    }

    const log = await ActivityLog.findOneAndUpdate(
      { _id: logId, userId },
      { visibility, sharedWith: sharedWith || [] },
      { new: true }
    );

    if (!log) {
      return res.status(404).json({ message: 'Log not found or unauthorized' });
    }

    res.json({
      message: 'Log visibility updated',
      log
    });
  } catch (error) {
    console.error('Update visibility error:', error);
    res.status(500).json({ message: 'Error updating visibility' });
  }
});

/**
 * Delete a shared log
 * DELETE /api/logs/:logId
 */
router.delete('/:logId', authenticateToken, async (req, res) => {
  try {
    const { logId } = req.params;
    const userId = req.user._id;

    const result = await ActivityLog.findOneAndDelete({ _id: logId, userId });

    if (!result) {
      return res.status(404).json({ message: 'Log not found or unauthorized' });
    }

    res.json({ message: 'Log deleted successfully' });
  } catch (error) {
    console.error('Delete log error:', error);
    res.status(500).json({ message: 'Error deleting log' });
  }
});

export default router;
