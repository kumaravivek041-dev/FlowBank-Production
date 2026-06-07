const mongoose = require('mongoose');

const ManualTransactionSchema = new mongoose.Schema({
  userId:   { type: String, required: true, index: true },
  name:     { type: String, required: true },
  amount:   { type: Number, required: true },
  date:     { type: Date, default: Date.now },
  category: { type: String, default: 'Other' },
  isDebit:  { type: Boolean, default: true },
  source:   { type: String, enum: ['manual', 'ocr'], default: 'manual' },
}, { timestamps: true });

module.exports = mongoose.model('ManualTransaction', ManualTransactionSchema);
