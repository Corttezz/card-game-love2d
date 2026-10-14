---
name: code_notes/tools/check_seal_sfx.lua
description: Comentários com decisão/regra/histórico colhidos de tools/check_seal_sfx.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/check_seal_sfx.lua`

Origem: `tools/check_seal_sfx.lua` em `7dbdb60d` (4 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local M = {}`)

> tools/check_seal_sfx.lua
> Confere que os 5 sons de lacre REGISTRAM e ficam visiveis pro Sfx.has.
> Existe porque a integracao depende de um registro sob demanda: se ele
> falhar, o jogo degrada calado pro som generico e ninguem percebe.

## L11-13 (em `M.run`, junto a `local audio = _G.audioSystem`)

> Tools nao passam pelo boot que cria _G.audioSystem, entao instanciamos um
> AudioManager proprio: o que interessa validar e se os 5 arquivos CARREGAM
> e ficam visiveis pro Sfx.has, nao qual instancia os guarda.

## L38-39 (em `M.run`, junto a `local again = PackThemes.registerSealSounds(audio)`)

> Idempotencia: e ela que torna seguro chamar o registro em toda abertura
> de pacote. Uma 2a passada tem que registrar ZERO.

## L44-45 (em `M.run`, junto a `print("  fallback packSealBreak presente=" .. tostring(Sfx.has("packSealBreak"))`)

> O fallback generico e carregado por main.lua no boot; num contexto de
> tool ele nao existe, e isso NAO e falha.

