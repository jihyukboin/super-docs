import { build } from 'vite';
import { resolve } from 'node:path';
import { mkdir, cp } from 'node:fs/promises';
await build({ configFile: false, root: resolve('web/markdown'), base: './', build: { outDir: resolve('.build/web/markdown'), emptyOutDir: true, sourcemap: false } });
await mkdir('.build/web/markdown/licenses', { recursive: true });
await cp('node_modules/marked/LICENSE', '.build/web/markdown/licenses/marked-LICENSE.md');
await cp('node_modules/dompurify/LICENSE', '.build/web/markdown/licenses/dompurify-LICENSE');
await cp('node_modules/dompurify/LICENSE-MPL', '.build/web/markdown/licenses/dompurify-LICENSE-MPL');
