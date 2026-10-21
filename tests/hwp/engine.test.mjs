import assert from 'node:assert/strict';
import init, { HwpDocument } from '@rhwp/core';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
await init({ module_or_path: await readFile(new URL('../../node_modules/@rhwp/core/rhwp_bg.wasm', import.meta.url)) });
const out = new URL('../../.build/verification/', import.meta.url); await mkdir(out, { recursive: true });
const expected = '슈퍼독스 HWP·HWPX 편집 검증 ABC 123';
const doc = HwpDocument.createEmpty(); doc.createBlankDocument();
assert.equal(JSON.parse(doc.insertText(0, 0, 0, expected)).ok, true);
for (const format of ['hwp', 'hwpx']) {
  const bytes = format === 'hwp' ? doc.exportHwp() : doc.exportHwpx();
  const reopened = new HwpDocument(bytes);
  assert.ok(reopened.getTextFileText().includes(expected), `${format} preserves Korean text`);
  assert.ok(reopened.pageCount() >= 1);
  await writeFile(new URL(`sample.${format}`, out), bytes);
  reopened.free();
}
doc.free();
const table = HwpDocument.createEmpty(); table.createBlankDocument();
const {paraIdx, controlIdx} = JSON.parse(table.createTable(0,0,0,2,2));
assert.equal(JSON.parse(table.insertTextInCell(0,paraIdx,controlIdx,0,0,0,'표 안의 한글')).ok,true);
for (const format of ['hwp','hwpx']) {
  const bytes = format === 'hwp' ? table.exportHwp() : table.exportHwpx();
  const reopened = new HwpDocument(bytes);
  assert.ok(reopened.getTextFileText().includes('표 안의 한글'));
  assert.deepEqual(JSON.parse(reopened.getTableDimensions(0,paraIdx,controlIdx)), {rowCount:2,colCount:2,cellCount:4});
  await writeFile(new URL(`table.${format}`,out), bytes);
  reopened.free();
}
table.free();
console.log('PASS: HWP + HWPX Korean body text, 2×2 tables and Korean cell text survive save/reopen');
