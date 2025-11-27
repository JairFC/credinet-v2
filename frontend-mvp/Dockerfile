# =============================================================================
# CrediNet V2 - Frontend Dockerfile
# =============================================================================
# Framework: React 18 + Vite 7.1.14 (Rolldown)
# Architecture: Feature-Sliced Design
# Estado: Sprint 7 - Auth + Dashboard completado
# =============================================================================

FROM node:20-alpine

# Metadata
LABEL maintainer="CrediNet Team"
LABEL version="2.0.0"
LABEL description="CrediNet V2 Frontend - React 18 + Vite"

# Establecer directorio de trabajo
WORKDIR /app

# Variables de entorno para optimización
ENV NODE_ENV=development
ENV VITE_HOST=0.0.0.0
ENV VITE_PORT=5173

# Copiar archivos de dependencias primero (para aprovechar cache de Docker)
COPY package.json package-lock.json ./

# Instalar dependencias
RUN npm ci --prefer-offline --no-audit

# Copiar el resto de los archivos del proyecto
COPY . .

# Exponer puerto de Vite
EXPOSE 5173

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5173', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Comando de desarrollo con hot-reload
CMD ["npm", "run", "dev"]
