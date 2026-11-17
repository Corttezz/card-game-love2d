// IndexNow depois do deploy de produção: envia as URLs do blog novas ou com lastmod novo (lidas do dist/sitemap.xml).
// Guarda o que já foi enviado em tools/out/indexnow-sent.json para não reenviar página sem mudança.
// uso: node tools/indexnow.mjs [--dry]
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
const R = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const { indexnowKey: KEY, site: SITE } = JSON.parse(fs.readFileSync(path.join(R, 'src/data/config.json'), 'utf8'));
const STATE = path.join(R, 'tools/out/indexnow-sent.json');
const sent = fs.existsSync(STATE) ? JSON.parse(fs.readFileSync(STATE, 'utf8')) : {};
const xml = fs.readFileSync(path.join(R, 'dist/sitemap.xml'), 'utf8');
const urls = [...xml.matchAll(/<url><loc>([^<]+)<\/loc>(?:<lastmod>([^<]+)<\/lastmod>)?/g)]
  .map(([, u, m]) => ({ u, m: m || '' })).filter((x) => x.u.startsWith(SITE) && /^\/(?:[a-z]{2}\/)?blog\//.test(x.u.slice(SITE.length)));
const todo = urls.filter((x) => sent[x.u] !== x.m);
if (!todo.length) { console.log('indexnow: nada novo no blog'); process.exit(0); }
if (process.argv.includes('--dry')) { console.log('indexnow (dry):', todo.map((x) => x.u).join(' ')); process.exit(0); }
const host = new URL(SITE).host;
const r = await fetch('https://api.indexnow.org/indexnow', {
  method: 'POST', headers: { 'Content-Type': 'application/json; charset=utf-8' },
  body: JSON.stringify({ host, key: KEY, keyLocation: `${SITE}/${KEY}.txt`, urlList: todo.map((x) => x.u) }),
});
console.log('indexnow:', r.status, todo.length, 'URL(s):', todo.map((x) => x.u).join(' '));
if (r.status === 200 || r.status === 202) {
  for (const x of todo) sent[x.u] = x.m;
  fs.mkdirSync(path.dirname(STATE), { recursive: true });
  fs.writeFileSync(STATE, JSON.stringify(sent, null, 2));
} else process.exitCode = 1;
