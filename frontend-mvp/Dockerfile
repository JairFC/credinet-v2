# =============================================================================
# CrediNet V2 - Frontend Dockerfile
# =============================================================================
# Framework: React 18 + Vite 7.1.14 (Rolldown)
# Architecture: Feature-Sliced Design
# 
# MODOS DE EJECUCIÓN:
# - Desarrollo local: CMD ["npm", "run", "dev"]
# - Producción/Remoto: CMD ["npm", "run", "prod"] (con serve)
#
# Para cambiar el modo, usa docker-compose.override.yml o variable FRONTEND_MODE
# =============================================================================

FROM node:20-alpine

# Metadata
LABEL maintainer="CrediNet Team"
LABEL version="2.0.0"
LABEL description="CrediNet V2 Frontend - React 18 + Vite"

# Instalar serve globalmente para modo producción
RUN npm install -g serve

# Establecer directorio de trabajo
WORKDIR /app

# Variables de entorno
ENV VITE_HOST=0.0.0.0
ENV VITE_PORT=5173

# Build args para Vite (se pasan en build-time)
ARG VITE_API_URL=http://10.5.26.141:8000
ARG VITE_APP_NAME=CrediCuenta
ARG VITE_APP_VERSION=2.0.0

# Copiar archivos de dependencias primero (para aprovechar cache de Docker)
COPY package.json package-lock.json ./

# Instalar TODAS las dependencias (incluyendo devDeps para build)
RUN npm ci --prefer-offline --no-audit --include=dev

# Copiar el resto de los archivos del proyecto
COPY . .

# Build para producción con variables de entorno
# IMPORTANTE: Las variables VITE_* deben estar disponibles durante el build
ENV VITE_API_URL=$VITE_API_URL
ENV VITE_APP_NAME=$VITE_APP_NAME
ENV VITE_APP_VERSION=$VITE_APP_VERSION
RUN npm run build

# Exponer puerto
EXPOSE 5173

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5173', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Por defecto: modo producción (funciona con acceso remoto)
# Para desarrollo local, cambiar a: ["npm", "run", "dev"]
CMD ["serve", "-s", "dist", "-l", "5173"]
