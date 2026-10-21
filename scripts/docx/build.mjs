import { build } from 'vite';
import { resolve } from 'node:path';
await build({
  configFile: false,
  root: resolve('web/docx'),
  base: './',
  build: { outDir: resolve('.build/web/docx'), emptyOutDir: true, sourcemap: false },
});
// Ship license texts for runtime dependencies, including font and HarfBuzz assets.
const { readFile, readdir, mkdir, cp, writeFile } = await import('node:fs/promises');
const { createRequire } = await import('node:module');
const seen = new Set();
const notices = ['DOCX Editor runtime dependencies', 'Bundled/minified for Super Docs; upstream source is not otherwise modified.'];
async function licenses(name, from = resolve('package.json')) {
  const local = createRequire(from);
  let path;
  for (const directory of local.resolve.paths(name) || []) {
    const candidate = resolve(directory, name, 'package.json');
    if (await readFile(candidate).then(() => true, () => false)) { path = candidate; break; }
  }
  if (!path) throw new Error(`Missing runtime package: ${name}`);
  if (seen.has(path)) return;
  seen.add(path);
  const pkg = JSON.parse(await readFile(path, 'utf8'));
  const directory = resolve(path, '..');
  const destination = resolve('.build/web/docx/licenses', pkg.name.replaceAll('/', '_'));
  await mkdir(destination, { recursive: true });
  notices.push(`${pkg.name} ${pkg.version} — ${pkg.license || 'See included license'}`);
  for (const file of await readdir(directory)) {
    if (/^(licen[sc]e|copying|notice|third.party)/i.test(file)) await cp(resolve(directory, file), resolve(destination, file), { recursive: true });
  }
  for (const dependency of Object.keys(pkg.dependencies || {})) await licenses(dependency, path);
}
for (const name of ['@docx-editor.dev/react', '@docx-editor.dev/core', '@docx-editor.dev/fonts', 'react', 'react-dom']) await licenses(name);
await writeFile(resolve('.build/web/docx/licenses/NOTICE.txt'), notices.join('\n') + '\n');
