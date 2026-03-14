FROM node:25-alpine3.22

WORKDIR /app

COPY package.json .

RUN npm install

COPY . .

CMD ["npm", "run", "start"]