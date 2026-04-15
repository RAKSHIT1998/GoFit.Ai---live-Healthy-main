import Meal from '../models/Meal.js';
import Workout from '../models/Workout.js';
import { GamificationPoints } from '../models/Gamification.js';

function buildDateMatch(fieldName, startDate) {
  if (!startDate) {
    return {};
  }

  return {
    [fieldName]: { $gte: startDate }
  };
}

export async function getUserSocialStats(userId, { startDate = null } = {}) {
  const mealMatch = {
    userId,
    ...buildDateMatch('timestamp', startDate)
  };

  const workoutMatch = {
    userId,
    ...buildDateMatch('timestamp', startDate)
  };

  const pointsMatch = {
    userId,
    ...(startDate ? { createdAt: { $gte: startDate } } : {})
  };

  const [totalMealsLogged, workoutSummary, lastMeal, lastWorkout, pointsSummary] = await Promise.all([
    Meal.countDocuments(mealMatch),
    Workout.aggregate([
      { $match: workoutMatch },
      {
        $group: {
          _id: null,
          totalWorkoutsCompleted: { $sum: 1 },
          totalCaloriesBurned: { $sum: { $ifNull: ['$caloriesBurned', 0] } }
        }
      }
    ]),
    Meal.findOne(mealMatch).sort({ timestamp: -1 }).select('timestamp'),
    Workout.findOne(workoutMatch).sort({ timestamp: -1 }).select('timestamp'),
    GamificationPoints.aggregate([
      { $match: pointsMatch },
      {
        $group: {
          _id: null,
          totalPoints: { $sum: '$points' }
        }
      }
    ])
  ]);

  const totalWorkoutsCompleted = workoutSummary[0]?.totalWorkoutsCompleted || 0;
  const totalCaloriesBurned = workoutSummary[0]?.totalCaloriesBurned || 0;
  const recordedPoints = pointsSummary[0]?.totalPoints || 0;
  const fallbackPoints = (totalMealsLogged * 15) + (totalWorkoutsCompleted * 25);

  return {
    totalMealsLogged,
    totalWorkoutsCompleted,
    totalCaloriesBurned,
    lastMealLogged: lastMeal?.timestamp || null,
    lastWorkoutCompleted: lastWorkout?.timestamp || null,
    totalPoints: recordedPoints > 0 ? recordedPoints : fallbackPoints
  };
}
