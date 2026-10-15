import { defineConfig } from 'vite'
import { fileURLToPath } from 'node:url'

// Resolve from this file so every deck uses the same optional user asset folder.
export default defineConfig({
  publicDir: fileURLToPath(new URL('../public', import.meta.url)),
  // Local themes need access to workspace dependencies, including KaTeX fonts.
  server: { fs: { allow: [fileURLToPath(new URL('../', import.meta.url))] } },
  // Avoid copying unrelated user assets into a presentation build.
  build: { copyPublicDir: false },
})
