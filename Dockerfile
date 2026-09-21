FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production PORT=8080 COMMERCE=true
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --chown=node:node src ./src
COPY --chown=node:node data ./data
COPY --chown=node:node web ./web
COPY --chown=node:node assets ./assets
USER node
EXPOSE 8080
CMD ["node","src/server.mjs"]
