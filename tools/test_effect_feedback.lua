local TK = require("tools.testkit")

local M = {}

local FILES = {
    exhaustBurn = "card-exhaust-ash", cardCopy = "card-copy", cardRetain = "card-retain",
    cardDiscard = "card-discard", deckShuffle = "deck-shuffle", manaRestore = "mana-restore",
    manaMaxUp = "mana-max-up", selfDamage = "self-damage", buffApplied = "buff-applied",
    intentReveal = "intent-reveal", innateRise = "innate-rise", mapOpen = "map-open",
    mapClose = "map-close", mapHover = "map-hover",
}

local NEW_SOUNDS = {}
for name in pairs(FILES) do NEW_SOUNDS[#NEW_SOUNDS + 1] = name end
table.sort(NEW_SOUNDS)

local function mockAudio(names)
    local played = {}
    local a = { sources = {} }
    for _, n in ipairs(names) do a.sources[n] = { volume = 0.5 } end
    function a:play(name) played[#played + 1] = name end
    function a:playSound(name) played[#played + 1] = name end
    function a:playMusic() end
    function a:stopMusic() end
    return a, played
end

local function has(list, name)
    for _, v in ipairs(list) do if v == name then return true end end
    return false
end

local function clear(list) for i = #list, 1, -1 do list[i] = nil end end

function M.run()
    TK.bootstrap()
    TK.seedRng(538)
    local t = TK.new("efeitos: som e animação próprios (#538)")
    local EffectFeedback = require("src.systems.EffectFeedback")
    local HandFx = require("src.ui.HandFx")
    local prevAudio = _G.audioSystem

    _G.audioSystem = mockAudio({})
    t:eq("sem o som novo, exaurir cai no som antigo", EffectFeedback.soundFor("exhaust"), "cardExhaust")
    t:eq("sem o som novo, embaralhar cai no deckStart", EffectFeedback.soundFor("reshuffle"), "deckStart")

    local audio, played = mockAudio(NEW_SOUNDS)
    _G.audioSystem = audio
    local seen, dup = {}, nil
    for event, list in pairs(EffectFeedback.SOUNDS) do
        local name = EffectFeedback.soundFor(event)
        if event ~= "armor" then
            t:eq("evento '" .. event .. "' usa o som próprio", name, list[1])
            if seen[name] then dup = event .. "/" .. seen[name] end
            seen[name] = event
        end
    end
    t:check("nenhum som novo é repetido entre efeitos" .. (dup and (" (" .. dup .. ")") or ""), dup == nil)
    for _, n in ipairs(NEW_SOUNDS) do
        t:truthy("arquivo do som '" .. n .. "' existe",
            love.filesystem.getInfo("audio/sfx/" .. FILES[n] .. ".mp3") ~= nil)
    end

    local g = TK.newRunGame("warrior")
    _G.audioSystem = audio
    HandFx.clear()
    TK.pump(g, 1.5)
    clear(played)

    EffectFeedback.exhaust()
    t:check("exaurir toca exhaustBurn", has(played, "exhaustBurn"))
    EffectFeedback.copy()
    t:check("duplicar toca cardCopy", has(played, "cardCopy"))

    clear(played)
    local nHand = #g.hand
    g.effectSystem:processEffectCard(g, { type = "discard_cards", value = 2 })
    t:eq("descartar tira 2 cartas da mão", #g.hand, math.max(0, nHand - 2))
    t:check("descartar toca cardDiscard", has(played, "cardDiscard"))
    t:eq("descartar anima as 2 cartas", HandFx.count("discard"), math.min(2, nHand))

    clear(played)
    g.player.mana = 0
    g.effectSystem:processEffectCard(g, { type = "restore_mana", value = 1 })
    t:check("recuperar mana toca manaRestore", has(played, "manaRestore"))
    g.effectSystem:processEffectCard(g, { type = "increase_max_mana", value = 1 })
    t:check("mana máxima toca manaMaxUp", has(played, "manaMaxUp"))
    g.effectSystem:processEffectCard(g, { type = "self_damage", value = 2 })
    t:check("auto-dano toca selfDamage", has(played, "selfDamage"))
    g.effectSystem:processEffectCard(g, { type = "apply_buff", value = "thorn", stacks = 1 })
    t:check("buff toca buffApplied", has(played, "buffApplied"))

    clear(played)
    HandFx.clear()
    local keep = { id = "r", type = "attack", attack = 1, cost = 0, retain = true }
    g.hand = { keep, { id = "s", type = "attack", attack = 1, cost = 0 } }
    g:discardHandEndOfTurn()
    t:eq("só a carta com reter fica na mão", g.hand[1] == keep and #g.hand, 1)
    t:check("reter toca cardRetain", has(played, "cardRetain"))
    t:eq("reter anima a carta que ficou", HandFx.count("retain"), 1)
    t:eq("reter acontece na própria carta (selo de runas)", keep.cardFx and keep.cardFx.mode, "seal")
    t:falsy("flag de reter é limpa depois do efeito", keep._fxRetained)

    clear(played)
    HandFx.clear()
    g.hand, g.deck = {}, {}
    g.discard = {
        { id = "a", type = "attack", attack = 1, cost = 0 },
        { id = "b", type = "attack", attack = 1, cost = 0 },
        { id = "c", type = "attack", attack = 1, cost = 0 },
    }
    g:drawCard(0)
    t:check("reembaralhar toca deckShuffle", has(played, "deckShuffle"))
    t:check("reembaralhar não toca mais deckStart", not has(played, "deckStart"))
    t:eq("reembaralhar anima o grimório", HandFx.count("shuffle"), 1)

    clear(played)
    HandFx.clear()
    local inn = { id = "inn", type = "attack", attack = 1, cost = 0, innate = true }
    g.deck = { { id = "x", type = "attack", attack = 1, cost = 0 }, inn }
    g:promoteInnateCardsToTop(true)
    t:eq("carta inata vai ao topo", g.deck[1], inn)
    t:truthy("carta inata do início da luta ganha a marca", inn._fxInnate)
    t:truthy("chegada da inata é tratada", EffectFeedback.onCardArrives(inn, 1))
    t:check("inata toca innateRise", has(played, "innateRise"))
    t:eq("inata anima a carta", HandFx.count("innate"), 1)
    t:eq("inata acontece na própria carta (alvorada)", inn.cardFx and inn.cardFx.mode, "dawn")
    g.deck = { inn }
    g:promoteInnateCardsToTop()
    t:falsy("reembaralhar no meio da luta não marca a inata de novo", inn._fxInnate)
    t:falsy("carta comum chega sem efeito extra", EffectFeedback.onCardArrives({ id = "y" }, 1))

    for _ = 1, 120 do HandFx.update(1 / 60) end
    t:falsy("efeitos da mão terminam sozinhos", HandFx.isActive())
    t:falsy("alvorada da inata sai da carta no fim", inn.cardFx)

    local CardFxShader = require("src.ui.CardFxShader")
    local modes, distinct, nd = 0, {}, 0
    for name, id in pairs(CardFxShader.MODES) do
        modes = modes + 1
        if not distinct[id] then nd = nd + 1 end
        distinct[id] = true
        t:truthy("efeito '" .. name .. "' tem paleta própria", CardFxShader.PALETTES[name])
    end
    t:eq("cada efeito na carta tem um modo de shader próprio", nd, modes)
    t:truthy("shader dos efeitos na carta existe", love.filesystem.getInfo("shaders/card_fx.glsl") ~= nil)
    if love.graphics and love.graphics.newShader then
        t:truthy("shader dos efeitos na carta compila", CardFxShader.load())
    end

    local ExhaustFx = require("src.ui.ExhaustFx")
    local burnt = { id = "e", type = "attack", attack = 1, cost = 0, dissolve = 0 }
    ExhaustFx.start(burnt, 0, 0, 100, 140)
    t:eq("exaurir vira cinza na própria carta", burnt.cardFx and burnt.cardFx.mode, "ash")
    burnt.dissolve = 0.5
    ExhaustFx.update(1 / 60)
    t:eq("a cinza segue o dissolve da carta", burnt.cardFx and burnt.cardFx.progress, 0.5)
    for _ = 1, 120 do ExhaustFx.update(1 / 60) end
    t:falsy("a cinza sai da carta no fim", burnt.cardFx)
    ExhaustFx.clear()

    HandFx.clear()
    _G.audioSystem = prevAudio
    return t:done()
end

return M
