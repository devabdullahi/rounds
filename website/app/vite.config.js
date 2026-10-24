import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Relative asset paths, so the built site works from any folder (Cloudflare Pages, a preview).
export default defineConfig({ plugins: [react()], base: './' });
