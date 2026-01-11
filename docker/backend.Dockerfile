# --- Etapa 1: Dependencias ---
FROM node:24-alpine AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Habilitamos Corepack y le decimos que ignore el yarn-path local
RUN corepack enable
ENV YARN_IGNORE_PATH=1

# Copiamos los archivos de definición de dependencias
# El asterisco en .yarnrc.yml* evita que falle si el archivo no existe
COPY package.json yarn.lock .yarnrc.yml* ./
COPY packages/shared/package.json ./packages/shared/
COPY packages/backend/package.json ./packages/backend/

# Forzamos el uso de node-modules (más compatible con Docker) 
# y evitamos que Yarn intente actualizar el lockfile
RUN echo 'nodeLinker: node-modules' > .yarnrc.yml && \
    yarn install

# --- Etapa 2: Builder ---
FROM node:24-alpine AS builder
WORKDIR /app
RUN corepack enable
ENV YARN_IGNORE_PATH=1

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# 1. Instalamos el plugin necesario para 'workspaces focus'
RUN yarn plugin import workspace-tools

# 2. Build de los paquetes
RUN yarn workspace @polypay/shared build
RUN DATABASE_URL="postgresql://dummy:dummy@localhost:5432/dummy" \
    yarn workspace @polypay/backend prisma generate
RUN yarn workspace @polypay/backend build

# 3. Ahora sí funcionará: dejamos solo dependencias de producción
RUN yarn workspaces focus @polypay/backend --production

# --- Etapa 3: Runner (Imagen Final) ---
FROM node:24-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN apk add --no-cache openssl

# Copiamos solo lo esencial
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/packages/shared/dist ./packages/shared/dist
COPY --from=builder /app/packages/shared/package.json ./packages/shared/package.json
COPY --from=builder /app/packages/backend/dist ./packages/backend/dist
COPY --from=builder /app/packages/backend/package.json ./packages/backend/package.json
COPY --from=builder /app/packages/backend/prisma ./packages/backend/prisma

EXPOSE 4000

CMD ["sh", "-c", "npx prisma migrate deploy && node packages/backend/dist/main"]