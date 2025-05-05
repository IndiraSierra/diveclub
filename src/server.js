const express = require('express');
const cors = require('cors');
require('dotenv').config();

const sequelize = require('./config/sequelize');
const router = require('./routes/api/router');

const app = express();
const PORT = process.env.PORT || 5000;

// Middlewares
app.use(cors());
app.use(express.json());

// Test route
app.get('/', (req, res) => {
  res.send('DiveClub API is properly working!');
});

// API routes
app.use('/api', router);

// Sync database and start server
sequelize.sync({ force: false })
  .then(() => {
    console.log('✅ Database synchronized successfully.');
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Server running on http://0.0.0.0:${PORT}`);
    });
  })
  .catch(err => {
    console.error('❌ Error synchronizing database:', err);
  });
