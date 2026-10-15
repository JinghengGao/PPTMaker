import { chromium } from 'playwright-chromium'
import fs from 'node:fs/promises'
import path from 'node:path'

const [baseRaw, output, countRaw, knownIssueFlag] = process.argv.slice(2)
if (knownIssueFlag && knownIssueFlag !== '--allow-known-toolchain-issues') throw new Error('Unknown QA option')
if (!baseRaw || !output || !/^[1-9]\d*$/.test(countRaw || '')) {
  throw new Error('Usage: node qa-deck.mjs <local-preview-url> <output-directory> <slide-count>')
}
const base = new URL(baseRaw)
if (base.protocol !== 'http:' || !['localhost', '127.0.0.1'].includes(base.hostname) || base.pathname !== '/' || base.search || base.hash || base.username || base.password) {
  throw new Error('Use a local HTTP preview root')
}
const count = Number(countRaw)
await fs.mkdir(output, { recursive: true })
const browser = await chromium.launch({ headless: true })
const report = {
  checked_at: new Date().toISOString(), browser: browser.version(),
  browserPlugin: 'Browser plugin not available; using project Playwright',
  base: base.href, viewport: { width: 1600, height: 900 },
  slides: [], errors: [], warnings: [], failedRequests: [], interaction: {},
  manual_visual_review: 'required',
}
try {
  const page = await browser.newPage({ viewport: report.viewport, deviceScaleFactor: 1 })
  page.on('pageerror', e => report.errors.push({ type: 'pageerror', text: e.message }))
  page.on('console', m => {
    if (m.type() === 'error') report.errors.push({ type: 'console', text: m.text() })
    if (['warning', 'warn'].includes(m.type())) report.warnings.push(m.text())
  })
  page.on('response', r => { if (r.status() >= 400) report.failedRequests.push({ url: r.url(), status: r.status() }) })
  page.on('requestfailed', r => report.failedRequests.push({ url: r.url(), error: r.failure()?.errorText }))
  const record = () => page.evaluate(() => {
    const root = [...document.querySelectorAll('.slidev-layout')].find(e => e.checkVisibility() && e.getBoundingClientRect().width > 10)
    if (!root) throw new Error('No visible slide')
    const rr = root.getBoundingClientRect(), issues = []
    for (const e of root.querySelectorAll('h1,h2,h3,p,li,img,table,pre,[data-qa-content]')) {
      const rect = e.getBoundingClientRect()
      if (!e.checkVisibility() || rect.width === 0 || rect.height === 0 || e.closest('.katex')) continue
      if (rect.left < rr.left - 2 || rect.right > rr.right + 2 || rect.top < rr.top - 2 || rect.bottom > rr.bottom + 2) issues.push({ kind: 'canvas-overflow', tag: e.tagName, text: e.innerText?.slice(0, 90) })
      if (e.scrollWidth > e.clientWidth + 2) issues.push({ kind: 'horizontal-overflow', tag: e.tagName, text: e.innerText?.slice(0, 90) })
      const content = e.closest('main,[data-qa-content]')
      if (content && rect.bottom > content.getBoundingClientRect().bottom + 2) issues.push({ kind: 'content-zone-overflow', tag: e.tagName })
    }
    const images = [...root.querySelectorAll('img')].map(e => ({ src: e.src, loaded: e.complete && e.naturalWidth > 0 }))
    return {
      url: location.href, title: document.title, class: root.className, text: root.innerText,
      blank: !root.innerText.trim() && !root.querySelector('img,svg,canvas,video'),
      overlay: !!document.querySelector('vite-error-overlay'), issues, images,
      katex: root.querySelectorAll('.katex').length, katexErrors: root.querySelectorAll('.katex-error').length,
      fonts: [...root.querySelectorAll('h1,p')].slice(0, 5).map(e => ({ font: getComputedStyle(e).fontFamily, size: getComputedStyle(e).fontSize })),
    }
  })
  for (let i = 1; i <= count; i++) {
    await page.goto(new URL(String(i), base).href, { waitUntil: 'networkidle', timeout: 60000 })
    await page.evaluate(() => document.fonts.ready)
    await page.mouse.move(1550, 30)
    await page.waitForTimeout(400)
    const slide = await record()
    const active = page.locator('.slidev-layout').filter({ visible: true }).first()
    await active.screenshot({ path: path.join(output, `slide-${String(i).padStart(2, '0')}.png`) })
    report.slides.push({ page: i, ...slide })
    console.log(`Page ${i}: issues=${slide.issues.length}, images=${slide.images.length}`)
  }
  await page.goto(new URL('1', base).href, { waitUntil: 'networkidle' })
  if (count > 1) {
    // Down/Up navigate whole slides even when click steps are present.
    await page.keyboard.press('ArrowDown')
    await page.waitForURL('**/2', { timeout: 10000 })
    report.interaction.next = page.url()
    await page.keyboard.press('ArrowUp')
    await page.waitForURL('**/1', { timeout: 10000 })
    report.interaction.previous = page.url()
  } else { report.interaction.skipped = 'Single-slide deck' }
  await page.setViewportSize({ width: 390, height: 844 })
  await page.screenshot({ path: path.join(output, 'mobile-letterbox.png') })
  report.mobile = await record()
  // Opt-in only: preserve full errors, classify the reproduced dependency failure.
  // Never accept an arbitrary application error or suppress errors by a broad substring.
  const pkg = JSON.parse(await fs.readFile(new URL('../node_modules/@slidev/cli/package.json', import.meta.url), 'utf8'))
  report.knownToolchainIssues = report.errors.filter(e => pkg.version === '53.0.0' && e.type === 'console'
    && e.text.startsWith("Failed to patch FloatingVue TypeError: Cannot read properties of undefined (reading 'Popper')")
    && e.text.includes('/@shikijs/vitepress-twoslash/'))
  report.acceptedKnownIssues = knownIssueFlag === '--allow-known-toolchain-issues'
  const blockingErrors = report.acceptedKnownIssues ? report.errors.filter(e => !report.knownToolchainIssues.includes(e)) : report.errors
  report.status = report.slides.some(s => s.blank || s.overlay || s.issues.length || s.images.some(i => !i.loaded) || s.katexErrors)
    || report.mobile.blank || report.mobile.overlay || report.mobile.issues.length || blockingErrors.length || report.failedRequests.length
    ? 'failed' : report.knownToolchainIssues.length ? 'passed_with_known_toolchain_issue' : 'passed'
} catch (error) { report.status = 'failed'; report.fatal = error.message }
finally {
  await fs.writeFile(path.join(output, 'browser-qa.json'), JSON.stringify(report, null, 2))
  await browser.close()
}
process.exitCode = report.status.startsWith('passed') ? 0 : 1
