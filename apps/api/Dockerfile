FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json ./
RUN npm install

COPY tsconfig.json nest-cli.json ./
COPY src ./src

RUN npm run build

# ── Production ─────────────────────────────────────────────
FROM node:20-alpine

WORKDIR /app

COPY --from=builder /app/package.json ./
RUN npm install --omit=dev

COPY --from=builder /app/dist ./dist

EXPOSE 3001

CMD ["node", "dist/main"]
