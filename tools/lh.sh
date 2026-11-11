#!/usr/bin/env bash
# Lighthouse móvel e desktop no site publicado (Chromium do Playwright, headless). Uso: bash tools/lh.sh [url]
set -u
U="${1:-https://runemoire.com/}"
export CHROME_PATH="${CHROME_PATH:-C:/Users/corte/AppData/Local/ms-playwright/chromium-1248/chrome-win64/chrome.exe}"
mkdir -p tools/out/lh
npx --yes lighthouse@12 "$U" --quiet --chrome-flags="--headless=new --no-sandbox" --only-categories=performance,accessibility,best-practices,seo --output=json --output-path=tools/out/lh/mobile.json >/dev/null 2>&1
npx --yes lighthouse@12 "$U" --quiet --preset=desktop --chrome-flags="--headless=new --no-sandbox" --only-categories=performance,accessibility,best-practices,seo --output=json --output-path=tools/out/lh/desktop.json >/dev/null 2>&1
python -X utf8 - <<'PY'
import json
for n in ['mobile','desktop']:
    d=json.load(open(f'tools/out/lh/{n}.json',encoding='utf-8')); A=d['audits']
    print(n, {k:round(v['score']*100) for k,v in d['categories'].items()}, 'LCP',A['largest-contentful-paint']['displayValue'],'TBT',A['total-blocking-time']['displayValue'],'CLS',A['cumulative-layout-shift']['displayValue'],'FCP',A['first-contentful-paint']['displayValue'],'peso',A['total-byte-weight']['displayValue'])
PY
