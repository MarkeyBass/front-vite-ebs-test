# Stage 1: Build phase
FROM node:25-alpine3.22 as builder
WORKDIR /app
COPY package.json .
RUN npm install
COPY . .
RUN npm run build

# Stage 2: Run phase
FROM nginx:1.29.6 as production
WORKDIR /app


COPY --from=builder /app/build /usr/share/nginx/html

# docker build -t react-app:1 -f Dockerfile .
# docker run -p 8080:80 react-app:1

# docker build .
# docker run -p 8080:80 <container_id>
# docker stop <container_id>
# docker rm <container_id>