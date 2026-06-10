import express from 'express';
import Challenge from '../models/Challenge.js';
import Notification from '../models/Notification.js';
import User from '../models/User.js';
import { GamificationPoints } from '../models/Gamification.js';
import { authenticateToken } from '../middleware/authMiddleware.js';
import { wsService } from '../services/websocketService.js';

const router = express.Router();

/**
 * Create a new challenge
 * POST /api/challenges/create
 */
router.post('/create', authenticateToken, async (req, res) => {
  try {
    const { name, description, challengeType, metric, targetValue, duration, isGroupChallenge, invitedUsers } = req.body;
    const userId = req.user._id;

    if (!name || !challengeType || !metric || !targetValue || !duration) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    // Map challengeType to schema enum
    const typeMap = {
      'personal': 'custom',
      'group': 'custom',
      'weight_loss': 'weight_loss',
      'muscle_gain': 'muscle_gain',
      'strength': 'strength',
      'endurance': 'endurance',
      'nutrition': 'nutrition',
      'consistency': 'consistency',
      'custom': 'custom'
    };

    const startDate = new Date();
    const endDate = new Date(startDate.getTime() + duration * 24 * 60 * 60 * 1000);

    const challenge = new Challenge({
      userId,
      name,
      description: description || '',
      type: typeMap[challengeType] || 'custom',
      target: {
        metric,
        targetValue,
        currentValue: 0,
        unit: metric === 'weight' ? 'kg' : metric === 'calories' ? 'kcal' : 'count'
      },
      startDate,
      endDate,
      status: 'active',
      isPublic: isGroupChallenge || false
    });

    await challenge.save();

    // Award points for creating challenge
    await GamificationPoints.create({
      userId,
      actionType: 'create_challenge',
      points: 25
    });

    // If group challenge, notify invited users
    if (isGroupChallenge && invitedUsers && invitedUsers.length > 0) {
      const creator = await User.findById(userId).select('name');

      for (const invitedUserId of invitedUsers) {
        // Create notification
        await Notification.create({
          recipientId: invitedUserId,
          type: 'challenge_invite',
          title: 'Challenge Invitation',
          message: `${creator.name} invited you to "${name}"`,
          relatedUserId: userId,
          challengeId: challenge._id
        });

        // Emit real-time WebSocket notification
        wsService.emitChallengeInvitation(invitedUserId, {
          challengeId: challenge._id.toString(),
          from: {
            id: userId.toString(),
            username: creator.name,
            fullName: creator.name
          },
          details: {
            name,
            description: description || '',
            metric,
            targetValue,
            duration
          },
          message: `${creator.name} invited you to: ${name}`
        });
      }
    }

    res.json({
      message: 'Challenge created successfully',
      challenge: {
        id: challenge._id.toString(),
        name,
        challengeType,
        metric,
        targetValue,
        startDate,
        endDate,
        status: 'active'
      }
    });
  } catch (error) {
    console.error('Create challenge error:', error);
    res.status(500).json({ message: 'Error creating challenge' });
  }
});

/**
 * Get all challenges
 * GET /api/challenges
 */
router.get('/', authenticateToken, async (req, res) => {
  try {
    const userId = req.user._id;
    const { type, status = 'active', limit = 20, offset = 0 } = req.query;

    const query = { userId };

    if (status === 'active') {
      query.status = 'active';
      query.endDate = { $gt: new Date() };
    } else if (status === 'completed') {
      query.$or = [
        { status: 'completed' },
        { endDate: { $lte: new Date() } }
      ];
    }

    if (type) {
      query.type = type;
    }

    const challenges = await Challenge.find(query)
      .sort({ createdAt: -1 })
      .skip(parseInt(offset))
      .limit(parseInt(limit));

    res.json({
      challenges: challenges.map(c => ({
        id: c._id.toString(),
        name: c.name,
        description: c.description,
        type: c.type,
        target: c.target,
        startDate: c.startDate,
        endDate: c.endDate,
        status: c.status,
        progress: c.progress,
        milestones: c.milestones,
        isPublic: c.isPublic
      })),
      count: challenges.length
    });
  } catch (error) {
    console.error('Get challenges error:', error);
    res.status(500).json({ message: 'Error fetching challenges' });
  }
});

/**
 * Get a single challenge
 * GET /api/challenges/:challengeId
 */
router.get('/:challengeId', authenticateToken, async (req, res) => {
  try {
    const { challengeId } = req.params;

    const challenge = await Challenge.findById(challengeId);

    if (!challenge) {
      return res.status(404).json({ message: 'Challenge not found' });
    }

    res.json({ challenge });
  } catch (error) {
    console.error('Get challenge error:', error);
    res.status(500).json({ message: 'Error fetching challenge' });
  }
});

/**
 * Update challenge score / progress
 * POST /api/challenges/:challengeId/score
 */
router.post('/:challengeId/score', authenticateToken, async (req, res) => {
  try {
    const { challengeId } = req.params;
    const { scoreValue, notes } = req.body;
    const userId = req.user._id;

    if (!scoreValue || scoreValue <= 0) {
      return res.status(400).json({ message: 'Invalid score value' });
    }

    const challenge = await Challenge.findOne({ _id: challengeId, userId });

    if (!challenge) {
      return res.status(404).json({ message: 'Challenge not found' });
    }

    // Update current value
    challenge.target.currentValue = (challenge.target.currentValue || 0) + scoreValue;

    // Add to progress log
    challenge.progress.push({
      date: new Date(),
      value: scoreValue,
      notes: notes || ''
    });

    // Check milestones
    for (const milestone of challenge.milestones) {
      if (!milestone.achieved && challenge.target.currentValue >= milestone.targetValue) {
        milestone.achieved = true;
        milestone.achievedDate = new Date();
      }
    }

    // Check if challenge is complete
    if (challenge.target.currentValue >= challenge.target.targetValue) {
      challenge.status = 'completed';

      // Award completion points
      await GamificationPoints.create({
        userId,
        actionType: 'complete_challenge',
        points: 50
      });
    }

    await challenge.save();

    res.json({
      message: 'Score updated',
      currentValue: challenge.target.currentValue,
      targetValue: challenge.target.targetValue,
      status: challenge.status
    });
  } catch (error) {
    console.error('Update challenge score error:', error);
    res.status(500).json({ message: 'Error updating score' });
  }
});

/**
 * Pause/resume a challenge
 * PUT /api/challenges/:challengeId/status
 */
router.put('/:challengeId/status', authenticateToken, async (req, res) => {
  try {
    const { challengeId } = req.params;
    const { status } = req.body;
    const userId = req.user._id;

    const validStatuses = ['active', 'paused', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ message: 'Invalid status' });
    }

    const challenge = await Challenge.findOneAndUpdate(
      { _id: challengeId, userId },
      { status },
      { new: true }
    );

    if (!challenge) {
      return res.status(404).json({ message: 'Challenge not found' });
    }

    res.json({ message: `Challenge ${status}`, challenge });
  } catch (error) {
    console.error('Update challenge status error:', error);
    res.status(500).json({ message: 'Error updating challenge status' });
  }
});

/**
 * Join a public challenge
 * POST /api/challenges/:challengeId/join
 */
router.post('/:challengeId/join', authenticateToken, async (req, res) => {
  try {
    const { challengeId } = req.params;
    const userId = req.user._id;

    const challenge = await Challenge.findById(challengeId);
    if (!challenge) return res.status(404).json({ message: 'Challenge not found' });
    if (!challenge.isPublic) return res.status(403).json({ message: 'Challenge is private' });
    if (challenge.status !== 'active') return res.status(400).json({ message: 'Challenge is not active' });

    const alreadyJoined = challenge.participants.some(p => p.userId.toString() === userId.toString());
    if (alreadyJoined) return res.status(409).json({ message: 'Already joined' });

    challenge.participants.push({ userId, score: 0 });
    await challenge.save();

    await GamificationPoints.create({ userId, actionType: 'join_challenge', points: 10 });

    wsService.emitChallengeUpdate(challenge.userId.toString(), {
      challengeId: challengeId,
      event: 'participant_joined',
      participantId: userId.toString()
    });

    res.json({ message: 'Joined challenge successfully', challengeId });
  } catch (error) {
    console.error('Join challenge error:', error);
    res.status(500).json({ message: 'Error joining challenge' });
  }
});

/**
 * Get challenge leaderboard
 * GET /api/challenges/:challengeId/leaderboard
 */
router.get('/:challengeId/leaderboard', authenticateToken, async (req, res) => {
  try {
    const { challengeId } = req.params;

    const challenge = await Challenge.findById(challengeId).populate('participants.userId', 'name email');
    if (!challenge) return res.status(404).json({ message: 'Challenge not found' });

    const sorted = [...challenge.participants]
      .sort((a, b) => b.score - a.score)
      .map((p, index) => ({
        id: p._id.toString(),
        userId: p.userId?._id?.toString() || p.userId?.toString(),
        username: p.userId?.name || 'Unknown',
        score: p.score,
        rank: index + 1,
        joinedAt: p.joinedAt
      }));

    // Also include the challenge creator at top if not already a participant
    res.json({
      challengeId,
      challengeName: challenge.name,
      leaderboard: sorted,
      count: sorted.length
    });
  } catch (error) {
    console.error('Get challenge leaderboard error:', error);
    res.status(500).json({ message: 'Error fetching leaderboard' });
  }
});

/**
 * Delete a challenge
 * DELETE /api/challenges/:challengeId
 */
router.delete('/:challengeId', authenticateToken, async (req, res) => {
  try {
    const { challengeId } = req.params;
    const userId = req.user._id;

    const result = await Challenge.findOneAndDelete({ _id: challengeId, userId });

    if (!result) {
      return res.status(404).json({ message: 'Challenge not found' });
    }

    res.json({ message: 'Challenge deleted' });
  } catch (error) {
    console.error('Delete challenge error:', error);
    res.status(500).json({ message: 'Error deleting challenge' });
  }
});

export default router;
