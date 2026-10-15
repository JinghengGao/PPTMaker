import fs from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

let failed = false
const check = async (name, run) => {
  try { console.log(`[OK] ${name}: ${await run()}`) }
  catch (error) { console.error(`[MISSING] ${name}: ${error.message}`); failed = true }
}
await check('Node >=22.12', () => {
  const [major, minor] = process.versions.node.split('.').map(Number)
  if (major < 22 || major === 22 && minor < 12) throw new Error('Upgrade Node to >=22.12')
  return process.versions.node
})
await check('Slidev editable PPTX', async () => {
  const root = new URL('../node_modules/@slidev/cli/', import.meta.url)
  const pkg = JSON.parse(await fs.readFile(new URL('package.json', root), 'utf8'))
  const cli = await fs.readFile(new URL('dist/cli.mjs', root), 'utf8')
  if (!cli.includes('pptx-editable')) throw new Error('CLI does not support pptx-editable')
  return pkg.version
})
await check('Chromium launch', async () => {
  const { chromium } = await import('playwright-chromium')
  const browser = await chromium.launch({ headless: true })
  try { return `${browser.version()} (${fileURLToPath(new URL('../', import.meta.url))})` }
  finally { await browser.close() }
})
process.exitCode = failed ? 1 : 0
