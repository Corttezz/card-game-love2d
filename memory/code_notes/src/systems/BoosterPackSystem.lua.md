---
name: code_notes/src/systems/BoosterPackSystem.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/BoosterPackSystem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/BoosterPackSystem.lua`

Origem: `src/systems/BoosterPackSystem.lua` em `7dbdb60d` (15 de 20 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-35 (junto a `local BoosterPackSystem = {}`)

> src/systems/BoosterPackSystem.lua
> Gera o conteúdo de um booster pack baseado no kind. Aplica edition/seal
> probabilisticamente em Standard packs (Balatro feel: foil/holo/poly
> + Red/Blue/Gold/Purple seals). A edition "negative" (cor invertida, +1 vaga
> de coringa) SAIU em Out/2026 (dono: "essa mecânica não é usada em lugar
> nenhum, tire isso"): nunca mais é sorteada, e cópias em saves antigos
> viram carta comum (RunManager:buildPlayableDeck).
>
> P0.6 (rebalance Jul/2026):
> (a) TODO roll de pack usa o stream "shop" do Rng seedado — packs são
> decisão de RUN (love.math.random quebrava a reprodutibilidade por seed
> e o anti-save-scum).
> (b) Estojo do Saltimbanco (kind Buffoon): pool = jokers da classe +
> neutros (class 'basic'/nil),
> pesado por raridade; dedup dentro do pack E contra jokers já
> possuídos (P0.10 — a posse/coleção fica intocada, a vitrine é que
> não repete).
> (c) Arcana/Celestial/Spectral: o fallback deixa de ser o pool GLOBAL e
> vira classe do jogador + neutras, com pesos de raridade por ato.
>
> ATENÇÃO — OS TRÊS SÃO O MESMO PACOTE (auditoria Set/2026): Arcana,
> Celestial e Spectral caem no MESMO gerador, com o MESMO pool e os MESMOS
> pesos; só o `size` muda (3/3/2). Arcana e Celestial são gêmeos idênticos:
> dois nomes, duas artes, um conteúdo. Os nomes antigos (Arcano/Celestial/
> Espectral, com descrições prometendo "tarôs", "planetas" e "espectrais")
> eram herança do Balatro e MENTIAM sobre o conteúdo — foram trocados pela
> família do mercador (Relicário do Vidente / Cofre do Astrólogo / Mortalha
> do Coveiro) e as descrições passaram a dizer a verdade ("cartas seletas").
> O nome agora é honesto, mas a DUPLICAÇÃO continua: se for dar identidade
> mecânica a cada um, é aqui que ela mora. `kind` é a chave que separa.
>
> Uso:
> local pack = { kind = "Standard", size = 3, classId = "warrior" }
> local contents = BoosterPackSystem.generateContents(pack)
> contents = { cardInstance, cardInstance, cardInstance }

## L42-43 (em `BoosterPackSystem`, junto a `local EDITION_RATES = {`)

> Rates "garantidas" pra Standard pack (Balatro: base × 25 multiplier
> aplicado quando o pack força roll). Soma 22,5% de chance de ter edition.

## L53-54 (em `SEAL_TYPES`, junto a `local BUFFOON_RARITY_WEIGHT = { common = 1.0, uncommon = 1.0, rare = 0.6, legendary = 0.15 }`)

> Peso por raridade dos jokers no Estojo do Saltimbanco (P0.6b): legendaries são
> raros de sair mesmo no pack dedicado.

## L74-77 (em `pollSeal`, junto a `local function sortedIds(all)`)

> IDs ordenados: pairs() não tem ordem estável e o pool alimenta rolls
> seedados — sem sort, a mesma seed daria packs diferentes por sessão
> (mesma razão do sort em CardRegistry:getCardsByClassAndRarity).
> Só cartas DESBLOQUEADAS (UnlockSystem): pacote é oferta como qualquer outra.

## L88 (em `ids`, junto a `local function classOk(c, classId)`)

> Neutra ofertável = class nil OU 'basic' (espelha o P0.1 do CardRegistry).

## L93-96 (em `classOk`, junto a `function BoosterPackSystem.generateContents(pack)`)

> pack: { kind, size, classId, choose, ownedJokerIds?, rarityWeights? }
> ownedJokerIds — set { [jokerId]=true } (P0.10, só Buffoon usa)
> rarityWeights — pesos por ato (P0.6c, Arcana/Celestial/Spectral usam)
> Retorna lista de instances.

## L112-113 (em `addInstance`, junto a `if require("src.systems.UnlockSystem").markDiscovered(cardId) then`)

> Pacote aberto = carta vista (Coleção revela). Inédita ganha o
> selo "NOVA" + varredura de luz (src/ui/DiscoveryMark.lua).

## L128-129 (em `addInstance`, junto a `local owned = pack.ownedJokerIds or {}`)

> P0.6b: jokers da classe + neutros, pesados por raridade, sem repetir
> dentro do pack nem oferecer joker já possuído (P0.10).

## L149-151 (em `entries`, junto a `local pool = {}`)

> Standard / Arcana / Celestial / Spectral: attack/defense/effect da
> classe + neutras (P0.6c: o fallback dos packs "especiais" não vaza mais
> carta de outra classe).

## L160-161 (em `pool`, junto a `local rarityWeights = (kind ~= "Standard") and pack.rarityWeights or nil`)

> P0.6c: packs não-Standard sorteiam pesado pelos pesos de raridade do ato
> (legendary peso 0 no A1 simplesmente não sai; rarity 'basic' fica fora).

## L169-181 (em `weightedEntries`, junto a `if kind == "Spectral" and (c.rarity == "common" or c.rarity == "basic") then`)

> ESPECTRAL (Mortalha do Coveiro): PISO DE RARIDADE.
>
> Ele dá 2 cartas onde os irmãos dão 3, pelo MESMO $4, e ainda é o
> mais raro de aparecer na loja (weight 0.3). Sem contrapartida
> isso é simplesmente um pacote pior — o jogador que entendesse a
> matemática nunca o compraria, e quem não entendesse seria punido
> por comprar. Decisão do dono (Set/2026): quem dá menos tem que
> dar MELHOR.
>
> A contrapartida é raridade, não edição, de propósito: edição e
> selo são o que torna o Fardo do Mercador único, e duplicar isso
> aqui apagaria a identidade dele — que é o mesmo erro dos packs
> gêmeos, um nível acima.

## L187-189 (em `weightedEntries`, junto a `if kind == "Spectral" then`)

> Rede: se o piso esvaziou a pool (ato/classe sem incomum+), volta aos
> pesos normais. Pack vazio seria muito pior que pack comum, e o
> jogador pagou. Avisa, porque isto não deveria acontecer.

## L218-221 (em `weightedEntries`, junto a `function BoosterPackSystem.expandPackRecord(packRecord, classId, opts)`)

> Helper: dado um pack record (vindo de pendingPacks), retorna metadata pronta
> pra PackOpenScreen consumir.
> opts (P0.6/P0.10, opcional): { runManager=, actNumber= } — liga o dedup de
> joker possuído (Buffoon) e os pesos de raridade por ato (packs especiais).

## L232 (em `pack`, junto a `local run = opts.runManager and opts.runManager.currentRun`)

> P0.10: jokers já possuídos nunca reaparecem na vitrine do pack.

## L243 (em `owned`, junto a `if opts.actNumber then`)

> P0.6c: pesos de raridade por ato pros packs de fallback.

