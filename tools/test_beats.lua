local TK = require("tools.testkit")
local CombatBeats = require("src.systems.CombatBeats")
local EffectSystem = require("src.systems.EffectSystem")

local M = {}

local function at(label)
    return CombatBeats.indexOf(label)
end

local function atPrefix(prefix)
    for i, l in ipairs(CombatBeats.log) do
        if l:sub(1, #prefix) == prefix then return i end
    end
    return nil
end

local function countPrefix(prefix)
    local n = 0
    for _, l in ipairs(CombatBeats.log) do
        if l:sub(1, #prefix) == prefix then n = n + 1 end
    end
    return n
end

local function countExact(label)
    local n = 0
    for _, l in ipairs(CombatBeats.log) do
        if l == label then n = n + 1 end
    end
    return n
end

local function thornCard(value)
    return {
        id = "tk_thorn", name = "Teste Espinhos", type = "defense",
        cost = 1, attack = 0, defense = 5,
        effects = { { type = "on_defend_damage", value = value } },
    }
end

function M.run()
    local t = TK.new("ritmo do combate: beats, ordem causal e espinhos")
    TK.bootstrap()

    CombatBeats.clear()
    CombatBeats.startTrace()
    local ran = {}
    CombatBeats.push("a", function() ran[#ran + 1] = "a" end, 0.5)
    CombatBeats.push("b", function() ran[#ran + 1] = "b" end, 0.5)
    CombatBeats.push("c", function() ran[#ran + 1] = "c" end, 0.5)
    TK.pump(nil, 0.2)
    t:eq("um beat por vez: so o 1o rodou em 0.2s", #ran, 1)
    TK.pump(nil, 0.5)
    t:eq("o 2o so roda depois do hold do 1o", #ran, 2)
    TK.pump(nil, 1.2)
    t:eq("a fila drena inteira", #ran, 3)
    t:eq("ordem preservada", table.concat(ran, ","), "a,b,c")
    t:eq("fila vazia no fim", CombatBeats.pending(), 0)

    ran = {}
    CombatBeats.push("outer", function()
        ran[#ran + 1] = "outer"
        CombatBeats.push("inner", function() ran[#ran + 1] = "inner" end, 0.1)
    end, 0.1)
    CombatBeats.push("after", function() ran[#ran + 1] = "after" end, 0.1)
    TK.pump(nil, 1.0)
    t:eq("push de dentro de um beat vai pro FIM da fila (regra da cadeia)",
        table.concat(ran, ","), "outer,after,inner")
    CombatBeats.stopTrace()

    local g = TK.newRunGame("warrior")
    TK.pump(g, 0.5)
    local hpEnemy = g.enemy.health
    g:processCardInCombat(thornCard(7), nil)
    t:eq("espinhos NAO ferem ao jogar a carta", g.enemy.health, hpEnemy)
    t:eq("a carta armou 7 de espinhos", g.player:getBuffStacks("thorn"), 7)
    t:eq("bloqueio da carta entrou normalmente", g.player.armor, 5)

    g.enemy.nextIntent = "attack"
    g.enemy.damage = 6; g.enemy.baseDamage = 6; g.enemy.nextIntentDamage = 6
    g.battleTurn = 1
    g.turn = "enemy"
    g:enemyTurn()
    TK.pump(g, 3.5)
    t:eq("o golpe do inimigo cobra os espinhos (-7)", g.enemy.health, hpEnemy - 7)
    t:eq("espinhos expiram no upkeep do jogador seguinte",
        g.player:getBuffStacks("thorn"), 0)
    t:eq("a vez voltou pro jogador", g.turn, "player")

    local g2 = TK.newRunGame("warrior")
    TK.pump(g2, 0.5)
    local hp2 = g2.enemy.health
    g2:processCardInCombat(thornCard(7), nil)
    g2.enemy.nextIntent = "defend"
    g2.battleTurn = 1
    g2.turn = "enemy"
    g2:enemyTurn()
    TK.pump(g2, 3.5)
    t:eq("inimigo que DEFENDE nao leva reflexo", g2.enemy.health, hp2)

    local gj = TK.newRunGame("warrior")
    TK.pump(gj, 0.5)

    local bulwark = {
        id = "warrior_eternal_bulwark", name = "Baluarte Eterno",
        type = "joker",
        effects = { { type = "on_defend_damage", value = 8 } },
    }
    gj.jokerSlots = { bulwark }

    local procs = {}
    gj.effectSystem.notifyJokerProc = function(_, _, joker, label, kind)
        procs[#procs + 1] = { id = joker and joker.id, label = label, kind = kind }
    end

    local hpj = gj.enemy.health
    gj:processCardInCombat(
        { id = "tk_def", name = "Defesa", type = "defense",
          cost = 1, attack = 0, defense = 5, effects = {} }, nil)
    t:eq("o coringa armou os 8 espinhos", gj.player:getBuffStacks("thorn"), 8)

    gj:processCardInCombat(
        { id = "tk_def2", name = "Defesa 2", type = "defense",
          cost = 1, attack = 0, defense = 5, effects = {} }, nil)
    t:eq("segunda defesa NAO rearma (teto 1x/turno do P2.3)",
        gj.player:getBuffStacks("thorn"), 8)

    gj.jokerSlots = { {
        id = "warrior_eternal_bulwark", name = "Baluarte Eterno",
        type = "joker",
        effects = { { type = "on_defend_damage", value = 8 } },
    } }
    gj:processCardInCombat(
        { id = "tk_def3", name = "Defesa 3", type = "defense",
          cost = 1, attack = 0, defense = 5, effects = {} }, nil)
    t:eq("nem depois de recriar a instancia do coringa (chave e o ID)",
        gj.player:getBuffStacks("thorn"), 8)

    local procsAntes = #procs
    gj.enemy.nextIntent = "attack"
    gj.enemy.damage = 6; gj.enemy.baseDamage = 6; gj.enemy.nextIntentDamage = 6
    gj.battleTurn = 1
    gj.turn = "enemy"
    gj:enemyTurn()
    TK.pump(gj, 3.5)

    t:eq("o reflexo cobrou os 8 no inimigo", gj.enemy.health, hpj - 8)

    local falouNoReflexo
    for i = procsAntes + 1, #procs do
        if procs[i].id == "warrior_eternal_bulwark" then falouNoReflexo = procs[i] end
    end
    t:truthy("o Baluarte Eterno PROCA quando os espinhos saem (era mudo)",
        falouNoReflexo ~= nil)
    t:eq("e o proc mostra o dano refletido",
        falouNoReflexo and falouNoReflexo.label, "-8")

    local gk = TK.newRunGame("warrior")
    TK.pump(gk, 0.5)
    gk.jokerSlots = { {
        id = "warrior_juggernaut", name = "Juggernaut", type = "joker",
        effects = { { type = "on_defend_damage", value = 6 } },
    } }
    local procsK = {}
    gk.effectSystem.notifyJokerProc = function(_, _, joker, label)
        procsK[#procsK + 1] = { id = joker and joker.id, label = label }
    end
    gk:processCardInCombat(
        { id = "tk_def", name = "Defesa", type = "defense",
          cost = 1, attack = 0, defense = 5, effects = {} }, nil)
    local nK = #procsK
    gk.enemy.nextIntent = "defend"
    gk.battleTurn = 1
    gk.turn = "enemy"
    gk:enemyTurn()
    TK.pump(gk, 3.5)
    t:eq("inimigo que DEFENDE nao faz o coringa falar (nada refletiu)",
        #procsK, nK)

    do
        local gp = TK.newRunGame("mage")
        TK.pump(gp, 0.5)

        gp.turn = "enemy"
        gp.enemy.health = 0
        t:truthy("cenario montado: fase limpa com a vez do inimigo",
            gp:isPhaseCleared() and gp.turn == "enemy")

        gp:nextPhase()
        TK.pump(gp, 0.5)

        t:eq("andar novo comeca na vez do JOGADOR", gp.turn, "player")
        t:truthy("e o inimigo do andar novo esta vivo (senao o teste nao prova nada)",
            gp.enemy and gp.enemy:isAlive())

        local portaoAbriria = (gp.turn == "enemy") and gp.enemy:isAlive()
        t:falsy("o portao do turno do inimigo NAO abre no primeiro frame do andar",
            portaoAbriria)
    end

    local g3 = TK.newRunGame("warrior")
    TK.pump(g3, 0.5)
    g3:processCardInCombat(thornCard(4), nil)
    g3.enemy:addStatusEffect({ name = "poison", stacks = 3, duration = 3 })
    g3.enemy.nextIntent = "attack"
    g3.enemy.damage = 4; g3.enemy.baseDamage = 4; g3.enemy.nextIntentDamage = 4
    g3.battleTurn = 1
    g3.turn = "enemy"

    CombatBeats.clear()
    CombatBeats.startTrace()
    g3:enemyTurn()

    TK.pump(g3, 0.2)
    local early = #CombatBeats.log
    t:truthy("turno do inimigo NAO resolve tudo em 0.2s (bloqueia mesmo)",
        early > 0 and early <= 2)
    t:truthy("isBlocking() segura o jogo enquanto ha beats pendentes",
        g3.combatAnimationSystem:isBlocking())

    TK.pump(g3, 4.0)
    CombatBeats.stopTrace()
    local order = {
        "enemy.telegraph", "enemy.attack", "player.thorn_reflect",
        "enemy.dot", "enemy.next_intent", "player.upkeep",
        "player.draw", "turn.player_ready",
    }
    local prev, okOrder = 0, true
    for _, label in ipairs(order) do
        local idx = at(label)
        if not idx then
            t:truthy("beat presente no turno: " .. label, false)
            okOrder = false
        elseif idx <= prev then
            okOrder = false
        else
            prev = idx
        end
    end
    t:truthy("ordem causal do turno do inimigo (" .. CombatBeats.traceString() .. ")",
        okOrder)
    t:truthy("nenhum beat do turno se repetiu (re-entrancia bloqueada)",
        countExact("enemy.telegraph") == 1 and countExact("enemy.attack") == 1)

    local gm = TK.newRunGame("mage")
    TK.pump(gm, 0.5)
    gm.player.orbs = {}
    gm.player:addOrb({ type = "lightning", value = 4 })
    gm.player:addOrb({ type = "ice", value = 4 })
    gm.player:addOrb({ type = "lightning", value = 4 })
    local enemyHpM = gm.enemy.health

    CombatBeats.clear()
    CombatBeats.startTrace()
    gm:endTurn()
    TK.pump(gm, 0.15)
    t:eq("pulso dos orbes: so o primeiro saiu em 0.15s", countPrefix("orb.pulse."), 1)
    TK.pump(gm, 2.0)
    CombatBeats.stopTrace()
    t:eq("um beat de pulso POR ORBE (3 orbes = 3 beats)",
        countPrefix("orb.pulse."), 3)
    local focusM = gm.player:getBuffStacks("focus") or 0
    local expectedPulse = 0
    for _, o in ipairs({ { type = "lightning", value = 4 }, { type = "lightning", value = 4 } }) do
        expectedPulse = expectedPulse + EffectSystem.orbPulseValue(o, focusM)
    end
    t:eq("os pulsos aplicaram o dano de cada orbe",
        gm.enemy.health, enemyHpM - expectedPulse)
    t:truthy("o pulso de gelo virou bloqueio", gm.player.armor >= 2)

    local gm2 = TK.newRunGame("mage")
    TK.pump(gm2, 0.5)
    gm2.player.orbs = {}
    gm2.player:addOrb({ type = "lightning", value = 3 })
    gm2.player:addOrb({ type = "lightning", value = 3 })
    CombatBeats.clear()
    CombatBeats.startTrace()
    local steps = {}
    gm2._beatSink = steps
    gm2.effectSystem:processEffectCard(gm2, { type = "evoke_all_orbs" })
    gm2._beatSink = nil
    CombatBeats.pushAll(steps)
    TK.pump(gm2, 2.0)
    CombatBeats.stopTrace()
    t:eq("evoke_all_orbs: um beat de evoke por orbe", countExact("orb.evoke"), 2)
    t:eq("evoke_all_orbs esvaziou os orbes", #gm2.player.orbs, 0)

    local gmc = TK.newRunGame("mage")
    TK.pump(gmc, 0.5)
    gmc.player.orbs = {}
    local meteor = {
        id = "tk_meteor", name = "Teste Chuva de Meteoros", type = "attack",
        cost = 0, attack = 6, defense = 0,
        effects = {
            { type = "channel_orb", orbType = "fire", value = 4 },
            { type = "channel_orb", orbType = "fire", value = 4 },
            { type = "channel_orb", orbType = "fire", value = 4 },
        },
    }
    table.insert(gmc.hand, meteor)
    gmc.player.mana = 3
    gmc:selectCard(meteor)

    local enemyHpC = gmc.enemy.health
    CombatBeats.clear()
    CombatBeats.startTrace()
    gmc:playSelectedCards()

    local sawCount, orbsAtImpact, dmgLanded = {}, nil, false
    for _ = 1, 160 do
        TK.pump(gmc, 0.05)
        local n = #gmc.player.orbs
        sawCount[n] = true
        if not dmgLanded and gmc.enemy.health < enemyHpC then
            dmgLanded = true
            orbsAtImpact = n
        end
    end
    CombatBeats.stopTrace()

    t:truthy("o dano da carta aconteceu", dmgLanded)
    t:eq("nenhum orbe nasceu no instante do DANO (dano e canalizacao sao"
        .. " acontecimentos separados)", orbsAtImpact, 0)
    t:eq("um beat de canalizacao POR ORBE (3 orbes = 3 beats)",
        countExact("orb.channel"), 3)
    t:truthy("a fileira passou por 1 orbe (os 3 nao aparecem de uma vez)",
        sawCount[1] == true)
    t:truthy("a fileira passou por 2 orbes", sawCount[2] == true)
    t:eq("os 3 orbes acabaram canalizados", #gmc.player.orbs, 3)
    t:truthy("cada canalizacao veio DEPOIS do impacto da carta ("
        .. CombatBeats.traceString() .. ")",
        atPrefix("card.impact.") and at("orb.channel")
        and at("orb.channel") > atPrefix("card.impact."))
    t:truthy("a carta so queima depois de canalizar tudo",
        at("card.dissolve") and at("orb.channel")
        and at("card.dissolve") > at("orb.channel"))

    local gof = TK.newRunGame("mage")
    TK.pump(gof, 0.5)
    gof.player.orbs = {}
    gof.player:addOrb({ type = "lightning", value = 3 })
    gof.player:addOrb({ type = "lightning", value = 3 })
    gof.player:addOrb({ type = "lightning", value = 3 })
    t:eq("fileira cheia (3 de 3)", #gof.player.orbs, gof.player.orbSlots)
    local hpOf = gof.enemy.health

    local steps = {}
    gof._beatSink = steps
    gof.effectSystem:processEffectCard(gof, { type = "channel_orb", orbType = "ice", value = 5 })
    gof._beatSink = nil
    t:eq("a fileira NAO muda na coleta, so quando o beat toca",
        gof.player.orbs[3].type, "lightning")
    t:eq("o inimigo NAO leva o dano do overflow na coleta", gof.enemy.health, hpOf)

    CombatBeats.clear()
    CombatBeats.startTrace()
    CombatBeats.pushAll(steps)
    TK.pump(gof, 2.5)
    CombatBeats.stopTrace()

    t:eq("expulsar o orbe mais antigo e UM acontecimento",
        countExact("orb.overflow"), 1)
    t:truthy("o orbe SAI antes do novo entrar (" .. CombatBeats.traceString() .. ")",
        at("orb.overflow") and at("orb.channel")
        and at("orb.overflow") < at("orb.channel"))
    t:eq("o orbe novo entrou no fim da fila", gof.player.orbs[3].type, "ice")
    t:eq("a fileira continua no cap", #gof.player.orbs, 3)
    t:truthy("o orbe expulso EVOCOU de verdade (o dano dele saiu)",
        gof.enemy.health < hpOf)

    local gro = TK.newRunGame("mage")
    TK.pump(gro, 0.5)
    gro.player.orbs = {}
    local steps2 = {}
    gro._beatSink = steps2
    gro.effectSystem:processEffectCard(gro, { type = "channel_orb", orbType = "ice", value = 5 })
    gro._beatSink = nil
    CombatBeats.clear()
    CombatBeats.startTrace()
    CombatBeats.pushAll(steps2)
    TK.pump(gro, 2.0)
    CombatBeats.stopTrace()
    t:eq("com vaga livre nao ha expulsao nenhuma", countExact("orb.overflow"), 0)
    t:eq("mesmo assim o orbe foi canalizado", #gro.player.orbs, 1)

    local gev = TK.newRunGame("mage")
    TK.pump(gev, 0.5)
    gev.player.orbs = {}
    gev.player:addOrb({ type = "lightning", value = 3 })
    gev.player:addOrb({ type = "ice", value = 3 })
    local steps3 = {}
    gev._beatSink = steps3
    gev.effectSystem:processEffectCard(gev, { type = "evoke_orb" })
    gev._beatSink = nil
    t:eq("o orbe NAO sai da fileira na coleta", #gev.player.orbs, 2)
    CombatBeats.pushAll(steps3)
    TK.pump(gev, 1.5)
    t:eq("o orbe sai quando o beat de evoke toca", #gev.player.orbs, 1)
    t:eq("saiu o MAIS ANTIGO (FIFO)", gev.player.orbs[1].type, "ice")

    do
        local Sfx = require("src.systems.Sfx")
        local CardFeel = require("src.systems.CardFeel")
        local OrbRow = require("src.ui.OrbRow")
        local realPlay      = Sfx.play
        local realAtEnemy   = CardFeel.burstAtEnemy
        local realAtPlayer  = CardFeel.burstAtPlayer
        local realAtSlot    = OrbRow.burstAtSlot

        local log
        local function resetLog() log = { sfx = {}, enemy = {}, player = {}, slot = {} } end
        resetLog()
        Sfx.play = function(name) log.sfx[#log.sfx + 1] = name end
        CardFeel.burstAtEnemy  = function(theme) log.enemy[#log.enemy + 1] = theme end
        CardFeel.burstAtPlayer = function(theme) log.player[#log.player + 1] = theme end
        OrbRow.burstAtSlot     = function(_, theme) log.slot[#log.slot + 1] = theme end

        local function pulseOf(orbType, value)
            local g = TK.newRunGame("mage")
            TK.pump(g, 0.5)
            g.player.orbs = { { type = orbType, value = value or 4 } }
            g.player.armor = 0
            g.player.health = math.max(1, g.player.maxHealth - 20)
            local before = {
                enemyHp = g.enemy.health,
                armor   = g.player.armor,
                hp      = g.player.health,
                orbVal  = g.player.orbs[1].value,
            }
            resetLog()
            local steps = {}
            g.effectSystem:orbPassiveTick(g, steps)
            CombatBeats.pushAll(steps)
            TK.pump(g, 1.5)
            return g, before
        end

        local sounds = {}

        local g, b = pulseOf("lightning", 4)
        t:truthy("pulso de RAIO fere o inimigo", g.enemy.health < b.enemyHp)
        t:eq("raio estoura NO INIMIGO", #log.enemy, 1)
        t:eq("raio usa a paleta de raio", log.enemy[1], "lightning")
        t:eq("raio nao estoura no painel do jogador", #log.player, 0)
        t:eq("raio toca UM som", #log.sfx, 1)
        sounds.lightning = log.sfx[1]

        g, b = pulseOf("fire", 6)
        t:truthy("pulso de FOGO fere o inimigo", g.enemy.health < b.enemyHp)
        t:eq("fogo estoura NO INIMIGO", #log.enemy, 1)
        t:eq("fogo usa a paleta de fogo", log.enemy[1], "fire")
        sounds.fire = log.sfx[1]

        g, b = pulseOf("ice", 4)
        t:truthy("pulso de GELO da Bloqueio", g.player.armor > b.armor)
        t:eq("o inimigo NAO leva dano do pulso de gelo", g.enemy.health, b.enemyHp)
        t:eq("gelo NAO estoura no inimigo (defender nao fere)", #log.enemy, 0)
        t:eq("gelo estoura no painel do jogador", #log.player, 1)
        t:eq("gelo usa a paleta de gelo", log.player[1], "ice")
        sounds.ice = log.sfx[1]

        g, b = pulseOf("holy", 6)
        t:truthy("pulso SAGRADO cura o heroi", g.player.health > b.hp)
        t:eq("o inimigo NAO leva dano do pulso sagrado", g.enemy.health, b.enemyHp)
        t:eq("sagrado NAO estoura no inimigo (curar nao fere)", #log.enemy, 0)
        t:eq("sagrado estoura no painel do jogador", #log.player, 1)
        t:eq("sagrado usa a paleta sagrada", log.player[1], "holy")
        sounds.holy = log.sfx[1]

        g, b = pulseOf("dark", 5)
        t:eq("pulso de SOMBRA engorda o proprio orbe",
            g.player.orbs[1].value, b.orbVal + 2)
        t:eq("o inimigo NAO leva dano do pulso de sombra", g.enemy.health, b.enemyHp)
        t:eq("sombra NAO estoura no inimigo", #log.enemy, 0)
        t:eq("sombra NAO estoura no painel do jogador", #log.player, 0)
        t:eq("sombra estoura NO PROPRIO ORBE", #log.slot, 1)
        t:eq("sombra usa a paleta de sombra", log.slot[1], "dark")
        sounds.dark = log.sfx[1]

        local uniq, names = {}, {}
        for k, v in pairs(sounds) do
            names[#names + 1] = k .. "=" .. tostring(v)
            uniq[tostring(v)] = true
        end
        local nUniq = 0
        for _ in pairs(uniq) do nUniq = nUniq + 1 end
        table.sort(names)
        t:eq("os 5 elementos soam DIFERENTE (" .. table.concat(names, " ") .. ")",
            nUniq, 5)

        Sfx.play = realPlay
        CardFeel.burstAtEnemy = realAtEnemy
        CardFeel.burstAtPlayer = realAtPlayer
        OrbRow.burstAtSlot = realAtSlot
    end

    do
        local OrbRow = require("src.ui.OrbRow")
        local TYPES = { "lightning", "ice", "fire", "dark", "holy" }

        local byPath, byPixels = {}, {}
        for _, ty in ipairs(TYPES) do
            local path = OrbRow.ART[ty]
            t:truthy("orbe " .. ty .. " tem arte propria declarada",
                type(path) == "string" and path ~= "")
            t:falsy("a arte de " .. ty .. " nao repete o arquivo de "
                .. tostring(byPath[path]), byPath[path] ~= nil)
            byPath[path] = ty

            local info = path and love.filesystem.getInfo(path)
            t:truthy("o arquivo de " .. ty .. " existe no disco (" .. tostring(path) .. ")",
                info ~= nil)

            if info then
                local ok, data = pcall(love.image.newImageData, path)
                if ok and data then
                    t:eq("a gema de " .. ty .. " e 48x48 nativa (largura)",
                        data:getWidth(), 48)
                    t:eq("a gema de " .. ty .. " e 48x48 nativa (altura)",
                        data:getHeight(), 48)
                    local sig = 0
                    for py = 0, 47, 4 do
                        for px = 0, 47, 4 do
                            local r, g, b, a = data:getPixel(px, py)
                            sig = sig + (r * 7 + g * 13 + b * 17) * a * (px + py + 1)
                        end
                    end
                    sig = math.floor(sig * 1000)
                    t:falsy("a gema de " .. ty .. " nao e um clone da de "
                        .. tostring(byPixels[sig]), byPixels[sig] ~= nil)
                    byPixels[sig] = ty
                end
            end
        end

        local function observedPulseUnit(orbType)
            local g = TK.newRunGame("mage")
            TK.pump(g, 0.5)
            g.player.orbs = { { type = orbType, value = 6 } }
            g.player.armor = 0
            g.player.health = math.max(1, g.player.maxHealth - 20)
            local b = { hp = g.enemy.health, armor = g.player.armor,
                        php = g.player.health, val = 6 }
            local steps = {}
            g.effectSystem:orbPassiveTick(g, steps)
            CombatBeats.pushAll(steps)
            TK.pump(g, 1.5)
            if g.enemy.health < b.hp then return "damage" end
            if g.player.armor > b.armor then return "block" end
            if g.player.health > b.php then return "heal" end
            if ((g.player.orbs[1] or {}).value or 0) > b.val then return "grow" end
            return "nada"
        end

        local function observedEvokeUnit(orbType)
            local g = TK.newRunGame("mage")
            TK.pump(g, 0.5)
            g.player.orbs = {}
            g.player.armor = 0
            g.player.health = math.max(1, g.player.maxHealth - 20)
            local b = { hp = g.enemy.health, armor = g.player.armor,
                        php = g.player.health }
            g.effectSystem:_evokeOrbEffect(g, { type = orbType, value = 6 })
            if g.enemy.health < b.hp then return "damage" end
            if g.player.armor > b.armor then return "block" end
            if g.player.health > b.php then return "heal" end
            return "nada"
        end

        for _, ty in ipairs(TYPES) do
            t:eq("o glifo do PULSO de " .. ty .. " diz o que o pulso faz",
                OrbRow.UNIT_OF.pulse[ty], observedPulseUnit(ty))
            t:eq("o glifo do EVOKE de " .. ty .. " diz o que o evoke faz",
                OrbRow.UNIT_OF.evoke[ty], observedEvokeUnit(ty))
        end

        local EffectSystem2 = require("src.systems.EffectSystem")
        local darkOrb = { type = "dark", value = 7 }
        t:eq("sombra nao pulsa (valor de pulso e zero)",
            EffectSystem2.orbPulseValue(darkOrb, 0), 0)
        local vDark, uDark = OrbRow.readout(darkOrb, 0, "pulse")
        t:eq("mas a fileira mostra o valor ACUMULADO, nao o zero", vDark, 7)
        t:eq("e o glifo dela diz CRESCE, nao dano", uDark, "grow")
        local vEv, uEv = OrbRow.readout(darkOrb, 0, "evoke")
        t:eq("no preview de evoke o numero vira o dobro", vEv, 14)
        t:eq("e o glifo vira DANO (e o que evocar sombra faz)", uEv, "damage")

        local vFocus = OrbRow.readout({ type = "lightning", value = 4 }, 2, "pulse")
        t:eq("o numero exibido ja inclui o Foco",
            vFocus, EffectSystem2.orbPulseValue({ type = "lightning", value = 4 }, 2))
    end

    do
        local gf = TK.newRunGame("mage")
        TK.pump(gf, 0.5)
        gf.player.orbs = {}
        gf.effectSystem:processEffectCard(gf,
            { type = "channel_orb", orbType = "fire", value = 6 })
        gf.effectSystem:processEffectCard(gf, { type = "evoke_orb" })

        t:truthy("evocar fogo deixa QUEIMADURA no inimigo",
            gf.enemy:hasStatus("burn"))
        t:falsy("e NAO deixa veneno (o mago nao tem carta de veneno no deck)",
            gf.enemy:hasStatus("poison"))

        local hpBefore = gf.enemy.health
        gf.enemy.armor = 0
        gf.enemy.nextIntent = "buff"
        gf.battleTurn = 1
        gf.turn = "enemy"
        CombatBeats.clear()
        CombatBeats.startTrace()
        gf:enemyTurn()
        TK.pump(gf, 4.0)
        CombatBeats.stopTrace()

        t:truthy("o beat do DoT aconteceu (" .. CombatBeats.traceString() .. ")",
            at("enemy.dot") ~= nil)
        t:truthy("a queimadura DOEU no turno do inimigo",
            gf.enemy.health < hpBefore)
    end

    do
        local gk = TK.newRunGame("mage")
        TK.pump(gk, 0.5)
        gk.enemy.armor = 0
        gk.enemy.health = 3
        gk.enemy:addStatusEffect({ name = "burn", duration = 2, stacks = 9 })
        gk.enemy.nextIntent = "buff"
        gk.battleTurn = 1
        gk.turn = "enemy"
        CombatBeats.clear()
        CombatBeats.startTrace()
        gk:enemyTurn()
        TK.pump(gk, 5.0)
        CombatBeats.stopTrace()

        t:eq("a queimadura derrubou o inimigo", gk.enemy.health, 0)
        t:truthy("morrer QUEIMADO encena a morte ("
            .. CombatBeats.traceString() .. ")", at("enemy.death") ~= nil)
        t:truthy("e ela acontece NO tick que matou, nao depois",
            at("enemy.dot") and at("enemy.death")
            and at("enemy.death") >= at("enemy.dot"))
    end

    do
        local CardDatabase = require("src.systems.CardDatabase")
        local all = CardDatabase.getAllCards and CardDatabase:getAllCards() or {}
        local multi, mixed, total = {}, {}, 0
        for id, cd in pairs(all) do
            total = total + 1
            local ch, dmg = 0, false
            for _, e in ipairs(cd.effects or {}) do
                if e.type == "channel_orb" then ch = ch + 1 end
                if e.type == "magic_damage" or e.type == "aoe_magic_damage" then dmg = true end
            end
            if (cd.attack or 0) > 0 then dmg = true end
            if ch >= 2 then multi[#multi + 1] = id end
            if ch >= 1 and dmg then mixed[#mixed + 1] = id end
        end
        table.sort(multi); table.sort(mixed)
        print("[beats] catalogo lido: " .. total .. " cartas")
        print("[beats] canalizam 2+ orbes: " .. table.concat(multi, ", "))
        print("[beats] misturam dano + canalizacao: " .. table.concat(mixed, ", "))
        t:truthy("o catalogo foi mesmo lido (" .. total .. " cartas)", total > 50)
        t:truthy("o catalogo TEM cartas que canalizam em rajada (" .. #multi .. ")",
            #multi >= 3)
        t:truthy("o catalogo TEM cartas que misturam dano e canalizacao ("
            .. #mixed .. ")", #mixed >= 8)
    end

    local gj = TK.newRunGame("warrior")
    TK.pump(gj, 0.5)
    gj:addJokerToRun("warrior_dark_embrace")
    local jk = gj.jokerSlots[#gj.jokerSlots]
    t:truthy("Abraco Sombrio ativo no slot", jk ~= nil)
    local procs = {}
    local healed = gj.effectSystem:applyHealMultiplier(gj, 10, procs)
    t:eq("heal_multiplier 1.5 aplicou o valor", healed, 15)
    t:eq("heal_multiplier EMPURRA proc (coringa deixa de ser mudo)", #procs, 1)
    t:truthy("o proc aponta o slot do coringa certo",
        procs[1] and procs[1].joker == jk)

    do
        local gAll = TK.newRunGame("warrior")
        TK.pump(gAll, 0.5)
        gAll.jokerSlots = {
            { effects = { { type = "damage_multiplier", target = "attack", value = 2 } } },
            { effects = { { type = "damage_bonus", value = 3 } } },
        }
        local _, p1 = gAll.effectSystem:applyJokerEffects(gAll, { type = "attack" }, 10)
        t:eq("damage_multiplier + damage_bonus ticam (2 procs)", #p1, 2)
        gAll.jokerSlots = {
            { effects = { { type = "defense_multiplier", target = "defense", value = 1.5 } } },
            { effects = { { type = "defense_bonus", value = 2 } } },
        }
        local _, p2 = gAll.effectSystem:applyJokerEffects(gAll, { type = "defense" }, 10)
        t:eq("defense_multiplier + defense_bonus ticam (2 procs)", #p2, 2)
    end

    local gc = TK.newRunGame("rogue")
    TK.pump(gc, 0.5)
    local atk = {
        id = "tk_atk", name = "Teste Golpe", type = "attack",
        cost = 0, attack = 6, defense = 0,
        effects = { { type = "apply_debuff", value = "poison", stacks = 2, duration = 2 } },
    }
    table.insert(gc.hand, atk)
    gc.player.mana = 3
    gc:selectCard(atk)
    CombatBeats.clear()
    CombatBeats.startTrace()
    gc:playSelectedCards()
    TK.pump(gc, 6.0)
    CombatBeats.stopTrace()
    local iImpact = atPrefix("card.impact.")
    local iEffect = at("effect.apply_debuff")
    local iDissolve = at("card.dissolve")
    t:truthy("carta impactou (" .. CombatBeats.traceString() .. ")", iImpact ~= nil)
    t:truthy("o debuff no inimigo tem beat proprio", iEffect ~= nil)
    t:truthy("debuff DEPOIS do impacto", iImpact and iEffect and iEffect > iImpact)
    t:truthy("dissolve DEPOIS do efeito da carta",
        iDissolve and iEffect and iDissolve > iEffect)
    t:truthy("o veneno chegou no inimigo", gc.enemy:hasStatus("poison"))

    local ge = TK.newRunGame("warrior")
    TK.pump(ge, 0.5)
    ge.enemy.health = 10
    ge.enemy.damage = 6; ge.enemy.baseDamage = 6
    ge.enemy:rollIntent()
    local intentBefore = ge.enemy.nextIntentDamage
    t:falsy("antes de ferir: nao esta enfurecido", ge.enemy:hasStatus("enraged"))

    local bigHit = {
        id = "tk_big", name = "Teste Pancada", type = "attack",
        cost = 0, attack = 8, defense = 0, effects = {},
    }
    table.insert(ge.hand, bigHit)
    ge.player.mana = 3
    ge:selectCard(bigHit)
    CombatBeats.clear()
    CombatBeats.startTrace()
    ge:playSelectedCards()
    TK.pump(ge, 6.0)
    CombatBeats.stopTrace()

    t:truthy("inimigo ferido vira status REAL `enraged` (pill no HUD)",
        ge.enemy:hasStatus("enraged"))
    local iImpactE = atPrefix("card.impact.")
    local iRage = at("enemy.enraged")
    t:truthy("o enfurecimento tem BEAT proprio (" .. CombatBeats.traceString() .. ")",
        iRage ~= nil)
    t:truthy("o enfurecimento vem DEPOIS do golpe que o causou",
        iImpactE and iRage and iRage > iImpactE)
    t:eq("o dano dele subiu 50%", ge.enemy.damage, math.floor(6 * 1.5))
    t:eq("o intent ja telegrafado NAO fica mais forte",
        ge.enemy.nextIntentDamage, intentBefore)

    CombatBeats.clear()
    CombatBeats.startTrace()
    ge.enemy:takeDamage(1)
    ge:announceEnrageIfPending(nil)
    TK.pump(ge, 1.0)
    CombatBeats.stopTrace()
    t:eq("enfurecer e evento de VIRADA, nao se repete a cada dano",
        countExact("enemy.enraged"), 0)

    local ge2 = TK.newRunGame("warrior")
    TK.pump(ge2, 0.5)
    ge2.enemy.health = 4
    ge2.enemy:takeDamage(0)
    t:truthy("dano de qualquer fonte marca o enfurecimento pendente",
        ge2.enemy._pendingEnrage == true)
    ge2.enemy.nextIntent = "defend"
    ge2.battleTurn = 1
    ge2.turn = "enemy"
    CombatBeats.clear()
    CombatBeats.startTrace()
    ge2:enemyTurn()
    TK.pump(ge2, 4.0)
    CombatBeats.stopTrace()
    t:eq("checkpoint do turno anuncia o enfurecimento pendente",
        countExact("enemy.enraged"), 1)
    t:truthy("o checkpoint vem ANTES do inimigo agir",
        at("enemy.enraged") and at("enemy.defend")
        and at("enemy.enraged") < at("enemy.defend"))

    do
        local src = love.filesystem.read("src/systems/EffectSystem.lua")
        local missing = {}
        for ttype, trig in src:gmatch('t == "(%w+)" and triggerType == "(%w+)"') do
            if EffectSystem.TRIGGER_OF[ttype] ~= trig then
                missing[#missing + 1] = ttype .. "->" .. trig
            end
        end
        t:eq("TRIGGER_OF cobre todo trigger implementado ("
            .. table.concat(missing, ", ") .. ")", #missing, 0)
    end

    CombatBeats.clear()
    return t:done()
end

return M
