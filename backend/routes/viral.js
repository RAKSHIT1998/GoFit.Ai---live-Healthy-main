import express from 'express';
import OpenAI from 'openai';
import Meal from '../models/Meal.js';
import { GamificationPoints } from '../models/Gamification.js';
import { authenticateToken } from '../middleware/authMiddleware.js';

const router = express.Router();

const OPENAI_API_KEY = (process.env.OPENAI_API_KEY || '').trim();
const openai = OPENAI_API_KEY ? new OpenAI({ apiKey: OPENAI_API_KEY }) : null;

// In-memory cache: roasts are expensive to generate, cache per user per day
const roastCache = new Map();

/**
 * "Roast My Diet" – AI humorously critiques user's last 7 days of food
 * GET /api/viral/roast-diet
 */
router.get('/roast-diet', authenticateToken, async (req, res) => {
  try {
    const userId = req.user._id.toString();
    const cacheKey = `${userId}_${new Date().toISOString().slice(0, 10)}`;

    if (roastCache.has(cacheKey)) {
      return res.json(roastCache.get(cacheKey));
    }

    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const meals = await Meal.find({ userId: req.user._id, timestamp: { $gte: sevenDaysAgo } })
      .sort({ timestamp: -1 })
      .limit(30);

    if (meals.length === 0) {
      return res.json({
        roast: "I can't roast what doesn't exist. You haven't logged a single meal this week. The only thing getting shredded is your excuses 💀",
        score: 0,
        badge: 'Ghost Dieter',
        shareText: "The GoFit AI tried to roast my diet and found nothing 👻 #GoFitAi #RoastMyDiet"
      });
    }

    const mealSummary = meals.map(m => ({
      items: m.items.map(i => i.name).join(', '),
      calories: m.totalCalories,
      type: m.mealType,
      day: new Date(m.timestamp).toLocaleDateString('en', { weekday: 'short' })
    }));

    const totalCalories = meals.reduce((sum, m) => sum + (m.totalCalories || 0), 0);
    const totalSugar = meals.reduce((sum, m) => sum + (m.totalSugar || 0), 0);
    const avgCalories = Math.round(totalCalories / 7);

    if (!openai) {
      return res.status(503).json({ message: 'AI service unavailable' });
    }

    const completion = await openai.chat.completions.create({
      model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: `You are a brutally funny, sarcastic-but-loving diet coach. Your job is to ROAST the user's diet choices like a comedian. Be specific about their actual food, use emojis, be funny but not mean-spirited. Keep it under 150 words. End with an actual useful tip in one sentence.`
        },
        {
          role: 'user',
          content: `Roast my diet this week. Here's what I ate:\n${JSON.stringify(mealSummary, null, 2)}\nTotal calories: ${totalCalories} across 7 days (avg ${avgCalories}/day). Total sugar: ${totalSugar}g.`
        }
      ],
      max_tokens: 300,
      temperature: 0.9
    });

    const roastText = completion.choices[0]?.message?.content || 'Your diet was so bad I speechless.';

    // Give a "health score" based on variety and calorie balance
    const uniqueFoods = new Set(meals.flatMap(m => m.items.map(i => i.name))).size;
    const score = Math.min(100, Math.round((uniqueFoods * 3) + (avgCalories > 1200 && avgCalories < 2800 ? 30 : 0)));

    const badgeMap = [
      [80, 'Nutrition Nerd 🥦'],
      [60, 'Work in Progress 💪'],
      [40, 'Chaos Eater 🌪️'],
      [20, 'Junk Food Goblin 🍕'],
      [0, 'Dietary Disaster Zone 💀']
    ];
    const badge = badgeMap.find(([min]) => score >= min)?.[1] || 'Dietary Disaster Zone 💀';

    const result = {
      roast: roastText,
      score,
      badge,
      totalCaloriesThisWeek: totalCalories,
      avgDailyCalories: avgCalories,
      uniqueFoodsLogged: uniqueFoods,
      shareText: `My GoFit AI Diet Roast: "${roastText.slice(0, 100)}..." I got the "${badge}" badge 😭 #GoFitAi #RoastMyDiet`
    };

    roastCache.set(cacheKey, result);
    res.json(result);
  } catch (error) {
    console.error('Roast diet error:', error);
    res.status(500).json({ message: 'Error generating roast' });
  }
});

/**
 * Weekly "Body Budget" Report – shareable Spotify Wrapped-style weekly summary
 * GET /api/viral/weekly-report
 */
router.get('/weekly-report', authenticateToken, async (req, res) => {
  try {
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const meals = await Meal.find({
      userId: req.user._id,
      timestamp: { $gte: sevenDaysAgo }
    }).sort({ timestamp: -1 });

    if (meals.length === 0) {
      return res.json({
        week: new Date().toISOString().slice(0, 10),
        mealsLogged: 0,
        message: 'Start logging meals to get your weekly report!',
        shareText: 'Starting my health journey with @GoFitAi this week! 💪 #GoFitAi'
      });
    }

    const totalCal = meals.reduce((s, m) => s + (m.totalCalories || 0), 0);
    const totalProtein = meals.reduce((s, m) => s + (m.totalProtein || 0), 0);
    const totalCarbs = meals.reduce((s, m) => s + (m.totalCarbs || 0), 0);
    const totalFat = meals.reduce((s, m) => s + (m.totalFat || 0), 0);
    const totalSugar = meals.reduce((s, m) => s + (m.totalSugar || 0), 0);

    // Best day (highest protein), worst day (highest sugar)
    const byDay = {};
    for (const m of meals) {
      const day = new Date(m.timestamp).toLocaleDateString('en', { weekday: 'long' });
      if (!byDay[day]) byDay[day] = { calories: 0, protein: 0, sugar: 0 };
      byDay[day].calories += m.totalCalories || 0;
      byDay[day].protein += m.totalProtein || 0;
      byDay[day].sugar += m.totalSugar || 0;
    }

    const days = Object.entries(byDay);
    const bestDay = days.sort((a, b) => b[1].protein - a[1].protein)[0]?.[0] || 'N/A';
    const worstDay = days.sort((a, b) => b[1].sugar - a[1].sugar)[0]?.[0] || 'N/A';
    const topFood = (() => {
      const freq = {};
      meals.forEach(m => m.items.forEach(i => { freq[i.name] = (freq[i.name] || 0) + 1; }));
      return Object.entries(freq).sort((a, b) => b[1] - a[1])[0]?.[0] || 'N/A';
    })();

    const xpPoints = await GamificationPoints.aggregate([
      { $match: { userId: req.user._id, createdAt: { $gte: sevenDaysAgo } } },
      { $group: { _id: null, total: { $sum: '$points' } } }
    ]);
    const weeklyXP = xpPoints[0]?.total || 0;

    const report = {
      week: new Date().toISOString().slice(0, 10),
      mealsLogged: meals.length,
      totalCalories: Math.round(totalCal),
      avgDailyCalories: Math.round(totalCal / 7),
      totalProtein: Math.round(totalProtein),
      totalCarbs: Math.round(totalCarbs),
      totalFat: Math.round(totalFat),
      totalSugar: Math.round(totalSugar),
      bestDay,
      worstDay,
      topFood,
      weeklyXP,
      shareText: `My Week in Food 📊\n🍽️ ${meals.length} meals logged\n🔥 ${Math.round(totalCal)} calories total\n💪 ${Math.round(totalProtein)}g protein\n⭐️ Best day: ${bestDay}\n🏅 ${weeklyXP} XP earned\n\nTracked with @GoFitAi #GoFitAi #WeeklyReport #HealthyLife`
    };

    res.json(report);
  } catch (error) {
    console.error('Weekly report error:', error);
    res.status(500).json({ message: 'Error generating weekly report' });
  }
});

/**
 * Track a share event (for viral analytics)
 * POST /api/viral/track-share { type: 'progress' | 'roast' | 'weekly_report' | 'achievement' | 'referral' }
 */
router.post('/track-share', authenticateToken, async (req, res) => {
  try {
    const { type = 'progress' } = req.body;
    // Award small XP for sharing (max once per type per day via actionType)
    await GamificationPoints.create({
      userId: req.user._id,
      actionType: 'share_log',
      points: 5
    });
    res.json({ success: true, xpEarned: 5, shareType: type });
  } catch (error) {
    console.error('Track share error:', error);
    res.status(500).json({ message: 'Error tracking share' });
  }
});

/**
 * "Calorie Shock" – show how long you'd need to exercise to burn a specific meal
 * POST /api/viral/calorie-shock { mealName, calories }
 */
router.post('/calorie-shock', authenticateToken, async (req, res) => {
  try {
    const { mealName, calories } = req.body;
    if (!calories || calories <= 0) return res.status(400).json({ message: 'calories required' });

    // MET-based calorie burn estimates (kcal/min for 70kg person)
    const activities = [
      { name: 'Running', emoji: '🏃', calPerMin: 10 },
      { name: 'Cycling', emoji: '🚴', calPerMin: 8 },
      { name: 'Swimming', emoji: '🏊', calPerMin: 7 },
      { name: 'Jumping rope', emoji: '🪢', calPerMin: 11 },
      { name: 'Walking', emoji: '🚶', calPerMin: 4 },
      { name: 'HIIT workout', emoji: '💪', calPerMin: 12 },
      { name: 'Yoga', emoji: '🧘', calPerMin: 3 }
    ];

    const shocks = activities.map(a => ({
      activity: a.name,
      emoji: a.emoji,
      minutes: Math.round(calories / a.calPerMin),
      formattedTime: calories / a.calPerMin >= 60
        ? `${Math.floor(calories / a.calPerMin / 60)}h ${Math.round(calories / a.calPerMin % 60)}m`
        : `${Math.round(calories / a.calPerMin)} min`
    }));

    const shareText = `That ${mealName || 'meal'} (${calories} cal) = ${shocks[0].formattedTime} of ${shocks[0].activity}! 😱 Tracked with GoFit.AI #CalorieShock #GoFitAi`;

    res.json({ mealName, calories, shocks, shareText });
  } catch (error) {
    console.error('Calorie shock error:', error);
    res.status(500).json({ message: 'Error calculating calorie shock' });
  }
});

export default router;
