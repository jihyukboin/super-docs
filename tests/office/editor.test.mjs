import { createServer } from 'node:http';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve, extname } from 'node:path';
import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
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
await mkdir('.build/office-tests', { recursive: true });
try {
  for (const format of ['xlsx', 'pptx']) {
    const page = await browser.newPage();
    await page.setViewport({ width: 1220, height: 860 });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') console.error(m.text()); });
    await page.goto(`http://127.0.0.1:${server.address().port}/office/index.html`);
    await page.waitForFunction(() => !!window.superDocs);
    const bytes = (await readFile(`tests/office/fixtures/sample.${format}`)).toString('base64');
    await page.evaluate((bytes, format) => window.superDocs.load(bytes, `sample.${format}`), bytes, format);
    assert.equal((await page.evaluate(() => window.superDocs.state())).ready, true);
    await page.screenshot({ path: `.build/office-tests/${format}.png` });
    if (format === 'xlsx') {
      const result = await page.evaluate(async () => {
        const api = window.superDocs.editor();
        return api.applyEdits({ expectVersion: await api.version(), steps: [{ op: 'setCellInputs', target: { sheetId: 'sheet:0', range: { kind: 'a1', a1: 'B2' } }, inputs: [['7']] }] });
      });
      assert.equal(result.ok, true, JSON.stringify(result));
      assert.equal((await page.evaluate(() => window.superDocs.state())).dirty, true);
      await page.evaluate(() => { const api = window.superDocs.editor(); api.selectCells(0, { anchor: { row: 1, col: 2 }, focus: { row: 1, col: 2 } }); api.focus(); });
      await page.keyboard.type('1500');
      await page.keyboard.press('Enter');
    }
    if (format === 'pptx') {
      const result = await page.evaluate(async () => {
        const api = window.superDocs.editor();
        const found = await api.findText({ text: 'Editable slide text' });
        if (!found.ok || found.matches.length !== 1) throw new Error('Slide text missing');
        return api.applyEdits({ expectVersion: found.version, steps: [{ op: 'replaceText', target: { kind: 'range', ...found.matches[0].range }, text: '수정한 발표 본문' }] });
      });
      assert.equal(result.ok, true, JSON.stringify(result));
    }
    await page.evaluate(() => window.superDocs.command('edit:find'));
    await page.type('#query', format === 'xlsx' ? '사과' : '수정한 발표 본문');
    await page.evaluate(() => window.superDocs.command('edit:select-all'));
    assert.equal(await page.$eval('#query', e => e.selectionEnd - e.selectionStart), format === 'xlsx' ? 2 : 9);
    await page.click('#find button[type="submit"]');
    await page.waitForFunction(() => document.getElementById('find-result').textContent === '1 / 1');
    await page.click('#close-find');
    const output = await page.evaluate(format => window.superDocs.export(format), format);
    await writeFile(`.build/office-tests/edited.${format}`, Buffer.from(output, 'base64'));
    await page.evaluate(format => window.superDocs.saved(`edited.${format}`), format);
    assert.equal((await page.evaluate(() => window.superDocs.state())).dirty, false);
    await page.evaluate((bytes, format) => window.superDocs.load(bytes, `edited.${format}`), output, format);
    const blank = (await readFile(`Resources/Templates/Blank.${format}`)).toString('base64');
    await page.evaluate((bytes, format) => window.superDocs.load(bytes, `blank.${format}`), blank, format);
    const blankSaved = await page.evaluate(format => window.superDocs.export(format), format);
    assert.ok(Buffer.from(blankSaved, 'base64').length > 100);
    assert.deepEqual(errors, []);
    console.log(`PASS: ${format} load/export/reopen`);
    await page.close();
  }
  const preview = await browser.newPage();
  await preview.goto(`http://127.0.0.1:${server.address().port}/markdown/index.html`);
  await preview.waitForFunction(() => !!window.renderMarkdown);
  await preview.evaluate(() => window.renderMarkdown('# 제목\n\n**강조**\n\n| 값 |\n| --- |\n| 한글 |\n\n<script>window.injected=true</script>'));
  assert.equal(await preview.$eval('h1', e => e.textContent), '제목');
  assert.equal(await preview.$eval('td', e => e.textContent), '한글');
  assert.equal(await preview.evaluate(() => window.injected), undefined);
  console.log('PASS: Markdown heading/table preview and script sanitization');
} finally { await browser.close(); server.close(); }
