---
name: code_notes/tools/test_enemy_fall.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_enemy_fall.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_enemy_fall.lua`

Origem: `tools/test_enemy_fall.lua` em `7dbdb60d` (3 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local TK = require("tools.testkit")`)

> tools/test_enemy_fall.lua
> Quem VOA, quando morre, CAI e fica deitado no chão (pedido do dono,
> Out/2026). Ver memory/boss_visuals.md e enemy_pose_and_scene_anchor §3.
>
> love . test_one test_enemy_fall
>
> Para TODO inimigo flutuante declarado em src/data/enemy_poses.lua, em cada
> linha de chão possível (os 6 salões em 3 tamanhos de tela + a estrada) e
> em 3 escalas de palco (sizeK da estrada / hallScreenK 1.3 em 1080p):
> (a) no meio da queda o corpo ainda está ACIMA do chão (caiu, não teleportou)
> (b) o quadro final repousa com o pixel opaco mais baixo FOOT_SINK px
> dentro do chão (± 1px de arredondamento) — a mesma régua de quem pisa.
> Salão com `deathYr` (scene_anchors): o chão é o do CADÁVER, no piso
> andável à frente (o do vivo no salão 2 é a faixa colada na parede)
> (c) e CONTINUA lá 3s depois (não volta a pairar)
> (d) reducedMotion: queda mais curta, mesmo repouso
> Apoiados não mudam: o pé da death continua na linha de antes.

## L36 (em `sizes`, junto a `local a = SceneAnchors.get(scene)`)

> chão do CADÁVER (deathYr): onde o corpo tem que terminar

## L131-135 (em `at`, junto a `do`)

> APOIADOS: o CADÁVER também repousa no chão (Out/2026, "os ratos
> morrem e ficam errado no chão" — o monte afundava atravessando a
> estrada). A margem de pé da death é a do QUADRO pela regra do apoio;
> o último quadro tem que terminar FOOT_SINK px dentro do chão, sem
> pairar nem atravessar, em todo inimigo que pisa e tem death.

