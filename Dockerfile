# ════════════════════════════════════════════════════════════════
# Dinacharya Analyzer — Multi-stage Production Dockerfile
# Stage 1: Build dependencies
# Stage 2: Production image (minimal, secure)
# ════════════════════════════════════════════════════════════════

# ── Stage 1: Builder ──────────────────────────────────────────────
FROM node:18-alpine AS builder

# Add metadata labels (best practice)
LABEL maintainer="Kunal"
LABEL description="Dinacharya Vedic Routine Analyzer"
LABEL version="1.0.0"

# Set working directory
WORKDIR /app

# Copy package files first (Docker layer caching optimization)
# This layer only rebuilds when package.json changes, not on code changes
COPY package*.json ./

# Install only production dependencies
RUN npm ci --only=production && npm cache clean --force

# ── Stage 2: Production ───────────────────────────────────────────
FROM node:18-alpine AS production

# Security: run as non-root user (best practice for containers)
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

WORKDIR /app

# Copy only what we need from builder (keeps image small)
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=appuser:appgroup backend/ ./backend/
COPY --chown=appuser:appgroup frontend/ ./frontend/
COPY --chown=appuser:appgroup package.json ./

# Switch to non-root user
USER appuser

# Expose application port
EXPOSE 3000

# Health check (Docker will mark container unhealthy if this fails)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode === 200 ? 0 : 1))"

# Environment variables with defaults
ENV NODE_ENV=production \
    PORT=3000

# Start the application
CMD ["node", "backend/server.js"]
