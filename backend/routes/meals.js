import express from 'express';
import OpenAI from 'openai';
import Meal from '../models/Meal.js';
import { GamificationPoints } from '../models/Gamification.js';
import { authMiddleware } from '../middleware/authMiddleware.js';
import mlService from '../services/mlService.js';

const router = express.Router();

// Initialize OpenAI for nutrition lookup
const OPENAI_API_KEY = (process.env.OPENAI_API_KEY || '').trim();
const openai = OPENAI_API_KEY ? new OpenAI({ apiKey: OPENAI_API_KEY }) : null;

// AI Nutrition Lookup - get nutrition from food name + portion
router.post('/ai-nutrition-lookup', authMiddleware, async (req, res) => {
  try {
    const { foodName, portion } = req.body;

    if (!foodName || !foodName.trim()) {
      return res.status(400).json({ message: 'Food name is required' });
    }

    if (!openai) {
      return res.status(503).json({ message: 'AI service unavailable' });
    }

    const portionText = portion && portion.trim() ? portion.trim() : '1 serving';

    const prompt = `You are a nutrition expert. Given the food item and portion size, provide accurate nutritional information.

Food: ${foodName.trim()}
Portion: ${portionText}

Respond with ONLY a JSON object (no markdown, no explanation) with these exact fields:
{
  "calories": <number>,
  "protein": <number in grams>,
  "carbs": <number in grams>,
  "fat": <number in grams>,
  "sugar": <number in grams>
}

Use established nutritional databases (USDA, etc.) for accuracy. Round to 1 decimal place.`;

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 200,
      temperature: 0.1
    });

    const responseText = completion.choices[0]?.message?.content?.trim();
    
    if (!responseText) {
      return res.status(500).json({ message: 'Empty AI response' });
    }

    // Parse JSON - handle markdown code blocks if present
    let jsonStr = responseText;
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replace(/```json?\n?/g, '').replace(/```/g, '').trim();
    }

    const nutrition = JSON.parse(jsonStr);

    res.json({
      calories: Number(nutrition.calories) || 0,
      protein: Number(nutrition.protein) || 0,
      carbs: Number(nutrition.carbs) || 0,
      fat: Number(nutrition.fat) || 0,
      sugar: Number(nutrition.sugar) || 0,
      source: 'ai',
      foodName: foodName.trim(),
      portion: portionText
    });

  } catch (error) {
    console.error('AI nutrition lookup error:', error);
    res.status(500).json({ message: 'AI nutrition lookup failed', error: error.message });
  }
});

// Save meal
router.post('/save', authMiddleware, async (req, res) => {
  try {
    const { items, imageUrl, imageKey, totalCalories, totalProtein, totalCarbs, totalFat, totalSugar, mealType, timestamp, aiVersion } = req.body;

    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: 'Items array is required' });
    }

    const meal = new Meal({
      userId: req.user._id,
      items,
      imageUrl,
      imageKey,
      totalCalories: totalCalories || items.reduce((sum, item) => sum + (item.calories || 0), 0),
      totalProtein: totalProtein || items.reduce((sum, item) => sum + (item.protein || 0), 0),
      totalCarbs: totalCarbs || items.reduce((sum, item) => sum + (item.carbs || 0), 0),
      totalFat: totalFat || items.reduce((sum, item) => sum + (item.fat || 0), 0),
      totalSugar: totalSugar || items.reduce((sum, item) => sum + (item.sugar || 0), 0),
      mealType: mealType || 'snack',
      timestamp: timestamp ? new Date(timestamp) : new Date(),
      aiVersion: aiVersion || 'unknown'
    });

    await meal.save();

    // Award XP for meal logging without blocking the main response.
    GamificationPoints.create({
      userId: req.user._id,
      actionType: 'log_meal',
      points: 15
    }).catch(err => {
      console.error('Gamification meal XP error (non-critical):', err);
    });

    // Learn from this meal for ML (async, don't wait)
    mlService.learnFromMeal(meal, req.user._id).catch(err => {
      console.error('ML learning error (non-critical):', err);
    });

    res.status(201).json(meal);
  } catch (error) {
    console.error('Save meal error:', error);
    res.status(500).json({ message: 'Failed to save meal', error: error.message });
  }
});

// Get meals
router.get('/list', authMiddleware, async (req, res) => {
  try {
    const { startDate, endDate, limit = 50, skip = 0 } = req.query;

    const query = { userId: req.user._id };

    if (startDate || endDate) {
      query.timestamp = {};
      if (startDate) query.timestamp.$gte = new Date(startDate);
      if (endDate) query.timestamp.$lte = new Date(endDate);
    }

    const meals = await Meal.find(query)
      .sort({ timestamp: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(skip));

    res.json(meals);
  } catch (error) {
    console.error('Get meals error:', error);
    res.status(500).json({ message: 'Failed to get meals', error: error.message });
  }
});

// Get today's summary
router.get('/summary/today', authMiddleware, async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const meals = await Meal.find({
      userId: req.user._id,
      timestamp: { $gte: today, $lt: tomorrow }
    });

    const summary = meals.reduce((acc, meal) => ({
      calories: acc.calories + (meal.totalCalories || 0),
      protein: acc.protein + (meal.totalProtein || 0),
      carbs: acc.carbs + (meal.totalCarbs || 0),
      fat: acc.fat + (meal.totalFat || 0),
      sugar: acc.sugar + (meal.totalSugar || 0),
      mealCount: acc.mealCount + 1
    }), { calories: 0, protein: 0, carbs: 0, fat: 0, sugar: 0, mealCount: 0 });

    res.json(summary);
  } catch (error) {
    console.error('Get summary error:', error);
    res.status(500).json({ message: 'Failed to get summary', error: error.message });
  }
});

// Delete meal
router.delete('/:mealId', authMiddleware, async (req, res) => {
  try {
    const meal = await Meal.findOne({
      _id: req.params.mealId,
      userId: req.user._id
    });

    if (!meal) {
      return res.status(404).json({ message: 'Meal not found' });
    }

    // TODO: Delete image from S3 if needed
    await meal.deleteOne();

    res.json({ message: 'Meal deleted successfully' });
  } catch (error) {
    console.error('Delete meal error:', error);
    res.status(500).json({ message: 'Failed to delete meal', error: error.message });
  }
});

// Batch sync (for offline support)
router.post('/sync', authMiddleware, async (req, res) => {
  try {
    const { meals } = req.body;

    if (!meals || !Array.isArray(meals)) {
      return res.status(400).json({ message: 'Meals array is required' });
    }

    const savedMeals = [];
    const errors = [];

    for (const mealData of meals) {
      try {
        const meal = new Meal({
          ...mealData,
          userId: req.user._id
        });
        await meal.save();
        savedMeals.push(meal);
      } catch (error) {
        errors.push({ meal: mealData, error: error.message });
      }
    }

    res.json({
      saved: savedMeals.length,
      errors: errors.length,
      details: errors
    });
  } catch (error) {
    console.error('Sync meals error:', error);
    res.status(500).json({ message: 'Failed to sync meals', error: error.message });
  }
});

export default router;
