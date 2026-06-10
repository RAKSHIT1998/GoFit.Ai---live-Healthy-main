import express from 'express';
import { ReferralCode, ReferralUse } from '../models/Referral.js';
import { GamificationPoints } from '../models/Gamification.js';
import { authenticateToken } from '../middleware/authMiddleware.js';
import { wsService } from '../services/websocketService.js';

const router = express.Router();

const XP_PER_REFERRAL = 50;
const XP_FOR_BEING_REFERRED = 100;

/**
 * Get or register user's referral code
 * GET  /api/referrals/code           → returns existing code
 * POST /api/referrals/code { code }  → registers a code generated on device
 */
router.get('/code', authenticateToken, async (req, res) => {
  try {
    let record = await ReferralCode.findOne({ userId: req.user._id });
    if (!record) {
      return res.status(404).json({ message: 'No code registered yet' });
    }
    res.json({ code: record.code, totalReferrals: record.totalReferrals });
  } catch (error) {
    console.error('Get referral code error:', error);
    res.status(500).json({ message: 'Error fetching referral code' });
  }
});

router.post('/code', authenticateToken, async (req, res) => {
  try {
    const { code } = req.body;
    if (!code || code.length < 4) return res.status(400).json({ message: 'Invalid code' });

    const clean = code.toUpperCase().replace(/[^A-Z0-9]/g, '');

    // Check if another user already has this code
    const conflict = await ReferralCode.findOne({ code: clean, userId: { $ne: req.user._id } });
    if (conflict) {
      // Generate a unique variation
      const fallback = clean + Math.floor(Math.random() * 90 + 10);
      const record = await ReferralCode.findOneAndUpdate(
        { userId: req.user._id },
        { code: fallback },
        { upsert: true, new: true }
      );
      return res.json({ code: record.code, totalReferrals: record.totalReferrals });
    }

    const record = await ReferralCode.findOneAndUpdate(
      { userId: req.user._id },
      { code: clean },
      { upsert: true, new: true }
    );

    res.json({ code: record.code, totalReferrals: record.totalReferrals });
  } catch (error) {
    console.error('Register referral code error:', error);
    res.status(500).json({ message: 'Error registering referral code' });
  }
});

/**
 * Apply a referral code (new user uses someone else's code)
 * POST /api/referrals/apply { code }
 */
router.post('/apply', authenticateToken, async (req, res) => {
  try {
    const { code } = req.body;
    if (!code) return res.status(400).json({ message: 'code is required' });

    const clean = code.toUpperCase().replace(/[^A-Z0-9]/g, '');
    const refereeId = req.user._id;

    // Can't use your own code
    const myCode = await ReferralCode.findOne({ userId: refereeId });
    if (myCode?.code === clean) return res.status(400).json({ message: "Can't use your own code" });

    // Can't apply twice
    const alreadyUsed = await ReferralUse.findOne({ refereeId });
    if (alreadyUsed) return res.status(409).json({ message: 'Already applied a referral code' });

    // Find the owner of this code
    const referrerRecord = await ReferralCode.findOne({ code: clean });
    if (!referrerRecord) return res.status(404).json({ message: 'Code not found' });

    const referrerId = referrerRecord.userId;

    // Record the use
    await ReferralUse.create({ referrerId, refereeId, code: clean, xpAwarded: XP_PER_REFERRAL });

    // Increment the referrer's count
    referrerRecord.totalReferrals += 1;
    referrerRecord.uses.push({ refereeId });
    await referrerRecord.save();

    // Award XP to referrer
    await GamificationPoints.create({ userId: referrerId, actionType: 'invite_friend', points: XP_PER_REFERRAL });

    // Award XP to referee
    await GamificationPoints.create({ userId: refereeId, actionType: 'bonus_reward', points: XP_FOR_BEING_REFERRED });

    // Notify referrer in real-time
    wsService.emitAchievement(referrerId.toString(), {
      type: 'referral_used',
      message: 'Someone used your referral code! +50 XP',
      xp: XP_PER_REFERRAL
    });

    res.json({
      success: true,
      referrerId: referrerId.toString(),
      xpEarned: XP_FOR_BEING_REFERRED,
      message: `Code applied! You earned ${XP_FOR_BEING_REFERRED} XP`
    });
  } catch (error) {
    console.error('Apply referral code error:', error);
    res.status(500).json({ message: 'Error applying referral code' });
  }
});

/**
 * Get current user's referral status
 * GET /api/referrals/status
 */
router.get('/status', authenticateToken, async (req, res) => {
  try {
    const userId = req.user._id;

    const [myCode, referralHistory] = await Promise.all([
      ReferralCode.findOne({ userId }).populate('uses.refereeId', 'name createdAt'),
      ReferralUse.find({ referrerId: userId }).populate('refereeId', 'name createdAt')
    ]);

    // Total XP from referrals
    const xpTotal = (myCode?.totalReferrals || 0) * XP_PER_REFERRAL;

    res.json({
      code: myCode?.code || null,
      totalReferrals: myCode?.totalReferrals || 0,
      totalXP: xpTotal,
      history: referralHistory.map(r => ({
        friendName: r.refereeId?.name || 'A friend',
        date: r.createdAt,
        xpEarned: r.xpAwarded
      }))
    });
  } catch (error) {
    console.error('Referral status error:', error);
    res.status(500).json({ message: 'Error fetching referral status' });
  }
});

export default router;
