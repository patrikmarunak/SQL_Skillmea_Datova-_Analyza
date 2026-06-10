import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// base: './' kvôli vloženiu do Teams / Power Apps hostingu (relatívne cesty)
export default defineConfig({
  plugins: [react()],
  base: './',
  server: { port: 3000 },
});
