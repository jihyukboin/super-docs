// Compiled into the pinned Studio entry point. No document data goes to a server.
function postNative(type: string, payload: Record<string, unknown> = {}) {
  (window as any).webkit?.messageHandlers?.superDocs?.postMessage({ type, ...payload });
}
function bytesToBase64(bytes: Uint8Array): string {
  let result = '';
  for (let i = 0; i < bytes.length; i += 32768) result += String.fromCharCode(...bytes.subarray(i, i + 32768));
  return btoa(result);
}
let hostLoading = false;
(window as any).superDocs = {
  async load(base64: string, name: string) {
    await initPromise;
    if (!rendererInitialized) throw new Error(rendererInitializationError || '편집 엔진을 시작하지 못했습니다.');
    hostLoading = true;
    try {
      const bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
      await loadBytes(bytes, name, null, undefined, { suppressDialogs: true });
      if ((window as any).webkit?.messageHandlers?.superDocsClipboard && inputHandler) {
        (inputHandler as any).performPaste = () => { void nativePaste(); return true; };
      }
      return { pages: wasm.pageCount, format: wasm.getSourceFormat() };
    } finally { hostLoading = false; }
  },
  async export(format: string) {
    await initPromise;
    if (!['hwp', 'hwpx'].includes(format)) throw new Error('지원하지 않는 저장 형식입니다.');
    if (wasm.requiresPasswordForSave) throw new Error('암호로 보호된 문서의 저장은 아직 지원하지 않습니다.');
    const artifact = format === 'hwp' ? wasm.exportHwpWithReport() : wasm.exportHwpxWithReport();
    if (artifact.contentLoss.count > 0) {
      throw new Error(`이 형식으로 저장하면 문서 요소 ${artifact.contentLoss.count}개가 보존되지 않습니다. 원본을 유지하고 다른 형식으로 저장해 주세요.`);
    }
    return bytesToBase64(artifact.bytes);
  },
  async saved(name: string) { return completeHostSave(name); },
  async command(id: string) {
    if (id === "edit:paste" && (window as any).webkit?.messageHandlers?.superDocsClipboard) { await nativePaste(); return { ok: true }; }
    return automation.execute(id, undefined, { allowDialog: true });
  },
  state() { return { dirty: documentState.isDirty(), pages: wasm.pageCount, format: wasm.getSourceFormat() }; },
  text() { return wasm.borrowDocumentHandle()?.getTextFileText(); },
};
eventBus.on('document-mutated', () => {
  if (!hostLoading) postNative('changed');
});
// All lifecycle commands are owned by the native host (chrome=embed).
void initPromise.then(() => {
  if (rendererInitialized) postNative('ready');
  else postNative('error', { message: rendererInitializationError || '편집기를 준비하지 못했습니다.' });
});
window.addEventListener('error', e => postNative('log', { message: e.message }));

// WebKit's asynchronous web clipboard prompt is replaced with the macOS pasteboard.
if ((window as any).webkit?.messageHandlers?.superDocsClipboard) {
  const requestClipboard = (request: unknown) => (window as any).webkit.messageHandlers.superDocsClipboard.postMessage(request);
  const decode = (value: string) => Uint8Array.from(atob(value), c => c.charCodeAt(0));
  Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
    async readText() {
      const values = await requestClipboard({ action: 'read' });
      return new TextDecoder().decode(decode(values['text/plain'] || ''));
    },
    async writeText(text: string) {
      await requestClipboard({ action: 'write', values: { 'text/plain': bytesToBase64(new TextEncoder().encode(text)) } });
    },
    async read() {
      const values = await requestClipboard({ action: 'read' });
      const types = Object.keys(values);
      return types.length ? [{ types, getType: async (mime: string) => new Blob([decode(values[mime])], { type: mime }) }] : [];
    },
    async write(items: ClipboardItem[]) {
      const values: Record<string, string> = {};
      for (const item of items) for (const mime of item.types) {
        values[mime] = bytesToBase64(new Uint8Array(await (await item.getType(mime)).arrayBuffer()));
      }
      await requestClipboard({ action: 'write', values });
    },
  } });
}

async function nativePaste() {
  if (!inputHandler) return;
  const values = await (window as any).webkit.messageHandlers.superDocsClipboard.postMessage({ action: 'read' });
  const data = new DataTransfer();
  for (const [mime, encoded] of Object.entries(values as Record<string, string>)) {
    const bytes = Uint8Array.from(atob(encoded), c => c.charCodeAt(0));
    if (mime.startsWith('text/')) data.setData(mime, new TextDecoder().decode(bytes));
    else if (mime === 'image/png' || mime === 'image/tiff') data.items.add(new File([bytes], 'clipboard.' + mime.split('/')[1], {type:mime}));
  }
  inputHandler.focus();
  const textarea = (inputHandler as any).textarea as HTMLTextAreaElement;
  textarea.dispatchEvent(new ClipboardEvent('paste', { clipboardData: data, bubbles: true, cancelable: true }));
}
window.addEventListener('keydown', event => {
  if (!(window as any).webkit?.messageHandlers?.superDocsClipboard || !inputHandler) return;
  if ((event.metaKey || event.ctrlKey) && !event.altKey && event.code === 'KeyV' && !(event.target as HTMLElement)?.closest('.modal-overlay')) {
    event.preventDefault(); event.stopImmediatePropagation(); void nativePaste();
  }
}, true);
