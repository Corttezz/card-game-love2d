---
name: code_notes/tools/test_intent_visibility.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_intent_visibility.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_intent_visibility.lua`

Origem: `tools/test_intent_visibility.lua` em `7dbdb60d` (17 de 38 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-27 (junto a `local TK = require("tools.testkit")`)

> tools/test_intent_visibility.lua
> TRAVA da NÉVOA DE INTENÇÃO (Out/2026, src/systems/IntentVisibility.lua).
>
> Ideia do dono: nos biomas do fim da jornada a nevasca esconde parte do que
> o inimigo anuncia (tipo sem número; na névoa fechada nem o tipo). Esta
> suíte trava o que não pode quebrar:
> 1. DADOS: toda regra de névoa aponta pra um bioma real; frost e dusk
> ligados, os outros limpos; a curva de densidade É a do clima na tela;
> densidade cresce com o andar, o salão tem a sua, o endless cicla.
> 2. RESOLUÇÃO: a mesma rolagem dá o mesmo nível; sem névoa nem véu o Rng
> NÃO anda; a rolagem usa o stream "misc" (o "enemy" fica intocado);
> a mesma seed reproduz a sequência.
> 3. VÉU do inimigo (kit/fase) combina pelo pior nível; chance parcial.
> 4. REVELAÇÃO: carta revela agora + N; pulso do Raio revela o PRÓXIMO.
> 5. CONGELADO: o golpe escondido acerta EXATAMENTE o número congelado
> (CLAUDE.md §6) — a névoa só muda a leitura.
> 6. HUD: intentSpec mostra "?" / desconhecido, tooltip da névoa nos 5
> idiomas, nenhum número vaza; drawIntent + véu desenham sem erro.
> 7. CONTADORES: efeito `reveal_intent` existe, 4 cartas o carregam
> (uma por classe + a neutra), o orbe de Raio revela o próximo anúncio.
> 8. MUNDO: o WeatherEngine engrossa quando o número some e volta quando
> aparece; salão e inimigo morto não empurram o clima; reset zera.
> 9. PILOTO: getKnownIntent / getKnownIncomingDamage nunca entregam número
> escondido.
> 10. TUTORIAL: conversa `fog` no roteiro, textos nos 5 idiomas.
>
> love . test_one test_intent_visibility

## L56-58 (em `M.run`, junto a `local list = biomes.list or biomes`)

> ======================================================================
> 1. DADOS
> ======================================================================

## L146-148 (em `endlessCtx`, junto a `local wolf = Enemy:new(100, 10, "frost_wolf")   -- kit SEM véu`)

> ======================================================================
> 2. RESOLUÇÃO (rolagem injetada)
> ======================================================================

## L199-201 (em `out`, junto a `t:eq("worst(type_only, hidden) = hidden", IV.worst("type_only", "hidden"), "hidden")`)

> ======================================================================
> 3. VÉU do inimigo
> ======================================================================

## L252 (em `seq`, junto a `i = 0; seq = { 0.99, 0.1 }`)

> névoa clareira (0.99) + véu (0.1) → type_only por causa do véu

## L266-268 (em `seq`, junto a `wight:rollIntent()`)

> ======================================================================
> 4. REVELAÇÃO
> ======================================================================

## L285-287 (em `seq`, junto a `TK.seedRng(2024)`)

> ======================================================================
> 5. CONGELADO: o golpe escondido acerta o número congelado
> ======================================================================

## L331-333 (em `seq`, junto a `local EnemyHud = require("src.ui.EnemyHud")`)

> ======================================================================
> 6. HUD: intentSpec e desenho
> ======================================================================

## L378 (em `seq`, junto a `local realTime = love.timer.getTime`)

> desenho: box + véu num canvas, o véu aparece depois de alguns quadros

## L410-412 (em `love.timer.getTime`, junto a `g.enemy.intentVisibility, g.enemy.intentVeilCause = "type_only", "fog"`)

> ======================================================================
> 7. CONTADORES
> ======================================================================

## L453-455 (em `g.player.orbs`, junto a `IV.noteActive(g.enemy)`)

> ======================================================================
> 8. MUNDO: o clima acompanha o estado
> ======================================================================

## L483-486 (em `weather`, junto a `local TH = IV.FOG_THRESHOLD`)

> INVARIANTE (lead): "?" nunca sobre céu limpo — assentado o clima, a
> bruma de tela (renderedFog) está acima do limiar sempre que o intent
> está encoberto, e abaixo quando revelado. 15 quadros ≈ 0,5 s: menos
> que os beats entre o anúncio e a vez voltar ao jogador.

## L498-501 (em `weather`, junto a `do`)

> CADEIA REAL (lead): o anúncio escondido acontece no turno do inimigo
> (beat enemy.next_intent) e a bruma precisa ter fechado ANTES de a vez
> voltar ao jogador (turn.player_ready). O espectro do gelo tem véu com
> chance 1: todo anúncio sai type_only, sem depender da rolagem.

## L537-538 (em `weather`, junto a `do`)

> a bruma é DESENHADA (bandas no flushAll) quando há véu, e não há
> banda alguma com o número à mostra

## L560-561 (em `frame`, junto a `g.enemy.intentVisibility = "hidden"`)

> salão: o clima do domo não responde; quem responde é o InteriorFX
> (hook de chefes-visual-3, e37a148) — mesmo limiar, mesma propriedade

## L600-602 (em `hallFrames`, junto a `local NUMERIC = { "perHit", "hits", "armor", "strength", "heal", "raw", "summon" }`)

> ======================================================================
> 9. PILOTO não enxerga número escondido
> ======================================================================

## L646-648 (em `leaked`, junto a `local Tutorial = require("src.systems.Tutorial")`)

> ======================================================================
> 10. TUTORIAL
> ======================================================================

