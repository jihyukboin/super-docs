import init, { HwpDocument } from '@rhwp/core';
import { readFile, writeFile } from 'node:fs/promises';
await init({ module_or_path: await readFile(new URL('../node_modules/@rhwp/core/rhwp_bg.wasm', import.meta.url)) });
const doc = HwpDocument.createEmpty();
doc.createBlankDocument();
await writeFile(new URL('../Resources/Blank.hwpx', import.meta.url), doc.exportHwpx());
doc.free();
