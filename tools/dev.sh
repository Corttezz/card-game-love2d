#!/usr/bin/env bash
# Sobe o servidor local da prévia (porta 8788, sem forçar HTTPS) e espera ele responder.
cd "$(dirname "$0")/.."
(nohup npx wrangler dev --local --port 8788 --ip 127.0.0.1 --var FORCE_HTTPS:0 > tools/out/dev.log 2>&1 &)
for i in $(seq 1 40); do curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8788/ 2>/dev/null | grep -q 200 && echo "dev ok" && exit 0; sleep 2; done
echo "dev não subiu"; exit 1
