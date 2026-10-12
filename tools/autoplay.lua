-- tools/autoplay.lua
-- PILOTO DE IA v5: joga o jogo de verdade, sozinho, pelos MESMOS sistemas do
-- jogador (Game:selectCard/playSelectedCards/enemyTurn, RunManager:chooseNode,
-- ShopSystem, Events.apply, forja) — e escreve um DIARIO de tudo que decidiu
-- e por que, mais metricas de experiencia por run.
--
--   love . autoplay [runs] [classe|all]
--   ex: love . autoplay 2 all      → 2 runs por classe (6 runs)
--       love . autoplay 3 warrior  → 3 runs de guerreiro
--
-- Saida: autoplay_report.md no save dir (~/Library/Application Support/LOVE/
-- card-game/). O relatorio e o insumo pra analise de game feel: decisoes
-- reais vs automaticas, causa das mortes, curva de HP/ouro, uso de cura,
-- combos, duracao de batalhas.
--
-- v5 (rebalance Jul/2026, plano pilot_changes V5.1-V5.16):
--   V5.1  loja com whitelist de upgrades reais + mana_upgrade prioridade maxima
--   V5.2  cerebro de orbes (channel juntos, dark segurado, evoke com proposito)
--   V5.3  simulador de lethal FIEL ao pipeline do Game (inclui P0.9 max-mult)
--   V5.4  dano gratis (poison liq. da armor do DEFEND + pulso) desconta antes
--   V5.5  turno em 2 fases: MOTOR (draw/mana sozinhas) → BATCH unico (combos)
--   V5.6  gate de cura anti-desperdicio (missing >= 0.6*cura efetiva)
--   V5.7  weak como defesa virtual (25% do golpe anunciado)
--   V5.8  passo SCALING quando a batalha vai ser longa (>= 4 turnos)
--   V5.9  forja por score (copias x ciclos / custo x ganho real x arquetipo)
--   V5.10 reroll de loja (ate 2x) quando a vitrine nao vale
--   V5.11 bancada de coringas: pontua e ativa o top via Game:setJokerActive
--   V5.12 defesa como alocacao de sobra + modo emergencia
--   V5.13 politica de caixa (reserva p/ juros; libera perto do boss)
--   V5.14 canElite com dano/turno MEDIDO (byAct) em vez de face value
--   V5.16 tripwires no diario (foco A3, jokers mult, thorn/turno)
--
-- IMPORTANTE: roda com _G.HEADLESS_TOOL (main.lua) — perfil real intocado.

local M = {}

-- Politica de batalha: "v6" (busca, tools/balance_ai.lua) ou "v5" (passos
-- heuristicos, mantida pra A/B de qualidade do piloto).
M.policy = "v6"
-- Diario detalhado (uma linha por turno). Desligado pelas baterias grandes
-- (tools/balance_sim.lua) — o relatorio delas e agregado.
M.quiet = false

-- A/B por METADE do cerebro: "v6c" = combate v6 + deck v5; "v6b" = deck v6 +
-- combate v5. Sem separar, uma melhora numa metade escondia a piora da outra.
local function v6Combat() return M.policy == "v6" or M.policy == "v6c" end
local function v6Build() return M.policy == "v6" or M.policy == "v6b" end

local AI = require("tools.balance_ai")
local EventManager = require("engine.EventManager")
local Events       = require("src.data.events")
local MapManager   = require("src.systems.MapManager")
local TagSystem    = require("src.systems.TagSystem")
local ComboSystem  = require("src.systems.ComboSystem")

-- ============================================================
-- Diario
-- ============================================================

local report = {}
local anomalies = {}   -- invariantes violadas (o "grito" que faltou no bug do escudo)
local function anomaly(fmt, ...)
    local line = select("#", ...) > 0 and fmt:format(...) or fmt
    table.insert(anomalies, line)
    if not M.quiet then table.insert(report, "  !! ANOMALIA: " .. line) end
    print("[autoplay] !! ANOMALIA: " .. line)
end
local function log(fmt, ...)
    if M.quiet then return end
    local line = select("#", ...) > 0 and fmt:format(...) or fmt
    table.insert(report, line)
end

-- ============================================================
-- Helpers de simulacao
-- ============================================================

-- FX de APRESENTACAO (texto flutuante, particulas, faixa de combo, cometas de
-- orbe, moedas) so esvaziam no update deles, que o love.update/HUD chama todo
-- frame. O piloto nao desenha nem chama esses updates: sem esvaziar aqui, cada
-- batalha simulada empilhava ~100 mil particulas presas a cartas (e, por elas,
-- Games inteiros) e a bateria longa chegava a 9 GB. Nenhuma regra do jogo le
-- esses singletons — limpar e invisivel pro resultado.
local function drainPresentation()
    require("src.ui.FloatingText").clear()
    require("src.systems.CardParticles").clear()
    require("src.ui.ComboBanner").clear()
    require("src.ui.OrbRow").clear()
    require("src.ui.CoinBurst").clear()
end
M.drainPresentation = drainPresentation

local function pump(game, secs)
    drainPresentation()
    local dt = 1 / 30
    for _ = 1, math.max(1, math.floor(secs * 30)) do
        EventManager.update(dt)
        if game.combatAnimationSystem and game.combatAnimationSystem.update then
            game.combatAnimationSystem:update(dt)
        end
        -- Enemy.attackCooldown decrementa em update(dt) — sem bombear isso o
        -- inimigo trava em cooldown eterno e a batalha congela (1a rodada de
        -- autoplay pegou exatamente esse sintoma).
        if game.enemy and game.enemy.update then
            game.enemy:update(dt)
        end
        -- Investida do inimigo: o dano e aplicado no APEX via
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

local function hasEffect(card, etype)
    for _, e in ipairs(card.effects or {}) do
        if e.type == etype then return true end
    end
    return false
end

local function hasDebuffEffect(card, which)
    for _, e in ipairs(card.effects or {}) do
        if e.type == "apply_debuff" and e.value == which then return true end
    end
    return false
end

local function hasBuffEffect(card, which)
    for _, e in ipairs(card.effects or {}) do
        if e.type == "apply_buff" and e.value == which then return true end
    end
    return false
end

local function getFocus(p)
    return (p.getBuffStacks and p:getBuffStacks("focus")) or 0
end

-- ============================================================
-- V5.3: SIMULADOR DE VALOR FIEL — replica computeCardValue do Game na ordem
-- EXATA: applyCardEffects (bonus_self/multi_hit, na ordem do card.effects)
-- → statBonus (scaling conta o stat em DOBRO) → ComboSystem.applyToCardValue
-- (modulo REAL, com o ctx do conjunto) → jokers com a regra P0.9
-- largest-multiplier-wins (flats somam TODOS) → edition (foil +5 / holo x1.2
-- / poly x1.5) → Red seal x2 → floor. O MESMO simulador serve o lethal e o
-- sort de valor/mana — o bot nunca mais superestima com produto em cadeia.
-- ============================================================

-- Melhor multiplicador + soma dos flats dos jokers ATIVOS (espelho fiel de
-- EffectSystem:applyJokerEffects pos-P0.9).
local function jokerMods(game, ctype)
    local bestMult, flat = nil, 0
    for _, joker in ipairs(game.jokerSlots or {}) do
        for _, e in ipairs(joker.effects or {}) do
            if ctype == "attack" then
                if e.type == "damage_multiplier" and e.target == "attack" then
                    local v = e.value or 1
                    if not bestMult or v > bestMult then bestMult = v end
                elseif e.type == "damage_bonus" then
                    flat = flat + (e.value or 1)
                end
            elseif ctype == "defense" then
                if e.type == "defense_multiplier" and e.target == "defense" then
                    local v = e.value or 1
                    if not bestMult or v > bestMult then bestMult = v end
                elseif e.type == "defense_bonus" then
                    flat = flat + (e.value or 1)
                end
            end
        end
    end
    return bestMult or 1, flat
end

-- Contexto de combos REAL para um conjunto (usa TagSystem+ComboSystem do jogo).
local function buildCtx(set)
    local ctx = { allSelectedCards = set, tagCounts = TagSystem.countAllTags(set) }
    ComboSystem.detect(ctx)
    return ctx
end

local function withCard(set, extra)
    local out = {}
    for _, c in ipairs(set) do out[#out + 1] = c end
    out[#out + 1] = extra
    return out
end

-- Valor final de UMA carta attack/defense dentro de um conjunto (ctx).
local function simulateCardValue(game, card, ctx)
    local base, stat, scalingType
    if card.type == "attack" then
        base = card.attack or 0
        stat = game.player.strength or 0
        scalingType = "strength_scaling"
    elseif card.type == "defense" then
        base = card.defense or 0
        stat = game.player.dexterity or 0
        scalingType = "dexterity_scaling"
    else
        return 0
    end
    if base <= 0 then return 0 end
    local v = base
    -- 1. applyCardEffects (ordem do proprio card.effects, como no EffectSystem)
    for _, e in ipairs(card.effects or {}) do
        if e.type == "damage_bonus_self" and card.type == "attack" then
            v = v + (e.value or 1)
        elseif e.type == "multi_hit" and card.type == "attack" then
            v = v * math.max(1, e.value or 1)
        end
    end
    -- 2. statBonus (scaling = stat em DOBRO, fonte unica processCardInCombat)
    local s = stat
    for _, e in ipairs(card.effects or {}) do
        if e.type == scalingType then s = s * 2; break end
    end
    v = v + s
    -- 3. combos (modulo real do jogo)
    if ctx then v = ComboSystem.applyToCardValue(card, v, ctx) end
    -- 4. jokers: P0.9 largest-multiplier-wins + flats somam
    local mult, flat = jokerMods(game, card.type)
    v = v * mult + flat
    -- 5. edition
    if card.edition == "foil" then v = v + 5
    elseif card.edition == "holo" then v = v * 1.2
    elseif card.edition == "polychrome" then v = v * 1.5 end
    -- 6. Red seal
    if card.seal == "Red" then v = v * 2 end
    return math.floor(v)
end

-- Ordem de jogada dentro da leva (V5.2: debuff → scaling → channel → resto →
-- ataques → evoke; channel SEMPRE antes de evoke).
local function playRank(c)
    if hasEffect(c, "apply_debuff") then return 0 end
    if hasEffect(c, "gain_strength") or hasEffect(c, "gain_dexterity")
        or hasEffect(c, "apply_buff") or hasEffect(c, "increase_max_mana") then
        return 1
    end
    if hasEffect(c, "evoke_orb") or hasEffect(c, "evoke_all_orbs") then return 5 end
    if hasEffect(c, "channel_orb") and (c.attack or 0) <= 0 then return 2 end
    if (c.attack or 0) > 0 then return 4 end
    return 3
end

local function sortedForPlay(set)
    local out = {}
    for _, c in ipairs(set) do out[#out + 1] = c end
    table.sort(out, function(x, y) return playRank(x) < playRank(y) end)
    return out
end

-- Dano de evocar um orb (com foco), espelho de _evokeOrbEffect.
local function evokeDmgOfOrb(orb, focus)
    local v = (orb.value or 1) + focus
    if orb.type == "lightning" then return v
    elseif orb.type == "dark" then return v * 2
    elseif orb.type == "fire" then return v end
    return 0  -- ice/holy nao causam dano
end

-- Dano TOTAL simulado de um conjunto: ataques (simulador fiel) + magic_damage
-- + evokes (fila FIFO simulada, incluindo channels do proprio set e overflow)
-- + x1.5 de vulnerable quando o PROPRIO set inclui o applier (debuffs jogam
-- primeiro na ordenacao, entao TODO o dano posterior amplifica).
local function simulateSetDamage(game, set)
    if #set == 0 then return 0 end
    local p = game.player
    local focus = getFocus(p)
    local ctx = buildCtx(set)
    local vuln = game.enemy:hasStatus("vulnerable")
    if not vuln then
        for _, c in ipairs(set) do
            if hasDebuffEffect(c, "vulnerable") then vuln = true; break end
        end
    end
    -- copia da fila de orbes (evoke/channel do set mudam o estado)
    local orbs = {}
    for _, o in ipairs(p.orbs or {}) do
        orbs[#orbs + 1] = { type = o.type, value = o.value }
    end
    local slots = p.orbSlots or 3
    local total = 0
    local function addDmg(d)
        if d > 0 then
            if vuln then d = math.floor(d * 1.5) end  -- Enemy:takeDamage aplica antes da armor
            total = total + d
        end
    end
    for _, c in ipairs(sortedForPlay(set)) do
        if c.type == "attack" then
            addDmg(simulateCardValue(game, c, ctx))
        end
        for _, e in ipairs(c.effects or {}) do
            if e.type == "magic_damage" or e.type == "aoe_magic_damage" then
                addDmg(e.value or 0)
            elseif e.type == "channel_orb" then
                if #orbs >= slots then
                    -- overflow FIFO: orb mais antigo evoca automaticamente
                    addDmg(evokeDmgOfOrb(table.remove(orbs, 1), focus))
                end
                orbs[#orbs + 1] = { type = e.orbType or "lightning", value = e.value or 1 }
            elseif e.type == "evoke_orb" then
                if #orbs > 0 then
                    addDmg(evokeDmgOfOrb(table.remove(orbs, 1), focus))
                end
            elseif e.type == "evoke_all_orbs" then
                while #orbs > 0 do
                    addDmg(evokeDmgOfOrb(table.remove(orbs, 1), focus))
                end
            end
        end
    end
    return total
end

-- V5.4: dano GRATIS que chega neste turno sem jogar carta nenhuma:
--   poison liquido = stacks - armor prevista do intent DEFEND congelado
--   (veneno e ABSORVIDO pela armor do inimigo em Enemy:onTurnEnd — a armor
--   do defend e ganha ANTES do tick; sem o desconto o bot superestimava
--   sempre que o inimigo telegrafava DEFEND)
--   + pulso passivo dos orbes (orbPassiveTick no fim do turno do jogador).
local function freeDamageThisTurn(game)
    local enemy = game.enemy
    local poison = enemy:hasStatus("poison") and enemy:getStatusStacks("poison") or 0
    -- DoT ignora a armadura do inimigo (Out/2026, Enemy:_applyDot): o
    -- bloqueio do intent nao desconta mais o veneno.
    local freePoison = poison
    local p = game.player
    local focus = getFocus(p)
    local pulse = 0
    for _, orb in ipairs(p.orbs or {}) do
        local ev = (orb.value or 1) + focus
        if orb.type == "lightning" then pulse = pulse + math.ceil(ev / 2)
        elseif orb.type == "fire" then pulse = pulse + math.ceil(ev / 3) end
    end
    return freePoison + pulse, freePoison, pulse
end

-- Cura efetiva de uma carta (instant_heal x heal_multiplier de jokers, com
-- floor — mesma conta do EffectSystem pos-P2.4).
local function healValue(game, card)
    local v = 0
    for _, e in ipairs(card.effects or {}) do
        if e.type == "instant_heal" then v = v + (e.value or 0) end
    end
    if v <= 0 then return 0 end
    local mult = 1
    for _, j in ipairs(game.jokerSlots or {}) do
        for _, e in ipairs(j.effects or {}) do
            if e.type == "heal_multiplier" then mult = mult * (e.value or 1) end
        end
    end
    return math.floor(v * mult)
end

-- V5.6: gate de cura — so joga se missingHP >= 60% da cura efetiva.
-- Vale em QUALQUER passo, inclusive sobra.
local function healPassesGate(game, card)
    local v = healValue(game, card)
    if v <= 0 then return false end
    local missing = game.player.maxHealth - game.player.health
    return missing >= v * 0.6
end

-- V5.16(b): quantos jokers multiplicadores ativos + multiplicador efetivo
-- (deve ser sempre o MAX — nunca o produto; deteta regressao do P0.9).
local function multJokerStats(game)
    local n, best = 0, 1
    for _, j in ipairs(game.jokerSlots or {}) do
        for _, e in ipairs(j.effects or {}) do
            if e.type == "damage_multiplier" or e.type == "defense_multiplier" then
                n = n + 1
                if (e.value or 1) > best then best = e.value or 1 end
            end
        end
    end
    return n, best
end

-- ============================================================
-- POLITICA DE BATALHA v5 (o "cerebro")
-- ============================================================
-- V5.5: o turno tem DUAS fases —
--   FASE MOTOR: cartas de draw/restore_mana jogadas SOZINHAS em loop enquanto
--   renderem (a mao cresce / a mana rende), respeitando exhaust natural.
--   FASE BATCH: UM conjunto unico com ataques/defesas/debuffs/channels na
--   MESMA leva (batch maximiza tagCounts → strike_combo/triple_strike/
--   magic_focus/poison_stack/channel_burst).

local battleStats -- metricas agregadas (setado em M.run)

-- REGISTRO ESTRUTURADO da run (Out/2026): o diario e texto pra gente ler; a
-- bateria grande (tools/balance_sim.lua) precisa de DADOS — o que foi
-- oferecido, o que entrou no deck e em que andar, onde e contra o que morreu.
local runRec = nil
local function recOffer(id)
    if runRec and id then runRec.offered[id] = (runRec.offered[id] or 0) + 1 end
end

-- ============================================================
-- MEDIDOR: quanto do VENENO a armadura do inimigo come (Set/2026)
-- ============================================================
-- `Enemy:_applyDot` faz `eff = max(0, dano - armor)` e CONSOME a armadura: o
-- veneno nao ignora Bloqueio como no Slay the Spire, ele e absorvido. Isso e
-- citado como suspeito da fraqueza do ladino — entao vira NUMERO, nao palpite.
--
-- O gancho e do INSTRUMENTO, nao do jogo: embrulha o metodo em memoria durante
-- a bateria e soma declarado x efetivo. `_applyDot` DEVOLVE o valor declarado
-- (nao o efetivo), entao a unica forma honesta de medir e olhar a vida antes e
-- depois — que e exatamente o que o jogador ve.
local dotMeter = { declared = 0, effective = 0, absorbedTicks = 0, ticks = 0 }
local function installDotMeter()
    local Enemy = require("src.entities.Enemy")
    if Enemy._autoplayDotHooked then return end
    Enemy._autoplayDotHooked = true
    local orig = Enemy._applyDot
    Enemy._applyDot = function(self, dmg)
        local hpBefore = self.health
        local ret = orig(self, dmg)
        if (dmg or 0) > 0 then
            local eff = hpBefore - self.health
            dotMeter.declared = dotMeter.declared + dmg
            dotMeter.effective = dotMeter.effective + eff
            dotMeter.ticks = dotMeter.ticks + 1
            if eff < dmg then
                dotMeter.absorbedTicks = dotMeter.absorbedTicks + 1
            end
        end
        return ret
    end
end

-- Carta de motor pagavel: effect com draw_cards, ou restore_mana que rende
-- mais mana do que custa.
local function chooseMotorCard(game)
    for _, c in ipairs(game.hand) do
        if c.type == "effect" and (c.cost or 0) <= game.player.mana then
            if hasEffect(c, "draw_cards") then return c end
            if hasEffect(c, "restore_mana") then
                local v = 0
                for _, e in ipairs(c.effects or {}) do
                    if e.type == "restore_mana" then v = v + (e.value or 0) end
                end
                if v > (c.cost or 0) then return c end
            end
        end
    end
    return nil
end

-- Conjunto de dano guloso com o simulador fiel (V5.3). perMana=true ordena o
-- greedy por ganho/mana (passo VALOR); false por ganho bruto (LETHAL).
local function bestDamageSet(game, budget, isPicked, perMana)
    local pool = {}
    for _, c in ipairs(game.hand) do
        if not isPicked(c) and c.type ~= "joker" then
            local isDmg = (c.attack or 0) > 0
            if not isDmg then
                for _, e in ipairs(c.effects or {}) do
                    local t = e.type
                    if t == "magic_damage" or t == "aoe_magic_damage"
                        or t == "evoke_orb" or t == "evoke_all_orbs"
                        or t == "channel_orb"
                        or (t == "apply_debuff" and e.value == "vulnerable") then
                        isDmg = true
                        break
                    end
                end
            end
            if isDmg then pool[#pool + 1] = c end
        end
    end
    local set, cost = {}, 0
    local inSet = {}
    while true do
        local cur = simulateSetDamage(game, set)
        local best, bestScore
        for _, c in ipairs(pool) do
            if not inSet[c] and cost + (c.cost or 0) <= budget then
                local gain = simulateSetDamage(game, withCard(set, c)) - cur
                local score = perMana and (gain / math.max(1, c.cost or 0)) or gain
                if gain > 0 and (not best or score > bestScore) then
                    best, bestScore = c, score
                end
            end
        end
        if not best then break end
        inSet[best] = true
        table.insert(set, best)
        cost = cost + (best.cost or 0)
    end
    return set, cost
end

-- FASE BATCH: monta o conjunto unico do turno. turnState carrega estado
-- por-turno (healsUsed). Retorna (picks, why).
local function chooseBatch(game, turnState)
    local p = game.player
    local hand = game.hand
    local enemy = game.enemy
    local manaLeft = p.mana
    -- Dano TOTAL do intent (multi-golpe soma; Vulneravel congelado entra).
    local incoming = enemy.getIncomingDamage and enemy:getIncomingDamage(p) or 0
    local hpRatio = p.health / p.maxHealth
    local run = (game.runManager and game.runManager.currentRun) or {}
    local floorInAct = run.floorInAct or 1
    local armorCap = p.maxArmor or 30

    local picks, reasons = {}, {}
    local function picked(card)
        for _, x in ipairs(picks) do if x == card then return true end end
        return false
    end
    local function pick(card, why)
        table.insert(picks, card)
        manaLeft = manaLeft - (card.cost or 0)
        reasons[why] = true
    end
    local function whyStr()
        local why = {}
        for r in pairs(reasons) do table.insert(why, r) end
        table.sort(why)
        return table.concat(why, "+")
    end

    -- V5.4: dano gratis DESCONTA do necessario ANTES de escolher cartas.
    local free = freeDamageThisTurn(game)
    local targetHP = enemy.health + (enemy.armor or 0)
    local need = targetHP - free

    -- ----- plano de defesa (usado por emergencia / sobra / dano-gratis) -----
    -- V5.12: cobre min(incoming, cap do ato); requireEff = eficiencia minima
    -- armor/mana (nil = emergencia, cobre a qualquer custo).
    -- V5.7: weak-applier vale floor(incoming*0.25) de defesa virtual e entra
    -- no MESMO sort de eficiencia (rank 0 na leva = joga antes dos blocos).
    local function planDefense(requireEff, why)
        if incoming <= 0 then return end
        local target = math.min(incoming, armorCap)
        local armorNow = p.armor or 0
        if armorNow >= target then return end
        local cands = {}
        for _, c in ipairs(hand) do
            if not picked(c) and c.type ~= "joker" then
                local armor = 0
                if (c.defense or 0) > 0 then
                    armor = simulateCardValue(game, c, buildCtx(withCard(picks, c)))
                else
                    for _, e in ipairs(c.effects or {}) do
                        if e.type == "add_armor" then armor = armor + (e.value or 0) end
                    end
                end
                if armor > 0 then
                    table.insert(cands, { card = c, armor = armor })
                end
            end
        end
        if not enemy:hasStatus("weak") then
            for _, c in ipairs(hand) do
                if not picked(c) and hasDebuffEffect(c, "weak") then
                    table.insert(cands, { card = c,
                        armor = math.floor(incoming * 0.25), virtualWeak = true })
                    break
                end
            end
        end
        table.sort(cands, function(a, b)
            return a.armor / math.max(1, a.card.cost or 0)
                > b.armor / math.max(1, b.card.cost or 0)
        end)
        for _, d in ipairs(cands) do
            if armorNow >= target then break end
            local cost = d.card.cost or 0
            local eff = d.armor / math.max(1, cost)
            if cost <= manaLeft
                and (not requireEff or eff >= requireEff or cost == 0) then
                pick(d.card, d.virtualWeak and "weak-defesa" or (why or "defender"))
                armorNow = armorNow + d.armor
            end
        end
    end

    -- ----- V5.4: dano gratis ja mata? NAO gastar mana em ataque — rotear
    -- tudo pra defesa (ate min(incoming, cap)) + scaling/channel. -----
    if need <= 0 then
        planDefense(nil, "dano-gratis")
        for _, c in ipairs(hand) do
            if not picked(c) and (c.cost or 0) <= manaLeft and c.type ~= "joker"
                and (hasEffect(c, "gain_strength") or hasEffect(c, "gain_dexterity")
                    or hasEffect(c, "apply_buff") or hasEffect(c, "increase_max_mana")
                    or (hasEffect(c, "channel_orb") and (c.attack or 0) <= 0)) then
                pick(c, "dano-gratis")
            end
        end
        return picks, (#picks > 0 and whyStr() or "")
    end

    -- ----- 1. LETHAL (V5.2/V5.3): conjunto guloso com simulador fiel,
    -- incluindo evoke/channel/magic + vulnerable do proprio set. -----
    do
        local set = bestDamageSet(game, manaLeft, picked, false)
        if #set > 0 and simulateSetDamage(game, set) >= need then
            for _, c in ipairs(set) do pick(c, "LETHAL") end
            -- seguranca: se o simulador otimista errar, a sobra vira bloco
            planDefense(5)
            return picks, whyStr()
        end
    end

    -- ----- 2. SCALING (V5.8): batalha longa (>=4 turnos no ritmo atual)?
    -- Investir ANTES do passo VALOR. Nunca em turno de lethal (ja retornou). -----
    do
        local fullSet = bestDamageSet(game, manaLeft, picked, false)
        local dpt = simulateSetDamage(game, fullSet) + free
        if targetHP / math.max(1, dpt) >= 4 then
            for _, c in ipairs(hand) do
                if not picked(c) and (c.cost or 0) <= manaLeft and c.type ~= "joker"
                    and (hasEffect(c, "gain_strength") or hasBuffEffect(c, "focus")
                        or hasEffect(c, "increase_max_mana")) then
                    pick(c, "scaling")
                end
            end
        end
    end

    -- ----- 3. CURAR (V5.6): threshold 35% (50% com boss a vista, F7+, e ai
    -- ate 2 curas no turno). Gate anti-desperdicio em qualquer caso. -----
    local nearBossFloor = floorInAct >= 7
    local healThreshold = nearBossFloor and 0.50 or 0.35
    local maxHeals = nearBossFloor and 2 or 1
    if hpRatio < healThreshold then
        for _, c in ipairs(hand) do
            if turnState.healsUsed >= maxHeals then break end
            if not picked(c) and (c.cost or 0) <= manaLeft
                and healPassesGate(game, c) then
                pick(c, "curar")
                turnState.healsUsed = turnState.healsUsed + 1
            end
        end
    end

    -- ----- 4. EMERGENCIA (V5.12): defesa ANTES do dano quando o golpe
    -- anunciado machuca de verdade. -----
    local emergency = incoming >= p.health * 0.25
        or (hpRatio < 0.6 and incoming >= p.health * 0.15)
    if emergency then planDefense(nil) end

    -- ----- 5. VALOR: resto da mana em dano pelo MESMO simulador (V5.3),
    -- greedy por ganho/mana. Anti-muro: a armor do inimigo EXPIRA no turno
    -- dele — socar um muro maior que o output e jogada fora. -----
    local wallBlocked = false
    do
        local set = bestDamageSet(game, manaLeft, picked, true)
        local wall = enemy.armor or 0
        local total = simulateSetDamage(game, set)
        if #set > 0 then
            if wall > 0 and total <= wall then
                wallBlocked = true  -- mana vai pra defesa/orbes abaixo
            else
                for _, c in ipairs(set) do pick(c, "dano") end
            end
        end
    end

    -- ----- 6. defesa como alocacao de sobra (V5.12, modo normal):
    -- eficiencia minima 5 armor/mana. -----
    if not emergency then planDefense(5) end

    -- ----- 7. ORBES (V5.2): channels tem prioridade sobre a sobra e vao
    -- JUNTOS na mesma leva (3+ channel = combo channel_burst). -----
    for _, c in ipairs(hand) do
        if not picked(c) and (c.cost or 0) <= manaLeft and c.type ~= "joker"
            and hasEffect(c, "channel_orb") and (c.attack or 0) <= 0 then
            pick(c, "channel")
        end
    end
    -- Evoke fora de lethal: (a) orbes cheios + channel na mao (overflow ia
    -- descartar); (b) orbe dark "maduro" ((v+foco)*2 >= alvo). evoke_all so
    -- com 2+ orbes de dano acumulados (Consumir/Fissao nao se desperdicam).
    do
        local orbs = p.orbs or {}
        local channelPending = false
        for _, c in ipairs(hand) do
            if hasEffect(c, "channel_orb") then channelPending = true; break end
        end
        local dmgOrbs = 0
        for _, o in ipairs(orbs) do
            if o.type == "lightning" or o.type == "dark" or o.type == "fire" then
                dmgOrbs = dmgOrbs + 1
            end
        end
        local oldest = orbs[1]
        local darkReady = oldest and oldest.type == "dark"
            and ((oldest.value or 1) + getFocus(p)) * 2 >= targetHP
        local orbsFull = #orbs >= (p.orbSlots or 3)
        for _, c in ipairs(hand) do
            if not picked(c) and (c.cost or 0) <= manaLeft and c.type ~= "joker" then
                if hasEffect(c, "evoke_all_orbs") then
                    if dmgOrbs >= 2 then pick(c, "evoke") end
                elseif hasEffect(c, "evoke_orb") then
                    if (orbsFull and channelPending) or darkReady then
                        pick(c, "evoke")
                    end
                end
            end
        end
    end

    -- ----- 8. SOBRA: dois passes (nao-ataque primeiro; anti-muro segura os
    -- ataques). Gates: defesa no cap e morta; cura respeita o gate V5.6 e o
    -- limite de curas; evoke ja foi decidido acima. -----
    for pass = 1, 2 do
        for _, c in ipairs(hand) do
            local wantPass = (pass == 1 and c.type ~= "attack")
                or (pass == 2 and c.type == "attack")
            if wantPass and not picked(c) and (c.cost or 0) <= manaLeft
                and c.type ~= "joker" then
                local skip = false
                if c.type == "defense"
                    and (p.armor or 0) >= armorCap then
                    skip = true  -- cap-aware: defesa alem do cap evapora
                end
                if hasEffect(c, "evoke_orb") or hasEffect(c, "evoke_all_orbs") then
                    skip = true  -- decisao de evoke e do passo 7 (V5.2)
                end
                if hasEffect(c, "instant_heal") then
                    if not healPassesGate(game, c)
                        or turnState.healsUsed >= maxHeals then
                        skip = true  -- V5.6: gate vale em QUALQUER passo
                    end
                end
                if pass == 2 and wallBlocked then
                    skip = true  -- anti-muro
                end
                if not skip then
                    pick(c, "sobra")
                    if hasEffect(c, "instant_heal") then
                        turnState.healsUsed = turnState.healsUsed + 1
                    end
                end
            end
        end
    end

    -- ----- 9. joker na mao (leak arquitetural — o Game roteia pra colecao):
    -- jogar cedo, valor passivo pro resto da run. -----
    for _, c in ipairs(hand) do
        if not picked(c) and c.type == "joker" and (c.cost or 0) <= manaLeft
            and game.canAcceptJoker and game:canAcceptJoker() then
            pick(c, "joker")
        end
    end

    return picks, whyStr()
end

-- ============================================================
-- BATALHA
-- ============================================================

-- Executa uma leva: loga, ordena pra jogada (debuff→scaling→channel→resto→
-- ataque→evoke), seleciona, joga e bombeia ate a animacao liberar.
local function playLeva(game, picks, why, levaNum)
    local pickNames = {}
    for _, c in ipairs(picks) do table.insert(pickNames, c.name or c.id) end
    log("  → leva %d: [%s] (%s)", levaNum,
        table.concat(pickNames, ", "), why ~= "" and why or "?")
    if v6Combat() then
        picks = AI.sortForPlay(picks)
    else
        table.sort(picks, function(x, y) return playRank(x) < playRank(y) end)
    end
    -- JOGADAS (Out/2026, combo-clareza): quantas cartas por leva e quanto do
    -- valor das cartas (dano/bloqueio) veio de COMBO — a pergunta do dono
    -- "jogar um milhao de cartas e o melhor?" precisa de numero.
    if battleStats and battleStats.plays then
        local ps = battleStats.plays
        local n = #picks
        ps.n = ps.n + 1
        ps.cards = ps.cards + n
        if n > ps.max then ps.max = n end
        ps.hist[n] = (ps.hist[n] or 0) + 1
        local ctx = buildCtx(picks)
        if #(ctx.activeCombos or {}) > 0 then ps.withCombo = ps.withCombo + 1 end
        for _, c in ipairs(picks) do
            if c.type == "attack" or c.type == "defense" then
                local stat = c.type == "attack" and game.player.strength or game.player.dexterity
                local plain = AI.cardValue(game, c, nil, stat)
                local combo = AI.cardValue(game, c, ctx, stat)
                local k = c.type == "attack" and "atk" or "def"
                ps[k] = ps[k] + combo
                ps[k .. "Combo"] = ps[k .. "Combo"] + (combo - plain)
            end
        end
    end
    for _, c in ipairs(picks) do game:selectCard(c) end
    game:playSelectedCards()
    local guard = 0
    while game.combatAnimationSystem:isBlocking() and guard < 900 do
        pump(game, 1 / 30)
        guard = guard + 1
    end
end

local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local o = {}
    for k, x in pairs(v) do o[k] = deepcopy(x) end
    return o
end

-- Retrato do comeco de UMA batalha (banco do tools/balance_bench.lua): tudo
-- que a batalha herda da run — deck com forja/edicao, coringas e quais estao
-- ativos, servicos (compra extra), ato/andar/no, vida e mana base.
local function snapshotBattle(game)
    local run = game.runManager.currentRun
    return {
        class = game.selectedClass,
        deck = deepcopy(run.currentDeck), jokers = deepcopy(run.jokers),
        jokerActive = deepcopy(run.jokerActive), services = deepcopy(run.services),
        maxJokerSlots = run.maxJokerSlots,
        act = run.actNumber, floorInAct = run.floorInAct,
        node = deepcopy(run.currentNode),
        hp = game.player.health, maxHp = game.player.maxHealth,
        baseMana = game.player.baseMaxMana or game.player.maxMana,
    }
end

local function playBattle(game, label)
    if M.onBattleStart then M.onBattleStart(snapshotBattle(game)) end
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

    -- V5.16(b): jokers multiplicadores ativos no inicio da batalha
    do
        local n, eff = multJokerStats(game)
        if n > (battleStats.multJokersMax or 0) then battleStats.multJokersMax = n end
        if eff > (battleStats.multEffective or 1) then battleStats.multEffective = eff end
    end

    local bctx = AI.newBattle(game)
    while game.enemy:isAlive() and game.player:isAlive() do
        turnCount = turnCount + 1
        if turnCount > 40 then
            log("- !! batalha passou de 40 turnos — abortando (stall?)")
            return false, "stall"
        end

        local kind, value, itLog = game.enemy:getIntentPreview(game.player)
        if itLog and (itLog.hits or 0) > 1 then value = tostring(value) .. "x" .. itLog.hits end

        log("- T%d: HP %d/%d armor %d | mana %d | intent %s %s | mao: %s",
            turnCount, game.player.health, game.player.maxHealth,
            game.player.armor, game.player.mana,
            kind:upper(), tostring(value or ""), handSummary(game))

        local hpBefore = game.player.health
        local enemyBefore = game.enemy.health
        local levas = 0
        local turnState = { healsUsed = 0 }
        local thornCardReflect = 0
        local defensePlayedThisTurn = false

        -- ===== FASE MOTOR (V5.5): draw/restore_mana SOZINHAS em loop
        -- enquanto renderem — a leva seguinte enxerga mao e mana novas.
        --
        -- CONSERTO Set/2026 — O BOT PODIA PASSAR A BATALHA INTEIRA CICLANDO.
        -- O orcamento de levas era UM SO, compartilhado com a fase BATCH:
        -- `while levas < 6` no motor e `while levas < 6` no batch. Uma carta
        -- que se auto-sustenta em mana (Sosia: custa 1, compra 2, devolve 1)
        -- num deck pequeno volta pra mao a cada reembaralhamento e o guard de
        -- nao-progresso NAO dispara — porque ela PROGRIDE mesmo: a mao cresce.
        -- O motor gastava as 6 levas, o batch nunca rodava, e o bot ficava
        -- parado sem atacar ate morrer. Medido no diario: run de ladino que
        -- morreu em A1-F5 com 8 turnos seguidos de "leva 1..6: [Sosia] (motor)"
        -- e "dano causado 0" — score 64 contra ~12.000 das runs vizinhas.
        -- Como o ladino e a classe com MAIS cartas de ciclo (Sosia, Adrenalina,
        -- Aposta Calculada, Acrobacias, Elixir Azul, Tempo-bala), o defeito
        -- penalizava justamente a classe que se estava tentando medir.
        --
        -- A correcao e dar ao motor um orcamento PROPRIO: ciclar e meio, nunca
        -- fim. O batch fica com o resto garantido.
        local MOTOR_MAX_LEVAS = 3
        local motorLevas = 0
        if v6Combat() then
            -- v6 (tools/balance_ai.lua): BUSCA sobre os subconjuntos da mao.
            -- Motor tem orcamento proprio (mesma licao do conserto Set/2026):
            -- depois de 3 levas de compra, o plano vai inteiro.
            while levas < 8 and game.enemy:isAlive() and game.player:isAlive() do
                local picks, why = AI.planLeva(game, bctx,
                    { noMotorSplit = motorLevas >= MOTOR_MAX_LEVAS })
                if #picks == 0 then
                    -- Passar com mana e carta na mao e DECISAO — o diario
                    -- mostra por que (score do vazio x do "joga tudo").
                    local afford = {}
                    local m = game.player.mana
                    for _, c in ipairs(game.hand) do
                        if c.type ~= "joker" and (c.cost or 0) <= m then
                            afford[#afford + 1] = c; m = m - (c.cost or 0)
                        end
                    end
                    if #afford > 0 then
                        local s0 = AI.score(game, {}, AI.simulate(game, {}, bctx), bctx)
                        local s1 = AI.score(game, afford, AI.simulate(game, afford, bctx), bctx)
                        log("  → passou o turno: vazio %.1f x jogar %d cartas %.1f",
                            s0, #afford, s1)
                    end
                    break
                end
                if why == "motor" then motorLevas = motorLevas + 1 end
                levas = levas + 1
                for _, c in ipairs(picks) do
                    if c.type == "defense" then
                        defensePlayedThisTurn = true
                        for _, e in ipairs(c.effects or {}) do
                            if e.type == "on_defend_damage" then
                                thornCardReflect = thornCardReflect + (e.value or 0)
                            end
                        end
                    end
                end
                -- Guard de nao-progresso por ASSINATURA do estado inteiro: a 1a
                -- versao comparava so vida/escudo/mao/mana e encerrava o turno
                -- depois de uma Sangria (custo 0, compra 1: mao e mana iguais)
                -- — o guerreiro passava turnos inteiros sem atacar.
                local function sig()
                    local p, e = game.player, game.enemy
                    local hand = {}
                    for _, c in ipairs(game.hand) do hand[#hand + 1] = tostring(c) end
                    return table.concat({ e.health, e.armor or 0, p.health, p.armor,
                        p.mana, p.strength, p.dexterity, #(p.orbs or {}),
                        #(e.statusEffects or {}), table.concat(hand, ",") }, "|")
                end
                local before = sig()
                playLeva(game, picks, why, levas)
                -- leva de MOTOR pode devolver a mesma mao (reembaralha e recompra as
                -- mesmas cartas): o orcamento de motor ja a limita, o guard nao.
                if why ~= "motor" and sig() == before then break end
            end
        end
        while not v6Combat() and motorLevas < MOTOR_MAX_LEVAS and levas < 6 do
            local motor = chooseMotorCard(game)
            if not motor then break end
            motorLevas = motorLevas + 1
            local handBefore, manaBefore = #game.hand, game.player.mana
            levas = levas + 1
            if motor.type == "joker" then jokersPlayed = jokersPlayed + 1 end
            playLeva(game, { motor }, "motor", levas)
            if not game.enemy:isAlive() or not game.player:isAlive() then break end
            -- guard de nao-progresso: nem a mao cresceu nem a mana rendeu
            if #game.hand <= handBefore - 1 and game.player.mana < manaBefore then
                break
            end
        end

        -- ===== FASE BATCH (V5.5): conjunto unico maximizando combos.
        -- Cap total de levas 4 → 6 com guard de nao-progresso.
        while not v6Combat() and levas < 6 and game.enemy:isAlive()
            and game.player:isAlive() do
            local picks, why = chooseBatch(game, turnState)
            if #picks == 0 then break end
            levas = levas + 1

            for _, c in ipairs(picks) do
                if c.type == "joker" then jokersPlayed = jokersPlayed + 1 end
                -- V5.16(c): reflexo de thorn — carta de defesa com o trigger
                -- reflete POR JOGADA; joker reflete 1x/turno (P2.3).
                if c.type == "defense" then
                    defensePlayedThisTurn = true
                    for _, e in ipairs(c.effects or {}) do
                        if e.type == "on_defend_damage" then
                            thornCardReflect = thornCardReflect + (e.value or 0)
                        end
                    end
                end
            end

            local snapHP = game.enemy.health
            local snapArmor = game.player.armor
            local snapHand = #game.hand
            local snapMana = game.player.mana
            playLeva(game, picks, why, levas)
            if game.enemy.health == snapHP and game.player.armor == snapArmor
                and #game.hand >= snapHand and game.player.mana >= snapMana then
                break  -- guard de nao-progresso (leva nao mudou nada)
            end
        end

        -- V5.16(c): estimativa de thorn refletido no turno
        if defensePlayedThisTurn or thornCardReflect > 0 then
            local jokerThorn = 0
            if defensePlayedThisTurn then
                for _, j in ipairs(game.jokerSlots or {}) do
                    for _, e in ipairs(j.effects or {}) do
                        if e.type == "on_defend_damage" then
                            jokerThorn = jokerThorn + (e.value or 0)
                        end
                    end
                end
            end
            local reflect = thornCardReflect + jokerThorn
            if reflect > 0 then
                battleStats.thornReflect = (battleStats.thornReflect or 0) + reflect
                battleStats.thornTurns = (battleStats.thornTurns or 0) + 1
            end
        end
        -- V5.16(a): foco maximo visto por ato (tripwire do mago no A3)
        do
            local act = (game.runManager.currentRun
                and game.runManager.currentRun.actNumber) or 1
            local f = getFocus(game.player)
            battleStats.focusMaxByAct[act] =
                math.max(battleStats.focusMaxByAct[act] or 0, f)
        end

        -- "Decisao real": sobrou carta pagavel NAO jogada (houve trade-off)
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

        -- INVARIANTES pre-turno-inimigo (detectores de anomalia):
        local armorBeforeEnemy = game.player.armor or 0
        local nextKind = game.enemy:getIntentPreview(game.player)
        -- Total do intent (multi-golpe soma) e se ele fura o Bloqueio de
        -- proposito (perfurante) — o detector abaixo nao pode acusar o golpe
        -- que ATRAVESSA o escudo por design.
        local nextIt = game.enemy:getIntent()
        local nextVal = game.enemy:getIncomingDamage(game.player)
        local nextPierce = nextIt.pierce and true or false
        local dotNext = game.player:getDebuffStacks("poison") + game.player:getDebuffStacks("burn")
        for _, d in ipairs(nextIt.debuffs or {}) do
            if d.name == "poison" or d.name == "burn" then dotNext = dotNext + (d.stacks or 0) end
        end
        -- usa o contador do ScoreSystem (so dano DO INIMIGO) — HP bruto
        -- pega custo de sangue de Berserk/Sangria (ignora armor por design)
        local dmgTakenBeforeEnemy =
            (game.scoreSystem._battle and game.scoreSystem._battle.damageTaken) or 0

        if game.enemy:isAlive() and game.turn == "player" then
            game:endTurn()
            -- O PULSO DOS ORBES vira beats na fila (endTurn so ENFILEIRA).
            -- A cena real so chama enemyTurn com a fila VAZIA e o inimigo
            -- vivo (GameplayScene: `not isBlocking() and enemy:isAlive()`).
            -- O piloto chamava na hora: quando o pulso matava o inimigo, o
            -- golpe ja estava enfileirado e o mago levava dano de um cadaver
            -- (Out/2026, medido: "inimigo 0 HP, dano sofrido 11"). Drena
            -- antes, como a cena.
            local guardP = 0
            while game.combatAnimationSystem:isBlocking() and guardP < 600 do
                pump(game, 1 / 30)
                guardP = guardP + 1
            end
        end
        if game.enemy:isAlive() and game.turn == "enemy" then
            game:enemyTurn()
            -- Set/2026: o turno do inimigo virou uma CADEIA de beats
            -- (telegrafia > golpe > espinhos > veneno > upkeep > compra >
            -- gatilhos > a vez volta) e nao tem mais duracao fixa. Pumpar um
            -- numero magico mediria meio turno: esperamos a fila DRENAR.
            local guardET = 0
            while game.combatAnimationSystem:isBlocking() and guardET < 600 do
                pump(game, 1 / 30)
                guardET = guardET + 1
            end
            pump(game, 0.2)
        end

        -- DETECTOR "escudo furado" (o bug que o dono pegou jogando e o
        -- piloto engoliu): escudo cobria o golpe anunciado (+4 de margem
        -- pra Furia) mas o HP caiu mesmo assim.
        local dmgTakenAfterEnemy =
            (game.scoreSystem._battle and game.scoreSystem._battle.damageTaken) or 0
        local enemyDealt = dmgTakenAfterEnemy - dmgTakenBeforeEnemy
        if (nextVal or 0) > 0 and not nextPierce and dotNext == 0
            and armorBeforeEnemy >= (nextVal or 0) + 4
            and enemyDealt > 0 then
            anomaly("escudo furado: %d de escudo vs golpe %s %d, inimigo furou %d",
                armorBeforeEnemy, nextKind, nextVal or 0, enemyDealt)
        end

        bctx.turns = bctx.turns + 1
        bctx.dealt = bctx.dealt + math.max(0, enemyBefore - game.enemy.health)
        if (nextVal or 0) > 0 then
            bctx.hitTurns = bctx.hitTurns + 1
            bctx.incSum = bctx.incSum + nextVal
            bctx.lostSum = bctx.lostSum + math.max(0, enemyDealt)
        end
        log("    dano causado %d | dano sofrido %d | inimigo %d HP",
            enemyBefore - game.enemy.health,
            math.max(0, hpBefore - game.player.health),
            math.max(0, game.enemy.health))
    end

    pump(game, 1.5) -- death anim / eventos pendentes

    -- metricas por ato (post-mortem: onde o output deixa de acompanhar)
    do
        local act = (game.runManager.currentRun
            and game.runManager.currentRun.actNumber) or 1
        local ba = battleStats.byAct[act]
            or { dealt = 0, taken = 0, turns = 0, battles = 0 }
        ba.dealt = ba.dealt + (game.enemy.maxHealth - math.max(0, game.enemy.health))
        ba.taken = ba.taken + math.max(0, dmgTakenBefore - game.player.health)
        ba.turns = ba.turns + turnCount
        ba.battles = ba.battles + 1
        -- chefe separado (kit Out/2026: meta de 7-10 turnos no fim de jogo)
        local cn = game.runManager.currentRun and game.runManager.currentRun.currentNode
        if cn and cn.type == "boss" then
            ba.bossTurns = (ba.bossTurns or 0) + turnCount
            ba.bosses = (ba.bosses or 0) + 1
        end
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
-- POS-BATALHA: recompensas + scoring de deck-building
-- ============================================================

-- Ids do deck da run normalizados (entries podem ser tabela {id, edition}).
local function deckIdList(game)
    local out = {}
    local deck = (game.runManager.currentRun
        and game.runManager.currentRun.currentDeck) or {}
    for _, e in ipairs(deck) do
        out[#out + 1] = type(e) == "table" and e.id or e
    end
    return out
end

local function classTagAffinity(game, cardData)
    -- afinidade simples: tags da carta que ja existem no deck contam
    local deckTags = {}
    for _, id in ipairs(deckIdList(game)) do
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

-- Arquetipo por classe (prior de deck-building): o bot compra pra FOCAR,
-- nao pra colecionar — combos exigem densidade da mesma tag.
-- V5.17 (re-baseline Jul/2026): mago/ladino ganharam afinidade de DEFESA.
-- A bateria 15x3 mostrou mago 0/15 morrendo de chip (sofrido 2-16/turno,
-- decks sem NENHUMA defesa alem do starter) enquanto o guerreiro (unico
-- prior com defend/armor) zerava o dano inimigo — vies de compra do bot,
-- nao (so) desbalanceio do jogo. Humano de mago compra Amuleto/Campo de
-- Forca; o bot agora tambem.
local CLASS_ARCHETYPE = {
    warrior = { strike = 3, armor = 2, defend = 2, strength = 2 },
    mage    = { channel = 3, magic = 3, lightning = 2, evoke = 2,
                defend = 2, armor = 2, ice = 1 },
    rogue   = { poison = 3, strike = 2, finisher = 2,
                defend = 2, armor = 1, thorn = 1 },
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
-- V5.9: FORJA POR SCORE — score = (copias x ciclosPorBatalha / max(1,custo))
-- x ganhoReal (getForgeGains, fonte unica com a UI) x (1 + arquetipo*0.3),
-- com priors por classe e sinal de morte-por-chip (taken/turno alto sem
-- nunca bater no cap de armor → dobra o peso de defesa).
-- ============================================================

local function forgeScore(game, cardId, counts)
    local RunManager = require("src.systems.RunManager")
    local cd = game.deckManager.cardDatabase:getCard(cardId)
    if not cd then return -1 end
    if not game.runManager:canUpgrade(cardId) then return -1 end
    local gains = RunManager.getForgeGains(cd)
    local realGain = (gains.atk or 0) + (gains.def or 0) + (gains.effect or 0)
    if realGain <= 0 then return -1 end
    local copies = (counts and counts[cardId]) or 1
    local deckN = math.max(1, #deckIdList(game))
    local avgTurns = (battleStats and battleStats.battles > 0)
        and (battleStats.turns / battleStats.battles) or 6
    -- ciclos do deck por batalha ~ (turnos x 4 compradas) / tamanho do deck
    local cycles = math.max(1, (avgTurns * 4) / deckN)
    local cost = math.max(1, cd.cost or 1)
    local s = (copies * cycles / cost) * realGain
        * (1 + archetypeScore(game, cd) * 0.3)
    -- priors por classe (V5.9)
    local classId = game.selectedClass or "warrior"
    if classId == "warrior" and (cd.attack or 0) > 0 then
        s = s * 1.5  -- warrior: o ataque mais jogado
    elseif classId == "rogue" and (cd.attack or 0) > 0 and (cd.cost or 0) <= 1 then
        s = s * 1.5  -- rogue: strikes custo 0-1
    elseif classId == "mage" then
        for _, e in ipairs(cd.effects or {}) do
            local t = e.type
            if t == "magic_damage" or t == "aoe_magic_damage" or t == "add_armor"
                or t == "draw_cards" or t == "restore_mana" then
                s = s * 1.5  -- mage: magic_damage/add_armor/motor
                break
            end
        end
    end
    -- morte por chip sem armorCapHits → defesa vale o dobro
    if battleStats then
        local act = (game.runManager.currentRun
            and game.runManager.currentRun.actNumber) or 1
        local ba = battleStats.byAct and battleStats.byAct[act]
        if ba and ba.turns > 2 and (ba.taken / ba.turns) >= 6
            and (battleStats.armorCapHits or 0) == 0
            and (cd.defense or 0) > 0 then
            s = s * 2
        end
    end
    return s
end

-- Melhor alvo de forja do deck atual (usado por fogueira, loja e picker).
-- Indice da copia que a forja VAI pegar: a de MENOR nivel entre as
-- forjaveis daquele id. Espelha a escolha de `RunManager:upgradeCard`, e
-- existe pra que o detector de "ouro queimado" meca a MESMA copia antes e
-- depois (a forja e por copia, nao por id — CLAUDE.md).
local function forgeIndexFor(game, cardId)
    local rm = game.runManager
    local run = rm and rm.currentRun
    if not run then return nil end
    local best, bestLvl
    for i, entry in ipairs(run.currentDeck or {}) do
        local RM = require("src.systems.RunManager")
        if RM.entryId(entry) == cardId and rm:canUpgradeAt(i) then
            local lvl = rm:getEntryLevel(entry)
            if not bestLvl or lvl < bestLvl then best, bestLvl = i, lvl end
        end
    end
    return best
end

local function bestForgeTarget(game)
    local counts = {}
    for _, id in ipairs(deckIdList(game)) do
        counts[id] = (counts[id] or 0) + 1
    end
    local bestId, bestS
    for id in pairs(counts) do
        local s = forgeScore(game, id, counts)
        if s > 0 and (not bestS or s > bestS) then bestId, bestS = id, s end
    end
    return bestId, bestS or 0
end

-- ============================================================
-- V5.11: BANCADA DE CORINGAS — pontua todos os owned e ativa o top via
-- Game:setJokerActive. REGRA P0.9: multiplicadores de MESMO tipo nao
-- compoem — o SEGUNDO damage_multiplier pontua ~0 (so o maior conta);
-- thorn de joker pontua como valor flat/turno (1x/turno via P2.3), nao
-- multiplicado por defesas jogadas.
-- ============================================================

local JOKER_EFFECT_SCORE = {
    damage_bonus = 8, defense_bonus = 6, on_attack_heal = 6,
    on_defend_damage = 4,   -- P2.3: 1x/turno — flat, NAO x defesas
    regen_per_turn = 5, strength_per_turn = 12, on_turn_start_draw = 15,
    channel_per_turn = 10, on_attack_debuff = 8,
    damage_per_turn = -8,
}

local function scoreJokerParts(inst)
    local flat, dmgMult, defMult = 0, nil, nil
    for _, e in ipairs(inst.effects or {}) do
        local t = e.type
        if t == "damage_multiplier" and e.target == "attack" then
            dmgMult = math.max(dmgMult or 1, e.value or 1)
        elseif t == "defense_multiplier" and e.target == "defense" then
            defMult = math.max(defMult or 1, e.value or 1)
        elseif t == "heal_multiplier" then
            flat = flat + ((e.value or 1) - 1) * 12
        elseif JOKER_EFFECT_SCORE[t] then
            flat = flat + JOKER_EFFECT_SCORE[t] * (tonumber(e.value) or 1)
        else
            flat = flat + 2  -- efeito desconhecido: valor simbolico
        end
    end
    return flat, dmgMult, defMult
end

local function optimizeJokerBench(game, whenLabel)
    local rm = game.runManager
    if not (game.isRunMode and rm.hasActiveRun and rm:hasActiveRun()) then return end
    if not game.setJokerActive then return end
    local all = rm:buildAllJokerInstances()
    if #all == 0 then return end
    local cap = rm:getMaxJokerSlots()

    local entries = {}
    for _, inst in ipairs(all) do
        local flat, dm, dfm = scoreJokerParts(inst)
        table.insert(entries, {
            idx = inst._ownedIndex, name = inst.name or inst.id,
            flat = flat, dmgMult = dm, defMult = dfm, score = flat,
        })
    end
    -- so o MAIOR multiplicador de cada tipo recebe valor (P0.9)
    local function grantBest(field)
        local best
        for _, en in ipairs(entries) do
            if en[field] and (not best or en[field] > best[field]) then
                best = en
            end
        end
        if best then best.score = best.score + (best[field] - 1) * 40 end
    end
    grantBest("dmgMult")
    grantBest("defMult")

    table.sort(entries, function(a, b) return a.score > b.score end)
    local want = {}
    for i = 1, math.min(cap, #entries) do want[entries[i].idx] = true end

    local changed = false
    -- desativa os fora do top primeiro (libera slots), depois ativa o top
    for _, en in ipairs(entries) do
        if not want[en.idx] and rm:isJokerActive(en.idx) then
            game:setJokerActive(en.idx, false)
            changed = true
        end
    end
    for i = 1, math.min(cap, #entries) do
        local en = entries[i]
        if not rm:isJokerActive(en.idx) then
            local ok = game:setJokerActive(en.idx, true)
            if ok then changed = true end
        end
    end
    if changed then
        local names = {}
        for i = 1, math.min(cap, #entries) do names[#names + 1] = entries[i].name end
        log("  (bancada %s: ativei [%s] de %d possuidos)",
            whenLabel or "?", table.concat(names, ", "), #entries)
    end
end

-- Injeta o contexto real da run na loja (classe + deck → afinidade/pity e
-- oferta de Forja, que exige context.runManager — sem isso o bot via uma
-- vitrine diferente da do jogador).
local function primeShopContext(game)
    if game.shopSystem.setContext then
        game.shopSystem:setContext({
            classId = game.selectedClass,
            deckIds = deckIdList(game),
            runManager = game.runManager,
        })
    end
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
        local ids = deckIdList(game)
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
            if v6Build() then
                -- v6: as 3 piores pela heuristica viram CANDIDATAS; a
                -- simulacao escolhe qual tirar (tirar a "pior" no papel as
                -- vezes tira a unica defesa que segura o chefe).
                local dctx = AI.deckContext(game)
                local cands = {}
                for _, id in ipairs(ids) do
                    local cd = game.deckManager.cardDatabase:getCard(id)
                    local isDef = cd and cd.type == "defense"
                    if cd and not (isDef and defCount <= 3) then
                        cands[#cands + 1] = { id = id, w = AI.cardWorth(game, cd, dctx, true) }
                    end
                end
                table.sort(cands, function(a, b) return a.w < b.w end)
                local baseLoss = M.evalDeckSim(game, nil)
                local seen = {}
                for i = 1, math.min(3, #cands) do
                    local id = cands[i].id
                    if not seen[id] then
                        seen[id] = true
                        local loss = M.evalDeckSim(game, function(snap)
                            for k, e in ipairs(snap.deck) do
                                if (type(e) == "table" and e.id or e) == id then
                                    table.remove(snap.deck, k); break
                                end
                            end
                        end)
                        if not worstS or loss < worstS then worst, worstS = id, loss end
                    end
                end
                if worst and worstS > baseLoss + 1 then
                    log("  (picker: nenhuma remocao ajuda na simulacao — mantive o deck)")
                    return
                end
            else
            for _, id in ipairs(ids) do
                local cd = game.deckManager.cardDatabase:getCard(id)
                local isDef = cd and cd.type == "defense"
                if not (isDef and defCount <= 3) then
                    local s = cardValueScore(game, id)
                    if not worstS or s < worstS then worst, worstS = id, s end
                end
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
            -- V5.9: mesmo score de forja da fogueira/loja
            local bestId, bestS = bestForgeTarget(game)
            if bestId then
                local lvl = game.runManager:upgradeCard(bestId)
                log("  (picker: FORJEI %s → nivel %s, score %.1f)",
                    bestId, tostring(lvl), bestS)
            end
        end
    end
end

local function doRewards(game)
    game.shopSystem:setMode("rewards")
    primeShopContext(game)
    game.shopSystem:generateOffers()
    local offers = game.shopSystem:getCurrentOffers()
    for _, o in ipairs(offers) do if o.type == "card" then recOffer(o.id) end end

    local best, bestScore = nil, -1
    if v6Build() then
        -- v6: entra quem MELHORA a media do deck (AI.wantsCard); coringa
        -- sempre (bancada nao dilui). Pular e uma jogada, nao um fracasso.
        local ids, byId = {}, {}
        for _, o in ipairs(offers) do
            if o.type == "card" and game.economySystem:canAfford(o.cost) then
                ids[#ids + 1] = o.id; byId[o.id] = o
            end
        end
        local pickId, gain = M.pickBySim(game, ids)
        if pickId then best, bestScore = byId[pickId], gain end
    else
    for _, o in ipairs(offers) do
        if o.type == "card" and game.economySystem:canAfford(o.cost) then
            local cd = game.deckManager.cardDatabase:getCard(o.id)
            local s = (RARITY_SCORE[o.rarity or "common"] or 1) * 2
                + classTagAffinity(game, cd)
                + archetypeScore(game, cd) * 2 - o.cost * 0.5
            if s > bestScore then best, bestScore = o, s end
        end
    end
    end

    local deckSize = #deckIdList(game)
    -- deck gordo dilui: acima de 18 cartas, so rare+ entra
    if not v6Build() and best and deckSize > 18 and (RARITY_SCORE[best.rarity] or 1) < 6 then
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
        -- V5.11: aquisicao de joker → re-otimiza a bancada
        local cd = game.deckManager.cardDatabase:getCard(best.id)
        if cd and cd.type == "joker" then
            optimizeJokerBench(game, "recompensa")
        end
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
    local run = game.runManager.currentRun

    -- V5.14: elite compensa? usa o dano/turno MEDIDO nas batalhas do ato
    -- (battleStats.byAct) — face value do deck so como fallback na primeira
    -- batalha do ato (estimativa cega superestimava decks de motor e
    -- subestimava scaling/orbes).
    local dptEstimate
    local ba = battleStats and battleStats.byAct
        and battleStats.byAct[run.actNumber]
    if ba and ba.turns and ba.turns > 0 then
        dptEstimate = ba.dealt / ba.turns
    else
        local deckDmg, deckN = 0, 0
        for _, id in ipairs(deckIdList(game)) do
            local cd = game.deckManager.cardDatabase:getCard(id)
            if cd and (cd.attack or 0) > 0 then
                deckDmg = deckDmg + cd.attack / math.max(1, cd.cost or 1)
                deckN = deckN + 1
            end
        end
        local dmgPerMana = deckN > 0 and deckDmg / deckN or 7
        dptEstimate = dmgPerMana * (game.player.maxMana or 3)
    end
    local ActSystem = require("src.systems.ActSystem")
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

    -- V5.13: chegando no F7 com caixa (>= $30), SHOP passa na frente de
    -- EVENT — e a ultima chance de converter ouro em poder pro boss.
    if nearBoss and gold >= 30 then
        local si, ei
        for i, t in ipairs(want) do
            if t == BT.SHOP and not si then si = i end
            if t == BT.EVENT and not ei then ei = i end
        end
        if si and ei and si > ei then
            table.remove(want, si)
            table.insert(want, ei, BT.SHOP)
        end
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
        -- V5.9: forja por SCORE (copias x ciclos / custo x ganho real x
        -- arquetipo) — substitui a heuristica "ataque com mais copias".
        local bestId, bestS = bestForgeTarget(game)
        if bestId then
            local lvl = game.runManager:upgradeCard(bestId)
            log("- Acampamento: **forjei** %s → nivel +%s (score %.1f)",
                bestId, tostring(lvl), bestS)
        else
            log("- Acampamento: nada forjavel — descansei mesmo cheio")
            p:heal(math.floor(p.maxHealth * 0.30))
        end
    end
end

-- Pontua UMA entrada de gain/cost declarada pelo evento.
--
-- CONSERTO Set/2026 — O PILOTO CRASHAVA EM TODO EVENTO COM CUSTO/GANHO.
-- A v4 recebia STRING e fazia `s:lower()`; os eventos passaram a declarar
-- TABELAS estruturadas (`{ k = "gold", n = 30, fb = "$30" }`) e a chamada
-- morria com "attempt to call method 'lower' (a nil value)". O pcall de
-- playRun engolia a run inteira: 3 de 8 corridas da bateria de ladino
-- terminaram em CRASH em vez de em morte medida — e o diario nao media
-- ganho nenhum de evento nas outras.
--
-- A correcao nao e so "aceitar tabela": e parar de LER TEXTO. O `fb` e o
-- fallback de exibicao em PT; ler ele faria o bot decidir diferente em
-- outro idioma. A chave `k` e o contrato estavel — o bot pontua por ela.
local function scoreEventEntry(game, entry, isCost)
    local p = game.player
    local hp, maxHp = p.health, p.maxHealth
    local gold = game.economySystem.currentGold
    local deckN = #deckIdList(game)
    local sign = isCost and -1 or 1

    if type(entry) ~= "table" or not entry.k then return 0 end
    local k, n, pct = entry.k, tonumber(entry.n) or 0, tonumber(entry.pct) or 0

    -- ===== custos que nao podemos pagar = veto =====
    if isCost and k == "hp" then
        if hp - n <= 4 then return -1000 end
        return -n * (hp < maxHp * 0.4 and 1.6 or 0.6)
    end
    if isCost and k == "gold" then
        if gold < n then return -1000 end
        return -n / 8
    end
    if k == "chance_trap" then
        return -(pct / 100) * n * 1.2
    end
    if k == "remove_random" then
        -- remocao ALEATORIA: boa com deck gordo de commons, ruim com deck afiado
        return (deckN > 16) and 3 or -6
    end

    -- ===== ganhos =====
    if k == "remove_choice"  then return sign * ((deckN >= 14) and 12 or 5) end
    if k == "dup_choice"     then return sign * 8 end
    if k == "forge_choice" or k == "forge_random" then return sign * 7 end
    if k == "max_mana"       then return sign * 12 end
    if k == "max_hp"         then return sign * 7 end
    if k == "card_legendary" then return sign * 10 end
    if k == "card_rare"      then return sign * ((deckN > 18) and 3 or 6) end
    if k == "cards_random"   then return sign * ((deckN > 16) and -2 or 2) end -- diluicao
    if k == "card_potion" or k == "chance_potion" then return sign * 2 end
    if k == "mystery"        then return sign * 1 end
    if k == "heal_pct" then
        local heal = math.min(maxHp * n / 100, maxHp - hp)
        return sign * (heal / maxHp) * 30
    end
    if k == "heal_flat" then
        local heal = math.min(n, maxHp - hp)
        return sign * (heal / maxHp) * 30
    end
    -- valor esperado de ouro probabilistico ("50% de ganhar $50", "40% $25")
    if k == "gamble" or k == "chance_gold" then
        return sign * (pct / 100) * n / 6
    end
    if k == "gold" then return sign * n / 6 end

    -- Chave DESCONHECIDA grita (fallback silencioso e proibido no projeto):
    -- evento novo com chave nova passaria a valer 0 e o bot nunca a escolheria.
    anomaly("evento com chave de %s desconhecida: '%s' — o piloto pontuou 0",
        isCost and "custo" or "ganho", tostring(k))
    return 0
end

local function doEvent(game)
    local run = game.runManager.currentRun
    local ev = Events.roll(run.actNumber or 1, nil, require("src.systems.EnemyRoster").biomeAct(run))
    if not ev then
        log("- Evento: nenhum disponivel")
        return
    end
    -- v4: pontua CADA opcao pelos gains/costs declarados; "ir embora" = 0.
    -- Escolhe a de maior valor esperado pro estado atual (HP/ouro/deck).
    local bestIdx, bestScore = #ev.options, 0.5  -- neutro levemente > 0: so
    for i, opt in ipairs(ev.options) do          -- aposta se valer a pena
        local s = 0
        for _, g in ipairs(opt.gains or {}) do s = s + scoreEventEntry(game, g, false) end
        for _, c in ipairs(opt.costs or {}) do s = s + scoreEventEntry(game, c, true) end
        if (opt.gains or opt.costs) and s > bestScore then
            bestIdx, bestScore = i, s
        end
    end
    local opt = ev.options[bestIdx]
    local okApply, feedback = pcall(opt.apply, game)
    log("- Evento **%s**: escolhi '%s' (score %.1f) → %s", ev.title, opt.label,
        bestScore, okApply and (feedback or "ok") or ("ERRO: " .. tostring(feedback)))
end

-- ============================================================
-- LOJA v5 (V5.1 whitelist / V5.9 forja / V5.10 reroll / V5.13 caixa)
-- ============================================================

-- V5.1: upgrades que aplicam efeito REAL. damage/defense/card_draw sao
-- toast-only (P3.2) — comprar e queimar ouro; o bot nao compra.
local REAL_UPGRADES = {
    increase_base_mana = true,
    increase_max_health = true,
    forge_card = true,
}

-- Servicos SEM picker (mexem no ledger da run, nao no deck). A tesoura e a
-- prensa ficam de fora de proposito: elas tem politica propria mais abaixo,
-- porque so fazem sentido em funcao do TAMANHO do deck.
local SERVICE_EFFECTS = {
    add_joker_slot    = true,
    raise_interest_cap = true,
    increase_draw     = true,
}

-- V5.1: o harness APLICA o efeito do upgrade (a UI real faz isso na
-- CardRewardScreen) + detector "ouro queimado": upgrade comprado que nao
-- altera estado observavel = anomalia.
-- Aplica um upgrade/servico comprado, ESPELHANDO CardRewardScreen:applyUpgrade
-- (a tela real). Set/2026: antes daqui so saiam mana e vida maxima — os cinco
-- SERVICOS da loja (tesoura, prensa, bancada de coringa, grimorio, cofre) nao
-- tinham caminho nenhum no piloto, e por isso a metade cara da loja NUNCA era
-- comprada numa bateria inteira. Qualquer conclusao de economia tirada dali
-- media o bot, nao a economia.
--
-- O detector de "ouro queimado" tambem estava errado para servicos: ele
-- perguntava se mana OU vida maxima mudou, e nenhum servico mexe nesses dois.
-- Ligar os servicos sem consertar o detector encheria o relatorio de alarme
-- falso — que e pior do que nao ter detector. Agora cada efeito declara QUAL
-- e o seu observavel.
local function applyUpgradeOffer(game, o)
    local p = game.player
    local rm = game.runManager
    local efeito = o.effect

    -- observador(game) -> valor comparavel antes/depois
    local OBSERVAVEL = {
        increase_base_mana  = function() return p.maxMana end,
        increase_max_health = function() return p.maxHealth end,
        add_joker_slot      = function()
            return (rm and rm.getMaxJokerSlots and rm:getMaxJokerSlots()) or 0
        end,
        raise_interest_cap  = function()
            return (game.economySystem and game.economySystem.getInterestCap
                and game.economySystem:getInterestCap()) or 0
        end,
        increase_draw       = function()
            return (rm and rm.getServiceCount and rm:getServiceCount("card_draw_upgrade")) or 0
        end,
    }
    local observa = OBSERVAVEL[efeito]
    local antes = observa and observa() or nil

    if efeito == "increase_base_mana" then
        p.baseMaxMana = (p.baseMaxMana or p.maxMana) + (o.value or 1)
        p.maxMana = p.maxMana + (o.value or 1)
        p.mana = p.mana + (o.value or 1)
    elseif efeito == "increase_max_health" then
        p.maxHealth = p.maxHealth + (o.value or 0)
        p.health = p.health + (o.value or 0)

    elseif efeito == "add_joker_slot" then
        if rm and rm.registerService then rm:registerService(o.id) end
        if game.recomputeMaxJokerSlots then game:recomputeMaxJokerSlots() end
    elseif efeito == "raise_interest_cap" then
        if rm and rm.registerService then rm:registerService(o.id) end
        if game.syncInterestCap then game:syncInterestCap() end
    elseif efeito == "increase_draw" then
        if rm and rm.registerService then rm:registerService(o.id) end

    elseif efeito == "remove_card" or efeito == "duplicate_card"
        or efeito == "forge_card" then
        -- Servicos de PICKER: quem muda o deck e o _G.openCardPicker headless
        -- (installHeadlessPicker), igual a tela real.
        --
        -- O LEDGER VEM ANTES DO PICKER, e isso nao e detalhe: e ele que faz o
        -- preco da PROXIMA compra subir (8, 12, 17, 25, 36, 45 na tesoura).
        -- Sem registrar, o servico fica eternamente no preco base — a primeira
        -- bateria com servicos ligados comprou a tesoura 40 vezes e TODAS as
        -- 40 sairam por $8, o que faria a economia parecer barata por um
        -- defeito do medidor. CardRewardScreen:_openDeckService registra na
        -- mesma ordem.
        if efeito == "forge_card" then
            if rm and rm.registerPaidForge then rm:registerPaidForge() end
        elseif rm and rm.registerService then
            rm:registerService(o.id)
        end
        if _G.openCardPicker then _G.openCardPicker(o.picker) end
        return  -- o observavel destes e o deck, checado pelo proprio picker

    else
        anomaly("upgrade sem caminho no piloto: %s (efeito '%s') — ouro gasto "
            .. "sem efeito aplicado", tostring(o.id or "?"), tostring(efeito))
        return
    end

    if observa and observa() == antes then
        anomaly("ouro queimado: upgrade %s nao alterou seu observavel (%s)",
            tostring(o.id or efeito or "?"), tostring(antes))
    end
end

local function doShop(game)
    game.shopSystem:setMode("shop")
    primeShopContext(game)
    game.shopSystem:generateOffers()

    local run = game.runManager.currentRun
    local act = run.actNumber or 1
    local floorInAct = run.floorInAct or 1
    -- Livro-caixa: ouro na entrada + se a bancada de coringa estava na
    -- vitrine e cabia no bolso (a pergunta do dono: "da pra alcancar?").
    if runRec and runRec.eco then
        local visit = { act = act, gold = game.economySystem.currentGold }
        for _, o in ipairs(game.shopSystem:getCurrentOffers()) do
            if o.effect == "add_joker_slot" then
                visit.slotCost = o.cost
                visit.slotAffordable = game.economySystem.currentGold >= o.cost
            end
        end
        table.insert(runRec.eco.shops, visit)
    end
    -- V5.13: politica de caixa — reserva alvo min(50, 15*ato) rendendo
    -- juros; a partir do F6 a reserva e liberada (boss a vista: ouro parado
    -- e poder desperdicado).
    local reserve = (floorInAct >= 6) and 0 or math.min(50, 15 * act)
    local function spendable()
        return game.economySystem.currentGold - reserve
    end

    local bought = 0
    local boughtJoker = false

    local function scoreCardOffer(o)
        local cd = game.deckManager.cardDatabase:getCard(o.id)
        if v6Build() then
            -- v6: >= 6 = compra (limiar do laco de compra abaixo)
            local want, w = AI.wantsCard(game, cd)
            if not want then return -1 end
            return 6 + w
        end
        local s = (RARITY_SCORE[o.rarity or "common"] or 1) * 2
            + classTagAffinity(game, cd) + archetypeScore(game, cd) * 2
        -- disciplina de deck: >18 cartas, so rare+ entra
        local deckSize = #deckIdList(game)
        if deckSize > 18 and (RARITY_SCORE[o.rarity or "common"] or 1) < 6 then
            s = -1
        end
        return s
    end

    -- V5.1: mana_upgrade tem prioridade MAXIMA (acima de qualquer carta)
    -- quando gold >= 25 — e o unico ganho de teto permanente da loja.
    local function tryManaUpgrade()
        for _, o in ipairs(game.shopSystem:getCurrentOffers()) do
            if o.type == "upgrade" and o.effect == "increase_base_mana"
                and game.economySystem.currentGold >= 25
                and game.economySystem:canAfford(o.cost) then
                game.economySystem:spendGold(o.cost, o.type, o.id)
                applyUpgradeOffer(game, o)
                run._usedShop = true
                bought = bought + 1
                log("- Loja: comprei **%s** ($%d) — mana base %d (prioridade maxima)",
                    o.name, o.cost, game.player.baseMaxMana or game.player.maxMana)
                return true
            end
        end
        return false
    end
    tryManaUpgrade()

    -- V5.10: reroll ate 2x se nenhuma CARTA com score >= 6 e sobra caixa.
    local rerolls = 0
    while rerolls < 2 do
        local bestCardScore = -1
        for _, o in ipairs(game.shopSystem:getCurrentOffers()) do
            if o.type == "card" then
                bestCardScore = math.max(bestCardScore, scoreCardOffer(o))
            end
        end
        local refreshCost = game.shopSystem:getRefreshCost()
        if bestCardScore < 6
            and game.economySystem.currentGold >= refreshCost + 15 then
            game.economySystem:spendGold(refreshCost, "refresh", "shop_refresh")
            game.shopSystem:refreshOffers()
            rerolls = rerolls + 1
            log("- Loja: REROLL #%d ($%d) — vitrine sem carta com score >= 6",
                rerolls, refreshCost)
        else
            break
        end
    end

    local offers = game.shopSystem:getCurrentOffers()
    for _, o in ipairs(offers) do if o.type == "card" then recOffer(o.id) end end

    -- ===== SERVICOS DA LOJA (Set/2026) =====
    -- Tesoura, prensa, bancada de coringa, grimorio e cofre: as compras CARAS
    -- e permanentes. O piloto nao tinha caminho nenhum pra elas, entao a
    -- metade cara da vitrine ficava intocada a corrida inteira e a economia
    -- media do relatorio era a de um jogador que so compra carta de $3.
    --
    -- A politica abaixo nao tenta ser otima — tenta ser um jogador RAZOAVEL,
    -- que e o que um instrumento de balanco precisa representar:
    --   • so compra o que tem uso AGORA (bancada de coringa so com coringa
    --     parado; tesoura so com deck inchado);
    --   • o cofre e decisao de ABERTURA — ele rende por batalha RESTANTE, e
    --     comprado tarde e prejuizo (o proprio Config.Offers explica isso);
    --   • nunca fura a reserva de caixa nem o teto de 3 compras por loja.
    local rm = game.runManager
    local Config = require("src.core.Config")
    local function serviceWorth(o)
        local ef = o.effect
        if ef == "increase_draw" then
            -- +1 carta por turno e motor puro e nao depende de estado.
            return 10
        elseif ef == "add_joker_slot" then
            -- So vale com coringa PARADO na bancada — senao e slot vazio.
            local possuidos = #((run.jokers) or {})
            local ativos = (rm and rm.getMaxJokerSlots and rm:getMaxJokerSlots())
                or (game.maxJokerSlots or 3)
            return (possuidos > ativos) and 9 or -1
        elseif ef == "raise_interest_cap" then
            -- Rende +N por batalha restante, e so se realiza mantendo
            -- 5x(teto) parado no bolso. Decisao de abertura: A1-A2 apenas, e
            -- so com caixa que aguente a imobilizacao.
            local eco = game.economySystem
            local tetoNovo = (eco:getInterestCap() or 5)
                + ((Config.Offers and Config.Offers.INTEREST_CAP_PER_BUY) or 2)
            local precisaNoBolso = 5 * tetoNovo
            if act > 2 then return -1 end
            if eco.currentGold - o.cost < precisaNoBolso then return -1 end
            return 8
        end
        return -1
    end

    for _, o in ipairs(offers) do
        if bought >= 3 then break end
        if o.type == "upgrade" and SERVICE_EFFECTS[o.effect] then
            local w = serviceWorth(o)
            if w > 0 and game.economySystem:canAfford(o.cost)
                and spendable() >= o.cost then
                game.economySystem:spendGold(o.cost, o.type, o.id)
                applyUpgradeOffer(game, o)
                run._usedShop = true
                bought = bought + 1
                log("- Loja: comprei SERVICO **%s** ($%d, peso %.1f)",
                    o.name, o.cost, w)
            end
        end
    end

    -- TESOURA (remove_card): deck inchado e o gatilho, igual ao guard do
    -- picker headless (que se recusa a remover abaixo de 8 cartas).
    for _, o in ipairs(offers) do
        if bought >= 3 then break end
        if o.type == "upgrade" and o.effect == "remove_card"
            and #deckIdList(game) >= 14
            and game.economySystem:canAfford(o.cost)
            and spendable() >= o.cost then
            game.economySystem:spendGold(o.cost, o.type, o.id)
            applyUpgradeOffer(game, o)
            run._usedShop = true
            bought = bought + 1
            log("- Loja: comprei SERVICO **%s** ($%d, deck %d cartas)",
                o.name, o.cost, #deckIdList(game))
        end
    end

    -- Forja paga (score V5.9 decide o alvo; so compra se ha alvo que rende)
    for _, o in ipairs(offers) do
        if bought >= 3 then break end
        if o.type == "upgrade" and o.effect == "forge_card"
            and game.economySystem:canAfford(o.cost)
            and spendable() >= o.cost then
            local target, ts = bestForgeTarget(game)
            if target and ts > 0 then
                game.economySystem:spendGold(o.cost, o.type, o.id)

                -- O DETECTOR PRECISA OLHAR A MESMA COPIA ANTES E DEPOIS.
                --
                -- A versao anterior comparava `getUpgrades(id)` com o retorno
                -- de `upgradeCard(id)` — e essas duas funcoes respondem a
                -- perguntas DIFERENTES: a primeira devolve o MAIOR nivel entre
                -- as copias daquela carta, a segunda forja a de MENOR nivel e
                -- devolve o nivel DELA. Com duas copias (uma ja forjada), o
                -- "antes" era 1 e o "depois" era 1, e o detector gritava "ouro
                -- queimado" numa forja que tinha funcionado. Era ALARME FALSO,
                -- e ele apareceu 3x na bateria de 6 corridas.
                --
                -- Isso importa alem do ruido: este harness e o que mede
                -- BALANCO. Tripwire que mente faz anomalia de verdade se
                -- perder no meio do barulho — e a forja e POR COPIA desde
                -- Set/2026 (CLAUDE.md), entao perguntar por ID e o erro de
                -- origem. Resolve-se o INDICE e usam-se as APIs `...At`.
                local idx = forgeIndexFor(game, target)
                local before = idx and game.runManager:getUpgradesAt(idx) or nil
                local lvl = idx and game.runManager:upgradeCardAt(idx) or nil
                if game.runManager.registerPaidForge then
                    game.runManager:registerPaidForge()
                end
                if not idx then
                    anomaly("ouro queimado: nenhuma copia forjavel de %s", target)
                elseif not lvl or lvl <= before then
                    anomaly("ouro queimado: forja de %s (copia %d) nao subiu "
                        .. "de nivel (%s -> %s)", target, idx,
                        tostring(before), tostring(lvl))
                end
                run._usedShop = true
                bought = bought + 1
                log("- Loja: **FORJEI** %s → nivel %s ($%d, score %.1f)",
                    target, tostring(lvl), o.cost, ts)
            end
        end
    end

    -- Cartas por score (melhores primeiro), respeitando a reserva de caixa
    local cardOffers = {}
    for _, o in ipairs(offers) do
        if o.type == "card" then table.insert(cardOffers, o) end
    end
    if v6Build() then
        -- v6: a SIMULACAO decide (mesma pergunta da recompensa: o deck sofre
        -- menos com a carta?). Ate 2 cartas por visita, a melhor primeiro;
        -- so compra o que melhora >= 1 HP-equivalente nas lutas a frente.
        for _ = 1, 2 do
            if bought >= 3 then break end
            local ids, byId = {}, {}
            for _, o in ipairs(cardOffers) do
                if not o._bought and game.economySystem:canAfford(o.cost)
                    and spendable() >= o.cost then
                    ids[#ids + 1] = o.id; byId[o.id] = o
                end
            end
            if #ids == 0 then break end
            local pickId, gain = M.pickBySim(game, ids)
            local o = pickId and byId[pickId]
            if not o or gain < 1.0 then break end
            o._bought = true
            game.economySystem:spendGold(o.cost, o.type, o.id)
            game:addCardToRun(o.id)
            run._usedShop = true
            bought = bought + 1
            log("- Loja: comprei **%s** ($%d, simulacao -%.1f HP)", o.name, o.cost, gain)
            local cd = game.deckManager.cardDatabase:getCard(o.id)
            if cd and cd.type == "joker" then boughtJoker = true end
        end
        cardOffers = {}
    end
    table.sort(cardOffers, function(a, b)
        return scoreCardOffer(a) > scoreCardOffer(b)
    end)
    for _, o in ipairs(cardOffers) do
        if bought >= 3 then break end
        local s = scoreCardOffer(o)
        if s >= 6 and game.economySystem:canAfford(o.cost)
            and spendable() >= o.cost then
            game.economySystem:spendGold(o.cost, o.type, o.id)
            game:addCardToRun(o.id)
            run._usedShop = true
            bought = bought + 1
            log("- Loja: comprei **%s** ($%d, score %.1f)", o.name, o.cost, s)
            local cd = game.deckManager.cardDatabase:getCard(o.id)
            if cd and cd.type == "joker" then boughtJoker = true end
        end
    end

    -- V5.1: increase_max_health como filler barato (sobrou caixa e vitrine)
    for _, o in ipairs(offers) do
        if bought >= 3 then break end
        if o.type == "upgrade" and o.effect == "increase_max_health"
            and REAL_UPGRADES[o.effect]
            and game.economySystem:canAfford(o.cost)
            and spendable() >= o.cost then
            game.economySystem:spendGold(o.cost, o.type, o.id)
            applyUpgradeOffer(game, o)
            run._usedShop = true
            bought = bought + 1
            log("- Loja: comprei upgrade filler **%s** ($%d)", o.name, o.cost)
        end
    end

    -- V5.11: aquisicao de joker → re-otimiza a bancada
    if boughtJoker then
        optimizeJokerBench(game, "compra na loja")
    end

    if bought == 0 then
        log("- Loja: sai sem comprar (ouro $%d, reserva $%d)",
            game.economySystem.currentGold, reserve)
    end
end

-- ============================================================
-- UMA RUN COMPLETA
-- ============================================================

local function playRun(classId, runIdx, maxEndlessFloors, seed)
    local Game = require("src.core.Game")
    -- Run nova num processo que ja jogou outras (bateria): nada da run
    -- anterior — eventos pendentes, FX — pode atravessar pra esta.
    EventManager.clear()
    drainPresentation()
    local game = Game:new()
    game:startNewRun(classId)

    -- SEED FIXA (Set/2026) — sem isto, medir "antes x depois" de uma mudanca
    -- de balanco compara duas amostras DIFERENTES e o ruido engole o efeito.
    -- Duas fontes precisam ser fixadas, nao uma:
    --   • Rng (streams card/shop/map/event/enemy) → ofertas, mapa, eventos;
    --   • love.math → o EMBARALHAMENTO do deck (Game:shuffleDeck), que decide
    --     a mao de cada turno e pesa tanto quanto a oferta.
    -- Fixar so o Rng deixaria metade da run solta.
    if seed then
        local Rng = require("src.systems.Rng")
        Rng.setActive(Rng.new(seed))
        game.runManager.currentRun.runSeed = seed
        love.math.setRandomSeed(seed)
        -- TERCEIRA fonte (Out/2026): o intent do inimigo (Enemy:rollIntent)
        -- sorteia com math.random do Lua. Sem fixar, duas baterias com a
        -- mesma seed lutavam contra inimigos que golpeavam diferente.
        math.randomseed(seed)
    end

    runRec = {
        class = classId, seed = seed, offered = {}, acquired = {},
        floors = 0, won = false,
    }
    M.lastRecord = runRec
    do
        local floorRef = function() return runRec.floors end
        local origCard, origJoker = game.addCardToRun, game.addJokerToRun
        local inCard = false
        game.addCardToRun = function(self, id, meta)
            runRec.acquired[#runRec.acquired + 1] = { id = id, floor = floorRef() }
            inCard = true
            local r1, r2 = origCard(self, id, meta)
            inCard = false
            return r1, r2
        end
        game.addJokerToRun = function(self, id, meta)
            if not inCard then
                runRec.acquired[#runRec.acquired + 1] = { id = id, floor = floorRef() }
            end
            return origJoker(self, id, meta)
        end
    end
    -- LIVRO-CAIXA (Out/2026, auditoria da economia): ouro ganho/gasto POR ATO
    -- e por categoria, mais as visitas a loja. Sem isto o relatorio so tinha
    -- o ouro FINAL — e "a loja e cara?" e pergunta sobre o meio da corrida.
    runRec.eco = { earned = {}, spent = {}, byType = {}, shops = {}, slot = {} }
    do
        local eco, rm = game.economySystem, game.runManager
        local function act()
            return (rm.currentRun and rm.currentRun.actNumber) or 1
        end
        local origEarn, origSpend = eco.earnGold, eco.spendGold
        eco.earnGold = function(self, amount, source)
            local got = origEarn(self, amount, source)
            local a = act()
            runRec.eco.earned[a] = (runRec.eco.earned[a] or 0) + (got or 0)
            return got
        end
        eco.spendGold = function(self, amount, itemType, itemId)
            local ok = origSpend(self, amount, itemType, itemId)
            if ok then
                local a = act()
                runRec.eco.spent[a] = (runRec.eco.spent[a] or 0) + amount
                local k = tostring(itemId and itemType == "upgrade" and itemId or itemType)
                runRec.eco.byType[k] = (runRec.eco.byType[k] or 0) + amount
            end
            return ok
        end
    end

    game:startGame()
    pump(game, 0.5)
    -- v4: picker headless — sem isso os eventos de deck (remover/duplicar/
    -- forjar a escolha) eram NO-OP no piloto (dependem de UI).
    installHeadlessPicker(game)

    battleStats = {
        battles = 0, turns = 0, dmgTaken = 0,
        realDecisionTurns = 0, totalTurns = 0,
        armorCapHits = 0, -- v3: turnos em que o Bloqueio bateu no cap
        byAct = {},   -- [act] = { dealt, taken, turns, battles }
        -- V5.16: tripwires
        focusMaxByAct = {},   -- [act] = foco maximo visto (mago)
        thornReflect = 0, thornTurns = 0,
        multJokersMax = 0, multEffective = 1,
        plays = { n = 0, cards = 0, max = 0, hist = {}, withCombo = 0,
            atk = 0, atkCombo = 0, def = 0, defCombo = 0 },
    }

    log("")
    log("---")
    log("## RUN %d — %s", runIdx, classId:upper())

    local outcome = "?"
    local floors = 0
    local lastAct = 1

    -- primeira batalha (startGame ja criou o inimigo do A1-F1)
    while true do
        floors = floors + 1
        runRec.floors = floors
        local run = game.runManager.currentRun
        local nodeType = (run.currentNode and run.currentNode.type) or "battle"
        local label = ("A%d-F%d [%s]"):format(
            run.actNumber, run.floorInAct, nodeType)

        -- V5.11: inicio de ato → re-otimiza a bancada de coringas
        if (run.actNumber or 1) ~= lastAct then
            lastAct = run.actNumber or 1
            optimizeJokerBench(game, ("inicio do A%d"):format(lastAct))
        end

        local won = playBattle(game, label)
        if not won then
            outcome = ("MORREU em %s (score %d)"):format(label, game.score)
            runRec.death = { act = run.actNumber, floor = run.floorInAct,
                node = nodeType, sprite = game.enemy and game.enemy.spriteId,
                enemyHpLeft = game.enemy and math.max(0, game.enemy.health or 0),
                enemyMaxHp = game.enemy and game.enemy.maxHealth }
            break
        end

        if game:checkVictory() then
            outcome = ("VENCEU O JOGO em %s (score %d)"):format(label, game.score)
            runRec.won = true
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

        -- mapa: gera opcoes e escolhe caminho ate cair numa batalha
        local safety = 0
        repeat
            safety = safety + 1
            if not game.runManager:getPendingNodes() then
                game.runManager:advanceFloorInAct()
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
                -- battle/elite/mini_boss/boss → proxima batalha
                game:nextPhase()
                pump(game, 0.5)
                break
            end
        until safety > 12

        if not game.player:isAlive() then
            outcome = ("MORREU fora de batalha (evento?) score %d"):format(game.score)
            runRec.death = { act = game.runManager.currentRun.actNumber,
                floor = game.runManager.currentRun.floorInAct, node = "event" }
            break
        end
        if safety > 12 then
            outcome = "loop de mapa abortado (bug?)"
            break
        end
    end

    -- metricas da run
    local run = game.runManager.currentRun
    runRec.outcome = outcome
    runRec.act, runRec.floorInAct = run.actNumber, run.floorInAct
    runRec.score = game.score
    runRec.hpEnd, runRec.maxHp = game.player.health, game.player.maxHealth
    runRec.gold = game.economySystem.currentGold
    runRec.battles = battleStats.battles
    runRec.turns = battleStats.turns
    runRec.byAct = battleStats.byAct
    runRec.plays = battleStats.plays
    runRec.deck, runRec.jokers = {}, {}
    for _, e in ipairs(run.currentDeck or {}) do
        runRec.deck[#runRec.deck + 1] = type(e) == "table" and e.id or e
    end
    for i, e in ipairs(run.jokers or {}) do
        runRec.jokers[#runRec.jokers + 1] = {
            id = type(e) == "table" and e.id or e,
            active = game.runManager.isJokerActive and game.runManager:isJokerActive(i) or false,
        }
    end
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

    -- POST-MORTEM: output vs pressao por ato + composicao do deck
    for act, ba in pairs(battleStats.byAct) do
        if ba.turns > 0 then
            log("- A%d: dano/turno %.1f | sofrido/turno %.1f | %.1f turnos/batalha",
                act, ba.dealt / ba.turns, ba.taken / ba.turns,
                ba.turns / math.max(1, ba.battles))
        end
    end

    -- V5.16: TRIPWIRES do rebalance v2 (alimentam a secao Validacao do plano)
    log("- Tripwires v5:")
    log("  - jokers multiplicadores ativos (max simultaneo): %d | efetivo x%.2f (P0.9: max, nunca produto)",
        battleStats.multJokersMax or 0, battleStats.multEffective or 1)
    if classId == "mage" then
        local fm = battleStats.focusMaxByAct or {}
        log("  - foco do mago (max por ato): A1 %d | A2 %d | A3 %d",
            fm[1] or 0, fm[2] or 0, fm[3] or 0)
    end
    if (battleStats.thornTurns or 0) > 0 then
        log("  - thorn refletido/turno (estimado, regra P2.3): %.1f em %d turno(s) — banda alvo 25-38 (Muralha)",
            battleStats.thornReflect / battleStats.thornTurns,
            battleStats.thornTurns)
    end

    do
        local names = {}
        for _, id in ipairs(run.currentDeck or {}) do
            local cardId = type(id) == "table" and id.id or id
            local cd = game.deckManager.cardDatabase:getCard(cardId)
            table.insert(names, (cd and cd.name or tostring(cardId)))
        end
        log("- Deck: %s", table.concat(names, ", "))
    end

    return outcome
end

-- ============================================================
-- ENTRY
-- ============================================================

-- love . autoplay [runs] [classe|all] [seedBase]
-- Com seedBase, a run i da classe C usa seed = seedBase + i (mesma seed por
-- indice em qualquer execucao) — e o unico jeito de um A/B de balanco medir a
-- MUDANCA em vez do sorteio.
function M.run(runsArg, classArg, seedArg)
    local runsPerClass = tonumber(runsArg or "2") or 2
    local classes = { "warrior", "mage", "rogue" }
    if classArg and classArg ~= "all" then classes = { classArg } end
    local seedBase = tonumber(seedArg)

    _G.EventManager = EventManager
    _G.Event = require("engine.Event")  -- CombatSequence usa _G.Event
    local I18n = require("src.i18n.I18n")
    I18n.init()
    installDotMeter()

    -- silencia print interno do jogo? nao — deixa no console, o diario e a parte.

    log("# Diario do Piloto de IA — autoplay v5")
    log("")
    log("Runs por classe: %d | Classes: %s | Seed base: %s", runsPerClass,
        table.concat(classes, ", "), seedBase and tostring(seedBase) or "aleatoria")

    local outcomes = {}
    for _, classId in ipairs(classes) do
        for i = 1, runsPerClass do
            local seed = seedBase and (seedBase + i) or nil
            local ok, res = pcall(playRun, classId, i, 3, seed)
            if ok then
                table.insert(outcomes, classId .. " #" .. i
                    .. (seed and (" (seed " .. seed .. ")") or "") .. ": " .. res)
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
    log("## Veneno/DoT: quanto a armadura do inimigo comeu")
    if dotMeter.ticks > 0 then
        local perdido = dotMeter.declared - dotMeter.effective
        log("- ticks de DoT: %d | declarado %d | efetivo %d | ABSORVIDO %d (%.1f%%)",
            dotMeter.ticks, dotMeter.declared, dotMeter.effective, perdido,
            100 * perdido / math.max(1, dotMeter.declared))
        log("- ticks com absorcao parcial ou total: %d (%.1f%% dos ticks)",
            dotMeter.absorbedTicks,
            100 * dotMeter.absorbedTicks / dotMeter.ticks)
    else
        log("- nenhum tick de DoT nesta bateria")
    end

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

-- ===== Superficie da bateria (tools/balance_sim.lua) =====
-- Roda UMA run e devolve o registro estruturado. pcall por fora fica com quem
-- chama (a bateria conta CRASH como resultado proprio).
function M.playRunRecord(classId, runIdx, seed)
    local outcome = playRun(classId, runIdx, 3, seed)
    local rec = M.lastRecord or {}
    rec.outcome = rec.outcome or outcome
    return rec
end
function M.installHooks() installDotMeter() end
function M.getAnomalies() return anomalies end
function M.getReport() return report end

-- Rejoga UMA batalha a partir do retrato, com a politica atual, vida CHEIA
-- (mede so o combate: HP perdido e turnos). Mesma seed = mesmo embaralhamento
-- e mesmos intents pra qualquer politica.
function M.replayBattle(snap, seed)
    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun(snap.class)
    local run = game.runManager.currentRun
    run.currentDeck = deepcopy(snap.deck)
    run.jokers = deepcopy(snap.jokers) or {}
    run.jokerActive = deepcopy(snap.jokerActive) or {}
    run.services = deepcopy(snap.services) or {}
    run.maxJokerSlots = snap.maxJokerSlots
    run.actNumber, run.floorInAct = snap.act, snap.floorInAct
    run.currentNode = deepcopy(snap.node) or { type = "battle" }
    local Rng = require("src.systems.Rng")
    Rng.setActive(Rng.new(seed))
    love.math.setRandomSeed(seed)
    math.randomseed(seed)
    game:startGame()
    pump(game, 0.3)
    game.player.maxHealth = snap.maxHp
    game.player.baseMaxMana = snap.baseMana
    game.player.maxMana = snap.baseMana
    game:nextPhase()
    pump(game, 0.3)
    game.player.health = snap.maxHp
    M._resetBattleStats()
    local before = game.player.health
    local won, turns = playBattle(game, "bench")
    return { won = won and true or false, hpLost = before - math.max(0, game.player.health),
        turns = turns, maxHp = snap.maxHp,
        enemyLeft = game.enemy and game.enemy.maxHealth
            and math.max(0, game.enemy.health) / math.max(1, game.enemy.maxHealth) or 0 }
end
M.snapshotBattle = snapshotBattle

-- ============================================================
-- v6: DECK BUILDING POR SIMULACAO
-- ============================================================
-- Heuristica de "quanto vale uma carta" erra justamente onde o balanceamento
-- precisa acertar (sinergia, escala, o que falta no deck). A pergunta certa e
-- empirica: COM esta carta, o deck sofre menos nas proximas lutas? Cada opcao
-- (incluindo PULAR) e jogada contra o CHEFE do ato e uma luta comum logo a
-- frente, com as mesmas seeds pra todas as opcoes (numeros aleatorios comuns:
-- a diferenca medida e a carta, nao o sorteio).
--
-- `mutate(snap)` altera o retrato (adiciona/remove carta). Devolve a perda
-- media em HP-equivalente: HP perdido + derrota pesada pelo quanto faltou.
M.SIM_PER_FIGHT = 2
local evalCounter = 0
function M.evalDeckSim(game, mutate)
    local Rng = require("src.systems.Rng")
    local savedRng = Rng.get()
    local savedLove = love.math.getRandomState()
    local savedStats, savedQuiet, savedHook = battleStats, M.quiet, M.onBattleStart
    M.quiet = true
    M.onBattleStart = nil
    local base = snapshotBattle(game)
    local run = game.runManager.currentRun
    local Config = require("src.core.Config")
    local act, floor = run.actNumber or 1, run.floorInAct or 1
    if floor >= 8 and act < (Config.TotalActs or 6) then act, floor = act + 1, 0 end
    local fights = {
        { act = act, floor = 8, node = "boss" },
        { act = act, floor = math.min(7, floor + 2), node = "battle" },
    }
    if mutate then mutate(base) end
    evalCounter = evalCounter + 1
    -- FILAS ISOLADAS: cada replay monta um Game descartavel que deixa eventos
    -- pendentes (materializar carta, fim de dissolve — "after" BLOQUEANTES) na
    -- fila GLOBAL. Sem isolar, milhares deles se acumulavam, serializados, e
    -- ainda rodavam por cima da run real. Cada replay ganha filas novas; as da
    -- run voltam intactas no fim.
    local savedQueues = EventManager.queues

    local total, n = 0, 0
    local realPrint = print
    for fi, f in ipairs(fights) do
        for k = 1, M.SIM_PER_FIGHT do
            local snap = deepcopy(base)
            snap.act, snap.floorInAct, snap.node = f.act, f.floor, { type = f.node }
            EventManager.queues = { base = {}, ui = {} }
            print = function() end
            local ok, r = pcall(M.replayBattle, snap, 9100000 + fi * 101 + k * 7919
                + (run.runSeed or 0) % 100000)
            print = realPrint
            drainPresentation()
            if ok and r then
                local loss = math.min(r.hpLost, r.maxHp)
                if not r.won then loss = loss + 30 + 60 * (r.enemyLeft or 1) end
                total, n = total + loss, n + 1
            end
        end
    end
    -- devolve o mundo da run como estava
    EventManager.queues = savedQueues
    Rng.setActive(savedRng)
    love.math.setRandomState(savedLove)
    math.randomseed((run.runSeed or 1) + evalCounter * 31)
    battleStats, M.quiet, M.onBattleStart = savedStats, savedQuiet, savedHook
    return n > 0 and total / n or 999
end

-- Melhor opcao entre `ids` (cartas candidatas) e PULAR. Devolve (id|nil, ganho)
function M.pickBySim(game, ids)
    local cdb = game.deckManager.cardDatabase
    local baseLoss = M.evalDeckSim(game, nil)
    local best, bestLoss = nil, baseLoss
    for _, id in ipairs(ids) do
        local cd = cdb:getCard(id)
        local loss = M.evalDeckSim(game, function(snap)
            if cd and cd.type == "joker" then
                snap.jokers = snap.jokers or {}
                snap.jokers[#snap.jokers + 1] = id
                snap.jokerActive = snap.jokerActive or {}
                local active = 0
                for i = 1, #snap.jokers - 1 do if snap.jokerActive[i] then active = active + 1 end end
                snap.jokerActive[#snap.jokers] = active < (snap.maxJokerSlots or 3)
            else
                snap.deck[#snap.deck + 1] = id
            end
        end)
        if loss < bestLoss then best, bestLoss = id, loss end
    end
    return best, baseLoss - bestLoss, baseLoss
end

-- ===== Superficie de teste =====
-- `tools/test_autoplay_pilot.lua` conduz UMA batalha pelo cerebro real do
-- piloto. Sem isto a unica forma de testar a politica de turno seria rodar uma
-- corrida inteira — caro demais pra suite e vago demais pra apontar defeito.
-- `battleStats` normalmente e montado por playRun; o teste precisa monta-lo.
M._playBattle = playBattle
function M._resetBattleStats()
    battleStats = {
        battles = 0, turns = 0, dmgTaken = 0,
        realDecisionTurns = 0, totalTurns = 0,
        armorCapHits = 0, byAct = {},
        focusMaxByAct = {}, thornReflect = 0, thornTurns = 0,
        multJokersMax = 0, multEffective = 1,
        plays = { n = 0, cards = 0, max = 0, hist = {}, withCombo = 0,
            atk = 0, atkCombo = 0, def = 0, defCombo = 0 },
    }
end

return M
