const express = require('express');
const Club = require('../models/Club');
const User = require('../models/User');
const router = express.Router();

// Create a club
router.post('/', async (req, res) => {
  try {
    const club = new Club({ ...req.body, createdBy: req.user._id, members: [req.user._id] });
    await club.save();
    res.status(201).json(club);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// List all clubs
router.get('/', async (req, res) => {
  const clubs = await Club.find().populate('members', 'name');
  res.json(clubs);
});

// Join a club
router.post('/:id/join', async (req, res) => {
  const club = await Club.findById(req.params.id);
  if (!club) return res.status(404).json({ error: 'Club not found' });
  if (!club.members.includes(req.user._id)) {
    club.members.push(req.user._id);
    await club.save();
  }
  res.json(club);
});

// Leave a club
router.post('/:id/leave', async (req, res) => {
  const club = await Club.findById(req.params.id);
  if (!club) return res.status(404).json({ error: 'Club not found' });
  club.members = club.members.filter(m => m.toString() !== req.user._id.toString());
  await club.save();
  res.json(club);
});

// Post an event
router.post('/:id/events', async (req, res) => {
  const club = await Club.findById(req.params.id);
  if (!club) return res.status(404).json({ error: 'Club not found' });
  club.events.push(req.body);
  await club.save();
  res.json(club);
});

// Get club members
router.get('/:id/members', async (req, res) => {
  const club = await Club.findById(req.params.id).populate('members', 'name');
  if (!club) return res.status(404).json({ error: 'Club not found' });
  res.json(club.members);
});

module.exports = router;
