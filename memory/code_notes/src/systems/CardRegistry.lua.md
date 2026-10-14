---
name: code_notes/src/systems/CardRegistry.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/CardRegistry.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/CardRegistry.lua`

Origem: `src/systems/CardRegistry.lua` em `7dbdb60d` (29 de 39 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-3 (junto a `local CardRegistry = {}`)

> src/systems/CardRegistry.lua
> Sistema centralizado para gestão de cartas e classes.
> Consolida consultas por classe/raridade, starter decks e rolagem de raridade.

## L26-30 (em `filtered`, junto a `local belongsToClass = (card.class == classId) or`)

> Verifica se pertence à classe (ou é básica)
> P0.1 (rebalance Jul/2026): class=='basic' e NEUTRA OFERTAVEL — devolve
> 9 cartas ao jogo (attack_cleave, defense_bulwark, scroll_wisdom,
> mystery_card, joker_004/005 e os 3 legendarios joker_001/002/003).
> O clause antigo por rarity=='basic' era codigo morto e foi removido.

## L40-41 (em `filtered`, junto a `table.sort(filtered)`)

> Ordena por id: pairs() não tem ordem estável e a pool alimenta rolls
> seedados — sem sort, a mesma seed daria ofertas diferentes por sessão.

## L57-60 (em `CardRegistry:getClassCardPool`, junto a `function CardRegistry:getStarterDeckForClass(classId)`)

> Retorna deck inicial para uma classe.
> Fase 5: deck minimo de 2 cartas (1 attack + 1 defense da classe). O resto e
> construido via recompensas/loja/eventos. Cada batalha puxa as 2 cartas direto
> na mao inicial (INITIAL_HAND_SIZE=4 garante folga mesmo com deck curto).

## L73-75 (em `RARITY_MIN_ORDER`, junto a `local AFFINITY_TAG_BLACKLIST = { strike = true, defend = true, armor = true, magic = true }`)

> ===== Afinidade de ofertas (P0.5, rebalance Jul/2026) =====
> Tags genericas demais para sinalizar arquetipo (quase toda carta as tem):
> conta-las fazia a afinidade puxar "mais do mesmo" em vez de build.

## L77-78 (em `AFFINITY_TAG_BLACKLIST`, junto a `local AFFINITY_PER_TAG = 0.45`)

> Peso por tag forte. SUPERSEDE Config.Offers.AFFINITY_PER_TAG=0.20 (handoff:
> centralizar em Config.Offers junto com o cap por ato e a blacklist).

## L80-83 (em `AFFINITY_TAG_BLACKLIST`, junto a `local AFFINITY_CAP_BY_ACT = { [1] = 0.9, [2] = 1.2, [3] = 1.5 }`)

> Cap PROGRESSIVO por ato (era 0.60 flat em Config.Offers.AFFINITY_CAP):
> A1 baixo preserva a variedade do draft inicial (2 primeiros picks nao
> travam a run); A2/A3 entregam densidade de arquetipo onde importa.
> Endless (ato > 3) usa o cap do A3.

## L85-86 (em `AFFINITY_CAP_BY_ACT`, junto a `local NEUTRAL_CARD_WEIGHT = 0.6`)

> P0.2: cartas neutras (class nil ou 'basic') ofertam com peso reduzido —
> a vitrine continua majoritariamente da classe.

## L89-92 (em `AFFINITY_CAP_BY_ACT`, junto a `local function buildOwnedJokerSet(runManager)`)

> P0.10: set { [jokerId]=true } dos jokers ja POSSUIDOS pela run (colecao +
> bancada). Dedup e de OFERTA apenas: a posse/colecao fica intocada (lei do
> projeto) — a vitrine e que nao repete joker (flat duplicado e valor
> marginal; multiplicador duplicado vale zero pos-largest-wins P0.9).

## L105-106 (em `owned`, junto a `local function getPity(rng)`)

> Pity de raridade vive em rng.meta (serializado no save junto com o RNG e
> compartilhado entre recompensas E loja — uma sequência de azar só).

## L116-120 (em `setPity`, junto a `local SUSTAIN_EFFECTS = { instant_heal = true, on_attack_heal = true, regen_per_turn = true }`)

> Conta as tags do deck atual (por cópia — 3 cartas de veneno = veneno forte).
> Alimenta a afinidade das ofertas: escolhas anteriores importam.
> wip/sustain: carta de SUSTENTO = devolve vida ao longo da run (cura
> instantânea, roubo de vida, regeneração). Fonte única pra oferta garantida
> (Config.Offers.SUSTAIN_*) e pro peso extra; o piloto tem a própria leitura.

## L151-162 (em `counts`, junto a `function CardRegistry:pickRewardCard(opts)`)

> Sorteia UMA carta de oferta com pity + afinidade + anti-duplicata.
> opts:
> classId       — filtra pool da classe (nil = todas as cartas com raridade)
> rarityWeights — pesos { common=, uncommon=, rare=, legendary= } (qualquer escala)
> minRarity     — piso ("uncommon"/"rare" pra elites/bosses)
> deckIds       — ids do deck atual (afinidade + penalidade de cópia)
> excludeIds    — set { [cardId]=true } já oferecidos (dedup na mesma oferta)
> actNumber     — ato atual (P0.5: cap progressivo de afinidade 0.9/1.2/1.5)
> runManager    — P0.10: dedup de joker já possuído (ou passe ownedJokerIds)
> ownedJokerIds — set { [jokerId]=true } pré-construído (opcional)
> rng, stream   — default Rng.get() / "card" (loja usa "shop")
> Retorna { cardId, rarity, affinity, affinityTags, fromPity } ou nil.

## L174-175 (em `CardRegistry:pickRewardCard`, junto a `local pool = self:_poolFor(opts.classId, rarity)`)

> Pool da raridade (fallback desce a escada se vazia — ex: legendary numa
> classe sem lendárias não pode travar a oferta).

## L183-185 (em `CardRegistry:pickRewardCard`, junto a `if opts.requireSustain then`)

> wip/sustain: vaga RESERVADA a sustento (opts.requireSustain) — filtra a
> pool; se a raridade sorteada não tem sustento, desce a escada; se a
> classe não tem nenhum, a vaga volta a ser comum (nunca trava a oferta).

## L217 (em `copies`, junto a `local actNumber = opts.actNumber or 1`)

> P0.5: cap de afinidade progressivo por ato (endless herda o do A3).

## L221 (em `copies`, junto a `local ownedJokers = opts.ownedJokerIds or buildOwnedJokerSet(opts.runManager)`)

> P0.10: jokers já possuídos saem da vitrine (posse intocada).

## L230 (em `entries`, junto a `local weight = (cd and (cd.class == nil or cd.class == "basic"))`)

> P0.2: neutras (class nil/'basic') entram com peso base 0.6.

## L235-236 (em `entries`, junto a `if cd and cd.tags then`)

> Afinidade: cada tag da carta que é "forte" no deck puxa a oferta.
> P0.5: tags genéricas (blacklist) não contam; 0.45/tag com cap por ato.

## L268-270 (em `item`, junto a `local isNew = false`)

> Ofertada = vista: passa a aparecer revelada na Coleção. discover=false
> (eventos): a candidata só é vista se o evento a ENTREGAR — aí quem
> descobre é o Game:addCardToRun, que anuncia a carta inédita.

## L283-286 (em `item`, junto a `function CardRegistry:_poolFor(classId, rarity)`)

> Pool ordenada por classe+raridade; classId nil = todas as cartas da raridade.
> SÓ cartas DESBLOQUEADAS (UnlockSystem, meta-progressão): esta é a porta
> única de rewards, loja e eventos — carta bloqueada nunca entra numa oferta.
> (Pacotes têm pool própria em BoosterPackSystem, com o mesmo filtro.)

## L305-308 (em `out`, junto a `function CardRegistry:generateCardRewards(classId, numCards, opts)`)

> Gera recompensas de cartas para uma classe (sem duplicata na mesma oferta).
> opts.rarityWeights: pesos customizados (ActSystem passa por ato).
> opts.minRarity: "uncommon"/"rare" para forcar piso (elites/bosses).
> opts.deckIds: deck atual — liga afinidade e anti-duplicata.

## L322 (em `exclude`, junto a `actNumber = opts.actNumber,`)

> P0.5: cap de afinidade por ato

## L323 (em `exclude`, junto a `runManager = opts.runManager,`)

> P0.10: dedup de joker possuído

## L339-347 (em `exclude`, junto a `function CardRegistry:rollRarity(weights, opts)`)

> Sistema de raridade com pesos customizaveis + PITY acumulativo.
> weights: { common=N, uncommon=N, rare=N, legendary=N } (qualquer escala).
> opts: { rng=, stream= }. Retorna (rarity, fromPity).
>
> Pity ("blizzard" adaptado do StS): cada roll SEM rare/legendary incrementa
> um contador que infla o peso de rare+legendary em PITY_STEP por nível;
> na HARD_PITY-ésima oferta seca, rare é garantida. Sair rare+ zera. O
> contador só se move quando rare é POSSÍVEL no peso (pools 100/0/0/0 dos
> testes não inflam nada).

## L400-402 (em `eff`, junto a `function CardRegistry:isClassCard(cardId, classId)`)

> Verifica se uma carta pertence a uma classe
> P0.1: mesmo critério de belongsToClass — class=='basic' é neutra (o clause
> antigo por rarity=='basic' foi removido).

## L419 (em `warrior`, junto a `passiveName = I18n.t("classes.warrior.passive_name"),`)

> Passiva de classe (identidade de gameplay — Jul/2026)

## L434 (em `mage`, junto a `passiveName = I18n.t("classes.mage.passive_name"),`)

> Passiva de classe (identidade de gameplay — Jul/2026)

## L449 (em `rogue`, junto a `passiveName = I18n.t("classes.rogue.passive_name"),`)

> Passiva de classe (identidade de gameplay — Jul/2026)

## L474 (em `CardRegistry:getAllClasses`, junto a `function CardRegistry:getCard(cardId)`)

> Delegate methods para manter compatibilidade com CardDatabase

