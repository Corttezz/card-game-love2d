-- tools/autoplay.lua
-- PILOTO DE IA: joga o jogo de verdade, sozinho, pelos MESMOS sistemas do
-- jogador (Game:selectCard/playSelectedCards/enemyTurn, RunManager:chooseNode,
-- ShopSystem, Events.apply, forja) — e escreve um DIÁRIO de tudo que decidiu
-- e por quê, mais métricas de experiência por run.
--
--   love . autoplay [runs] [classe|all]
--   ex: love . autoplay 2 all      → 2 runs por classe (6 runs)
--       love . autoplay 3 warrior  → 3 runs de guerreiro
--
-- Saída: autoplay_report.md no save dir (~/Library/Application Support/LOVE/
-- card-game/). O relatório é o insumo pra análise de game feel: decisões
-- reais vs automáticas, causa das mortes, curva de HP/ouro, uso de cura,
-- combos, duração de batalhas.
--
-- IMPORTANTE: roda com _G.HEADLESS_TOOL (main.lua) — perfil real intocado.

local M = {}

local EventManager = require("engine.EventManager")
local Events       = require("src.data.events")
local MapManager   = require("src.systems.MapManager")
local TagSystem    = require("src.systems.TagSystem")

-- ============================================================
-- Diário
-- ============================================================

local report = {}
local anomalies = {}   -- invariantes violadas (o "grito" que faltou no bug do escudo)
local function anomaly(fmt, ...)
    local line = select("#", ...) > 0 and fmt:format(...) or fmt
    table.insert(anomalies, line)
    table.insert(report, "  !! ANOMALIA: " .. line)
    print("[autoplay] !! ANOMALIA: " .. line)
end
local function log(fmt, ...)
    local line = select("#", ...) > 0 and fmt:format(...) or fmt
    table.insert(report, line)
end

-- ============================================================
-- Helpers de simulação
-- ============================================================

local function pump(game, secs)
    local dt = 1 / 30
    for _ = 1, math.max(1, math.floor(secs * 30)) do
        EventManager.update(dt)
        if game.combatAnimationSystem and game.combatAnimationSystem.update then
            game.combatAnimationSystem:update(dt)
        end
        -- Enemy.attackCooldown decrementa em update(dt) — sem bombear isso o
        -- inimigo trava em cooldown eterno e a batalha congela (1ª rodada de
        -- autoplay pegou exatamente esse sintoma).
        if game.enemy and game.enemy.update then
            game.enemy:update(dt)
        end
        -- Investida do inimigo: o dano é aplicado no APEX via
        -- EnemyRenderer.update — sem bombear, o hit nunca acontece.
        do
            local okER, ER = pcall(require, "src.ui.EnemyRenderer")
            if okER and ER.update then ER.update(dt) end
        end
    end
end

local function handSummary(game)
    local parts = {}
    for _, c in ipairs(game.hand) do
        local stat = (c.attack or 0) > 0 and (c.attack .. "atk")
            or (c.defense or 0) > 0 and (c.defense .. "def")
            or c.type
        table.insert(parts, ("%s(%d:%s)"):format(c.name or c.id, c.cost or 0, stat))
    end
    return table.concat(parts, " ")
end

-- ============================================================
-- POLÍTICA DE BATALHA (o "cérebro")
-- ============================================================
-- Decide o que jogar num turno, com uma razão legível. Heurística:
--   1. LETHAL: se dá pra matar agora, mata.
--   2. SOBREVIVER: se o hit anunciado machuca de verdade, defende primeiro.
--   3. CURAR: HP < 35% e tem cura na mão → usa.
--   4. VALOR: maximiza dano por mana, preferindo pares de tags (combos).

local function expectedDamage(game, card)
    local dmg = (card.attack or 0)
    if dmg <= 0 then return 0 end
    local str = game.player.strength or 0
    -- v3: strength_scaling agora conta Forca em DOBRO (auditoria Jul/2026)
    for _, e in ipairs(card.effects or {}) do
        if e.type == "strength_scaling" then str = str * 2; break end
    end
    return dmg + str
end

local function expectedArmor(game, card)
    local def = (card.defense or 0)
    if def <= 0 then return 0 end
    return def + (game.player.dexterity or 0)
end

local function hasEffect(card, etype)
    for _, e in ipairs(card.effects or {}) do
        if e.type == etype then return true end
    end
    return false
end

-- Tags relevantes pros combos ativos (ComboSystem): jogar PARES paga.
local COMBO_TAGS = { strike = true, poison = true, magic = true,
                     defend = true, armor = true, channel = true }

local function cardHasTag(card, tag)
    for _, t in ipairs(card.tags or {}) do
        if t == tag then return true end
    end
    return false
end

-- Estima o dano REAL de um conjunto, aproximando os combos principais
-- (strike_combo ×1.4 com 2+ strikes, +6 com 3+; magic_focus ×1.5).
local function estimateSetDamage(game, set)
    local total, strikes, magics = 0, 0, 0
    for _, c in ipairs(set) do
        local d = expectedDamage(game, c)
        total = total + d
        if d > 0 and cardHasTag(c, "strike") then strikes = strikes + 1 end
        if d > 0 and cardHasTag(c, "magic") then magics = magics + 1 end
    end
    if strikes >= 2 then total = math.floor(total * 1.4) end
    if strikes >= 3 then total = total + 6 end
    if magics >= 2 then total = math.floor(total * 1.5) end
    return total
end

local function chooseCards(game)
    local mana = game.player.mana
    local hand = game.hand
    local kind, value = game.enemy:getIntentPreview()
    local incoming = (kind == "attack" or kind == "strong") and (value or 0) or 0

    local picks, reasons = {}, {}
    local manaLeft = mana

    local function pick(card, why)
        table.insert(picks, card)
        manaLeft = manaLeft - (card.cost or 0)
        reasons[why] = true
    end
    local function picked(card)
        for _, p in ipairs(picks) do if p == card then return true end end
        return false
    end

    -- 0. Utilidade custo 0 (draw/mana) sempre vale.
    for _, c in ipairs(hand) do
        if (c.cost or 0) == 0 and c.type == "effect"
            and (hasEffect(c, "draw_cards") or hasEffect(c, "restore_mana")) then
            pick(c, "utilidade-0")
        end
    end

    -- 1. LETHAL? (v2: considera combos do conjunto, não só a soma)
    local atkCards = {}
    for _, c in ipairs(hand) do
        if not picked(c) and expectedDamage(game, c) > 0 then
            table.insert(atkCards, c)
        end
    end
    -- v2: ordena por dano/mana MAS com bônus de sinergia — a 2ª carta da
    -- mesma tag de combo vale mais que o valor de face.
    local function synergyScore(c, chosenSet)
        local ca = math.max(1, c.cost or 0)
        local s = expectedDamage(game, c) / ca
        for _, tag in ipairs(c.tags or {}) do
            if COMBO_TAGS[tag] then
                for _, other in ipairs(chosenSet) do
                    if cardHasTag(other, tag) then
                        s = s + 4  -- completa/estende um combo
                        break
                    end
                end
            end
        end
        return s
    end
    do
        -- monta o melhor conjunto guloso COM sinergia e testa lethal
        local set, cost = {}, 0
        local pool = {}
        for _, c in ipairs(atkCards) do table.insert(pool, c) end
        while true do
            local best, bestS = nil, -1
            for _, c in ipairs(pool) do
                local inSet = false
                for _, x in ipairs(set) do if x == c then inSet = true end end
                if not inSet and cost + (c.cost or 0) <= manaLeft then
                    local s = synergyScore(c, set)
                    if s > bestS then best, bestS = c, s end
                end
            end
            if not best then break end
            table.insert(set, best)
            cost = cost + (best.cost or 0)
        end
        if estimateSetDamage(game, set)
            >= (game.enemy.health + (game.enemy.armor or 0)) then
            for _, c in ipairs(set) do pick(c, "LETHAL") end
            return picks, "LETHAL"
        end
    end

    -- 1b. DEBUFF SETUP (v2): Vulnerável ANTES dos ataques amplifica o turno
    -- inteiro (+50%). Só vale se ainda vamos atacar 2+ vezes.
    if #atkCards >= 2 then
        for _, c in ipairs(hand) do
            if not picked(c) and (c.cost or 0) <= manaLeft then
                for _, e in ipairs(c.effects or {}) do
                    if e.type == "apply_debuff" and e.value == "vulnerable"
                        and not game.enemy:hasStatus("vulnerable") then
                        pick(c, "setup-vulneravel")
                        break
                    end
                end
            end
        end
    end

    -- 2. CURAR (antes de defesa: potion barata salva o turno).
    local hpRatio = game.player.health / game.player.maxHealth
    if hpRatio < 0.35 then
        for _, c in ipairs(hand) do
            if not picked(c) and hasEffect(c, "instant_heal")
                and (c.cost or 0) <= manaLeft then
                pick(c, "curar")
                break
            end
        end
    end

    -- 3. SOBREVIVER: cobre o hit anunciado se ele dói (>25% do HP atual).
    -- v3 cap-aware: Bloqueio trunca em maxArmor (30) — defender além do
    -- min(hit, cap) é desperdício puro (o jogo agora até avisa no toast).
    if incoming > 0 and incoming >= game.player.health * 0.25 then
        local defCards = {}
        for _, c in ipairs(hand) do
            if not picked(c) and expectedArmor(game, c) > 0 then
                table.insert(defCards, c)
            end
        end
        table.sort(defCards, function(a, b)
            local ca, cb = math.max(1, a.cost or 0), math.max(1, b.cost or 0)
            return expectedArmor(game, a) / ca > expectedArmor(game, b) / cb
        end)
        local armor = game.player.armor or 0
        local target = math.min(incoming, game.player.maxArmor or 30)
        for _, c in ipairs(defCards) do
            if armor >= target then break end
            if (c.cost or 0) <= manaLeft then
                pick(c, "defender")
                armor = armor + expectedArmor(game, c)
            end
        end
    end

    -- 4. VALOR (v2): resto da mana em dano escolhido POR SINERGIA — a 2ª
    -- carta da mesma tag de combo vale +4 (strike_combo/magic_focus/poison).
    -- v4 anti-muro: a armadura do inimigo EXPIRA no turno dele — socar um
    -- muro maior que nosso output total e leva jogada fora ("dano causado 0"
    -- nos diarios). Nesse caso a mana vai pra defesa/orbes na sobra.
    local wall = game.enemy.armor or 0
    local atkWorthIt = true
    if wall > 0 then
        local affordable = {}
        for _, c in ipairs(atkCards) do
            if not picked(c) and (c.cost or 0) <= manaLeft then
                table.insert(affordable, c)
            end
        end
        atkWorthIt = estimateSetDamage(game, affordable) > wall
    end
    while atkWorthIt do
        local best, bestS = nil, -1
        for _, c in ipairs(atkCards) do
            if not picked(c) and (c.cost or 0) <= manaLeft then
                local s = synergyScore(c, picks)
                if s > bestS then best, bestS = c, s end
            end
        end
        if not best then break end
        pick(best, "dano")
    end
    -- 4b. mana sobrando e nada de ataque? joga defesa/efeito que couber.
    -- v3: defesa com Bloqueio ja no cap e jogada morta — pula.
    -- v4: dois passes — nao-ataque primeiro (no anti-muro, a mana util vai
    -- pra defesa/efeito antes de sobrar pra ataques que batem no muro).
    for pass = 1, 2 do
        for _, c in ipairs(hand) do
            local wantPass = (pass == 1 and c.type ~= "attack")
                or (pass == 2 and c.type == "attack")
            if wantPass and not picked(c) and (c.cost or 0) <= manaLeft
                and c.type ~= "joker" then
                local atCap = c.type == "defense"
                    and (game.player.armor or 0) >= (game.player.maxArmor or 30)
                if not atCap then
                    pick(c, "sobra")
                end
            end
        end
    end
    -- 5. joker na mão: jogar cedo (valor passivo pro resto da run).
    for _, c in ipairs(hand) do
        if not picked(c) and c.type == "joker" and (c.cost or 0) <= manaLeft
            and game.canAcceptJoker and game:canAcceptJoker() then
            pick(c, "joker")
        end
    end

    local why = {}
    for r in pairs(reasons) do table.insert(why, r) end
    table.sort(why)
    return picks, table.concat(why, "+")
end

-- ============================================================
-- BATALHA
-- ============================================================

local battleStats -- métricas agregadas (setado em M.run)

local function playBattle(game, label)
    local turnCount = 0
    local dmgTakenBefore = game.player.health
    local realDecisions = 0

    -- v3: DETECTOR DE INTEGRIDADE DO DECK — o grito que faltou no bug do
    -- Sobrevivente (discard_cards deletava a carta em vez de descartar).
    -- Invariante: mao + deck + descarte + exauridas + jokers jogados = pool
    -- inicial da batalha. Qualquer vazamento vira ANOMALIA no relatorio.
    local jokersPlayed = 0
    local battlePool = #game.hand + #game.deck + #game.discard
        + #(game._exhaustedThisBattle or {})

    log("")
    log("### %s — inimigo %d HP (dmg %d)", label,
        game.enemy.maxHealth, game.enemy.damage)

    while game.enemy:isAlive() and game.player:isAlive() do
        turnCount = turnCount + 1
        if turnCount > 40 then
            log("- !! batalha passou de 40 turnos — abortando (stall?)")
            return false, "stall"
        end

        local kind, value = game.enemy:getIntentPreview()

        log("- T%d: HP %d/%d armor %d | mana %d | intent %s %s | mao: %s",
            turnCount, game.player.health, game.player.maxHealth,
            game.player.armor, game.player.mana,
            kind:upper(), tostring(value or ""), handSummary(game))

        -- ===== TURNO MULTI-JOGADA (v3): joga em LEVAS ate o cerebro passar.
        -- Elixir/draw agora RENDEM — a leva seguinte enxerga a mana e as
        -- cartas novas (no modelo de 1 leva, carta de motor era letra morta).
        local hpBefore = game.player.health
        local enemyBefore = game.enemy.health
        local levas = 0
        while levas < 4 do
            local picks, why = chooseCards(game)
            if #picks == 0 then break end
            levas = levas + 1

            local pickNames = {}
            for _, c in ipairs(picks) do table.insert(pickNames, c.name or c.id) end
            log("  → leva %d: [%s] (%s)", levas,
                table.concat(pickNames, ", "), why ~= "" and why or "?")

            -- Ordem importa: debuffs (Vulnerável) ANTES dos ataques.
            table.sort(picks, function(x, y)
                local function rank(c)
                    for _, e in ipairs(c.effects or {}) do
                        if e.type == "apply_debuff" then return 0 end
                    end
                    if (c.attack or 0) > 0 then return 2 end
                    return 1
                end
                return rank(x) < rank(y)
            end)
            for _, c in ipairs(picks) do game:selectCard(c) end
            for _, c in ipairs(picks) do
                if c.type == "joker" then jokersPlayed = jokersPlayed + 1 end
            end
            game:playSelectedCards()

            local guard = 0
            while game.combatAnimationSystem:isBlocking() and guard < 900 do
                pump(game, 1 / 30)
                guard = guard + 1
            end
            if not game.enemy:isAlive() or not game.player:isAlive() then break end
        end

        -- "Decisão real": sobrou carta pagável NÃO jogada (houve trade-off)
        local leftoverPlayable = 0
        for _, c in ipairs(game.hand) do
            if (c.cost or 0) <= game.player.mana then
                leftoverPlayable = leftoverPlayable + 1
            end
        end
        if leftoverPlayable > 0 then realDecisions = realDecisions + 1 end

        -- v3: integridade do deck (pos-levas, pre-turno-inimigo)
        do
            local nowPool = #game.hand + #game.deck + #game.discard
                + #(game._exhaustedThisBattle or {}) + jokersPlayed
            if nowPool ~= battlePool then
                anomaly("cartas sumiram/apareceram na batalha: pool %d -> %d (T%d)",
                    battlePool, nowPool, turnCount)
                battlePool = nowPool -- re-ancora pra nao spammar todo turno
            end
        end
        -- v3: metrica de Bloqueio no cap (defesa desperdicada e sintoma)
        if (game.player.armor or 0) >= (game.player.maxArmor or 30) then
            battleStats.armorCapHits = (battleStats.armorCapHits or 0) + 1
        end

        -- multi-jogada: o bot joga 1 leva e encerra o turno explicitamente
        -- INVARIANTES pré-turno-inimigo (detectores de anomalia):
        local armorBeforeEnemy = game.player.armor or 0
        local nextKind, nextVal = game.enemy:getIntentPreview()
        -- usa o contador do ScoreSystem (só dano DO INIMIGO) — HP bruto
        -- pega custo de sangue de Berserk/Sangria (ignora armor por design)
        local dmgTakenBeforeEnemy =
            (game.scoreSystem._battle and game.scoreSystem._battle.damageTaken) or 0

        if game.enemy:isAlive() and game.turn == "player" then
            game:endTurn()
        end
        if game.enemy:isAlive() and game.turn == "enemy" then
            game:enemyTurn()
            -- 0.8s: cobre a investida completa (apex do dano em 0.34s)
            pump(game, 0.8)
        end

        -- DETECTOR "escudo furado" (o bug que o dono pegou jogando e o
        -- piloto engoliu): escudo cobria o golpe anunciado (+4 de margem
        -- pra Fúria) mas o HP caiu mesmo assim.
        local dmgTakenAfterEnemy =
            (game.scoreSystem._battle and game.scoreSystem._battle.damageTaken) or 0
        local enemyDealt = dmgTakenAfterEnemy - dmgTakenBeforeEnemy
        if (nextKind == "attack" or nextKind == "strong")
            and armorBeforeEnemy >= (nextVal or 0) + 4
            and enemyDealt > 0 then
            anomaly("escudo furado: %d de escudo vs golpe %s %d, inimigo furou %d",
                armorBeforeEnemy, nextKind, nextVal or 0, enemyDealt)
        end

        log("    dano causado %d | dano sofrido %d | inimigo %d HP",
            enemyBefore - game.enemy.health,
            math.max(0, hpBefore - game.player.health),
            math.max(0, game.enemy.health))
    end

    pump(game, 1.5) -- death anim / eventos pendentes

    -- métricas por ato (post-mortem: onde o output deixa de acompanhar)
    do
        local act = (game.runManager.currentRun
            and game.runManager.currentRun.actNumber) or 1
        local ba = battleStats.byAct[act]
            or { dealt = 0, taken = 0, turns = 0, battles = 0 }
        ba.dealt = ba.dealt + (game.enemy.maxHealth - math.max(0, game.enemy.health))
        ba.taken = ba.taken + math.max(0, dmgTakenBefore - game.player.health)
        ba.turns = ba.turns + turnCount
        ba.battles = ba.battles + 1
        battleStats.byAct[act] = ba
    end

    local won = not game.enemy:isAlive() and game.player:isAlive()
    battleStats.battles = battleStats.battles + 1
    battleStats.turns = battleStats.turns + turnCount
    battleStats.realDecisionTurns = battleStats.realDecisionTurns + realDecisions
    battleStats.totalTurns = battleStats.totalTurns + turnCount
    battleStats.dmgTaken = battleStats.dmgTaken
        + math.max(0, dmgTakenBefore - game.player.health)

    if won then
        local sb = game.scoreSystem.lastBattle
        if sb then
            local parts = {}
            for _, item in ipairs(sb.breakdown or {}) do
                table.insert(parts, item.label .. " " .. item.value)
            end
            log("- **VITORIA em %d turnos** → +%d pts (%s)", turnCount,
                sb.total, table.concat(parts, " · "))
        end
    else
        log("- **MORREU** na batalha (turno %d)", turnCount)
    end
    return won, turnCount
end

-- ============================================================
-- PÓS-BATALHA: recompensas pagas (modo rewards)
-- ============================================================

local function classTagAffinity(game, cardData)
    -- afinidade simples: tags da carta que já existem no deck contam
    local deckTags = {}
    for _, id in ipairs(game.runManager.currentRun.currentDeck or {}) do
        local cd = game.deckManager.cardDatabase:getCard(id)
        for _, t in ipairs(TagSystem.getCardTags(cd or {})) do
            deckTags[t] = (deckTags[t] or 0) + 1
        end
    end
    local score = 0
    for _, t in ipairs(TagSystem.getCardTags(cardData or {})) do
        score = score + (deckTags[t] or 0)
    end
    return score
end

local RARITY_SCORE = { common = 1, uncommon = 3, rare = 6, legendary = 10 }

-- Arquétipo por classe (prior de deck-building): o bot compra pra FOCAR,
-- não pra colecionar — combos exigem densidade da mesma tag.
local CLASS_ARCHETYPE = {
    warrior = { strike = 3, armor = 2, defend = 2, strength = 2 },
    mage    = { channel = 3, magic = 3, lightning = 2, evoke = 2 },
    rogue   = { poison = 3, strike = 2, finisher = 2 },
}

local function archetypeScore(game, cardData)
    local classId = game.selectedClass or "warrior"
    local prior = CLASS_ARCHETYPE[classId] or {}
    local s = 0
    for _, t in ipairs(TagSystem.getCardTags(cardData or {})) do
        s = s + (prior[t] or 0)
    end
    return s
end

-- ============================================================
-- v4: PICKER HEADLESS — eventos de deck (remover/duplicar/forjar) usam
-- _G.openCardPicker (UI). Sem shim, o piloto ganhava a opcao e recebia
-- um NO-OP ("o escriba se distrai") — as melhores ferramentas de
-- consistencia de deck eram inacessiveis ao bot.
-- ============================================================

-- Valor de uma carta DO DECK pro build atual (quanto maior, mais sagrada).
local function cardValueScore(game, cardId)
    local cd = game.deckManager.cardDatabase:getCard(cardId)
    if not cd then return 0 end
    return (RARITY_SCORE[cd.rarity or "common"] or 1) * 2
        + archetypeScore(game, cd) * 2
        + classTagAffinity(game, cd) * 0.5
        + ((cd.attack or 0) + (cd.defense or 0)) / 4
end

local function installHeadlessPicker(game)
    _G.openCardPicker = function(mode)
        local run = game.runManager.currentRun
        local deck = run.currentDeck or {}
        local ids = {}
        for _, e in ipairs(deck) do
            ids[#ids + 1] = type(e) == "table" and e.id or e
        end
        if #ids == 0 then return end
        if mode == "remove" then
            if #ids <= 8 then
                log("  (picker: deck %d ja enxuto — nao removi)", #ids)
                return
            end
            -- guard: defesa pontua baixo em arquetipo ofensivo, mas remover
            -- a ultima Esquiva do rogue e suicidio — piso de 3 defesas.
            local defCount = 0
            for _, id in ipairs(ids) do
                local cd = game.deckManager.cardDatabase:getCard(id)
                if cd and cd.type == "defense" then defCount = defCount + 1 end
            end
            local worst, worstS
            for _, id in ipairs(ids) do
                local cd = game.deckManager.cardDatabase:getCard(id)
                local isDef = cd and cd.type == "defense"
                if not (isDef and defCount <= 3) then
                    local s = cardValueScore(game, id)
                    if not worstS or s < worstS then worst, worstS = id, s end
                end
            end
            if not worst then
                log("  (picker: nada removivel com seguranca)")
                return
            end
            game.runManager:removeCardFromDeck(worst)
            if game.synchronizeRunDeck then game:synchronizeRunDeck() end
            log("  (picker: REMOVI a pior carta: %s)", worst)
        elseif mode == "duplicate" then
            local best, bestS
            for _, id in ipairs(ids) do
                local s = cardValueScore(game, id)
                if not bestS or s > bestS then best, bestS = id, s end
            end
            game:addCardToRun(best)
            log("  (picker: DUPLIQUEI a melhor carta: %s)", best)
        elseif mode == "forge" then
            local counts = {}
            for _, id in ipairs(ids) do counts[id] = (counts[id] or 0) + 1 end
            local bestId, bestW = nil, 0
            for id, n in pairs(counts) do
                local cd = game.deckManager.cardDatabase:getCard(id)
                local w = n * (((cd and cd.attack or 0) > 0) and 2 or 1)
                if w > bestW and game.runManager:canUpgrade(id) then
                    bestId, bestW = id, w
                end
            end
            if bestId then
                local lvl = game.runManager:upgradeCard(bestId)
                log("  (picker: FORJEI %s → nivel %s)", bestId, tostring(lvl))
            end
        end
    end
end

local function doRewards(game)
    game.shopSystem:setMode("rewards")
    game.shopSystem:generateOffers()
    local offers = game.shopSystem:getCurrentOffers()

    local best, bestScore = nil, -1
    for _, o in ipairs(offers) do
        if o.type == "card" and game.economySystem:canAfford(o.cost) then
            local cd = game.deckManager.cardDatabase:getCard(o.id)
            local s = (RARITY_SCORE[o.rarity or "common"] or 1) * 2
                + classTagAffinity(game, cd)
                + archetypeScore(game, cd) * 2 - o.cost * 0.5
            if s > bestScore then best, bestScore = o, s end
        end
    end

    local deckSize = #(game.runManager.currentRun.currentDeck or {})
    -- deck gordo dilui: acima de 18 cartas, só rare+ entra
    if best and deckSize > 18 and (RARITY_SCORE[best.rarity] or 1) < 6 then
        best = nil
    end

    if best then
        local goldBefore = game.economySystem.currentGold
        game.economySystem:spendGold(best.cost, best.type, best.id)
        if game.economySystem.currentGold ~= goldBefore - best.cost then
            anomaly("ouro errado na recompensa: %d - %d != %d",
                goldBefore, best.cost, game.economySystem.currentGold)
        end
        game:addCardToRun(best.id)
        log("- Recompensa: comprei **%s** (%s, $%d) → ouro $%d",
            best.name, best.rarity or "?", best.cost,
            game.economySystem.currentGold)
    else
        log("- Recompensa: pulei (nada valia / deck cheio) → ouro $%d",
            game.economySystem.currentGold)
    end
end

-- ============================================================
-- NODES: escolha de caminho + rest/event/shop
-- ============================================================

local function chooseNode(game, pending)
    local hpRatio = game.player.health / game.player.maxHealth
    local gold = game.economySystem.currentGold
    local BT = MapManager.NODE_TYPES

    -- v2: força do deck decide se elite compensa (dano médio por turno
    -- estimado vs 6 turnos de batalha).
    local deckDmg = 0
    local deckN = 0
    for _, id in ipairs(game.runManager.currentRun.currentDeck or {}) do
        local cd = game.deckManager.cardDatabase:getCard(id)
        if cd and (cd.attack or 0) > 0 then
            deckDmg = deckDmg + cd.attack / math.max(1, cd.cost or 1)
            deckN = deckN + 1
        end
    end
    local dmgPerMana = deckN > 0 and deckDmg / deckN or 7
    local dptEstimate = dmgPerMana * (game.player.maxMana or 3)
    local ActSystem = require("src.systems.ActSystem")
    local run = game.runManager.currentRun
    local eliteStats = ActSystem.getEnemyStats(run.actNumber,
        math.min(8, run.floorInAct + 1), "elite")
    local canElite = dptEstimate * 6 >= (eliteStats.health or 60)

    -- prioridade situacional
    -- v4 boss-aware: F7=mini_boss e F8=boss — chegar neles meio-morto era a
    -- causa nº1 de morte medida (10/33 no boss A2-F8). Perto do muro, o
    -- descanso vale mais que qualquer loja/evento.
    local nearBoss = (run.floorInAct or 1) >= 6
    local want
    if nearBoss and hpRatio < 0.7 then
        want = { BT.REST, BT.EVENT, BT.SHOP, BT.BATTLE }
    elseif hpRatio < 0.5 then
        want = { BT.REST, BT.EVENT, BT.BATTLE, BT.SHOP }
    elseif gold >= 14 then
        want = canElite and { BT.SHOP, BT.ELITE, BT.BATTLE, BT.EVENT, BT.REST }
            or { BT.SHOP, BT.BATTLE, BT.EVENT, BT.REST, BT.ELITE }
    elseif hpRatio > 0.75 and canElite then
        want = { BT.ELITE, BT.BATTLE, BT.EVENT, BT.SHOP, BT.REST }
    else
        want = { BT.BATTLE, BT.EVENT, BT.REST, BT.SHOP, BT.ELITE }
    end

    for _, wantType in ipairs(want) do
        for i, node in ipairs(pending) do
            if node.type == wantType then return i, node end
        end
    end
    return 1, pending[1]
end

local function doRest(game)
    local p = game.player
    -- v4 boss-aware: com mini_boss/boss a 1-2 andares, curar vale mais que
    -- forjar mesmo acima do threshold normal de 60%.
    local floorInAct = game.runManager.currentRun.floorInAct or 1
    local nearBoss = floorInAct >= 6
    if p.health <= p.maxHealth * (nearBoss and 0.75 or 0.6) then
        local amt = math.floor(p.maxHealth * 0.30)
        p:heal(amt)
        log("- Acampamento: **descansei** +%d HP → %d/%d", amt, p.health, p.maxHealth)
    else
        -- forja a carta de ATAQUE com mais cópias (dano escala a run;
        -- +2 atk em 3 cópias = +6 de output por ciclo do deck)
        local counts = {}
        for _, id in ipairs(game.runManager.currentRun.currentDeck) do
            counts[id] = (counts[id] or 0) + 1
        end
        local bestId, bestN = nil, 0
        for id, n in pairs(counts) do
            local cd = game.deckManager.cardDatabase:getCard(id)
            local weight = n * (((cd and cd.attack or 0) > 0) and 2 or 1)
            if weight > bestN then bestId, bestN = id, weight end
        end
        if bestId then
            local lvl = game.runManager:upgradeCard(bestId)
            log("- Acampamento: **forjei** %s → nivel +%s", bestId, tostring(lvl))
        end
    end
end

-- v4: pontua UMA string de gain/cost declarada pelo evento. As strings sao
-- o contrato explicito do design ("risco informado, nunca pegadinha") — o
-- bot le exatamente o que o jogador leria no botao.
local function scoreEventStr(game, s, isCost)
    local p = game.player
    local hp, maxHp = p.health, p.maxHealth
    local gold = game.economySystem.currentGold
    local deckN = #(game.runManager.currentRun.currentDeck or {})
    local sign = isCost and -1 or 1
    s = s:lower()

    -- custos que nao podemos pagar = veto
    local costHp = isCost and s:match("^(%d+) hp$")
    if costHp then
        local n = tonumber(costHp)
        if hp - n <= 4 then return -1000 end
        return -n * (hp < maxHp * 0.4 and 1.6 or 0.6)
    end
    local costGold = isCost and s:match("^%$(%d+)$")
    if costGold then
        local n = tonumber(costGold)
        if gold < n then return -1000 end
        return -n / 8
    end
    if s:find("carta aleatoria do deck") then
        -- remocao ALEATORIA: boa com deck gordo de commons, ruim com deck afiado
        return (deckN > 16) and 3 or -6
    end
    if s:find("armadilha") then
        local pct, n = s:match("(%d+)%% armadilha (%d+) hp")
        if pct and n then return -(tonumber(pct) / 100) * tonumber(n) * 1.2 end
        return -3
    end

    -- ganhos
    if s:find("remova 1 carta a sua escolha") then
        return sign * ((deckN >= 14) and 12 or 5)
    end
    if s:find("duplique") then return sign * 8 end
    if s:find("forj") then return sign * 7 end
    if s:find("mana maxima") then return sign * 12 end
    if s:find("hp maximo") then return sign * 7 end
    if s:find("carta lendaria") then return sign * 10 end
    if s:find("carta rara") then return sign * ((deckN > 18) and 3 or 6) end
    if s:find("cartas aleatorias") then
        return sign * ((deckN > 16) and -2 or 2)  -- diluicao
    end
    if s:find("pocao") then return sign * 2 end
    if s:find("misterioso") then return sign * 1 end
    local curaPct = s:match("cura (%d+)%%")
    if curaPct then
        local heal = math.min(maxHp * tonumber(curaPct) / 100, maxHp - hp)
        return sign * (heal / maxHp) * 30
    end
    local curaFlat = s:match("cura (%d+) hp")
    if curaFlat then
        local heal = math.min(tonumber(curaFlat), maxHp - hp)
        return sign * (heal / maxHp) * 30
    end
    -- valor esperado: "50% de ganhar $50", "40% $25"
    local pct, val = s:match("(%d+)%%[^%$]*%$(%d+)")
    if pct and val then return sign * (tonumber(pct) / 100) * tonumber(val) / 6 end
    local flatGold = s:match("^%$(%d+)$")
    if flatGold then return sign * tonumber(flatGold) / 6 end
    return 0
end

local function doEvent(game)
    local run = game.runManager.currentRun
    local ev = Events.roll(run.actNumber or 1)
    if not ev then
        log("- Evento: nenhum disponivel")
        return
    end
    -- v4: pontua CADA opcao pelos gains/costs declarados; "ir embora" = 0.
    -- Escolhe a de maior valor esperado pro estado atual (HP/ouro/deck).
    local bestIdx, bestScore = #ev.options, 0.5  -- neutro levemente > 0: só
    for i, opt in ipairs(ev.options) do          -- aposta se valer a pena
        local s = 0
        for _, g in ipairs(opt.gains or {}) do s = s + scoreEventStr(game, g, false) end
        for _, c in ipairs(opt.costs or {}) do s = s + scoreEventStr(game, c, true) end
        if (opt.gains or opt.costs) and s > bestScore then
            bestIdx, bestScore = i, s
        end
    end
    local opt = ev.options[bestIdx]
    local okApply, feedback = pcall(opt.apply, game)
    log("- Evento **%s**: escolhi '%s' (score %.1f) → %s", ev.title, opt.label,
        bestScore, okApply and (feedback or "ok") or ("ERRO: " .. tostring(feedback)))
end

local function doShop(game)
    game.shopSystem:setMode("shop")
    game.shopSystem:generateOffers()
    local offers = game.shopSystem:getCurrentOffers()
    local bought = 0
    -- compra gulosa por valor (cartas afinadas + upgrades baratos), até 2 itens
    for _, o in ipairs(offers) do
        if bought >= 2 then break end
        local afford = game.economySystem:canAfford(o.cost)
        if afford and o.type == "card" then
            local cd = game.deckManager.cardDatabase:getCard(o.id)
            local s = (RARITY_SCORE[o.rarity or "common"] or 1) * 2
                + classTagAffinity(game, cd) + archetypeScore(game, cd) * 2
            -- v4: MESMA disciplina de deck das recompensas — a loja era o
            -- furo que engordava o deck por fora do gate (>18 so rare+).
            local deckSize = #(game.runManager.currentRun.currentDeck or {})
            if deckSize > 18 and (RARITY_SCORE[o.rarity or "common"] or 1) < 6 then
                s = -1
            end
            if s >= 6 then
                game.economySystem:spendGold(o.cost, o.type, o.id)
                game:addCardToRun(o.id)
                game.runManager.currentRun._usedShop = true
                bought = bought + 1
                log("- Loja: comprei **%s** ($%d)", o.name, o.cost)
            end
        elseif afford and o.type == "upgrade" and o.effect == "forge_card" then
            -- v3: FORJA paga — o piloto agora usa a bigorna da loja.
            -- Alvo: a carta de ATAQUE com mais peso no deck (mais copias
            -- x2 se ataque), igual a heuristica da fogueira.
            local counts = {}
            for _, id in ipairs(game.runManager.currentRun.currentDeck or {}) do
                counts[id] = (counts[id] or 0) + 1
            end
            local bestId, bestW = nil, 0
            for id, n in pairs(counts) do
                local cd = game.deckManager.cardDatabase:getCard(id)
                local w = n * (((cd and cd.attack or 0) > 0) and 2 or 1)
                if w > bestW and game.runManager:canUpgrade(id) then
                    bestId, bestW = id, w
                end
            end
            if bestId then
                game.economySystem:spendGold(o.cost, o.type, o.id)
                local lvl = game.runManager:upgradeCard(bestId)
                game.runManager.currentRun._usedShop = true
                bought = bought + 1
                log("- Loja: **FORJEI** %s → nivel %s ($%d)",
                    bestId, tostring(lvl), o.cost)
            end
        elseif afford and o.type == "upgrade" and o.cost <= 6 then
            game.economySystem:spendGold(o.cost, o.type, o.id)
            if o.effect == "increase_max_health" then
                game.player.maxHealth = game.player.maxHealth + o.value
                game.player.health = game.player.health + o.value
            end
            game.runManager.currentRun._usedShop = true
            bought = bought + 1
            log("- Loja: comprei upgrade **%s** ($%d)", o.name, o.cost)
        end
    end
    if bought == 0 then
        log("- Loja: sai sem comprar (ouro $%d)", game.economySystem.currentGold)
    end
end

-- ============================================================
-- UMA RUN COMPLETA
-- ============================================================

local function playRun(classId, runIdx, maxEndlessFloors)
    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun(classId)
    game:startGame()
    pump(game, 0.5)
    -- v4: picker headless — sem isso os eventos de deck (remover/duplicar/
    -- forjar a escolha) eram NO-OP no piloto (dependem de UI).
    installHeadlessPicker(game)

    battleStats = {
        battles = 0, turns = 0, dmgTaken = 0,
        realDecisionTurns = 0, totalTurns = 0,
        armorCapHits = 0, -- v3: turnos em que o Bloqueio bateu no cap (30)
        byAct = {},   -- [act] = { dealt, taken, turns, battles }
    }

    log("")
    log("---")
    log("## RUN %d — %s", runIdx, classId:upper())

    local outcome = "?"
    local floors = 0

    -- primeira batalha (startGame já criou o inimigo do A1-F1)
    while true do
        floors = floors + 1
        local run = game.runManager.currentRun
        local nodeType = (run.currentNode and run.currentNode.type) or "battle"
        local label = ("A%d-F%d [%s]"):format(
            run.actNumber, run.floorInAct, nodeType)

        local won = playBattle(game, label)
        if not won then
            outcome = ("MORREU em %s (score %d)"):format(label, game.score)
            break
        end

        if game:checkVictory() then
            outcome = ("VENCEU O JOGO em %s (score %d)"):format(label, game.score)
            break
        end
        if run.endlessMode and (run.floorsInEndless or 0) >= (maxEndlessFloors or 0) then
            outcome = ("parou no endless F%d (score %d)"):format(
                run.floorsInEndless or 0, game.score)
            break
        end

        -- Cash-out do RoundEval (headless): o pagamento da batalha vive na
        -- tela de RoundEval — sem simular o resgate o bot morre de fome.
        if game._buildRoundEvalSources then
            local sources = game:_buildRoundEvalSources()
            local total = 0
            local names = {}
            for _, s in ipairs(sources or {}) do
                total = total + (s.dollars or 0)
                table.insert(names, (s.label or "?") .. " $" .. (s.dollars or 0))
            end
            if total > 0 then
                game.economySystem:earnGold(total, "round_eval")
            end
            log("- Resgate: +$%d (%s) → ouro $%d", total,
                table.concat(names, " · "), game.economySystem.currentGold)
        end

        doRewards(game)

        -- mapa: gera opções e escolhe caminho até cair numa batalha
        local safety = 0
        repeat
            safety = safety + 1
            if not game.runManager:getPendingNodes() then
                game.runManager:advanceFloorInAct(3)
                game.runManager:generateNextNodes(3)
            end
            local pending = game.runManager:getPendingNodes()
            local idx, node = chooseNode(game, pending)
            local opts = {}
            for _, n in ipairs(pending) do table.insert(opts, n.type) end
            game.runManager:chooseNode(idx)
            log("")
            log("**Caminho A%d-F%d**: opcoes [%s] → escolhi **%s** (HP %d%%, $%d)",
                game.runManager.currentRun.actNumber,
                game.runManager.currentRun.floorInAct,
                table.concat(opts, ", "), node.type,
                math.floor(100 * game.player.health / game.player.maxHealth),
                game.economySystem.currentGold)

            local BT = MapManager.NODE_TYPES
            if node.type == BT.REST then
                doRest(game)
            elseif node.type == BT.EVENT then
                doEvent(game)
            elseif node.type == BT.SHOP then
                doShop(game)
            else
                -- battle/elite/mini_boss/boss → próxima batalha
                game:nextPhase()
                pump(game, 0.5)
                break
            end
        until safety > 12

        if not game.player:isAlive() then
            outcome = ("MORREU fora de batalha (evento?) score %d"):format(game.score)
            break
        end
        if safety > 12 then
            outcome = "loop de mapa abortado (bug?)"
            break
        end
    end

    -- métricas da run
    local run = game.runManager.currentRun
    log("")
    log("### Resultado: %s", outcome)
    log("- Andares visitados: %d | Ato final: A%d-F%d%s", floors,
        run.actNumber, run.floorInAct, run.endlessMode and " (endless)" or "")
    log("- Batalhas: %d | turnos/batalha: %.1f", battleStats.battles,
        battleStats.battles > 0 and battleStats.turns / battleStats.battles or 0)
    log("- Turnos com decisao REAL (sobrou carta pagavel): %d de %d (%.0f%%)",
        battleStats.realDecisionTurns, battleStats.totalTurns,
        battleStats.totalTurns > 0
            and 100 * battleStats.realDecisionTurns / battleStats.totalTurns or 0)
    log("- Bloqueio no cap: %d turno(s) — defesa alem disso evapora",
        battleStats.armorCapHits or 0)
    log("- Deck final: %d cartas | Ouro final: $%d | Score: %d",
        #(run.currentDeck or {}), game.economySystem.currentGold, game.score)

    -- POST-MORTEM: output vs pressão por ato + composição do deck
    for act, ba in pairs(battleStats.byAct) do
        if ba.turns > 0 then
            log("- A%d: dano/turno %.1f | sofrido/turno %.1f | %.1f turnos/batalha",
                act, ba.dealt / ba.turns, ba.taken / ba.turns,
                ba.turns / math.max(1, ba.battles))
        end
    end
    do
        local names = {}
        for _, id in ipairs(run.currentDeck or {}) do
            local cd = game.deckManager.cardDatabase:getCard(id)
            table.insert(names, (cd and cd.name or id))
        end
        log("- Deck: %s", table.concat(names, ", "))
    end

    return outcome
end

-- ============================================================
-- ENTRY
-- ============================================================

function M.run(runsArg, classArg)
    local runsPerClass = tonumber(runsArg or "2") or 2
    local classes = { "warrior", "mage", "rogue" }
    if classArg and classArg ~= "all" then classes = { classArg } end

    _G.EventManager = EventManager
    _G.Event = require("engine.Event")  -- CombatSequence usa _G.Event
    local I18n = require("src.i18n.I18n")
    I18n.init()

    -- silencia print interno do jogo? não — deixa no console, o diário é à parte.

    log("# Diario do Piloto de IA — autoplay")
    log("")
    log("Runs por classe: %d | Classes: %s", runsPerClass,
        table.concat(classes, ", "))

    local outcomes = {}
    for _, classId in ipairs(classes) do
        for i = 1, runsPerClass do
            local ok, res = pcall(playRun, classId, i, 3)
            if ok then
                table.insert(outcomes, classId .. " #" .. i .. ": " .. res)
            else
                table.insert(outcomes, classId .. " #" .. i .. ": CRASH " .. tostring(res))
                log("")
                log("!!! CRASH na run: %s", tostring(res))
            end
        end
    end

    log("")
    log("---")
    log("## Placar geral")
    for _, o in ipairs(outcomes) do log("- %s", o) end
    log("")
    log("## Anomalias detectadas: %d", #anomalies)
    for _, an in ipairs(anomalies) do log("- %s", an) end
    if #anomalies > 0 then
        print(("\n[autoplay] *** %d ANOMALIAS — ver relatorio ***"):format(#anomalies))
    end

    local content = table.concat(report, "\n")
    love.filesystem.write("autoplay_report.md", content)
    print("\n[autoplay] relatorio salvo: autoplay_report.md ("
        .. #report .. " linhas)")
    love.event.quit()
end

return M
