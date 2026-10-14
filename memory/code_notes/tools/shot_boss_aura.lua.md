---
name: code_notes/tools/shot_boss_aura.lua
description: Comentários com decisão/regra/histórico colhidos de tools/shot_boss_aura.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/shot_boss_aura.lua`

Origem: `tools/shot_boss_aura.lua` em `7dbdb60d` (4 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local M = {}`)

> tools/shot_boss_aura.lua
> Prancha dos CHEFES vivos: cada sala com o chefe dela, pelo caminho real de
> desenho (GameplayScene.draw), em 4 instantes seguidos — prova que o idle
> assado mexe, que a aura (src/data/boss_auras.lua) aparece e em que
> profundidade. Sem janela própria: desenha num Canvas e salva.
>
> love . test_one shot_boss_aura [ato|all][:hurt|:death]
> (ex.: `1:death` — o test_one só repassa UM argumento)
> SHOT_SIZE=1920x1080 muda o tamanho da janela (um setMode só).
> `:death` captura 6 instantes da queda/morte + boss_full_<ato>_death_last.
>
> Saída no save dir: boss_aura_<ato>.png (4 recortes lado a lado) e
> boss_full_<ato>.png (tela inteira do 1º instante).

## L69-70 (em `render`, junto a `render()`)

> assenta: aura cheia de partículas e idle no meio do ciclo. Um draw
> ANTES: é o draw que diz ao EnemyRenderer quem é o chefe da aura.

## L80-83 (em `shots`, junto a `local marks = { 0.0, 0.18, 0.32, 0.45, 0.8, 2.6 }`)

> queda do flutuante: início, meio da queda, impacto, quique,
> assentado e o cadáver 2s depois (não pode voltar a pairar)
> desenha a cada passo: a mão (que desce quando o cadáver cai atrás
> dela) anima no draw, com o dt do quadro

## L127 (em `M.run`, junto a `local sw, sh = (os.getenv("SHOT_SIZE") or ""):match("^(%d+)x(%d+)$")`)

> SHOT_SIZE=1920x1080: UM setMode antes de tudo (repetido trava em tool)

