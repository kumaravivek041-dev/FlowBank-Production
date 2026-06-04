FROM node:20-alpine
WORKDIR /app
COPY server/package*.json ./
RUN npm install
COPY server/ .
ENV PORT=5000
EXPOSE 5000
CMD ["node", "server.js"]
