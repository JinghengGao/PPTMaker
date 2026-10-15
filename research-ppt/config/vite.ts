import { defineConfig } from 'vite'
import { fileURLToPath } from 'node:url'

// Location is relative to this helper, independent of the selected deck entry.
export default defineConfig({
  publicDir: fileURLToPath(new URL('../public', import.meta.url)),
  build: { copyPublicDir: false },
})
