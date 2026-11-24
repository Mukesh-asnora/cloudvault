import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    // In local dev without the gateway running you can proxy straight to it
    proxy: {
      '/auth': 'http://localhost:8080',
      '/files': 'http://localhost:8080',
      '/metadata': 'http://localhost:8080'
    }
  }
});