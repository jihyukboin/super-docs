import { createServer } from 'node:http';
import { readFile, writeFile } from 'node:fs/promises';
import { resolve, extname } from 'node:path';
import { execFileSync } from 'node:child_process';
import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
execFileSync('python3', ['tests/docx/make-fixture.py']);
const root = resolve('.build/web');
const server = createServer(async (req, res) => {
  const file = resolve(root, '.' + new URL(req.url, 'http://localhost').pathname);
  try {
    if (!file.startsWith(root + '/')) throw Error();
    res.setHeader('Content-Type', ({ '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.wasm': 'application/wasm' })[extname(file)] || 'application/octet-stream');
    res.end(await readFile(file));
  } catch { res.writeHead(404); res.end(); }
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const browser = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1220, height: 860 });
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') console.error(m.text()); });
  await page.goto(`http://127.0.0.1:${server.address().port}/docx/index.html`);
  await page.waitForFunction(() => !!window.superDocs);
  const bytes = (await readFile('.build/native-tests/sample.docx')).toString('base64');
  const loaded = await page.evaluate(bytes => window.superDocs.load(bytes, 'sample.docx'), bytes);
  assert.ok(loaded.pages >= 1);
  const body = () => page.$eval('.docx-pages', e => e.textContent);
  assert.ok((await body()).includes('첫 번째 셀'));
  await page.waitForSelector('.docx-pages img');
  await page.keyboard.type('DOCX edited ');
  await page.waitForFunction(() => window.superDocs.state().dirty);
  assert.ok((await body()).includes('DOCX edited'));
  await page.evaluate(() => window.superDocs.command('edit:undo'));
  assert.ok(!(await body()).includes('DOCX edited'));
  await page.evaluate(() => window.superDocs.command('edit:redo'));
  assert.ok((await body()).includes('DOCX edited'));
  await page.evaluate(() => {
    const data = new DataTransfer(); data.setData('text/plain', '한글 저장 검증 ');
    document.querySelector('.docx-pages').dispatchEvent(new ClipboardEvent('paste', { clipboardData: data, bubbles: true, cancelable: true }));
  });
  await page.waitForFunction(() => document.querySelector('.docx-pages').textContent.includes('한글 저장 검증'));
  const cell = await page.evaluate(() => {
    const element = [...document.querySelectorAll('.docx-pages *')].reverse().find(e => e.textContent === '첫 번째 셀');
    if (!element) throw new Error('Table cell not rendered');
    const rect = element.getBoundingClientRect();
    return { x: rect.x + 2, y: rect.y + rect.height / 2 };
  });
  await page.mouse.click(cell.x, cell.y);
  await page.keyboard.type('Cell edited ');
  await page.waitForFunction(() => document.querySelector('.docx-pages').textContent.includes('Cell edited'));
  const output = await page.evaluate(() => window.superDocs.export('docx'));
  await writeFile('.build/native-tests/edited.docx', Buffer.from(output, 'base64'));
  await page.evaluate(() => window.superDocs.saved('edited.docx'));
  assert.equal((await page.evaluate(() => window.superDocs.state())).dirty, false);
  await page.evaluate(bytes => window.superDocs.load(bytes, 'edited.docx'), output);
  assert.ok((await body()).includes('한글 저장 검증'));
  await page.screenshot({ path: '.build/native-tests/docx.png' });
  execFileSync('python3', ['tests/docx/verify-files.py']);
  assert.deepEqual(errors, []);
  await assert.rejects(page.evaluate(() => window.superDocs.load(btoa('invalid DOCX'), 'invalid.docx')), /DOCX/);
  console.log('PASS: DOCX keyboard, Korean paste, undo/redo, save/reopen, table and image preservation');
} finally { await browser.close(); server.close(); }
