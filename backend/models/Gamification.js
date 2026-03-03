import mongoose from 'mongoose';

const gamificationPointsSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  actionType: {
    type: String,
    enum: [
      'share_log', 'create_challenge', 'join_challenge', 'complete_challenge',
      'complete_workout', 'log_meal', 'log_water', 'streak_bonus',
      'first_workout', 'first_meal', 'invite_friend'
    ],
    required: true
  },
  points: {
    type: Number,
    required: true
  }
}, {
  timestamps: true
});

const badgeSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  name: {
    type: String,
    required: true
  },
  description: String,
  icon: String,
  earnedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

const achievementSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  name: {
    type: String,
    required: true
  },
  description: String,
  points: {
    type: Number,
    default: 0
  },
  earnedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

const userStreakSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  currentDays: {
    type: Number,
    default: 0
  },
  longestDays: {
    type: Number,
    default: 0
  },
  lastActiveDate: Date,
  streakType: {
    type: String,
    enum: ['workout', 'meal_logging', 'app_usage'],
    default: 'app_usage'
  }
}, {
  timestamps: true
});

export const GamificationPoints = mongoose.model('GamificationPoints', gamificationPointsSchema);
export const Badge = mongoose.model('Badge', badgeSchema);
export const Achievement = mongoose.model('Achievement', achievementSchema);
export const UserStreak = mongoose.model('UserStreak', userStreakSchema);
