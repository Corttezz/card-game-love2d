#!/usr/bin/env bash
# Publica a v2 só na URL de prévia (workers.dev). Não mexe em runemoire.com. uso: bash tools/deploy_preview.sh
set -euo pipefail
cd "$(dirname "$0")/.."
node tools/build.mjs
set -a; . "${CF_ENV_FILE:-$HOME/.config/iqnorth/cloudflare.env}"; set +a
npx wrangler deploy -c wrangler.v2.jsonc 2>&1 | grep -v -i "token"
