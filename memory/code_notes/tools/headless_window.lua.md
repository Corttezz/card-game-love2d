---
name: code_notes/tools/headless_window.lua
description: Comentários com decisão/regra/histórico colhidos de tools/headless_window.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/headless_window.lua`

Origem: `tools/headless_window.lua` em `7dbdb60d` (1 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local M = {}`)

> tools/headless_window.lua
> ZERO JANELA VISIVEL na bateria de balanceamento (requisito do dono,
> Out/2026: "varias janelas do Grimoire" apareciam durante as baterias).
>
> Com CARDGAME_HEADLESS=1 o conf.lua ja faz a janela nascer 1x1, sem borda,
> em (-32000, -32000). Falta tira-la da BARRA DE TAREFAS: a LOVE nao tem API
> pra esconder a propria janela, entao no Windows usamos user32 via FFI
> (ShowWindow SW_HIDE) na janela deste processo — achada pelo titulo, que
> antes trocamos por um unico (o `love.exe .` do dono tambem se chama
> "Grimoire" e NUNCA pode ser tocado). Esconder de FORA (balance.py via
> ctypes) nao funcionava: o SDL re-mostra a janela se o SW_HIDE chega antes
> do fim da criacao — aqui chamamos DEPOIS, de dentro do proprio processo.
>
> Fora do Windows / sem FFI: AVISA e segue (a janela 1x1 fora da tela ja nao
> aparece em monitor nenhum).

