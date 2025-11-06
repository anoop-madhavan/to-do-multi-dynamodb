# Build stage
FROM node:18-alpine as build

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Set build-time environment variables
ARG REACT_APP_NAME=Todo SaaS
ARG REACT_APP_DESCRIPTION=Simple, clean, and efficient task management
ARG REACT_APP_API_URL=/api

# Set environment variables for build
ENV REACT_APP_NAME=$REACT_APP_NAME
ENV REACT_APP_DESCRIPTION=$REACT_APP_DESCRIPTION
ENV REACT_APP_API_URL=$REACT_APP_API_URL

# Build the app
RUN npm run build

# Production stage
FROM nginx:alpine

# Install gettext for envsubst
RUN apk add --no-cache gettext

# Copy built app from build stage
COPY --from=build /app/build /usr/share/nginx/html

# Copy nginx configuration template
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

# Set default backend URL for Docker Compose (can be overridden via env var)
ENV BACKEND_URL=backend

# Expose port
EXPOSE 3000

# Start nginx (envsubst will process the template automatically)
CMD ["nginx", "-g", "daemon off;"]
