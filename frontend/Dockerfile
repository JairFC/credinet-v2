FROM node:18

WORKDIR /app

# Copiar package.json y package-lock.json primero para cache de dependencias
COPY package*.json ./

RUN npm install

# Copiar el resto de los archivos
COPY . .

# Exponer el puerto
EXPOSE 5173

# Comando de desarrollo con hot-reload
CMD ["npm", "run", "dev", "--", "--host"]
