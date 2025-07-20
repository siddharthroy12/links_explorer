# client/Dockerfile
FROM node:20-slim

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build the SvelteKit app
RUN npm run build

# Expose port
EXPOSE 3000

# Start the application
CMD ["node", "build"]