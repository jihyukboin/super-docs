import React from 'react';
import { createRoot } from 'react-dom/client';
import { DocxEditor, type Editor } from '@docx-editor.dev/react';
import '@docx-editor.dev/core/styles/editor.css';
import './native.css';
import { ko } from './ko';
import { defaultFonts } from '@docx-editor.dev/fonts';
const fontsPromise = defaultFonts();
let fonts: Awaited<ReturnType<typeof defaultFonts>>;

const post = (type: string, payload = {}) => (window as any).webkit?.messageHandlers?.superDocs?.postMessage({ type, ...payload });
const root = createRoot(document.getElementById('root')!);
let editor: Editor | undefined;
let loading = false;
let dirty = false;
let source: Uint8Array;
let title = '';
let findOpen = false;
function base64(bytes: Uint8Array) {
  let result = '';
  for (let i = 0; i < bytes.length; i += 32768) result += String.fromCharCode(...bytes.subarray(i, i + 32768));
  return btoa(result);
}
function render(onReady?: (value: Editor) => void) {
  root.render(<DocxEditor i18n={ko} fonts={fonts} document={source} title={title} mode="edit" colorMode="dark" locale="ko-KR"
    menu={false} onOpen={() => post('open')} onSave={() => post('save')}
    navigation={{ open: findOpen, onOpenChange: value => { findOpen = value; render(); }, tab: 'find' }}
    onReady={value => { editor = value; onReady?.(value); }}
    onChange={() => { if (!loading) { dirty = true; post('changed'); } }} />);
}
(window as any).superDocs = {
  async load(encoded: string, name: string) {
    loading = true;
    editor = undefined;
    title = name;
    source = Uint8Array.from(atob(encoded), c => c.charCodeAt(0));
    try {
      fonts = await fontsPromise;
      await new Promise<void>((resolve, reject) => {
        const timeout = setTimeout(() => reject(new Error('DOCX 문서를 열지 못했습니다. 파일이 손상되었거나 지원하지 않는 문서입니다.')), 30000);
        render(value => {
          clearTimeout(timeout);
          const failure = value.snapshot().openFailure;
          if (failure) reject(new Error('DOCX 문서를 열지 못했습니다. 파일을 확인해 주세요.'));
          else resolve();
        });
      });
      dirty = false;
      editor!.focus();
      return { pages: editor!.snapshot().page.total };
    } finally { loading = false; }
  },
  async export(format: string) {
    if (format !== 'docx' || !editor) throw new Error('DOCX 문서가 준비되지 않았습니다.');
    return base64(new Uint8Array(await editor.save()));
  },
  async saved(name: string) { title = name; dirty = false; render(); },
  async command(id: string) {
    if (!editor) return;
    const type = { 'edit:undo': 'undo', 'edit:redo': 'redo', 'edit:select-all': 'selectAll' }[id];
    if (type) { editor.exec({ type } as any); editor.focus(); }
    if (id === 'edit:find') { findOpen = true; render(); }
  },
  state() { return { dirty, format: 'docx', ...editor?.snapshot() }; },
};
// AppKit owns open/save shortcuts; text input and the native WebKit clipboard stay in the editor.
document.addEventListener('keydown', event => {
  if ((event.metaKey || event.ctrlKey) && ['s', 'o'].includes(event.key.toLowerCase())) {
    event.preventDefault(); post(event.key.toLowerCase() === 's' ? 'save' : 'open');
  }
}, true);
post('ready');
