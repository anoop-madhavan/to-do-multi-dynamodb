import React, { useState, useEffect } from 'react';
import './App.css';

interface Todo {
  id: number;
  text: string;
  createdAt: string;
}

const API_BASE_URL = process.env.REACT_APP_API_URL || '/api';
const APP_NAME = process.env.REACT_APP_NAME || 'Todo SaaS';
const APP_DESCRIPTION = process.env.REACT_APP_DESCRIPTION || 'Simple, clean, and efficient task management';

const App: React.FC = () => {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [newTodo, setNewTodo] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Fetch todos from API
  const fetchTodos = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await fetch(`${API_BASE_URL}/todos`);
      
      if (!response.ok) {
        throw new Error('Failed to fetch todos');
      }
      
      const data = await response.json();
      setTodos(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  // Add new todo
  const addTodo = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!newTodo.trim()) {
      setError('Please enter a todo item');
      return;
    }

    try {
      setError(null);
      setSuccess(null);
      const response = await fetch(`${API_BASE_URL}/todos`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text: newTodo.trim() }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to add todo');
      }

      const newTodoItem = await response.json();
      setTodos([...todos, newTodoItem]);
      setNewTodo('');
      setSuccess('Todo added successfully!');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to add todo');
    }
  };

  // Delete todo
  const deleteTodo = async (id: number) => {
    try {
      setError(null);
      setSuccess(null);
      const response = await fetch(`${API_BASE_URL}/todos/${id}`, {
        method: 'DELETE',
      });

      if (!response.ok) {
        throw new Error('Failed to delete todo');
      }

      setTodos(todos.filter(todo => todo.id !== id));
      setSuccess('Todo deleted successfully!');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete todo');
    }
  };

  // Load todos on component mount
  useEffect(() => {
    fetchTodos();
  }, []);

  // Clear success message after 3 seconds
  useEffect(() => {
    if (success) {
      const timer = setTimeout(() => setSuccess(null), 3000);
      return () => clearTimeout(timer);
    }
  }, [success]);

  return (
    <div className="container">
      <div className="header">
        <h1>{APP_NAME}</h1>
        <p>{APP_DESCRIPTION}</p>
      </div>

      {error && (
        <div className="error">
          {error}
        </div>
      )}

      {success && (
        <div className="success">
          {success}
        </div>
      )}

      <form onSubmit={addTodo} className="todo-form">
        <div className="form-group">
          <input
            type="text"
            value={newTodo}
            onChange={(e) => setNewTodo(e.target.value)}
            placeholder="Add a new todo..."
            className="form-input"
            disabled={loading}
          />
          <button 
            type="submit" 
            className="btn btn-primary"
            disabled={loading || !newTodo.trim()}
          >
            {loading ? 'Adding...' : 'Add Todo'}
          </button>
        </div>
      </form>

      <div className="todo-list">
        {loading && todos.length === 0 ? (
          <div className="loading">Loading todos...</div>
        ) : todos.length === 0 ? (
          <div className="empty-state">
            <h3>No todos yet</h3>
            <p>Add your first todo above to get started!</p>
          </div>
        ) : (
          todos.map((todo) => (
            <div key={todo.id} className="todo-item">
              <div>
                <div className="todo-text">{todo.text}</div>
                <div className="todo-meta">
                  Created: {new Date(todo.createdAt).toLocaleString()}
                </div>
              </div>
              <button
                onClick={() => deleteTodo(todo.id)}
                className="btn btn-danger"
                disabled={loading}
              >
                Delete
              </button>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default App;
