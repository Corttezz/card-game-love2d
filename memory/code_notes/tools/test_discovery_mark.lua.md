---
name: code_notes/tools/test_discovery_mark.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_discovery_mark.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_discovery_mark.lua`

Origem: `tools/test_discovery_mark.lua` em `7dbdb60d` (3 de 15 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-8 (junto a `local TK = require("tools.testkit")`)

> tools/test_discovery_mark.lua
> Carta INÉDITA na vitrine (src/ui/DiscoveryMark.lua):
> * markDiscovered devolve true só na virada (e a lista da Coleção enche)
> * a oferta (recompensa/loja) carrega isNew → instância isNewDiscovery
> * pacote marca a instância inédita; evento só descobre o que ENTREGA
> * o marcador desenha só com a flag; reducedMotion tira a varredura e
> mantém o marcador; estado persiste no perfil
> Perfil FALSO (ProfileStats._swapForTests), override de ferramenta desligado.

## L73-74 (em `M.run`, junto a `local u = ProfileStats.get().unlocks`)

> volta a um perfil com só as vistas de antes (o resto do teste
> precisa de cartas inéditas)

## L130-134 (em `DiscoveryMark.clock`, junto a `_G.gameSettings.reducedMotion = false`)

> TUDO no tempo simulado: o relógio do DiscoveryMark é injetado e o
> love.timer congela durante o draw (ícone animado, camada de
> animação da carta, wobble do shader). Antes o teste dependia do
> relógio de parede e falhava no test_all sob carga. reducedMotion
> explícito: outra suite pode ter deixado ligado.

