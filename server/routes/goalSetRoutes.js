// routes/budgetGoals.js
const express = require("express");
const router = require('express').Router();
const {HighLimiter, MediumLimiter, ModerateLimiter} = require('./rateLimiter.js');
const protect = require('../middleware/middleware.js');

const BudgetGoal = require('../models/BudgetGoal.js');

router.post('/goal-set', protect, ModerateLimiter,async (req, res) => {
  try {
    const goal = await BudgetGoal.create({ ...req.body, userId: req.user._id.toString() });
    res.status(201).json(goal);
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
});

router.get('/my-goals', protect, async (req, res) => {
  try {
    const goals = await BudgetGoal.find({ userId: req.user._id }).sort({ createdAt: -1 });
    res.json(goals);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.patch('/:id/add-spend', protect, ModerateLimiter, async (req, res) => {
  try {
    const { amount } = req.body;
    if (typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({ message: 'amount must be a positive number' });
    }
    const goal = await BudgetGoal.findOneAndUpdate(
      { _id: req.params.id, userId: req.user._id },
      { $inc: { currentSpend: amount } },
      { new: true }
    );
    if (!goal) return res.status(404).json({ message: 'Goal not found' });
    res.json(goal);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

module.exports = router;