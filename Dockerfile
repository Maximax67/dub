# ---------- deps (install workspace deps with cache) ----------
FROM node:20-alpine AS deps
WORKDIR /app

RUN apk add --no-cache libc6-compat
RUN npm install -g pnpm

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json ./

COPY packages ./packages
COPY apps ./apps

RUN pnpm install

# ---------- builder ----------
FROM node:20-alpine AS builder
WORKDIR /app

RUN apk add --no-cache libc6-compat
RUN npm install -g pnpm dotenv-cli

COPY --from=deps /app /app
COPY . .

ENV NODE_ENV=production
ENV TURBO_TELEMETRY_DISABLED=1
ENV NEXT_TELEMETRY_DISABLED=1

RUN --mount=type=secret,id=web_env,target=/run/secrets/.env \
    dotenv -e /run/secrets/.env -- pnpm turbo run build --filter=web...

# ---------- runner (standalone production image) ----------
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=8888
ENV HOST=0.0.0.0

COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=builder /app/apps/web/public ./apps/web/public

EXPOSE 8888

CMD ["node", "apps/web/server.js"]
