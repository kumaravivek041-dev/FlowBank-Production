// server.js (fixed)
const express = require("express");
const mongoose = require("mongoose");
const dotenv = require("dotenv");
dotenv.config();
const cors = require("cors");
const morgan = require("morgan");

const authRoutes = require("./routes/authRoutes");
const notificationRoutes = require("./routes/notificationRoutes");
const collabRoutes = require("./routes/collabRoutes");
const searchRoutes = require("./routes/userSearch");
const plaidRoutes = require('./routes/plaid');
const bankRoutes = require('./routes/bank');
const googleAuthRoute = require('./routes/auth/googleAuth');
const budgetGoalRoutes = require('./routes/goalSetRoutes');
const categorizationRoutes = require('./routes/categorizationRoutes');
const investmentRoutes = require('./routes/investmentRoutes');
const aiRoutes = require('./routes/aiRoutes');
const networthRoutes = require('./routes/networthRoutes');
const manualTransactionRoutes = require('./routes/manualTransactionRoutes');





// ✅ Create app FIRST before using it
const app = express();

app.set('trust proxy', 1);

// ✅ Middleware
app.use(
  cors({
    origin: true,   // allows all origins (phone APK, web, etc.)
    credentials: true,
    exposedHeaders: ["x-access-token"],
  })
);

app.use(express.json({ limit: '5mb' }));
app.use(morgan("dev"));

// ✅ Connect MongoDB
mongoose
  .connect(process.env.MONGO_URI)
  .then(() => {console.log("✅ MongoDB Connected");
    require("./cron/ledgerCron");
  })
  .catch((err) => console.error("❌ MongoDB connection error:", err));

// ✅ Routes
app.use("/api/auth", authRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/collab", collabRoutes);
app.use("/api/search", searchRoutes);
app.use('/api/plaid', plaidRoutes);
app.use('/api/bank', bankRoutes);
app.use('/api/auth', googleAuthRoute);
app.use('/api/goals', budgetGoalRoutes);
app.use('/api/categorize', categorizationRoutes);
app.use('/api/investments', investmentRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/networth', networthRoutes);
app.use('/api/manual-transactions', manualTransactionRoutes);


// ✅ Test route
app.get("/", (req, res) => res.send("API is running..."));

// ✅ Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
