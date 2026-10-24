// After the client build, render the page to HTML and drop it into dist/index.html.
import { readFileSync, writeFileSync, rmSync } from 'node:fs';
import { render } from './dist-ssr/entry-server.js';

const file = new URL('./dist/index.html', import.meta.url);
const html = readFileSync(file, 'utf8').replace('<div id="root"></div>', `<div id="root">${render()}</div>`);
writeFileSync(file, html);
rmSync(new URL('./dist-ssr', import.meta.url), { recursive: true, force: true });
console.log('prerendered dist/index.html');
