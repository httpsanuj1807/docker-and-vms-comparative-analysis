# =============================================================================
# Dockerfile for Research Web Application
# Comparative Analysis of Docker Containers vs Virtual Machines
# =============================================================================
# Base image: node:18-alpine (as specified in research paper)
# Multi-stage build for minimal production image
# =============================================================================

# Stage 1: Dependencies
FROM node:18-alpine AS dependencies

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production && npm cache clean --force

# Stage 2: Production
FROM node:18-alpine AS production

# Add labels for identification
LABEL maintainer="Arham Jain, Ansh Mittal, Anuj Kumar"
LABEL description="Research web application for Docker vs VM performance comparison"
LABEL institution="Chitkara University"

# Create non-root user for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# Copy dependencies from previous stage
COPY --from=dependencies /app/node_modules ./node_modules

# Copy application code
COPY server.js ./
COPY package.json ./

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose application port
EXPOSE 3000

# Environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Health check for container orchestration
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Start the application
CMD ["node", "server.js"]
