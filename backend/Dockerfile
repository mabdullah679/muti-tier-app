# Use the official Node.js image as the base image
FROM node:14

# Set the working directory in the container
WORKDIR /app

# Copy backend package.json and package-lock.json
COPY package*.json ./

# Install backend dependencies
RUN npm install

# Copy the rest of the backend files
COPY . .

# Expose the backend port (e.g., 3001)
EXPOSE 3001

# Start the backend server
CMD ["npm", "start"]
