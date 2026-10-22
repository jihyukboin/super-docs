import { marked } from 'marked';
import DOMPurify from 'dompurify';
(window as any).renderMarkdown = (text: string) => {
  const html = marked.parse(text, { async: false, gfm: true });
  document.getElementById('preview')!.innerHTML = DOMPurify.sanitize(html, { USE_PROFILES: { html: true }, FORBID_TAGS: ['input', 'form', 'iframe', 'object', 'embed'], FORBID_ATTR: ['style'] });
};
// Keep preview navigation inside the current document; external links are not loaded implicitly.
document.addEventListener('click', event => {
  const link = (event.target as Element).closest('a');
  if (link && !link.getAttribute('href')?.startsWith('#')) event.preventDefault();
});
