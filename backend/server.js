const express = require('express');
const app = express();
const port = 3001;

app.use(express.json());

// Dummy data endpoint for demonstration purposes
app.get('/api/data', (req, res) => {
  const dummyData = {
    message: 'Welcome to the API',
    items: [1, 2, 3, 4, 5]
  };
  res.json(dummyData);
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
