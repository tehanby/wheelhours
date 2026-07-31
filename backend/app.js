const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth');
const taskRoutes = require('./routes/task');
const timeLoggingRoutes = require('./routes/time_logging');

const app = express();
const port = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/time-logging', timeLoggingRoutes);

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
