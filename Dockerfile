# Main image with Python and system dependencies
FROM python:3.11-slim

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

# Install Node.js in the main image
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

WORKDIR /app/client

# Copy client package files
COPY client/package.json client/package-lock.json* ./

# Install client dependencies
RUN npm install

# Copy client source and build
COPY client/ ./
RUN echo 'PUBLIC_API_URL="http://localhost:5000"' > .env
RUN npm run build

WORKDIR /app


# Copy and install server dependencies
COPY server/requirements.txt ./server/
RUN pip install --no-cache-dir -r server/requirements.txt

# Copy server code
COPY server/ ./server/

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