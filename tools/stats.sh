#!/usr/bin/env bash
# Números da conversão do "Me avise" (D1 de produção). O token vem do arquivo de ambiente e não é impresso.
# uso: bash tools/stats.sh [dias=14]
set -euo pipefail
cd "$(dirname "$0")/.."
DAYS="${1:-14}"
set -a; . "${CF_ENV_FILE:-$HOME/.config/iqnorth/cloudflare.env}"; set +a
q() { npx wrangler d1 execute runemoire-site --remote --command "$1" 2>&1 | grep -v -i token | sed -n '/┌/,/┘/p'; }
echo "== A/B do botão: visitas (1 por sessão), cadastros e conversão, últimos $DAYS dias"
q "SELECT variant, SUM(views) AS visitas, SUM(signups) AS cadastros, ROUND(100.0*SUM(signups)/MAX(SUM(views),1),2) AS conv_pct FROM stats_daily WHERE day >= date('now','-$DAYS day') GROUP BY variant ORDER BY variant"
echo "== por dia e idioma"
q "SELECT day, lang, variant, views, signups FROM stats_daily WHERE day >= date('now','-$DAYS day') ORDER BY day DESC, lang, variant"
echo "== cadastros por bioma e por botão (lista atual, sem e-mails)"
q "SELECT COALESCE(biome,'?') AS bioma, COALESCE(source,'?') AS botao, COALESCE(variant,'?') AS versao, COUNT(*) AS n FROM notify GROUP BY 1,2,3 ORDER BY n DESC"
