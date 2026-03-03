import mongoose from 'mongoose';

const activityLogSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  type: {
    type: String,
    enum: ['meal', 'workout', 'weight', 'water', 'progress_photo', 'achievement'],
    required: true
  },
  title: {
    type: String,
    required: true
  },
  referenceId: {
    type: mongoose.Schema.Types.ObjectId
  },
  visibility: {
    type: String,
    enum: ['private', 'friends_only', 'public'],
    default: 'friends_only'
  },
  sharedWith: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  metadata: {
    type: mongoose.Schema.Types.Mixed
  }
}, {
  timestamps: true
});

activityLogSchema.index({ userId: 1, createdAt: -1 });
activityLogSchema.index({ visibility: 1, createdAt: -1 });

export default mongoose.model('ActivityLog', activityLogSchema);
