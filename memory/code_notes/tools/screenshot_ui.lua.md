---
name: code_notes/tools/screenshot_ui.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_ui.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_ui.lua`

Origem: `tools/screenshot_ui.lua` em `7dbdb60d` (6 de 14 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `local M = {}`)

> tools/screenshot_ui.lua
> Captura as telas de UI SEM harness próprio (levantamento do redesign UI/UX):
> love . screenshot_ui menu|class|settings|rest|event|collection|all
> Salva ui_<tela>.png no save dir. Segue o pipeline de validação visual do
> memory/balatro_fidelity_directive.md ("ver com os olhos").

## L9-10 (em `M`, junto a `local function capture(name)`)

> padrão do screenshot_worldroad "all": loop SÍNCRONO draw→capture→present
> (encadear present dentro do callback de captura não dispara o próximo)

## L46-47 (em `addShot`, junto a `local seeded = false`)

> Seed TEMPORÁRIO de perfil (plaque só aparece com histórico). Só se
> não existe perfil real — removido no fim pra não poluir o do jogador.

## L63-65 (em `addShot`, junto a `local EventManager = require("engine.EventManager")`)

> Splash no auge da cascade (título visível). BootScene é module-level
> state — init + simula 2.3s manualmente com EventManager.
> BootScene consome _G.EventManager (sem ele, pula direto pro fim).

## L71-72 (em `addShot`, junto a `for _ = 1, math.floor(2.8 * 60) do`)

> 2.8s: título já em alpha 1 (ease termina em splash+2.05 = 2.55s
> total) e cascade ainda no ar; flash só em splash+2.70.

## L149-150 (em `addShot`, junto a `local ProfileStats = require("engine.ProfileStats")`)

> Galeria de conquistas (F4). Seed em memória: HEADLESS_TOOL impede
> gravação no profile.lua real.

