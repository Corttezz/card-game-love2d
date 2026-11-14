# runemoire.com

Site oficial do Runemoire. Esta branch (`site`) guarda só o código do site; o jogo fica na `main`.

- `src/`: TypeScript e CSS da página (a abertura do jogo recriada no navegador).
- `tools/`: build (`build.mjs`, `page.mjs`), deploy e testes ponta a ponta (`e2e.mjs`, `consent_e2e.mjs`).
- `worker/`: Cloudflare Worker (páginas por idioma, "Me avise" no D1, aceite do Clarity para a Europa).
- `public/`: arquivos estáticos.
- `migrations/`: esquema do D1 (sem dados).

## Uso

```sh
npm install
bash tools/deploy_preview.sh   # prévia em workers.dev
node tools/e2e.mjs <url>       # teste ponta a ponta
node tools/consent_e2e.mjs     # aceite do Clarity na prévia (?cc=DE simula o país)
node tools/utm_e2e.mjs [url]   # origem da visita (UTM): captura, primeira vence, D1, saída apaga
bash tools/deploy.sh           # produção, só a partir da main local
```

Segredos não ficam no repositório; o deploy usa o login do `wrangler`.

Autor: Daniel Cortez.
