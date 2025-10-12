# Todo SaaS Application

A simple Todo SaaS application built with React (TypeScript) frontend and Node.js (Express) backend, both containerized with Docker.

## Features

- ✅ Add, list, and delete todos
- 🚀 RESTful API with proper error handling
- 🐳 Docker containerization for both frontend and backend
- 🔄 In-memory storage (ephemeral, resets on container restart)
- 🎨 Clean, modern UI with responsive design
- 🌐 CORS configured for cross-origin requests
- ⚙️ Environment-based configuration for app name and settings

## Architecture

- **Frontend**: React + TypeScript, served by Nginx
- **Backend**: Node.js + Express API
- **Storage**: In-memory (no external database)
- **Containerization**: Docker + Docker Compose

## API Endpoints

- `GET /api/todos` - List all todos
- `POST /api/todos` - Add a new todo (JSON body: `{ text: string }`)
- `DELETE /api/todos/:id` - Delete a todo by ID
- `GET /api/health` - Health check endpoint

## Quick Start

1. **Clone and navigate to the project directory:**
   ```bash
   cd to-do-multi-saas
   ```

2. **Build and start the application:**
   ```bash
   docker-compose up --build
   ```

3. **Access the application:**
   - Frontend: http://localhost:3700
   - Backend API: http://localhost:4000/api

4. **Stop the application:**
   ```bash
   docker-compose down
   ```

## Configuration

The application uses a **single root-level environment file** following Docker Compose best practices:

### Main Configuration (`.env`)
```env
# Application Configuration
APP_NAME=Todo SaaS
APP_DESCRIPTION=Simple, clean, and efficient task management

# Backend Configuration
BACKEND_PORT=4000
NODE_ENV=production

# Frontend Configuration
FRONTEND_PORT=3700
REACT_APP_API_URL=http://localhost:4000/api
```

### Benefits of Root-Level Environment File:
- ✅ **Single source of truth** - All configuration in one place
- ✅ **Easier management** - No need to maintain multiple files
- ✅ **Better for CI/CD** - Simpler deployment configuration
- ✅ **Docker Compose best practice** - Standard pattern for multi-service apps
- ✅ **Environment inheritance** - Services can share common variables

**To customize:**
1. Edit `.env` with your desired values
2. Restart the application: `docker-compose down && docker-compose up -d`

**Example file provided:**
- `env.example` - Copy to `.env` and customize

## Development

### Backend Development

```bash
cd backend
npm install
npm run dev
```

The backend will run on http://localhost:4000

### Frontend Development

```bash
cd frontend
npm install
npm start
```

The frontend will run on http://localhost:3000 (or 3700 when using Docker)

## Docker Commands

- **Build and start**: `docker-compose up --build`
- **Start in background**: `docker-compose up -d`
- **Stop**: `docker-compose down`
- **View logs**: `docker-compose logs -f`
- **Rebuild specific service**: `docker-compose up --build frontend`

## Project Structure

```
to-do-multi-saas/
├── backend/
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── package.json
│   ├── public/
│   │   └── index.html
│   └── src/
│       ├── App.tsx
│       ├── App.css
│       ├── index.tsx
│       └── index.css
├── docker-compose.yml
└── README.md
```

## Notes

- Todos are stored in-memory and will be lost when the backend container restarts
- The frontend proxies API requests to the backend through Nginx
- CORS is properly configured for cross-origin requests
- The application is production-ready for learning deployment scenarios
