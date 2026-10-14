---
name: code_notes/tools/screenshot_weather.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_weather.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_weather.lua`

Origem: `tools/screenshot_weather.lua` em `7dbdb60d` (4 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-12 (junto a `local M = {}`)

> tools/screenshot_weather.lua
> Captura o CLIMA do WorldRoad (WeatherEngine) num bioma, já assentado
> (8 s simulados com draw a cada frame — a projeção precisa do frame).
>
> love . test_one screenshot_weather 4                 (geleira, janela atual)
> love . test_one screenshot_weather 2:1920x1080:strike (raio no quadro)
> love . test_one screenshot_weather 2:storm            (pico da tempestade)
> love . test_one screenshot_weather 4:off              (A/B: clima desligado)
> love . test_one screenshot_weather 4:travel           (viajando — o clima vem em você)
> love . test_one screenshot_weather 1:start / 1:castle (começo do ato × perto do chefe)
>
> Saída: weather_<bioma>[_<modo>].png no save dir.

## L39-40 (em `M.run`, junto a `if modes.castle then`)

> start = começo do ato (andar 1: calmo, tod 0.62) | castle = perto do
> chefe (andar 8: pico, tod 1) | sem modo = meio do ato

## L71-72 (em `frame`, junto a `if modes.seq then`)

> seq: 16 quadros de uma VIAGEM (o que aparece/surge em movimento —
> ex. luminária chegando da crista). Saída weather_<b>_seqNN.png

## L125 (em `hist`, junto a `if not done then frame(); love.graphics.present() end`)

> captureScreenshot dispara no present; garante a escrita antes de sair

