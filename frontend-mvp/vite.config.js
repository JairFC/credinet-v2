import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    host: '0.0.0.0', // Exponer en todas las interfaces de red
    port: 5173, // Puerto estándar de Vite (para Docker)
    strictPort: false, // Buscar otro puerto si está ocupado
    open: false, // No abrir browser automáticamente
    watch: {
      usePolling: true, // Necesario para hot-reload en Docker
    },
  },
})
