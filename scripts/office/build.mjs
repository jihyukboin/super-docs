import { build } from 'vite';
import { resolve } from 'node:path';
import { mkdir, cp, writeFile } from 'node:fs/promises';
await build({ configFile: false, root: resolve('web/office'), base: './', build: { outDir: resolve('.build/web/office'), emptyOutDir: true, sourcemap: false } });
const directory = resolve('.build/web/office/licenses');
await mkdir(directory, { recursive: true });
for (const name of ['xlsx', 'xlsx-react', 'xlsx-i18n', 'pptx', 'pptx-react', 'pptx-i18n']) {
  await cp(resolve('node_modules/@betteroffice', name, 'LICENSE'), resolve(directory, name + '-LICENSE.txt'));
}
await writeFile(resolve(directory, 'NOTICE.txt'), 'BetterOffice XLSX 0.3.0 and PPTX 0.2.0\nCopyright 2026 Elia Hilse, The OpenOOXML Project\nApache-2.0. Bundled without upstream source modifications.\nhttps://github.com/openooxml/betteroffice\nFont and React license texts are included in ../../docx/licenses.\n');
