FROM node:16-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install && npm install -g nodemon
COPY . .
EXPOSE 5000
CMD ["npm", "run", "dev"]