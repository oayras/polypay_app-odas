FROM node:20-alpine AS builder

WORKDIR /app

# Accept build arguments
ARG NEXT_PUBLIC_API_URL

# Set as environment variables
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL

RUN corepack enable

COPY package.json yarn.lock .yarnrc.yml ./

RUN echo 'nodeLinker: node-modules' > .yarnrc.yml

COPY packages/shared ./packages/shared
COPY packages/nextjs ./packages/nextjs

RUN yarn install
RUN yarn workspace @polypay/shared build
RUN yarn workspace @polypay/frontend build

FROM node:20-alpine AS runner

WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/packages/nextjs/.next/standalone ./

COPY --from=builder /app/packages/nextjs/.next/static ./packages/nextjs/.next/static
COPY --from=builder /app/packages/nextjs/public ./packages/nextjs/public

EXPOSE 3000

CMD ["node", "packages/nextjs/server.js"]