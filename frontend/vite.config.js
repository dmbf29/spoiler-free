import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // 5173 is often taken by other local projects; pin a dedicated port and
    // fail loudly rather than silently drifting to another one.
    port: 5180,
    strictPort: true,
    // Proxy API calls to the Rails backend so the browser only ever talks to
    // this origin (no CORS needed in dev, and no YouTube API access from React).
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
})
