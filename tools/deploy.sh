#!/usr/bin/env bash
# Publica o runemoire.com (Worker + static assets). O token vem do arquivo de ambiente, só em tempo de deploy,
# e nunca é impresso nem gravado no repositório. Uso: bash tools/deploy.sh
set -euo pipefail
cd "$(dirname "$0")/.."
ENV_FILE="${CF_ENV_FILE:-$HOME/.config/iqnorth/cloudflare.env}"
node tools/build.mjs
set -a; . "$ENV_FILE"; set +a
npx wrangler deploy 2>&1 | grep -v -i "token"
