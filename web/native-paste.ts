// Replaces only InputHandler.performPaste's web execCommand fallback in the pinned engine.
if ((window as any).webkit?.messageHandlers?.superDocsClipboard) {
  const textarea = this.textarea;
  (window as any).webkit.messageHandlers.superDocsClipboard.postMessage({ action: 'read' }).then((values: Record<string, string>) => {
    const data = new DataTransfer();
    for (const [mime, base64] of Object.entries(values)) {
      const bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
      if (mime.startsWith('text/')) data.setData(mime, new TextDecoder().decode(bytes));
      else if (mime.startsWith('image/')) data.items.add(new File([bytes], 'clipboard.' + mime.split('/')[1], { type: mime }));
    }
    textarea.dispatchEvent(new ClipboardEvent('paste', { clipboardData: data, bubbles: true, cancelable: true }));
  }).catch((error: unknown) => {
    (window as any).webkit.messageHandlers.superDocs.postMessage({ type: 'error', message: String(error) });
  });
  return true;
}
return document.execCommand('paste');
