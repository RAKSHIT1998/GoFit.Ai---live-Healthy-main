import express from 'express';
import Notification from '../models/Notification.js';
import User from '../models/User.js';
import Meal from '../models/Meal.js';
import WaterLog from '../models/WaterLog.js';
import { authenticateToken } from '../middleware/authMiddleware.js';
import { generateCompetitiveNotification } from '../services/aiNotificationService.js';
import mlService from '../services/mlService.js';
import OpenAI from 'openai';

const router = express.Router();

// Initialize OpenAI (optional – gracefully handle missing key)
let openai = null;
try {
  if (process.env.OPENAI_API_KEY) {
    openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  }
} catch (e) {
  console.warn('⚠️ OpenAI not configured for notifications');
}

/**
 * Get all notifications for user
 * GET /api/notifications
 */
router.get('/', authenticateToken, async (req, res) => {
  try {
    const userId = req.user._id;
    const { limit = 30, offset = 0, unreadOnly = false } = req.query;

    const query = { recipientId: userId };
    if (unreadOnly === 'true') {
      query.isRead = false;
    }

    const notifications = await Notification.find(query)
      .sort({ createdAt: -1 })
      .skip(parseInt(offset))
      .limit(parseInt(limit))
      .populate('relatedUserId', 'name profilePictureURL');

    res.json({
      notifications,
      count: notifications.length
    });
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({ message: 'Error fetching notifications' });
  }
});

/**
 * Get unread notification count
 * GET /api/notifications/unread/count
 */
router.get('/unread/count', authenticateToken, async (req, res) => {
  try {
    const userId = req.user._id;

    const unreadCount = await Notification.countDocuments({
      recipientId: userId,
      isRead: false
    });

    res.json({ unreadCount });
  } catch (error) {
    console.error('Get unread count error:', error);
    res.status(500).json({ message: 'Error fetching unread count' });
  }
});

/**
 * Mark notification as read
 * PUT /api/notifications/:notificationId/read
 */
router.put('/:notificationId/read', authenticateToken, async (req, res) => {
  try {
    const { notificationId } = req.params;
    const userId = req.user._id;

    const notification = await Notification.findOneAndUpdate(
      { _id: notificationId, recipientId: userId },
      { isRead: true },
      { new: true }
    );

    if (!notification) {
      return res.status(404).json({ message: 'Notification not found' });
    }

    res.json({
      message: 'Notification marked as read',
      notification
    });
  } catch (error) {
    console.error('Mark as read error:', error);
    res.status(500).json({ message: 'Error marking notification' });
  }
});

/**
 * Delete notification
 * DELETE /api/notifications/:notificationId
 */
router.delete('/:notificationId', authenticateToken, async (req, res) => {
  try {
    const { notificationId } = req.params;
    const userId = req.user._id;

    const result = await Notification.findOneAndDelete({
      _id: notificationId,
      recipientId: userId
    });

    if (!result) {
      return res.status(404).json({ message: 'Notification not found' });
    }

    res.json({ message: 'Notification deleted' });
  } catch (error) {
    console.error('Delete notification error:', error);
    res.status(500).json({ message: 'Error deleting notification' });
  }
});

/**
 * Generate competitive notification for a user
 * POST /api/notifications/competitive
 */
router.post('/competitive', authenticateToken, async (req, res) => {
  try {
    const { userId, triggerType, contextData } = req.body;

    if (!userId || !triggerType) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    const notificationData = await generateCompetitiveNotification(userId, triggerType, contextData);

    if (!notificationData) {
      return res.status(400).json({ message: 'Could not generate notification' });
    }

    const notification = await Notification.create({
      recipientId: userId,
      type: 'ai_competitive',
      title: notificationData.title,
      message: notificationData.message,
      aiGenerated: true
    });

    res.json({
      message: 'Competitive notification generated',
      notification
    });
  } catch (error) {
    console.error('Generate competitive notification error:', error);
    res.status(500).json({ message: 'Error generating notification' });
  }
});

/**
 * Mark all notifications as read
 * PUT /api/notifications/read/all
 */
router.put('/read/all', authenticateToken, async (req, res) => {
  try {
    const userId = req.user._id;

    await Notification.updateMany(
      { recipientId: userId, isRead: false },
      { isRead: true }
    );

    res.json({ message: 'All notifications marked as read' });
  } catch (error) {
    console.error('Mark all as read error:', error);
    res.status(500).json({ message: 'Error marking notifications' });
  }
});

// ─── Helper: get user context for AI reminders ───

async function getUserContext(userId) {
  const user = await User.findById(userId);
  if (!user) return null;

  let mlInsights = {};
  try { mlInsights = await mlService.getMLInsights(userId); } catch (_) { /* optional */ }

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const todayMeals = await Meal.find({ userId, timestamp: { $gte: today } }).sort({ timestamp: -1 });
  const todayWater = await WaterLog.find({ userId, timestamp: { $gte: today } });
  const totalWater = todayWater.reduce((sum, log) => sum + (log.amount || 0), 0);
  const recentMeals = await Meal.find({ userId }).sort({ timestamp: -1 }).limit(10);

  return {
    user: {
      name: user.name,
      goals: user.goals,
      activityLevel: user.activityLevel,
      dietaryPreferences: user.dietaryPreferences || [],
      allergies: user.allergies || [],
      targetCalories: user.metrics?.targetCalories || 2000,
      targetProtein: user.metrics?.targetProtein || 150,
      targetCarbs: user.metrics?.targetCarbs || 200,
      targetFat: user.metrics?.targetFat || 65,
      weightKg: user.metrics?.weightKg || 70,
      heightCm: user.metrics?.heightCm || 170,
      workoutPreferences: user.onboardingData?.workoutPreferences || [],
      favoriteCuisines: user.onboardingData?.favoriteCuisines || [],
      mealTimingPreference: user.onboardingData?.mealTimingPreference || 'regular',
      drinkingFrequency: user.onboardingData?.drinkingFrequency || 'never',
      smokingStatus: user.onboardingData?.smokingStatus || 'never'
    },
    today: {
      meals: todayMeals.length,
      calories: todayMeals.reduce((sum, m) => sum + (m.totalCalories || 0), 0),
      protein: todayMeals.reduce((sum, m) => sum + (m.totalProtein || 0), 0),
      carbs: todayMeals.reduce((sum, m) => sum + (m.totalCarbs || 0), 0),
      water: totalWater
    },
    mlInsights,
    recentMeals: recentMeals.map(m => ({
      items: (m.items || []).map(i => i.name),
      calories: m.totalCalories,
      timestamp: m.timestamp
    }))
  };
}

// ─── AI Meal Reminder ───

router.post('/meal-reminder', authenticateToken, async (req, res) => {
  try {
    const { mealType } = req.body;

    if (!openai) {
      return res.json({
        title: "Time to eat! 🍽️",
        body: `Don't forget your ${mealType || 'meal'}. Your body needs fuel to stay healthy!`
      });
    }

    const context = await getUserContext(req.user._id);
    if (!context) return res.status(404).json({ message: 'User not found' });

    const prompt = `You are a friendly health coach. Generate a personalized meal reminder for ${context.user.name}.
USER: Goals=${context.user.goals}, Activity=${context.user.activityLevel}, Diets=${context.user.dietaryPreferences.join(', ') || 'None'}, Fav Cuisines=${context.user.favoriteCuisines.join(', ') || 'Varied'}
TODAY: Meals=${context.today.meals}, Calories=${context.today.calories}/${context.user.targetCalories}, Protein=${context.today.protein}g/${context.user.targetProtein}g
MEAL TYPE: ${mealType}
Return ONLY JSON: {"title":"max 50 chars","body":"max 100 chars"}`;

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [
        { role: 'system', content: 'Return ONLY valid JSON with "title" and "body". No markdown.' },
        { role: 'user', content: prompt }
      ],
      max_tokens: 200,
      temperature: 0.7
    });

    let jsonContent;
    try {
      const raw = completion.choices[0]?.message?.content?.trim()
        .replace(/^```json\s*/i, '').replace(/^```\s*/i, '').replace(/\s*```$/i, '');
      jsonContent = JSON.parse(raw);
    } catch (_) {
      jsonContent = { title: "Time to eat! 🍽️", body: `Don't forget your ${mealType}!` };
    }

    res.json({
      title: jsonContent.title || `Time for ${mealType}! 🍽️`,
      body: jsonContent.body || `Don't forget your ${mealType}!`
    });
  } catch (error) {
    console.error('Error generating meal reminder:', error);
    res.json({
      title: "Time to eat! 🍽️",
      body: `Don't forget your ${req.body.mealType || 'meal'}!`
    });
  }
});

// ─── AI Water Reminder ───

router.post('/water-reminder', authenticateToken, async (req, res) => {
  try {
    if (!openai) {
      return res.json({
        title: "Stay Hydrated! 💧",
        body: "Time to drink water! Staying hydrated helps your body function at its best."
      });
    }

    const context = await getUserContext(req.user._id);
    if (!context) return res.status(404).json({ message: 'User not found' });

    const prompt = `You are a friendly health coach. Generate a water reminder for ${context.user.name}.
USER: Goals=${context.user.goals}, Activity=${context.user.activityLevel}, Weight=${context.user.weightKg}kg
TODAY: Water=${context.today.water.toFixed(1)}L, Target=${(context.user.weightKg * 0.035).toFixed(1)}L
Return ONLY JSON: {"title":"max 50 chars","body":"max 100 chars"}`;

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [
        { role: 'system', content: 'Return ONLY valid JSON with "title" and "body". No markdown.' },
        { role: 'user', content: prompt }
      ],
      max_tokens: 200,
      temperature: 0.7
    });

    let jsonContent;
    try {
      const raw = completion.choices[0]?.message?.content?.trim()
        .replace(/^```json\s*/i, '').replace(/^```\s*/i, '').replace(/\s*```$/i, '');
      jsonContent = JSON.parse(raw);
    } catch (_) {
      jsonContent = { title: "Stay Hydrated! 💧", body: "Time to drink water!" };
    }

    res.json({
      title: jsonContent.title || "Stay Hydrated! 💧",
      body: jsonContent.body || "Time to drink water!"
    });
  } catch (error) {
    console.error('Error generating water reminder:', error);
    res.json({
      title: "Stay Hydrated! 💧",
      body: "Time to drink water! Staying hydrated helps your body function at its best."
    });
  }
});

// ─── AI Workout Reminder ───

router.post('/workout-reminder', authenticateToken, async (req, res) => {
  try {
    if (!openai) {
      return res.json({
        title: "Workout Time! 💪",
        body: "Time for your workout! Your body will thank you for staying active."
      });
    }

    const context = await getUserContext(req.user._id);
    if (!context) return res.status(404).json({ message: 'User not found' });

    const prompt = `You are a friendly fitness coach. Generate a workout reminder for ${context.user.name}.
USER: Goals=${context.user.goals}, Activity=${context.user.activityLevel}, Prefs=${context.user.workoutPreferences.join(', ') || 'General fitness'}
TODAY: Calories=${context.today.calories}/${context.user.targetCalories}, Water=${context.today.water.toFixed(1)}L
Return ONLY JSON: {"title":"max 50 chars","body":"max 100 chars"}`;

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [
        { role: 'system', content: 'Return ONLY valid JSON with "title" and "body". No markdown.' },
        { role: 'user', content: prompt }
      ],
      max_tokens: 200,
      temperature: 0.7
    });

    let jsonContent;
    try {
      const raw = completion.choices[0]?.message?.content?.trim()
        .replace(/^```json\s*/i, '').replace(/^```\s*/i, '').replace(/\s*```$/i, '');
      jsonContent = JSON.parse(raw);
    } catch (_) {
      jsonContent = { title: "Workout Time! 💪", body: "Time for your workout!" };
    }

    res.json({
      title: jsonContent.title || "Workout Time! 💪",
      body: jsonContent.body || "Time for your workout!"
    });
  } catch (error) {
    console.error('Error generating workout reminder:', error);
    res.json({
      title: "Workout Time! 💪",
      body: "Time for your workout! Your body will thank you for staying active."
    });
  }
});

export default router;

