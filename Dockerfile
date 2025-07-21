# Multi-stage Dockerfile for SvelteKit + Flask
FROM oven/bun:1-alpine AS client-builder

WORKDIR /app/client

# Copy client package files
COPY client/package.json client/bun.lockb* ./

# Install client dependencies
RUN bun install --frozen-lockfile

# Copy client source and build
COPY client/ ./
RUN bun run build

# Main image with Python and system dependencies
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for Chromium, Node.js, and other tools
RUN apt-get update && apt-get install -y \
    chromium \
    chromium-driver \
    curl \
    gcc \
    libnss3 \
    unzip \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libxss1 \
    libasound2 \
    libatspi2.0-0 \
    libgtk-3-0 \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Bun in the main image
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

# Copy and install server dependencies
COPY server/requirements.txt ./server/
RUN pip install --no-cache-dir -r server/requirements.txt

# Copy server code
COPY server/ ./server/

# Copy built client from builder stage
COPY --from=client-builder /app/client/build ./client/build
COPY --from=client-builder /app/client/package.json ./client/

# Copy client source (needed for package.json and any runtime files)
COPY client/package.json ./client/

# Configure Nginx for serving client
COPY nginx.conf /etc/nginx/nginx.conf

# Create nginx log directory and set permissions
RUN mkdir -p /var/log/nginx && \
    touch /var/log/nginx.access.log /var/log/nginx.error.log && \
    chmod 644 /var/log/nginx.access.log /var/log/nginx.error.log

# Configure Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set Chromium path for zendriver
ENV CHROME_BIN=/usr/bin/chromium

# Expose ports
EXPOSE 80 5000

# Start supervisor (manages both services)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]