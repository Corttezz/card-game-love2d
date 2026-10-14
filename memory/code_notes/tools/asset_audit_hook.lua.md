---
name: code_notes/tools/asset_audit_hook.lua
description: Comentários com decisão/regra/histórico colhidos de tools/asset_audit_hook.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/asset_audit_hook.lua`

Origem: `tools/asset_audit_hook.lua` em `7dbdb60d` (1 de 1 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local out = os.getenv("ASSET_AUDIT")`)

> tools/asset_audit_hook.lua
> Instrumentacao da auditoria de imagens orfas (Out/2026). Envolve os pontos
> de entrada de arquivo do LOVE e registra todo caminho que o jogo TOCA:
> imagem carregada, getInfo que achou algo, pasta varrida. Ligada por env:
> ASSET_AUDIT=<arquivo de log absoluto>
> e instalada por uma linha TEMPORARIA no topo do main.lua (nao commitada).
> O log alimenta a classificacao USADO x ORFAO junto com a analise estatica.

