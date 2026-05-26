# ─── Stage 1 : Build ───────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Copier uniquement package.json d'abord (optimise le cache Docker)
COPY package.json ./

# Installer les dépendances
RUN npm install --omit=dev

# ─── Stage 2 : Runtime ─────────────────────────────────────────
FROM node:20-alpine AS runtime

# Sécurité : ne pas tourner en root
RUN addgroup -S nexaretail && adduser -S nexaretail -G nexaretail

WORKDIR /app

# Copier uniquement ce qui est nécessaire depuis le stage builder
COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/
COPY package.json ./

# Changer le propriétaire des fichiers
RUN chown -R nexaretail:nexaretail /app

# Basculer sur l'utilisateur non-root
USER nexaretail

# Variables d'environnement
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

# Health check intégré à Docker
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/index.js"]
