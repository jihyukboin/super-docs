import { build } from 'vite';
import { cp, mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
process.env.RHWP_DISABLE_EXTERNAL_WEBFONTS = '1';
const root = resolve(import.meta.dirname, '..');
const upstream = resolve(root, '.build/upstream/rhwp');
const revision = '1a76570e833917d15817415a53c09ad61ab3203f';
try { await readFile(resolve(upstream, 'Cargo.toml')); } catch {
  await mkdir(resolve(root, '.build/upstream'), { recursive: true });
  execFileSync('git', ['clone', '--depth', '1', '--filter=blob:none', '--sparse', 'https://github.com/edwardkim/rhwp.git', upstream], { stdio: 'inherit' });
}
if (execFileSync('git', ['rev-parse', 'HEAD'], { cwd: upstream, encoding: 'utf8' }).trim() !== revision) {
  execFileSync('git', ['fetch', '--depth', '1', 'origin', revision], { cwd: upstream, stdio: 'inherit' });
  execFileSync('git', ['checkout', '--detach', revision], { cwd: upstream, stdio: 'inherit' });
}
execFileSync('git', ['sparse-checkout', 'set', 'rhwp-studio', 'rhwp-shared', 'npm/hwpctrl-ocx', 'assets/fonts', 'scripts', 'typescript'], { cwd: upstream, stdio: 'inherit' });
await mkdir(resolve(upstream, 'pkg'), { recursive: true });
for (const name of ['rhwp.js', 'rhwp.d.ts', 'rhwp_bg.wasm', 'rhwp_bg.wasm.d.ts']) {
  await cp(resolve(root, 'node_modules/@rhwp/core', name), resolve(upstream, 'pkg', name));
  await cp(resolve(root, 'node_modules/@rhwp/core', name), resolve(upstream, 'rhwp-studio/public', name));
}
// The pinned Studio source and npm WASM are from the same upstream commit.
const hostBridge = await readFile(resolve(root, 'web/native-bridge.ts'), 'utf8');
const nativePaste = await readFile(resolve(root, 'web/native-paste.ts'), 'utf8');
const result = await build({
  configFile: resolve(upstream, 'rhwp-studio/vite.config.ts'),
  root: resolve(upstream, 'rhwp-studio'),
  base: './',
  plugins: [{ name: 'super-docs-native-bridge', enforce: 'pre', transform(code, id) {
    if (id === resolve(upstream, 'rhwp-studio/src/main.ts')) return code + '\n' + hostBridge;
    if (id === resolve(upstream, 'rhwp-studio/src/engine/input-handler.ts')) {
      const original = "return document.execCommand('paste');";
      if (code.split(original).length !== 2) throw new Error('Pinned engine paste integration changed');
      return code.replace(original, nativePaste);
    }
  } }],
  build: { outDir: resolve(root, '.build/web'), emptyOutDir: true, sourcemap: false },
});
await cp(resolve(upstream, 'LICENSE'), resolve(root, '.build/web/LICENSE.rhwp.txt'));
await cp(resolve(upstream, 'THIRD_PARTY_LICENSES.md'), resolve(root, '.build/web/THIRD_PARTY_LICENSES.rhwp.md'));
await writeFile(resolve(root, '.build/web/engine-version.json'), JSON.stringify({ version: '0.8.7', revision }));
console.log('Bundled RHWP', revision);
