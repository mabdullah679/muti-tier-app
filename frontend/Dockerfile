FROM node:16-alpine as build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
FROM nginx:alpine
COPY /path/to/your/built/files /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
