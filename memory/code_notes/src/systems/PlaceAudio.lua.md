---
name: code_notes/src/systems/PlaceAudio.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/PlaceAudio.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/PlaceAudio.lua`

Origem: `src/systems/PlaceAudio.lua` em `7dbdb60d` (4 de 12 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-27 (junto a `local PlaceAudio = {}`)

> src/systems/PlaceAudio.lua
> ============================================================================
> PLACEAUDIO — o som AMBIENTE de cada lugar da run (Out/2026, dono: "ao
> entrar na loja, forja, descanso, evento, o som da estrada não pode
> continuar — no máximo o ambiente do lugar novo")
> ============================================================================
> Mesmo desenho do MusicDirector: OBSERVA o estado todo frame (apply) em vez
> de ser avisado por cada tela — transição esquecida não vira "som errado".
>
> Decide o LUGAR (road / shop / forge / rest / event / reward / boss / nil)
> e:
> 1. abre ou fecha o portão do clima da estrada (WeatherAudio.roadActive);
> 2. toca a cama do lugar + avulsos raros, com o MESMO motor de camas do
> WeatherAudio (vozes em crossfade de variantes, ponto de início e pitch
> sorteados, nunca a mesma variante seguida — nada de loop fixo);
> 3. um avulso de CHEGADA (sino da porta da loja) uma vez por entrada.
>
> Volume bem abaixo da música: PLACE_VOLUME × AMBIENT_VOLUME × categoria,
> grupo "ambient" (slider próprio em Configurações).
> Não duplica SFX de UI: a batida da forja (forgeStrike) continua sendo da
> RestScreen; aqui a bigorna é DISTANTE, rara e para enquanto a cerimônia de
> forja toca (forgeBusy).
>
> Sons em audio/sfx/place/ (ElevenLabs FREE — lista pra regenerar em
> memory/weather_engine.md) + reuso de audio/sfx/weather/ (grilos, brasa,
> vento, coruja). Registro por SCAN (código "pl:<nome>").
> ============================================================================

## L117-121 (em `PlaceAudio.registerSounds`, junto a `function PlaceAudio.placeFor(state, ctx)`)

> QUAL LUGAR — pura, testável sem áudio.
> state   = currentState do main.lua
> ctx     = { nodeType, restMode, bossRoom (bool) }

## L150 (em `playOne`, junto a `function PlaceAudio.apply(dt, state, ctx)`)

> chamado TODO frame pelo main.lua

## L159-160 (em `onesT`, junto a `if cfg and cfg.enter and prev ~= place then playOne(cfg.enter, 1) end`)

> avulso de CHEGADA (sino da loja) — só na entrada, não na volta do
> pause/deck viewer (o estado não muda nesses casos)

