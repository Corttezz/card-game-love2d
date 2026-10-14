---
name: code_notes/tools/jsonlite.lua
description: Comentários com decisão/regra/histórico colhidos de tools/jsonlite.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/jsonlite.lua`

Origem: `tools/jsonlite.lua` em `7dbdb60d` (1 de 1 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local J = {}`)

> tools/jsonlite.lua
> Encoder JSON minimo pros registros da bateria de balanceamento
> (tools/balance_sim.lua → tools/balance.py). So ENCODE: quem le e o Python.
>
> Regras: tabela com [1] ou vazia = array; senao objeto com chaves em string
> (chave numerica vira "n"). NaN/inf viram null. Chaves ordenadas pra saida
> estavel (diff de dois relatorios da mesma seed e vazio).

