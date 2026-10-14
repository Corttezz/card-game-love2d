---
name: code_notes/tools/screenshot_discovery.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_discovery.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_discovery.lua`

Origem: `tools/screenshot_discovery.lua` em `7dbdb60d` (4 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-11 (junto a `local M = {}`)

> tools/screenshot_discovery.lua
> Carta INÉDITA na vitrine (src/ui/DiscoveryMark.lua): recompensa, loja e
> pacote, cada um em dois instantes — no meio da varredura de luz e em
> repouso (só o marcador "NOVA") — mais a recompensa com reducedMotion.
>
> DISC_SIZE=1920x1080 love . test_one screenshot_discovery
> DISC_LOCALE=fr ...   (marcador mais largo: "NOUVELLE")
>
> Grava disc_<WxH>_<cena>_<instante>.png no save dir. O relógio do
> DiscoveryMark é trocado pelo tempo SIMULADO: o instante da captura é
> exato, não depende da velocidade da máquina.

## L57-58 (em `drawScene`, junto a `local function simulate(screen, secs)`)

> O draw de cada quadro importa: é nele que a carta "aparece" e a
> revelação começa (pacote: só depois de materializar).

## L121-122 (em `offerScene`, junto a `do`)

> Pacote: generateContents marca isNewDiscovery na carta inédita; aqui
> forçamos 2 de 3 (o perfil do tool pode já ter visto todas).

## L132-133 (em `offerScene`, junto a `local t0`)

> 1.3s até as cartas nascerem + materialize; captura logo depois
> que a 1ª carta revela e com tudo em repouso

