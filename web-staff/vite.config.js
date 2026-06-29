import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
// Staff portal runs on its own port and proxies /api to the Node backend.
export default defineConfig({
    plugins: [react()],
    server: {
        port: 5174,
        proxy: {
            '/api': { target: 'http://localhost:3000', changeOrigin: true },
        },
    },
});
