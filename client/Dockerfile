FROM node:24-alpine AS builder

WORKDIR /app

RUN npm install --global pnpm@12.14.0

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

RUN pnpm install --frozen-lockfile

COPY . .

ARG VITE_APPLICATION_SERVER_URL
ENV VITE_APPLICATION_SERVER_URL=${VITE_APPLICATION_SERVER_URL}

RUN pnpm build

FROM nginx:alpine AS production

COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80