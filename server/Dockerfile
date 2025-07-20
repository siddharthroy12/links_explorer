# server/Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for Chromium and zendriver
RUN apt-get update && apt-get install -y \
    chromium \
    chromium-driver \
    curl \
    gcc \
    libnss3 \
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
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

# Set Chromium path for zendriver
ENV CHROME_BIN=/usr/bin/chromium

# Expose port
EXPOSE 5000

# Start the Flask app
CMD ["python", "main.py"]