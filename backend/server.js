const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 4000;
const APP_NAME = process.env.APP_NAME || 'Todo SaaS';
const APP_DESCRIPTION = process.env.APP_DESCRIPTION || 'Simple, clean, and efficient task management';

// Middleware
app.use(cors());
app.use(express.json());

// In-memory storage for todos
let todos = [];
let nextId = 1;

// Routes
app.get('/api/todos', (req, res) => {
  res.json(todos);
});

app.post('/api/todos', (req, res) => {
  const { text } = req.body;
  
  if (!text || typeof text !== 'string' || text.trim() === '') {
    return res.status(400).json({ error: 'Text is required and must be a non-empty string' });
  }

  const newTodo = {
    id: nextId++,
    text: text.trim(),
    createdAt: new Date().toISOString()
  };

  todos.push(newTodo);
  res.status(201).json(newTodo);
});

app.delete('/api/todos/:id', (req, res) => {
  const id = parseInt(req.params.id);
  
  if (isNaN(id)) {
    return res.status(400).json({ error: 'Invalid todo ID' });
  }

  const todoIndex = todos.findIndex(todo => todo.id === id);
  
  if (todoIndex === -1) {
    return res.status(404).json({ error: 'Todo not found' });
  }

  todos.splice(todoIndex, 1);
  res.status(204).send();
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    app: APP_NAME,
    description: APP_DESCRIPTION
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT}`);
});
