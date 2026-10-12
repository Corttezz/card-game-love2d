-- tools/test_damage_preview.lua
-- PREVIA == RESULTADO (Out/2026). A previa de dano (src/systems/DamagePreview)
-- e o que o jogador le antes de jogar; se ela errar, ensina a conta errada —
-- pior que nao ter previa. Este teste joga centenas de levas ALEATORIAS pelo
-- combate de verdade (selectCard -> playSelectedCards -> fila de beats) e
-- confere carta a carta: vida que o inimigo perdeu, Bloqueio dele consumido e
-- Bloqueio que o jogador ganhou batem com a previa.
--
-- Cobre: Forca/Destreza (e scaling em dobro), multi-golpe, combos, coringas
-- (maior multiplicador vence, planos, Eco), edicoes e selos, Fraco/Fragil,
-- Vulneravel (ja ativo e aplicado NO MEIO da leva), armadura do inimigo,
-- orbes (canalizar com fileira cheia, evocar, evocar todos, Foco), inimigo
-- morrendo no meio da leva, Impeto do guerreiro.
--   love . test_one test_damage_preview

local TK = require("tools.testkit")

local M = {}

local TRIALS = 300

function M.run()
    local t = TK.new("previa de dano == combate real")
    TK.bootstrap()
    local DamagePreview = require("src.systems.DamagePreview")
    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()

    -- catalogo jogavel (sem joker; sem `mystery`, que e sorteio por definicao)
    local pool, jokers = {}, {}
    for id, cd in pairs(db:getAllCards()) do
        local mystery = false
        for _, e in ipairs(cd.effects or {}) do
            if e.type == "mystery" then mystery = true end
        end
        if cd.type == "joker" then jokers[#jokers + 1] = id
        elseif not mystery then pool[#pool + 1] = id end
    end
    table.sort(pool); table.sort(jokers)

    local rng = love.math.newRandomGenerator(424242)
    local function pick(list) return list[rng:random(1, #list)] end
    local CLASSES = { "warrior", "mage", "rogue" }
    local EDITIONS = { "foil", "holo", "polychrome" }
    local SEALS = { "Red", "Purple", "Gold", "Blue" }
    local ORBS = { "lightning", "ice", "dark", "fire", "holy" }

    local mismatches, checked, lethal, withCombo = 0, 0, 0, 0
    local absorbedTrials, orbTrials, totalDmg = 0, 0, 0
    for trial = 1, TRIALS do
        TK.seedRng(1000 + trial)
        local g = TK.newRunGame(CLASSES[(trial % 3) + 1])
        TK.pump(g, 0.6)
        local p, e = g.player, g.enemy

        -- estado aleatorio do turno
        p.strength = rng:random(0, 4)
        p.dexterity = rng:random(0, 3)
        p.armor = rng:random(0, 10)
        p.mana, p.maxMana = 99, 99
        p.orbs = {}
        for _ = 1, rng:random(0, 3) do
            p.orbs[#p.orbs + 1] = { type = pick(ORBS), value = rng:random(1, 6) }
        end
        if rng:random() < 0.3 then p:addBuff("focus", 3, rng:random(1, 3)) end
        if rng:random() < 0.15 then p:addDebuff("weak", 2) end
        if rng:random() < 0.15 then p:addDebuff("frail", 2) end
        e.health = rng:random(15, 160)
        e.maxHealth = math.max(e.maxHealth, e.health)
        e.armor = rng:random() < 0.4 and rng:random(1, 15) or 0
        e.maxArmor = math.max(e.maxArmor or 0, e.armor, 999)
        if rng:random() < 0.25 then
            e:addStatusEffect({ name = "vulnerable", stacks = 1, duration = 2 })
        end
        -- coringas ativos
        g.jokerSlots = {}
        for _ = 1, rng:random(0, 3) do
            local inst = db:createCardInstance(db:getCard(pick(jokers)))
            g.jokerSlots[#g.jokerSlots + 1] = inst
        end

        -- a leva (2-6 cartas), com edicao/selo as vezes
        local hand = {}
        for _ = 1, rng:random(2, 6) do
            local c = db:createCardInstance(db:getCard(pick(pool)))
            if rng:random() < 0.12 then c.edition = pick(EDITIONS) end
            if rng:random() < 0.12 then c.seal = pick(SEALS) end
            hand[#hand + 1] = c
        end
        g.hand = {}
        for _, c in ipairs(hand) do g.hand[#g.hand + 1] = c end
        for _, c in ipairs(hand) do g:selectCard(c) end

        local prev = DamagePreview.simulate(g, g.selectedCards)
        local hp0, ea0, pa0 = e.health, e.armor, p.armor
        g:playSelectedCards()
        TK.pump(g, 2.0)
        local guard = 0
        while (g.combatAnimationSystem:isBlocking() or
            require("src.systems.CombatBeats").isBusy()) and guard < 600 do
            TK.pump(g, 0.1); guard = guard + 1
        end

        local hpLoss = hp0 - e.health
        local armorGain = p.armor - pa0
        checked = checked + 1
        if prev.lethal then lethal = lethal + 1 end
        if #prev.combos > 0 then withCombo = withCombo + 1 end
        if prev.blocked > 0 then absorbedTrials = absorbedTrials + 1 end
        for _, x in ipairs(prev.extras) do
            if x.kind == "orb" then orbTrials = orbTrials + 1; break end
        end
        totalDmg = totalDmg + hpLoss
        local enemyArmorUsed = ea0 - e.armor
        if hpLoss ~= prev.damage or armorGain ~= prev.block
            or enemyArmorUsed ~= prev.blocked then
            mismatches = mismatches + 1
            if mismatches <= 8 then
                local names = {}
                for _, c in ipairs(hand) do
                    names[#names + 1] = c.id .. (c.edition and ("/" .. c.edition) or "")
                        .. (c.seal and ("/" .. c.seal) or "")
                end
                print(string.format("  [diverge] trial %d: dano real %d previa %d | bloqueio real %d previa %d | [%s] jokers=%d orbs=%d",
                    trial, hpLoss, prev.damage, armorGain, prev.block,
                    table.concat(names, ", "), #g.jokerSlots, #(p.orbs or {})))
            end
        end
    end
    t:eq("levas conferidas", checked, TRIALS)
    t:eq("previa diverge do combate em 0 levas", mismatches, 0)
    t:truthy("amostra tem levas com combo (" .. withCombo .. ")", withCombo > 20)
    t:truthy("amostra tem levas letais (" .. lethal .. ")", lethal > 5)
    t:truthy("amostra tem Bloqueio do inimigo absorvendo (" .. absorbedTrials .. ")",
        absorbedTrials > 20)
    t:truthy("amostra tem orbe evocado causando dano (" .. orbTrials .. ")", orbTrials > 10)
    t:truthy("amostra causa dano de verdade (" .. totalDmg .. ")", totalDmg > 3000)

    -- ===== cardValue e a conta do combate (passos somam o valor) =====
    local g = TK.newRunGame("warrior"); TK.pump(g, 0.5)
    local c = db:createCardInstance(db:getCard("warrior_strike"))
    local c2 = db:createCardInstance(db:getCard("warrior_strike"))
    g.player.strength = 2
    local ctx = DamagePreview.buildContext({ c, c2 })
    local v, steps = DamagePreview.cardValue(g, c, ctx)
    t:eq("ultimo passo carrega o valor final", steps[#steps].after, v)
    local kinds = {}
    for _, s in ipairs(steps) do kinds[s.kind] = true end
    t:truthy("passo de Forca presente", kinds.stat)
    t:truthy("passo de combo presente (2 golpes)", kinds.combo)

    -- ===== dicas de combo =====
    local added = DamagePreview.combosAddedBy({ c }, c2)
    t:truthy("2o golpe dispara um combo novo", #added >= 1)
    local near = DamagePreview.nearCombos({ c })
    local foundStrike = false
    for _, n in ipairs(near) do if n.need == "strike" then foundStrike = true end end
    t:truthy("1 golpe selecionado: falta 1 'strike' pra combo", foundStrike)

    return t:done()
end

return M
