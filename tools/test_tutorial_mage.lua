local TK = require("tools.testkit")

local M = {}

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

function M.run()
    local t = TK.new("tutorial do mago: orbes do zero")
    TK.bootstrap()
    local I18n = require("src.i18n.I18n")
    local Tutorial = require("src.systems.Tutorial")
    local Narrator = require("src.ui.Narrator")
    local ProfileStats = require("engine.ProfileStats")
    local EffectSystem = require("src.systems.EffectSystem")
    local Game = require("src.core.Game")
    local MAGE = Tutorial.MAGE_CONVERSATIONS
    local MAGE_SET = {}
    for _, id in ipairs(MAGE) do MAGE_SET[id] = true end

    local prevProfile = ProfileStats._swapForTests({})
    Tutorial._reset()
    Tutorial._forceForTests(true)
    Tutorial._quiet = true
    I18n.setLocale("pt_BR", true)

    local g = TK.newRunGame("mage")
    TK.pump(g, 0.5)
    g.turn, g._enemyActing, g.battleTurn, g.selectedCards = "player", false, 0, {}
    g.enemy.maxHealth, g.enemy.health = 900, 900
    local db = g.deckManager.cardDatabase
    local function instance(id) return db:createCardInstance(db:getCard(id)) end
    local function hasEffect(c, ty)
        for _, e in ipairs(c.effects or {}) do if e.type == ty then return true end end
        return false
    end
    local function handCard(ty)
        for _, c in ipairs(g.hand) do if hasEffect(c, ty) then return c end end
    end

    local missing, dashes, unresolved = {}, {}, {}
    for _, loc in ipairs(LOCALES) do
        local data = require("src.i18n.locales.tutorial." .. loc)
        I18n.setLocale(loc, true)
        for _, id in ipairs(MAGE) do
            local conv = Tutorial.byId(id)
            if not conv then missing[#missing + 1] = "roteiro sem " .. id end
            for _, line in ipairs((conv and conv.lines) or {}) do
                local s = data.script and data.script[id] and data.script[id][line.id]
                if not (type(s) == "string" and #s > 10) then
                    missing[#missing + 1] = loc .. ":" .. id .. "." .. line.id
                else
                    if s:find("—", 1, true) or s:find("–", 1, true) or s:find(" - ", 1, true) then
                        dashes[#dashes + 1] = loc .. ":" .. id .. "." .. line.id
                    end
                    local txt = Tutorial.lineText(conv, line, g)
                    if txt:find("{", 1, true) then unresolved[#unresolved + 1] = loc .. ":" .. id .. "." .. line.id end
                end
            end
        end
    end
    I18n.setLocale("pt_BR", true)
    t:eq("toda fala do mago existe nos 5 idiomas", table.concat(missing, ","), "")
    t:eq("nenhum travessão nas falas do mago", table.concat(dashes, ","), "")
    t:eq("toda {variável} das falas resolve (nada cravado, nada solto)", table.concat(unresolved, ","), "")

    t:eq("Conduíte: o mago abre a 1ª luta com UM orbe", #g.player.orbs, 1)
    t:eq("...e ele é de Raio", g.player.orbs[1] and g.player.orbs[1].type, "lightning")
    local v = Tutorial.orbVars(g)
    t:eq("{passive} = nome da passiva do mago", v.passive, I18n.t("classes.mage.passive_name"))
    t:eq("{slots} = vagas reais da fileira", v.slots, g.player.orbSlots)
    t:eq("{pulse} = EffectSystem.orbPulseValue do orbe mais antigo", v.pulse,
        EffectSystem.orbPulseValue(g.player.orbs[1], 0))
    t:eq("{evoke} = EffectSystem.orbEvokeValue do orbe mais antigo", v.evoke,
        EffectSystem.orbEvokeValue(g.player.orbs[1], 0))
    t:eq("ato 1: o Conduíte não dá Foco ({f} = 0)", v.f, 0)
    t:eq("...e o jogador não tem Foco", v.focus, 0)
    do
        local mg = TK.mockGame({ class = "mage", enemyHp = 200 })
        mg.player.orbs = { { type = "lightning", value = 7 }, { type = "ice", value = 3 }, { type = "fire", value = 3 } }
        local before = mg.enemy.health
        mg.effectSystem:_stepChannelOrb(mg, { type = "lightning", value = 5 }, nil)
        t:eq("estouro: o mais antigo sai e o novo entra (3 orbes)", #mg.player.orbs, 3)
        t:eq("estouro: o expulso EVOCOU com o valor cheio (dano no inimigo)",
            before - mg.enemy.health, EffectSystem.orbEvokeValue({ type = "lightning", value = 7 }, 0))
        t:eq("estouro: o novo é o último da fila (entra pela direita)", mg.player.orbs[3].type, "lightning")
        t:eq("estouro: o 2º antigo virou o mais antigo", mg.player.orbs[1].type, "ice")
        before = mg.enemy.health
        mg.player.orbs = { { type = "lightning", value = 6 }, { type = "ice", value = 3 } }
        mg.effectSystem:_stepEvokeOrb(mg, nil, 1)
        t:eq("evocar: só o mais antigo sai", #mg.player.orbs, 1)
        t:eq("evocar: dano = valor cheio", before - mg.enemy.health, 6)
        mg.player:addBuff("focus", 99, 2)
        t:eq("Foco entra no pulso", EffectSystem.orbPulseValue({ type = "lightning", value = 4 }, 2),
            math.ceil((4 + 2) / 2))
        t:eq("Foco entra na evocação", EffectSystem.orbEvokeValue({ type = "lightning", value = 4 }, 2), 6)
        t:eq("Sombra: pulso 0", EffectSystem.orbPulseValue({ type = "dark", value = 5 }, 0), 0)
        t:eq("Sombra: evoca em dobro", EffectSystem.orbEvokeValue({ type = "dark", value = 5 }, 0), 10)
        local run = g.runManager.currentRun
        local act0 = run.actNumber
        local byAct = {}
        for act = 1, 6 do
            run.actNumber = act
            byAct[act] = math.max(0, g:classPassiveTier() + Game.MAGE_FOCUS_OFFSET)
        end
        run.actNumber = act0
        t:eq("Foco inicial do Conduíte cresce com os atos (0/0/1/1/2/2)",
            table.concat(byAct, "/"), "0/0/1/1/2/2")
    end

    local function anchorsNow()
        love.graphics.origin()
        Tutorial.anchor("hand", 300, 560, 400, 180)
        Tutorial.anchor("mana", 940, 680, 60, 60)
        Tutorial.anchor("intent", 470, 160, 90, 48)
        Tutorial.anchor("enemy", 440, 200, 150, 200)
        Tutorial.anchor("enemy_hp", 440, 410, 150, 12)
        Tutorial.anchor("play", 820, 600, 150, 46)
        Tutorial.anchor("end_turn", 820, 654, 150, 33)
        Tutorial.anchor("player_panel", 14, 660, 220, 90)
        Tutorial.anchor("preview", 760, 470, 220, 90)
        Tutorial.anchor("orbs", 10, 540, 180, 84)
        if #g.player.orbs > 0 then Tutorial.anchor("orb_next", 10, 540, 56, 76) end
        if handCard("channel_orb") then Tutorial.anchor("hand_channel", 300, 560, 130, 180) end
        if handCard("evoke_orb") or handCard("evoke_all_orbs") then
            Tutorial.anchor("hand_evoke", 440, 560, 130, 180)
        end
        if (g.player:getBuffStacks("focus") or 0) > 0 then Tutorial.anchor("buff_focus", 14, 620, 36, 36) end
    end
    local function step(secs)
        local n = math.max(1, math.floor((secs or 0.5) / (1 / 30)))
        for _ = 1, n do anchorsNow(); Tutorial.update(1 / 30, "playing", g) end
    end
    local CombatBeats = require("src.systems.CombatBeats")
    local function settle()
        for _ = 1, 40 do
            TK.pump(g, 0.5)
            local cs = g.combatAnimationSystem
            if not (cs and cs:isBlocking()) and not CombatBeats.isBusy() then return end
        end
        error("a jogada não resolveu em 20s")
    end
    local function walk()
        local seq = {}
        for _ = 1, 10 do
            local l = Tutorial.activeLine()
            if not l then break end
            seq[#seq + 1] = l
            Tutorial.overlay:keypressed("return")
            Tutorial.overlay:keypressed("return")
        end
        return table.concat(seq, ">")
    end
    local function seen(...)
        ProfileStats.resetTips()
        for _, id in ipairs({ ... }) do ProfileStats.markTipSeen(id) end
    end

    seen()
    Tutorial._reset()
    step(1.0)
    t:eq("antes da apresentação, o corvo abre com a apresentação (não com orbes)", Tutorial.activeId(), "intro")
    Tutorial.skipConversation()

    seen("intro", "end_turn", "second_turn")
    Tutorial._reset()
    g.turn, g.battleTurn, g.selectedCards = "player", 0, {}
    step(1.0)
    t:eq("1ª luta do mago: a 1ª conversa é o Conduíte", Tutorial.activeId(), "conduit")
    t:eq("...abrindo na passiva", Tutorial.activeLine(), "passive")
    local def = Tutorial.byId("conduit")
    local txt = Tutorial.lineText(def, def.lines[1], g)
    t:truthy("a fala cita a passiva pelo nome lido do i18n", txt:find(I18n.t("classes.mage.passive_name"), 1, true))
    local txt3 = Tutorial.lineText(def, def.lines[3], g)
    t:truthy("a fala do número traz o PULSO real do orbe (" .. tostring(v.pulse) .. ")",
        txt3:find("*" .. tostring(v.pulse) .. "*", 1, true))
    t:eq("Conduíte: passiva > fileira > número", walk(), "passive>row>number")
    t:truthy("Conduíte fica visto", ProfileStats.isTipSeen("conduit"))
    step(1.0)
    t:eq("em seguida, a canalização (Descarga está na mão)", Tutorial.activeId(), "channel")
    t:eq("antes de jogar: a fala é a da CARTA, não a do orbe criado", Tutorial.activeLine(), "card")
    t:eq("canalizar (carta na mão): carta > mais antigo > hover", walk(), "card>oldest>hover")

    seen("intro", "end_turn", "second_turn", "conduit")
    Tutorial._reset()
    local zap = handCard("channel_orb")
    t:truthy("a mão inicial do mago tem uma carta que canaliza (Descarga)", zap ~= nil)
    g.player.mana = g.player.maxMana or 3
    local hpBefore = g.enemy.health
    g:selectCard(zap)
    g:playSelectedCards()
    Tutorial._quiet = false
    step(0.3)
    settle()
    t:eq("Descarga canalizou: 2 orbes na fileira", #g.player.orbs, 2)
    t:truthy("o OrbRow contou a canalização pro corvo (Tutorial.noteEvent)", Tutorial.eventInfo("orb_channel") ~= nil)
    t:eq("...com a cena andando, ninguém fala", Tutorial.activeId(), nil)
    Tutorial._quiet = true
    step(1.0)
    t:eq("cena quieta: a canalização fala", Tutorial.activeId(), "channel")
    t:eq("depois de jogar: a fala é a do orbe CRIADO (a da carta não se aplica)", Tutorial.activeLine(), "made")
    t:eq("canalizar (orbe criado): criado > mais antigo > hover", walk(), "made>oldest>hover")

    seen("intro", "end_turn", "second_turn", "conduit", "channel")
    Tutorial._reset()
    t:eq("antes do fim do turno nenhum pulso foi contado", Tutorial.eventInfo("orb_pulse"), nil)
    step(0.5)
    t:eq("...e a conversa do pulso NÃO sai antes do pulso", Tutorial.activeId(), nil)
    hpBefore = g.enemy.health
    local expected = 0
    for _, o in ipairs(g.player.orbs) do expected = expected + EffectSystem.orbPulseValue(o, 0) end
    g:endTurn()
    settle()
    t:eq("fim do turno: os orbes pulsaram (dano = soma dos pulsos escritos)", hpBefore - g.enemy.health, expected)
    t:truthy("o OrbRow contou o pulso pro corvo", Tutorial.eventInfo("orb_pulse") ~= nil)
    t:eq("o turno passou pro inimigo", g.turn, "enemy")
    step(1.0)
    t:eq("na vez do inimigo o corvo cala (mesmo com o pulso armado)", Tutorial.activeId(), nil)
    g.turn, g._enemyActing, g.battleTurn = "player", false, 1
    Tutorial._quiet = false
    step(1.0)
    t:eq("turno 2 com a cena em movimento (banner/investida): espera", Tutorial.activeId(), nil)
    Tutorial._quiet = true
    step(1.0)
    t:eq("turno 2, cena quieta: a conversa do pulso", Tutorial.activeId(), "pulse")
    t:eq("pulso: aconteceu > elementos > Raio revela a intenção", walk(), "happened>kinds>reveal")

    seen("intro", "end_turn", "second_turn", "conduit", "channel", "pulse")
    Tutorial._reset()
    g.player.mana = g.player.maxMana or 3
    local dual = instance("mage_dualcast")
    table.insert(g.hand, dual)
    step(1.0)
    t:eq("carta de Evocar na mão: a conversa de evocar", Tutorial.activeId(), "evoke_card")
    t:eq("evocar: carta > prévia em ciano (sem 'todos', a carta evoca um)", walk(), "card>preview")
    seen("intro", "end_turn", "second_turn", "conduit", "channel", "pulse")
    Tutorial._reset()
    table.insert(g.hand, instance("mage_fission"))
    step(1.0)
    t:eq("Evocar todos na mão: a fala extra aparece", walk(), "card>preview>all")
    seen("intro", "end_turn", "second_turn", "conduit", "channel", "pulse")
    Tutorial._reset()
    local savedOrbs = g.player.orbs
    g.player.orbs = {}
    step(1.0)
    t:eq("sem orbe na fileira: a fala da prévia é pulada", walk(), "card>all")
    g.player.orbs = savedOrbs
    for i = #g.hand, 1, -1 do
        if hasEffect(g.hand[i], "evoke_orb") or hasEffect(g.hand[i], "evoke_all_orbs") then table.remove(g.hand, i) end
    end

    seen("intro", "end_turn", "second_turn", "conduit", "channel", "pulse", "evoke_card")
    Tutorial._reset()
    g.player.orbs = { { type = "lightning", value = 4 }, { type = "ice", value = 3 }, { type = "fire", value = 3 } }
    local zap2 = instance("mage_zap")
    table.insert(g.hand, zap2)
    g.player.mana = g.player.maxMana or 3
    g.selectedCards = {}
    step(0.1)
    hpBefore = g.enemy.health
    g:selectCard(zap2)
    g:playSelectedCards()
    Tutorial._quiet = false
    settle()
    t:truthy("o OrbRow contou a EXPULSÃO pro corvo", Tutorial.eventInfo("orb_overflow") ~= nil)
    t:eq("fileira continua com 3 orbes", #g.player.orbs, 3)
    t:eq("o novo entrou pela direita", g.player.orbs[3].type, "lightning")
    t:truthy("o expulso evocou: o inimigo levou pelo menos ataque + evocação",
        hpBefore - g.enemy.health >= (zap2.attack or 8) + EffectSystem.orbEvokeValue({ type = "lightning", value = 4 }, 0))
    step(0.5)
    t:eq("com a cena andando, ninguém fala", Tutorial.activeId(), nil)
    Tutorial._quiet = true
    step(1.0)
    t:eq("cena quieta: a conversa do estouro", Tutorial.activeId(), "overflow")
    local od = Tutorial.byId("overflow")
    t:truthy("a fala do estouro traz o nº real de vagas",
        Tutorial.lineText(od, od.lines[2], g):find(tostring(g.player.orbSlots), 1, true))
    t:eq("estouro: cheia > plano", walk(), "full>plan")

    seen("intro", "end_turn", "second_turn", "conduit", "channel", "pulse", "evoke_card", "overflow")
    Tutorial._reset()
    g.player:addBuff("focus", 99, 2)
    step(1.0)
    t:eq("Foco apareceu: a conversa do Foco", Tutorial.activeId(), "focus")
    local fd = Tutorial.byId("focus")
    t:eq("ato 1 (Conduíte sem Foco): só a fala do que é Foco", walk(), "what")
    seen("intro", "end_turn", "second_turn", "conduit", "channel", "pulse", "evoke_card", "overflow")
    Tutorial._reset()
    local run = g.runManager.currentRun
    local act0 = run.actNumber
    run.actNumber = 3
    step(1.0)
    t:eq("ato 3: Foco > Conduíte dá Foco", walk(), "what>conduit")
    run.actNumber = 3
    t:truthy("a fala do Conduíte traz o Foco inicial real do ato (1)",
        Tutorial.lineText(fd, fd.lines[2], g):find(" 1 ", 1, true))
    run.actNumber = act0

    seen("intro", "end_turn", "second_turn", unpack(MAGE))
    Tutorial._reset()
    g.player.orbs = { { type = "lightning", value = 4 }, { type = "ice", value = 3 }, { type = "fire", value = 3 } }
    table.insert(g.hand, instance("mage_dualcast"))
    Tutorial.noteEvent("orb_pulse", {}); Tutorial.noteEvent("orb_overflow", {}); Tutorial.noteEvent("orb_channel", {})
    step(2.0)
    t:eq("tudo visto: nenhuma conversa de orbe volta", Tutorial.activeId(), nil)
    t:eq("...nem fica armada", #Tutorial.latchedIds(), 0)
    for i = #g.hand, 1, -1 do
        if hasEffect(g.hand[i], "evoke_orb") then table.remove(g.hand, i) end
    end

    seen("intro", "end_turn", "second_turn", "conduit", "channel", "evoke_card", "overflow", "focus")
    Tutorial._reset()
    step(0.1)
    Tutorial.noteEvent("orb_pulse", {})
    run.currentFloor = (run.currentFloor or 1) + 1
    step(1.0)
    t:eq("pulso de outra batalha: a conversa do pulso não abre", Tutorial.activeId(), nil)
    run.currentFloor = run.currentFloor - 1

    local leaks = {}
    for _, cls in ipairs({ "warrior", "rogue" }) do
        seen("intro", "end_turn", "second_turn", "block", "combo", "jokers")
        Tutorial._reset()
        local og = g
        g = TK.newRunGame(cls)
        TK.pump(g, 0.5)
        g.turn, g._enemyActing, g.battleTurn, g.selectedCards = "player", false, 0, {}
        step(2.0)
        if Tutorial.activeId() and MAGE_SET[Tutorial.activeId()] then leaks[#leaks + 1] = cls .. ":" .. Tutorial.activeId() end
        for _, id in ipairs(Tutorial.latchedIds()) do
            if MAGE_SET[id] then leaks[#leaks + 1] = cls .. ":armado:" .. id end
        end
        Tutorial.skipConversation()
        g.player.mana = g.player.maxMana or 3
        g:selectCard(g.hand[1]); g:playSelectedCards(); settle()
        g:endTurn(); settle()
        g.turn, g._enemyActing, g.battleTurn = "player", false, 1
        step(2.0)
        if Tutorial.activeId() and MAGE_SET[Tutorial.activeId()] then leaks[#leaks + 1] = cls .. ":t2:" .. Tutorial.activeId() end
        if #g.player.orbs > 0 then leaks[#leaks + 1] = cls .. ":orbe" end
        Tutorial.skipConversation()
        g = og
    end
    t:eq("guerreiro e ladino: nenhuma conversa de orbe (ativa ou armada)", table.concat(leaks, ","), "")

    do
        Tutorial._reset()
        g.player.orbs = { { type = "lightning", value = 4 }, { type = "ice", value = 3 } }
        local OrbRow = require("src.ui.OrbRow")
        local cv = love.graphics.newCanvas(1024, 768)
        love.graphics.setCanvas(cv)
        love.graphics.origin()
        OrbRow.draw(g, 14, 660)
        love.graphics.setCanvas()
        local row, nextA = Tutorial.anchorRect("orbs"), Tutorial.anchorRect("orb_next")
        t:truthy("OrbRow reporta a fileira ('orbs')", row ~= nil)
        t:truthy("OrbRow reporta a célula do mais antigo ('orb_next')", nextA ~= nil)
        if row and nextA then
            t:truthy("a célula do mais antigo fica DENTRO da fileira",
                nextA.x >= row.x and nextA.y >= row.y and nextA.x + nextA.w <= row.x + row.w
                and nextA.y + nextA.h <= row.y + row.h)
            t:truthy("a fileira cobre as 3 vagas (largura >= 3 gemas)", row.w >= 3 * 48)
            t:truthy("a célula é uma gema só", nextA.w < row.w / 2)
        end
        Tutorial._reset()
        g.player.orbs = {}
        love.graphics.setCanvas(cv); love.graphics.origin()
        OrbRow.draw(g, 14, 660)
        love.graphics.setCanvas()
        t:truthy("mago sem orbe: a fileira vazia ainda é ancorada", Tutorial.anchorRect("orbs") ~= nil)
        t:eq("mago sem orbe: sem 'mais antigo'", Tutorial.anchorRect("orb_next"), nil)
        g.player.orbs = { { type = "lightning", value = 4 } }

        local GameplayScene = require("src.scenes.GameplayScene")
        local prevSceneGame = GameplayScene.getGame()
        GameplayScene.init({ game = g })
        for i = #g.hand, 1, -1 do
            if hasEffect(g.hand[i], "evoke_orb") or hasEffect(g.hand[i], "evoke_all_orbs")
                or hasEffect(g.hand[i], "channel_orb") then table.remove(g.hand, i) end
        end
        table.insert(g.hand, instance("defense_001"))
        table.insert(g.hand, instance("mage_zap"))
        table.insert(g.hand, instance("mage_dualcast"))
        for i, c in ipairs(g.hand) do c.renderX, c.renderY = 300 + (i - 1) * 140, 560 end
        Tutorial._reset()
        love.graphics.origin()
        GameplayScene._reportTutorialAnchors()
        local hand, ch, ev = Tutorial.anchorRect("hand"), Tutorial.anchorRect("hand_channel"), Tutorial.anchorRect("hand_evoke")
        t:truthy("mão reporta a carta que canaliza", ch ~= nil)
        t:truthy("mão reporta a carta que evoca", ev ~= nil)
        if hand and ch and ev then
            t:truthy("a carta que canaliza fica dentro da mão", ch.x >= hand.x and ch.x + ch.w <= hand.x + hand.w)
            t:truthy("canaliza e evoca são cartas DIFERENTES", math.abs(ch.x - ev.x) > 50)
            t:truthy("o recorte é de UMA carta, não da mão toda", ch.w < hand.w)
        end
        GameplayScene.init({ game = prevSceneGame })
    end

    Tutorial._forceForTests(false)
    Tutorial._quiet = nil
    Tutorial._reset()
    ProfileStats._swapForTests(prevProfile)
    return t:done()
end

return M
