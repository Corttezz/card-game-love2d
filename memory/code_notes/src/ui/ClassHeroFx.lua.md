---
name: code_notes/src/ui/ClassHeroFx.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/ClassHeroFx.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/ClassHeroFx.lua`

Origem: `src/ui/ClassHeroFx.lua` em `7dbdb60d` (1 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local ClassHeroFx = {}`)

> src/ui/ClassHeroFx.lua
> Atmosfera do emblema em FOCO na seleção de classe v4 (Out/2026). O idle
> do próprio objeto (lâmina que brilha, orbe que flutua, gotas da adaga) mora
> no ClassEmblem; aqui fica o AR em volta, um por classe:
> warrior — brasas subindo da base e faíscas de aço
> mage    — poeira arcana em órbita lenta, piscando
> rogue   — névoa de veneno escorrendo e um brilho de lâmina que corre
> Tudo em quadradinhos de pixel no tamanho do pixel do emblema (sem
> partícula suave). `burst` = a classe acabou de entrar em foco.
>
> ClassHeroFx.update(dt, classId, box)   box = { cx, cy, w, h, px }
> ClassHeroFx.draw(alpha)
> ClassHeroFx.burst(classId, box)

