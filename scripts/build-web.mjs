// HWP builds clean the output directory, so bundle DOCX afterwards.
await import('./hwp/build.mjs');
await import('./docx/build.mjs');
