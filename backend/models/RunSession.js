import mongoose from 'mongoose';

const RunPointSchema = new mongoose.Schema({
  latitude: Number,
  longitude: Number,
  altitude: Number,
  timestamp: Date
});

const RunSessionSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  distance: Number, // meters
  duration: Number, // seconds
  altitudeGain: Number, // meters
  route: [RunPointSchema],
  manual: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now }
});

export default mongoose.model('RunSession', RunSessionSchema);
