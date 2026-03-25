const express = require('express');
const RunSession = require('../models/RunSession');
const router = express.Router();

// Save a run session
router.post('/', async (req, res) => {
  try {
    const run = new RunSession({ ...req.body, user: req.user._id });
    await run.save();
    res.status(201).json(run);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Get all runs for user
router.get('/', async (req, res) => {
  const runs = await RunSession.find({ user: req.user._id }).sort({ createdAt: -1 });
  res.json(runs);
});

// Get run details
router.get('/:id', async (req, res) => {
  const run = await RunSession.findOne({ _id: req.params.id, user: req.user._id });
  if (!run) return res.status(404).json({ error: 'Run not found' });
  res.json(run);
});

module.exports = router;
