import React from 'react';
import { createRoot } from 'react-dom/client';
import { EditorToolbar as XToolbar, ToolbarCommand as XCommand, XlsxEditor, type XlsxEditorApi } from '@betteroffice/xlsx-react';
import { EditorToolbar as PToolbar, ToolbarCommand as PCommand, PptxEditor, type PptxEditorApi } from '@betteroffice/pptx-react';
import { defaultFonts } from '@docx-editor.dev/fonts';
import './native.css';
import { xlsxKo, pptxKo } from './ko';

const root = createRoot(document.getElementById('root')!);
const post = (type: string, payload = {}) => (window as any).webkit?.messageHandlers?.superDocs?.postMessage({ type, ...payload });
let api: XlsxEditorApi | PptxEditorApi | undefined;
let format = '';
let dirty = false;
let loading = false;
let exported: Uint8Array | undefined;
let exporting = false;
let generation = 0;
let matchIndex = -1;
const findBar = document.getElementById('find') as HTMLFormElement;
const query = document.getElementById('query') as HTMLInputElement;
query.addEventListener('input', () => { matchIndex = -1; });
document.getElementById('close-find')!.addEventListener('click', () => { findBar.hidden = true; api?.focus(); });
findBar.addEventListener('submit', async event => {
  event.preventDefault();
  if (!api || !query.value) return;
  try {
    const result = await api.findText({ text: query.value });
    if (!result.ok || !result.matches.length) { document.getElementById('find-result')!.textContent = '검색 결과 없음'; return; }
    matchIndex = (matchIndex + 1) % result.matches.length;
    const match: any = result.matches[matchIndex];
    if (format === 'xlsx') {
      const editor = api as XlsxEditorApi;
      const catalog = await editor.readCells({ ranges: [] });
      if (catalog.ok) {
        const sheet = catalog.sheets.findIndex(s => s.sheetId === match.cell.sheetId);
        editor.selectCells(sheet, { anchor: { row: match.cell.row, col: match.cell.col }, focus: { row: match.cell.row, col: match.cell.col } });
      }
    } else {
      const editor = api as PptxEditorApi;
      const slide = editor.handle.snapshot().slides.findIndex(s => s.id === match.range.slideId) + 1;
      editor.selectText({ slide, shapeId: match.range.shapeId, storyId: match.range.storyId, start: match.range.start, end: match.range.end });
    }
    document.getElementById('find-result')!.textContent = `${matchIndex + 1} / ${result.matches.length}`;
  } catch (error) { post('error', { message: String(error) }); }
});
const encode = (bytes: Uint8Array) => {
  let result = '';
  for (let i = 0; i < bytes.length; i += 32768) result += String.fromCharCode(...bytes.subarray(i, i + 32768));
  return btoa(result);
};
const onSave = (bytes: Uint8Array) => {
  if (exporting) exported = bytes;
  else post('save');
};
const onChange = () => { if (!loading) { dirty = true; post('changed'); } };
(window as any).superDocs = {
  async load(encoded: string, name: string) {
    format = name.split('.').pop()!.toLowerCase();
    if (!['xlsx', 'pptx'].includes(format)) throw new Error('지원하지 않는 Office 문서입니다.');
    const file = Uint8Array.from(atob(encoded), c => c.charCodeAt(0));
    api = undefined; loading = true; dirty = false;
    const key = ++generation;
    try {
      const fonts = format === 'pptx' ? (await defaultFonts()).sources.map(face => ({
        family: face.request.family, bytes: face.bytes, bold: face.request.weight >= 600, italic: face.request.style === 'italic',
      })) : [];
      await new Promise<void>((resolve, reject) => {
        const timeout = setTimeout(() => reject(new Error('문서를 열지 못했습니다. 손상되었거나 지원하지 않는 문서입니다.')), 30000);
        const onReady = (value: XlsxEditorApi | PptxEditorApi) => { api = value; clearTimeout(timeout); resolve(); };
        const onError = (error: Error) => { clearTimeout(timeout); reject(error); };
        root.render(format === 'xlsx'
          ? <XlsxEditor i18n={xlsxKo} toolbar={<XToolbar mode="commands"><XToolbar.Toolbar>{['save','undo','redo','zoom','fontFamily','fontSize','bold','italic','numberFormat','textColor','fillColor','borderPreset','merge','horizontalAlignment','textWrapping'].map(id => <XCommand key={id} id={id as any} />)}</XToolbar.Toolbar><XToolbar.FormulaBar /></XToolbar>} key={key} file={file} fileName={name} onReady={onReady} onChange={onChange} onSave={onSave} />
          : <PptxEditor i18n={pptxKo} toolbar={<PToolbar mode="commands"><PToolbar.Toolbar>{['save','undo','redo','zoom','insertSlide','insertImage','tool','fontFamily','fontSize','bold','italic','underline','textColor','alignment','shapeFill','shapeStrokeColor','zOrder','slideshow'].map(id => <PCommand key={id} id={id as any} />)}</PToolbar.Toolbar></PToolbar>} key={key} file={file} fileName={name} fonts={fonts} onReady={onReady} onError={onError} onChange={onChange} onSave={onSave}
              onSaveRequest={() => { if (exporting) return true; post('save'); return false; }} />);
      });
      api!.focus();
      if (format === 'pptx') {
        const pages = (api as PptxEditorApi).handle.snapshot().slides.length;
        return { pages, detail: `${pages}개 슬라이드` };
      }
      const catalog = await (api as XlsxEditorApi).readCells({ ranges: [] });
      return { pages: 1, detail: `${catalog.ok ? catalog.sheets.length : 1}개 시트` };
    } finally { loading = false; }
  },
  async export(requested: string) {
    if (!api || requested !== format) throw new Error('문서가 준비되지 않았습니다.');
    exporting = true; exported = undefined;
    try {
      const result = await api.commands.execute('save', null);
      if (!result.ok) throw new Error('편집 내용을 저장하지 못했습니다.');
      if (!exported?.length) throw new Error('저장 데이터가 없습니다.');
      return encode(exported);
    } finally { exporting = false; }
  },
  async saved(_name: string) { dirty = false; },
  async command(id: string) {
    if (!api) return;
    const command = { 'edit:undo': 'undo', 'edit:redo': 'redo' }[id];
    if (id === 'edit:find') { findBar.hidden = false; query.focus(); query.select(); return; }
    if (id === 'edit:select-all' && (document.activeElement instanceof HTMLInputElement || document.activeElement instanceof HTMLTextAreaElement)) { document.activeElement.select(); return; }
    if (id === 'edit:select-all') { api.focus(); document.activeElement?.dispatchEvent(new KeyboardEvent('keydown', { key: 'a', metaKey: true, bubbles: true, cancelable: true })); return; }
    if (command) { await api.commands.execute(command as any, null); api.focus(); }
  },
  state() { return { dirty, format, ready: !!api }; },
  // The integration test drives the same editor command API used by toolbar and keyboard input.
  editor() { return api; },
};
document.addEventListener('keydown', event => {
  if ((event.metaKey || event.ctrlKey) && ['s', 'o'].includes(event.key.toLowerCase())) {
    event.preventDefault(); event.stopImmediatePropagation();
    post(event.key.toLowerCase() === 's' ? 'save' : 'open');
  }
}, true);
post('ready');
