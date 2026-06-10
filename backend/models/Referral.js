import mongoose from 'mongoose';

const referralCodeSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true, index: true },
  code: { type: String, required: true, unique: true, index: true, uppercase: true },
  totalReferrals: { type: Number, default: 0 },
  uses: [{
    refereeId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    usedAt: { type: Date, default: Date.now }
  }]
}, { timestamps: true });

export const ReferralCode = mongoose.model('ReferralCode', referralCodeSchema);

const referralUseSchema = new mongoose.Schema({
  referrerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  refereeId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  code: { type: String, required: true },
  xpAwarded: { type: Number, default: 50 }
}, { timestamps: true });

export const ReferralUse = mongoose.model('ReferralUse', referralUseSchema);
