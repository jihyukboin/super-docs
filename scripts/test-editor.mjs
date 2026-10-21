import { createServer } from 'node:http';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve, extname } from 'node:path';
import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
const root = resolve('.build/web');
const server = createServer(async (req, res) => {
  const path = new URL(req.url, 'http://localhost').pathname;
  const file = resolve(root, '.' + path + (path.endsWith('/') ? 'index.html' : ''));
  try {
    if (!file.startsWith(root + '/')) throw Error();
    const data = await readFile(file);
    res.setHeader('Content-Type', ({'.wasm':'application/wasm','.js':'text/javascript','.css':'text/css','.html':'text/html','.json':'application/json','.woff2':'font/woff2'})[extname(file)] || 'application/octet-stream');
    res.end(data);
  } catch { res.writeHead(404); res.end(); }
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const browser = await puppeteer.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless:true, args:['--no-first-run']});
try {
  const page = await browser.newPage();
  await page.setViewport({width:1280,height:900});
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => {if(m.type()==='error') console.log('Browser error:',m.text().slice(0,500));});
  await page.goto(`http://127.0.0.1:${server.address().port}/?chrome=embed&lang=ko`);
  await page.waitForFunction(() => !!window.superDocs, {timeout:60000});
  const results = [];
  for (const format of ['hwp','hwpx']) {
    const bytes = (await readFile(`.build/verification/sample.${format}`)).toString('base64');
    const loaded = await page.evaluate((bytes,format)=>window.superDocs.load(bytes,`test.${format}`),bytes,format);
    assert.ok(loaded.pages >= 1);
    assert.ok((await page.evaluate(()=>window.superDocs.text())).includes('슈퍼독스 HWP·HWPX 편집 검증'));
    const textarea = await page.$('textarea'); await textarea.focus();
    const addition = ` Browser-${format}`;
    await page.keyboard.type(addition);
    assert.ok((await page.evaluate(()=>window.superDocs.text())).includes(addition));
    assert.equal((await page.evaluate(()=>window.superDocs.state())).dirty,true);
    await page.evaluate(()=>window.superDocs.command('edit:undo'));
    assert.ok(!(await page.evaluate(()=>window.superDocs.text())).includes(addition));
    await page.evaluate(()=>window.superDocs.command('edit:redo'));
    assert.ok((await page.evaluate(()=>window.superDocs.text())).includes(addition));
    const korean = ' 한글 붙여넣기 검증';
    await page.evaluate(text=>{
      const data = new DataTransfer(); data.setData('text/plain',text);
      document.querySelector('textarea').dispatchEvent(new ClipboardEvent('paste',{clipboardData:data,bubbles:true,cancelable:true}));
    },korean);
    assert.ok((await page.evaluate(()=>window.superDocs.text())).includes(korean));
    await page.evaluate(()=>window.superDocs.command('edit:select-all'));
    assert.equal((await page.evaluate(()=>window.superDocs.command('format:bold'))).ok,true);
    const beforeSave = await page.evaluate(()=>window.superDocs.text());
    const encoded = await page.evaluate(format=>window.superDocs.export(format),format);
    await writeFile(`.build/verification/browser.${format}`,Buffer.from(encoded,'base64'));
    await page.evaluate(()=>window.superDocs.saved('saved'));
    assert.equal((await page.evaluate(()=>window.superDocs.state())).dirty,false);
    await page.evaluate((encoded,format)=>window.superDocs.load(encoded,`saved.${format}`),encoded,format);
    assert.equal(await page.evaluate(()=>window.superDocs.text()),beforeSave);
    await page.screenshot({path:`.build/verification/browser-${format}.png`});
    results.push({format,pages:loaded.pages,keyboard:true,koreanPaste:true,undoRedo:true,bold:true,saveReopen:true});
  }
  // Real upstream corpus files exercise parsing paths beyond our generated documents.
  for (const name of ['samples/basic/KTX.hwp','samples/form-002.hwpx']) {
    const bytes = (await readFile(resolve(root,name))).toString('base64');
    const loaded = await page.evaluate((bytes,name)=>window.superDocs.load(bytes,name),bytes,name);
    assert.ok(loaded.pages>=1,name);
    await page.screenshot({path:'.build/verification/corpus-'+name.split('/').pop()+'.png'});
    results.push({file:name,pages:loaded.pages,opened:true});
  }
  assert.deepEqual(errors,[]);
  await writeFile('.build/verification/editor-results.json',JSON.stringify({at:new Date().toISOString(),results,errors},null,2));
  console.log('PASS:',JSON.stringify(results));

} finally {await browser.close();server.close();}
