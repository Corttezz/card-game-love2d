---
name: code_notes/tools/test_systems.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_systems.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_systems.lua`

Origem: `tools/test_systems.lua` em `7dbdb60d` (13 de 34 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local Rng = require("src.systems.Rng")`)

> tools/test_systems.lua
> Valida a entrega STS-improvements v1 (docs/plan/sts-improvements-v1.md):
> Step 1 — Rng seedável com streams (determinismo + roundtrip getState)
> Step 2 — pity de raridade + afinidade/anti-duplicata nas ofertas
> Step 3 — upgrade infinito + custo crescente da forja paga
> Step 6 — Events.roll com histórico por ato
> Rodar: love . test_systems   (headless-ish; sai com exit code)

## L75 (em `after2`, junto a `local r5 = Rng.new(42)`)

> 5. Peso 100/0/0/0: sempre common e o pity NÃO se move (rare impossível).

## L94-96 (em `after2`, junto a `local r7 = Rng.new(31337)`)

> 7. Janela de pity: com pesos do ato 1 (rare 5%), nunca passa de HARD_PITY
> ofertas sem rare+ — e o crescimento do peso segura a janela real bem
> abaixo do teto na prática.

## L115-116 (em `deckIds`, junto a `local pool = reg:getCardsByClassAndRarity("warrior", "common")`)

> Monta um deck com 3 cópias da primeira carta common do warrior que tenha
> tags (afinidade precisa de tag presente 2+ vezes).

## L135-137 (em `seen`, junto a `local AFFINITY_BLACKLIST = { strike = true, defend = true, armor = true, magic = true }`)

> Coerência do flag: affinity ⟺ carta tem tag forte NÃO-genérica do deck.
> P0.5 (rebalance Jul/2026): tags genéricas {strike, defend, armor, magic}
> saíram da contagem de afinidade (blacklist em CardRegistry.pickRewardCard).

## L193-194 (em `AFFINITY_BLACKLIST`, junto a `local gAtk = RunManager.getForgeGains({ attack = 8, defense = 0 })`)

> 11b. Regra de forja por CENÁRIO (playtest: ataque puro ganhava DEF
> fantasma — defense=0 é truthy). getForgeGains é a fonte única.

## L208 (em `effects`, junto a `if upgraded and cdBase and (cdBase.defense or 0) == 0 then`)

> Instância real: a carta forjada +7 não pode ter DEF fantasma.

## L242 (em `nodesB`, junto a `Rng.setActive(Rng.new(88))`)

> 14. Histórico: evento visto no ato não repete (com pool > 1).

## L261 (em `history`, junto a `local okER, ER = pcall(require, "src.ui.EnemyRenderer")`)

> ===== Fix Jul/2026: attack anim (loop infinito + encolhimento) =====

## L263-264 (em `history`, junto a `local okER, ER = pcall(require, "src.ui.EnemyRenderer")`)

> 14b. Ciclo attack→idle: o clip de ataque é ONE-SHOT e volta pro idle
> sozinho (bug: caía no default loop+pingpong e repetia pra sempre).

## L280 (em `fakeGame`, junto a `for _ = 1, 180 do ER.update(1 / 60) end`)

> 3s simulados >> 9 frames a 12fps (~0.75s): tem que ter voltado.

## L286-287 (em `fakeGame`, junto a `local mi = ER.debugClipMetrics("cursed_scarecrow", "idle")`)

> 14c. Escala estável: a referência de escala é o IDLE; o canvas cru
> do attack (PixelLab sem crop) é maior mas NÃO pode mudar o corpo.

## L303-305 (em `fakeGame`, junto a `local rmJ = RunManager:new()`)

> ===== Jokers: modelo coleção + bancada (Jul/2026) =====
> Bug morto: comprar o 4º joker o fazia SUMIR. Agora entra na bancada e o
> jogador escolhe quais MAX_JOKER_SLOTS ativar.

