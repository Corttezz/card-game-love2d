---
name: code_notes/tools/screenshot_endless.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_endless.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_endless.lua`

Origem: `tools/screenshot_endless.lua` em `7dbdb60d` (2 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local M = {}`)

> tools/screenshot_endless.lua
> Captura do PÓS-JOGO (Out/2026): escolha de maldição do ciclo do endless e
> a TopBar com Selo + ciclo + maldições. memory/endless_and_seals.md.
>
> END_W=1920 END_H=1080 END_LOCALE=de END_TAG=x_ love . test_one screenshot_endless
> Saída (save dir): <tag>endless_1_escolha.png, <tag>endless_2_topbar.png

## L51-52 (em `frame`, junto a `local function snap(name, withModal)`)

> Canvas + encode síncrono: roda dentro do test_one sem depender do
> callback do captureScreenshot.

