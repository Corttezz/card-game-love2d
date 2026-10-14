local Debug = require("src.core.Debug")

local Tutorial = {}

local Narrator = require("src.ui.Narrator")

local STABLE_FOR = 0.45
local GAP_AFTER = 0.40
local ANCHOR_TTL = 0.25
local FADE_IN, FADE_OUT = 0.22, 0.20
local HOLD_MAX = 3.0

local anchors = {}
local screens = {}
local active = nil
local closing = nil
local pendingId, pendingSince = nil, 0
local cooldown = 0
local latched = {}
local forceTest = false
local blockedPress = false
local events = {}
local lastGame = nil

local function store(id, x1, y1, x2, y2)
    anchors[id] = { x = math.min(x1, x2), y = math.min(y1, y2),
        w = math.abs(x2 - x1), h = math.abs(y2 - y1), t = love.timer.getTime() }
end

function Tutorial.anchor(id, x, y, w, h)
    if not (x and y and w and h) then return end
    local g = love.graphics
    local x1, y1 = g.transformPoint(x, y)
    local x2, y2 = g.transformPoint(x + w, y + h)
    store(id, x1, y1, x2, y2)
end

function Tutorial.anchorList(id, list)
    local x1, y1, x2, y2
    for _, b in pairs(list or {}) do
        if type(b) == "table" then
            local w, h = b.w or b.width, b.h or b.height
            if b.x and b.y and w and h and b.visible ~= false and w > 0 and h > 0 then
                x1 = math.min(x1 or b.x, b.x); y1 = math.min(y1 or b.y, b.y)
                x2 = math.max(x2 or (b.x + w), b.x + w); y2 = math.max(y2 or (b.y + h), b.y + h)
            end
        end
    end
    if x1 then Tutorial.anchor(id, x1, y1, x2 - x1, y2 - y1) end
end

function Tutorial.anchorRect(id)
    local a = anchors[id]
    if not a then return nil end
    if love.timer.getTime() - a.t > ANCHOR_TTL then return nil end
    if a.w < 2 or a.h < 2 then return nil end
    return a
end

local function spotRect(spot)
    if spot == nil then return nil end
    if type(spot) == "function" then return spot() end
    if type(spot) == "string" then return Tutorial.anchorRect(spot) end
    local x1, y1, x2, y2
    for _, id in ipairs(spot) do
        local a = Tutorial.anchorRect(id)
        if a then
            x1 = math.min(x1 or a.x, a.x); y1 = math.min(y1 or a.y, a.y)
            x2 = math.max(x2 or (a.x + a.w), a.x + a.w); y2 = math.max(y2 or (a.y + a.h), a.y + a.h)
        end
    end
    if not x1 then return nil end
    return { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
end
Tutorial.spotRect = spotRect

function Tutorial.setScreens(t) screens = t or {} end

local function realDims()
    local ok, UiScale = pcall(require, "src.ui.UiScale")
    if ok and UiScale.realDimensions then return UiScale.realDimensions() end
    return love.graphics.getWidth(), love.graphics.getHeight()
end

local function uiK()
    local ok, UiScale = pcall(require, "src.ui.UiScale")
    if ok and UiScale.k then return UiScale.k() end
    return 1
end

local function run(game)
    return game and game.runManager and game.runManager.currentRun
end

local function nodeType(game)
    local r = run(game)
    return r and r.currentNode and r.currentNode.type
end

local function sceneQuiet()
    if Tutorial._quiet ~= nil then return Tutorial._quiet end
    local ok, GS = pcall(require, "src.scenes.GameplayScene")
    if ok and GS.isQuiet then return GS.isQuiet() end
    return true
end

local function battleIdle(game)
    if not game or game.gameState ~= "playing" then return false end
    if game.turn ~= "player" or game._enemyActing then return false end
    if not (game.enemy and game.enemy:isAlive() and game.player and game.player:isAlive()) then
        return false
    end
    local cs = game.combatAnimationSystem
    if cs and cs.isBlocking and cs:isBlocking() then return false end
    if #(game.hand or {}) == 0 then return false end
    return sceneQuiet()
end
Tutorial.battleIdle = battleIdle

local function battleQuiet(game)
    if not game or game.gameState ~= "playing" then return false end
    if game.turn ~= "player" or game._enemyActing then return false end
    if not (game.enemy and game.enemy:isAlive() and game.player and game.player:isAlive()) then
        return false
    end
    local cs = game.combatAnimationSystem
    if cs and cs.isBlocking and cs:isBlocking() then return false end
    return sceneQuiet()
end
Tutorial.battleQuiet = battleQuiet

local function firstTurn(game) return (game.battleTurn or 0) == 0 end

local function handHasCombo(game)
    local ok, res = pcall(function()
        local TagSystem = require("src.systems.TagSystem")
        local ComboSystem = require("src.systems.ComboSystem")
        local hand = game.hand or {}
        local ctx = { tagCounts = TagSystem.countAllTags(hand), allSelectedCards = hand,
            snapshot = hand }
        return #ComboSystem.detect(ctx) > 0
    end)
    return ok and res
end

local function screenVisible(name, mode)
    local sc = screens[name]
    if not (sc and sc.visible) then return false end
    if mode and sc.mode ~= mode then return false end
    return true
end

local function forkActive()
    local ok, WorldRoad = pcall(require, "src.ui.WorldRoad")
    return ok and WorldRoad.isForkActive and WorldRoad.isForkActive() or false
end

local function forkRect()
    if not forkActive() then return nil end
    local f = require("src.ui.WorldRoad")._fork
    local x1, y1, x2, y2
    for _, b in pairs((f and f.markBoxes) or {}) do
        if b.x1 then
            x1 = math.min(x1 or b.x1, b.x1); y1 = math.min(y1 or b.y1, b.y1)
            x2 = math.max(x2 or b.x2, b.x2); y2 = math.max(y2 or b.y2, b.y2)
        end
    end
    if not x1 then return nil end
    return { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
end

local function anyAnchor(...)
    for _, id in ipairs({ ... }) do
        if Tutorial.anchorRect(id) then return true end
    end
    return false
end

local function battleKey(g)
    local r = run(g)
    if not r then return "classic" end
    return tostring(r.actNumber or 0) .. ":" .. tostring(r.currentFloor or 0)
end

function Tutorial.noteEvent(name, info)
    local prev = events[name]
    events[name] = { t = love.timer.getTime(), count = ((prev and prev.count) or 0) + 1,
        key = battleKey(lastGame or _G.game), info = info }
end

function Tutorial.eventInfo(name) return events[name] end

local function eventThisBattle(g, name)
    local e = events[name]
    return e ~= nil and e.key == battleKey(g)
end

local function isMage(g) return g and g.selectedClass == "mage" end

local function orbs(g) return (g and g.player and g.player.orbs) or {} end

local function focusStacks(g)
    local p = g and g.player
    return (p and p.getBuffStacks and p:getBuffStacks("focus")) or 0
end

local function conduitFocus(g)
    if not (g and g.classPassiveTier) then return 0 end
    local ok, Game = pcall(require, "src.core.Game")
    local off = ok and Game.MAGE_FOCUS_OFFSET or 0
    return math.max(0, g:classPassiveTier() + off)
end

local function handHasEffect(g, ...)
    local want = {}
    for _, t in ipairs({ ... }) do want[t] = true end
    for _, c in ipairs((g and g.hand) or {}) do
        for _, e in ipairs(c.effects or {}) do
            if want[e.type] then return true end
        end
    end
    return false
end
local function handHasChannel(g) return handHasEffect(g, "channel_orb") end
local function handHasEvoke(g) return handHasEffect(g, "evoke_orb", "evoke_all_orbs") end
local function handHasEvokeAll(g) return handHasEffect(g, "evoke_all_orbs") end

function Tutorial.orbVars(g)
    local I18n = require("src.i18n.I18n")
    local v = { passive = I18n.t("classes.mage.passive_name"),
        slots = (g and g.player and g.player.orbSlots) or 3,
        focus = focusStacks(g), f = conduitFocus(g), pulse = 0, evoke = 0 }
    local first = orbs(g)[1]
    if first then
        local ok, ES = pcall(require, "src.systems.EffectSystem")
        if ok then
            v.pulse = ES.orbPulseValue(first, v.focus)
            v.evoke = ES.orbEvokeValue(first, v.focus)
        end
    end
    return v
end

local function focusSpot()
    return spotRect({ "buff_focus", "orbs" })
end

local function played(g, base)
    return base and base.hand and #(g.hand or {}) < base.hand
end
Tutorial.ACTIONS = {
    select = {
        done = function(g, base) return #(g.selectedCards or {}) > 0 or played(g, base) end,
        keys = {}, label = "tutorial.act.select",
    },
    play = {
        done = function(g, base)
            if played(g, base) then return true end
            local cs = g.combatAnimationSystem
            return cs and cs.isBlocking and cs:isBlocking() or false
        end,
        keys = { e = true, y = true }, label = "tutorial.act.play",
    },
    end_turn = {
        done = function(g) return g.turn ~= "player" or g._enemyActing == true end,
        keys = { q = true, x = true }, label = "tutorial.act.end_turn",
    },
}

Tutorial.SCRIPT = {
    { id = "intro", state = "playing",
      when = function(g) return battleIdle(g) and firstTurn(g)
          and anyAnchor("hand") and anyAnchor("enemy") end,
      lines = {
          { id = "hello" },
          { id = "enemy", spot = { "enemy", "enemy_hp" } },
          { id = "intent", spot = "intent" },
          { id = "hero", spot = "player_panel" },
          { id = "hand", spot = "hand", action = "select" },
          { id = "mana", spot = "mana" },
          { id = "preview", spot = "preview" },
          { id = "play", spot = "play", action = "play" },
      } },
    { id = "end_turn", state = "playing", after = "intro",
      latch = function(g)
          return battleQuiet(g) and #(g.selectedCards or {}) == 0
              and (g.player.mana or 0) < (g.player.maxMana or 3)
      end,
      ready = function(g)
          return battleQuiet(g) and #(g.selectedCards or {}) == 0
              and (g.player.mana or 0) < (g.player.maxMana or 3) and anyAnchor("end_turn")
      end,
      lines = { { id = "end", spot = "end_turn", action = "end_turn" } } },
    { id = "second_turn", state = "playing", after = "end_turn",
      latch = function(g) return g.turn == "player" and (g.battleTurn or 0) >= 1 end,
      ready = function(g) return battleQuiet(g) end,
      lines = { { id = "kept", spot = "intent" }, { id = "loop", spot = "hand" } } },
    { id = "boss", state = "playing", after = "intro",
      latch = function(g) return firstTurn(g) and nodeType(g) == "boss" end,
      ready = function(g) return battleQuiet(g) end,
      lines = { { id = "arrive", spot = { "enemy", "enemy_hp" } }, { id = "signature", spot = "intent" } } },
    { id = "elite", state = "playing", after = "intro",
      latch = function(g) return firstTurn(g) and nodeType(g) == "elite" end,
      ready = function(g) return battleQuiet(g) end,
      lines = { { id = "warn", spot = { "enemy", "enemy_hp" } } } },
    { id = "fog", state = "playing", after = "intro",
      latch = function(g)
          local e = g.enemy
          return g.turn == "player" and e and e.getIntentVisibility
              and e:getIntentVisibility() ~= "full"
      end,
      ready = function(g)
          return battleQuiet(g) and anyAnchor("intent")
              and g.enemy and g.enemy:getIntentVisibility() ~= "full"
      end,
      lines = { { id = "veil", spot = "intent" }, { id = "counter", spot = "intent" } } },
    { id = "block", state = "playing", after = "intro", sameTurn = true,
      latch = function(g) return g.turn == "player" and (g.player.armor or 0) > 0 end,
      ready = function(g) return battleQuiet(g) and anyAnchor("player_panel") end,
      lines = { { id = "reset", spot = "player_panel" } } },
    { id = "combo", state = "playing", after = "intro", sameTurn = true,
      latch = function(g) return battleIdle(g) and handHasCombo(g) end,
      ready = function(g) return battleIdle(g) and anyAnchor("hand") end,
      lines = { { id = "seal", spot = "hand" }, { id = "guide" } } },
    { id = "conduit", state = "playing", after = "intro",
      latch = function(g) return isMage(g) and g.turn == "player" and #orbs(g) >= 1 end,
      ready = function(g) return battleQuiet(g) and anyAnchor("orbs") and #orbs(g) >= 1 end,
      lines = {
          { id = "passive", spot = "orb_next", vars = Tutorial.orbVars },
          { id = "row", spot = "orbs", vars = Tutorial.orbVars },
          { id = "number", spot = "orb_next", vars = Tutorial.orbVars },
      } },
    { id = "channel", state = "playing", after = "intro",
      latch = function(g)
          return g.turn == "player" and (eventThisBattle(g, "orb_channel") or handHasChannel(g))
      end,
      ready = function(g)
          return battleQuiet(g) and anyAnchor("orbs")
              and (eventThisBattle(g, "orb_channel") or anyAnchor("hand_channel"))
      end,
      lines = {
          { id = "card", spot = "hand_channel",
            cond = function(g) return not eventThisBattle(g, "orb_channel") and handHasChannel(g) end },
          { id = "made", spot = "orbs", cond = function(g) return eventThisBattle(g, "orb_channel") end },
          { id = "oldest", spot = "orb_next", cond = function(g) return #orbs(g) >= 1 end },
          { id = "hover", spot = "orbs" },
      } },
    { id = "pulse", state = "playing", after = "second_turn",
      latch = function(g) return g.turn == "player" and eventThisBattle(g, "orb_pulse") end,
      ready = function(g) return battleQuiet(g) and anyAnchor("orbs") end,
      lines = {
          { id = "happened", spot = "orbs" },
          { id = "kinds", spot = "orbs" },
          { id = "reveal", spot = "intent", cond = function() return anyAnchor("intent") end },
      } },
    { id = "evoke_card", state = "playing", after = "intro",
      latch = function(g) return g.turn == "player" and handHasEvoke(g) end,
      ready = function(g) return battleIdle(g) and anyAnchor("hand_evoke") end,
      lines = {
          { id = "card", spot = "hand_evoke" },
          { id = "preview", spot = "orbs", cond = function(g) return #orbs(g) >= 1 and anyAnchor("orbs") end },
          { id = "all", spot = "hand_evoke", cond = handHasEvokeAll },
      } },
    { id = "overflow", state = "playing", after = "intro",
      latch = function(g) return eventThisBattle(g, "orb_overflow") end,
      ready = function(g) return battleQuiet(g) and anyAnchor("orbs") end,
      lines = {
          { id = "full", spot = "orbs" },
          { id = "plan", spot = "orbs", vars = Tutorial.orbVars },
      } },
    { id = "focus", state = "playing", after = "intro",
      latch = function(g) return g.turn == "player" and focusStacks(g) > 0 end,
      ready = function(g) return battleQuiet(g) and anyAnchor("orbs") and focusStacks(g) > 0 end,
      lines = {
          { id = "what", spot = focusSpot, vars = Tutorial.orbVars },
          { id = "conduit", spot = focusSpot, vars = Tutorial.orbVars,
            cond = function(g) return isMage(g) and conduitFocus(g) > 0 end },
      } },
    { id = "jokers", state = "playing", after = "intro",
      latch = function(g)
          local r = run(g)
          return r and #(r.jokers or {}) > 0
      end,
      ready = function(g) return battleQuiet(g) and anyAnchor("jokers") end,
      lines = { { id = "passive", spot = "jokers" }, { id = "bench", spot = "jokers" } } },
    { id = "rewards", state = "cardReward",
      when = function() return screenVisible("cardReward", "rewards") and anyAnchor("offers") end,
      lines = { { id = "pick", spot = "offers" }, { id = "skip", spot = "reward_skip" } } },
    { id = "dice", state = "cardReward",
      when = function() return screenVisible("dice") and anyAnchor("dice_table") end,
      lines = { { id = "odds", spot = "dice_table" }, { id = "bet", spot = "dice_bets" } } },
    { id = "dice_help", state = "cardReward", onDemand = true,
      when = function() return false end,
      lines = {
          { id = "what", spot = function()
              return Tutorial.anchorRect("dice_table") or Tutorial.anchorRect("shop_dice") end },
          { id = "bets", spot = "dice_bets" },
          { id = "stakes", spot = "dice_stakes" },
          { id = "once" },
      } },
    { id = "shop", state = "cardReward",
      when = function() return screenVisible("cardReward", "shop") and anyAnchor("offers") end,
      lines = { { id = "offers", spot = "offers" }, { id = "price", spot = "shop_prices" },
          { id = "buy", spot = "shop_scroll" }, { id = "refresh", spot = "shop_refresh" },
          { id = "dice", spot = "shop_dice" }, { id = "interest" } } },
    { id = "forge", state = "rest",
      when = function() return screenVisible("rest", "forge") and anyAnchor("forge_cards") end,
      lines = { { id = "pick", spot = "forge_cards" } } },
    { id = "rest", state = "rest",
      when = function() return screenVisible("rest", "choose") and anyAnchor("rest_options") end,
      lines = { { id = "choose", spot = "rest_options" } } },
    { id = "event", state = "event",
      when = function() return screenVisible("event") and anyAnchor("event_options") end,
      lines = { { id = "read", spot = "event_options" } } },
    { id = "fork", state = "mapSelection",
      when = function() return forkRect() ~= nil end,
      lines = { { id = "paths", spot = forkRect } } },
    { id = "endless", state = "*",
      when = function() return screenVisible("endless") and anyAnchor("curse_options") end,
      lines = { { id = "cycle", spot = "curse_options" }, { id = "grow" } } },
    { id = "class_select", state = "classSelection",
      when = function() return anyAnchor("class_hero") and anyAnchor("class_start") end,
      lines = {
          { id = "welcome", spot = "class_hero" },
          { id = "warrior", spot = "class_hero", vars = function()
              local I18n = require("src.i18n.I18n")
              return { passive = I18n.t("classes.warrior.passive_name"),
                       rule = I18n.t("classes.warrior.passive_short") }
          end },
          { id = "start", spot = "class_start" },
          { id = "locked", spot = "class_locked", cond = function() return Tutorial.lockedClassesText() ~= "" end,
            vars = function() return { list = Tutorial.lockedClassesText() } end },
          { id = "details", spot = "class_details" },
      } },
    { id = "seals", state = "classSelection",
      when = function() return anyAnchor("seal_band") end,
      lines = { { id = "unlocked", spot = "seal_band" }, { id = "score", spot = "seal_band" } } },
}

function Tutorial.lockedClassesText()
    local I18n = require("src.i18n.I18n")
    local US = require("src.systems.UnlockSystem")
    local parts = {}
    for _, id in ipairs({ "warrior", "mage", "rogue" }) do
        local info = US.getClassUnlockInfo(id)
        if info and not info.unlocked then
            parts[#parts + 1] = "*" .. I18n.t("classes." .. id .. ".name") .. "*: "
                .. I18n.t(info.reqKey, info.vars) .. "."
        end
    end
    return table.concat(parts, " ")
end

local function byId(id)
    for _, d in ipairs(Tutorial.SCRIPT) do if d.id == id then return d end end
end
Tutorial.byId = byId

local function scriptIndex(id)
    for i, d in ipairs(Tutorial.SCRIPT) do if d.id == id then return i end end
    return math.huge
end

Tutorial.MAGE_CONVERSATIONS = { "conduit", "channel", "pulse", "evoke_card", "overflow", "focus" }

local function PS() return require("engine.ProfileStats") end

function Tutorial.enabled()
    if forceTest then return true end
    if _G.HEADLESS_TOOL and not Tutorial._allowHeadless then return false end
    local gs = _G.gameSettings
    return not (gs and gs.tipsEnabled == false)
end

function Tutorial.isSeen(id) return PS().isTipSeen(id) end

function Tutorial.resetAll()
    active, closing, pendingId, cooldown = nil, nil, nil, 0
    latched = {}
    return PS().resetTips()
end

local function stateMatches(def, state)
    return def.state == "*" or def.state == state
end

local function eligible(def, state, game)
    if def.latch or def.onDemand then return false end
    if not stateMatches(def, state) then return false end
    if Tutorial.isSeen(def.id) then return false end
    if def.after and not Tutorial.isSeen(def.after) then return false end
    local ok, res = pcall(def.when, game, screens)
    if not ok then
        Debug.warn("[Tutorial] condicao da conversa '" .. def.id .. "' falhou: " .. tostring(res))
        return false
    end
    return res and true or false
end

local function safeCall(fn, def, game)
    local ok, res = pcall(fn, game, screens)
    if not ok then
        Debug.warn("[Tutorial] gatilho da conversa '" .. def.id .. "' falhou: " .. tostring(res))
        return false
    end
    return res and true or false
end

local function updateLatches(state, game)
    local now = love.timer.getTime()
    local turn = game and game.battleTurn
    for _, def in ipairs(Tutorial.SCRIPT) do
        local l = latched[def.id]
        if l then
            if not stateMatches(def, state) or Tutorial.isSeen(def.id)
                or (def.sameTurn and turn ~= l.turn) then
                latched[def.id] = nil
            end
        elseif def.latch and stateMatches(def, state) and game
            and not Tutorial.isSeen(def.id)
            and not (active and active.def == def)
            and (not def.after or Tutorial.isSeen(def.after))
            and safeCall(def.latch, def, game) then
            latched[def.id] = { t = now, turn = turn }
        end
    end
end

local function nextCandidate(state, game)
    for _, def in ipairs(Tutorial.SCRIPT) do
        if eligible(def, state, game) then return def end
    end
    local best, bestT, bestI
    for id, l in pairs(latched) do
        local def = byId(id)
        local idx = scriptIndex(id)
        if def and (not bestT or l.t < bestT or (l.t == bestT and idx < bestI))
            and (not def.ready or safeCall(def.ready, def, game)) then
            best, bestT, bestI = def, l.t, idx
        end
    end
    return best
end

function Tutorial.holdsTurn()
    if not Tutorial.enabled() then return false end
    if active and active.def.state == "playing" then return true end
    local now = love.timer.getTime()
    for id, l in pairs(latched) do
        local def = byId(id)
        if def and def.state == "playing" and (now - l.t < HOLD_MAX
            or (def.ready and safeCall(def.ready, def, active and active.game))) then
            return true
        end
    end
    return false
end

function Tutorial.latchedIds()
    local ids = {}
    for id in pairs(latched) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

local function lineText(conv, line, game)
    local I18n = require("src.i18n.I18n")
    local vars
    if line.vars then
        local ok, v = pcall(line.vars, game or (active and active.game))
        if ok then vars = v else Debug.warn("[Tutorial] vars da fala '" .. line.id .. "' falharam: " .. tostring(v)) end
    end
    return I18n.t("tutorial.script." .. conv.id .. "." .. line.id, vars, conv.id .. "." .. line.id)
end
Tutorial.lineText = lineText

local function curLine()
    return active and active.def.lines[active.line]
end

local function startLine(game)
    local line = curLine()
    Narrator.say(lineText(active.def, line, game or active.game))
    active.lineShownAt = love.timer.getTime()
    if line.action and not Tutorial.ACTIONS[line.action] then
        Debug.warn("[Tutorial] acao desconhecida: " .. tostring(line.action))
    end
end

local function finish(markSeen)
    if not active then return end
    if markSeen then PS().markTipSeen(active.def.id) end
    closing = { L = active.L, size = active.size, t = 0, spot = active.lastSpot }
    active = nil
    Narrator.releaseVoice()
    cooldown = GAP_AFTER
    blockedPress = false
end

local function lineApplies(line, game)
    if not line.cond then return true end
    local ok, res = pcall(line.cond, game or (active and active.game))
    if not ok then Debug.warn("[Tutorial] cond da fala '" .. tostring(line.id) .. "' falhou: " .. tostring(res)) end
    return ok and res and true or false
end

local function nextLine(game)
    if not active then return end
    local i = active.line + 1
    while i <= #active.def.lines and not lineApplies(active.def.lines[i], game) do i = i + 1 end
    if i <= #active.def.lines then
        active.line = i
        startLine(game)
    else
        finish(true)
    end
end

function Tutorial.inAction()
    local line = curLine()
    return line ~= nil and line.action ~= nil and not Narrator.isRevealing()
end

function Tutorial.mode()
    if not active then return nil end
    return Tutorial.inAction() and "action" or "talk"
end

function Tutorial.update(dt, state, game)
    Narrator.update(dt)
    if game then lastGame = game end
    if Tutorial.enabled() then updateLatches(state, game) else latched = {} end
    if closing then
        closing.t = closing.t + dt
        if closing.t >= FADE_OUT then closing = nil end
    end
    if active then
        active.game = game
        if not stateMatches(active.def, state) then
            finish(false)
            return
        end
        local line = curLine()
        if line.action and game then
            local A = Tutorial.ACTIONS[line.action]
            local ok, done = pcall(A.done, game, active.base or {})
            if ok and done then nextLine(game) end
        end
        return
    end
    if not Tutorial.enabled() then pendingId = nil return end
    if cooldown > 0 then cooldown = cooldown - dt return end
    local IF = require("src.ui.InputFocus")
    local cap = IF.captor and IF.captor()
    if cap and cap ~= Tutorial.overlay then
        local okD = screens.dice and cap == screens.dice
        local okE = screens.endless and cap == screens.endless
        if not (okD or okE) then pendingId = nil return end
    end

    local found = nextCandidate(state, game)
    if not found then pendingId = nil return end
    if pendingId ~= found.id then
        pendingId, pendingSince = found.id, 0
        return
    end
    pendingSince = pendingSince + dt
    if pendingSince >= STABLE_FOR then
        Tutorial._start(found.id, game)
    end
end

function Tutorial._start(id, game)
    local def = byId(id)
    if not def then Debug.warn("[Tutorial] conversa desconhecida: " .. tostring(id)) return false end
    latched[id] = nil
    lastGame = game or lastGame
    active = { def = def, line = 1, shownAt = love.timer.getTime(), game = game,
        base = { hand = game and #(game.hand or {}) or nil } }
    pendingId = nil
    closing = nil
    while active.line <= #def.lines and not lineApplies(def.lines[active.line], game) do
        active.line = active.line + 1
    end
    if active.line > #def.lines then
        active = nil
        PS().markTipSeen(id)
        return false
    end
    startLine(game)
    pcall(function() require("src.systems.Sfx").play("menuOpen") end)
    return true
end

function Tutorial.explain(id, game)
    if active then return false end
    return Tutorial._start(id, game)
end

function Tutorial.activeId() return active and active.def.id end
function Tutorial.activeLine() local l = curLine() return l and l.id end

function Tutorial.advance()
    if not active then return false end
    if Narrator.isRevealing() then
        Narrator.finishReveal()
        return true
    end
    if curLine().action then return false end
    nextLine(active.game)
    return true
end

function Tutorial.skipConversation()
    if not active then return false end
    finish(true)
    return true
end

function Tutorial.disable()
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.tipsEnabled = false
    if active then finish(true) end
    pcall(function()
        local SM = require("engine.SaveManager")
        local cur = SM.loadSettings() or {}
        cur.tipsEnabled = false
        local ok, err = SM.saveSettings(cur)
        if not ok then Debug.warn("[Tutorial] falha ao salvar settings: " .. tostring(err)) end
    end)
end

Tutorial.dismiss = Tutorial.skipConversation

function Tutorial._show(id, lineId, game)
    if not Tutorial._start(id, game) then return false end
    if lineId then
        for i, l in ipairs(active.def.lines) do
            if l.id == lineId then active.line = i; startLine(game) end
        end
    end
    Narrator.finishReveal()
    active.shownAt = love.timer.getTime() - 1
    return true
end
function Tutorial._forceForTests(b) forceTest = b and true or false end
function Tutorial._reset()
    active, closing, pendingId, pendingSince, cooldown = nil, nil, nil, 0, 0
    latched = {}
    blockedPress = false
    anchors = {}
    events = {}
    lastGame = nil
    Narrator._reset()
    Narrator.releaseVoice()
end

function Tutorial.avoidZones()
    local W = realDims()
    return { { x = 0, y = 0, w = W, h = 80 * uiK() } }
end

local function footerFor(line, isFirstOfRun)
    local I18n = require("src.i18n.I18n")
    local okNC, NC = pcall(require, "src.ui.NavCursor")
    local dev = okNC and NC.device and NC.device() or "mouse"
    if not okNC and not Tutorial._navWarned then
        Tutorial._navWarned = true
        Debug.warn("[Tutorial] AVISO: src.ui.NavCursor indisponível — glifos ficam no do teclado")
    end
    local lab = (okNC and NC.labelFor) or function(a) return ({ confirm = "ENTER", back = "ESC", x = "Q" })[a] end
    local f = {}
    if isFirstOfRun then
        f.left = { glyph = lab("x"), label = I18n.t("tutorial.footer.disable"), act = "disable" }
    else
        f.left = { glyph = lab("back"), label = I18n.t("tutorial.footer.skip"), act = "skip" }
    end
    if line and line.action then
        f.right = { glyph = nil, label = I18n.t(Tutorial.ACTIONS[line.action].label), gold = true }
    else
        f.right = { glyph = dev ~= "mouse" and lab("confirm") or nil,
            label = I18n.t("tutorial.footer.continue") }
    end
    return f
end
Tutorial.footerFor = footerFor

function Tutorial.layoutFor(text, spot, line, isFirst, keep)
    local W, H = realDims()
    local k = uiK()
    local footer = footerFor(line, isFirst)
    local size = Narrator.measure(text, k, W, footer)
    local L = Narrator.layout(size, W, H, k, spot, Tutorial.avoidZones(), keep)
    return L, size, footer
end

function Tutorial.draw()
    local W, H = realDims()
    local k = uiK()
    if not active then
        if closing then
            local a = 1 - closing.t / FADE_OUT
            Narrator.drawSpotlight(closing.spot, W, H, k, a, 0.62)
            if closing.L then
                Narrator.drawRaven(closing.L.raven, closing.L.flip, a, k)
            end
        end
        return
    end
    local line = curLine()
    local spot = spotRect(line.spot)
    active.lastSpot = spot
    local isFirst = active.def.id == "intro" and active.line == 1
    local text = lineText(active.def, line, active.game)
    local L, size, footer = Tutorial.layoutFor(text, spot, line, isFirst, active.L and active.L.side)
    active.L, active.size, active.footer = L, size, footer
    local age = love.timer.getTime() - active.shownAt
    local alpha = math.min(1, age / FADE_IN)
    local inAct = Tutorial.inAction()
    local towards = { x = L.bubble.x + L.bubble.w / 2, y = L.bubble.y + L.bubble.h / 2 }
    Narrator.drawSpotlight(spot, W, H, k, alpha, inAct and 0.50 or 0.62, towards)
    local slide = math.floor((1 - alpha) * 40 * k) * (L.flip and 1 or -1)
    love.graphics.push()
    love.graphics.translate(slide, 0)
    Narrator.drawRaven(L.raven, L.flip, alpha, k)
    Narrator.drawBubble(L.bubble, size, alpha, k, L.flip, footer)
    love.graphics.pop()
end

local function inRect(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function footerClick(x, y)
    local f = active and active.footer
    if f and f.left and f.left.rect and inRect(f.left.rect, x, y) then
        if f.left.act == "disable" then Tutorial.disable() else Tutorial.skipConversation() end
        return true
    end
    return false
end

function Tutorial.blocksPointer(x, y, phase)
    if not (active and Tutorial.inAction()) then
        if phase == "released" and blockedPress then blockedPress = false return true end
        return false
    end
    if phase == "pressed" then
        if footerClick(x, y) then blockedPress = true return true end
        local spot = active.lastSpot
        local pad = 10 * uiK()
        local hit = spot and x >= spot.x - pad and x <= spot.x + spot.w + pad
            and y >= spot.y - pad and y <= spot.y + spot.h + pad
        blockedPress = not hit
        return blockedPress
    end
    if blockedPress then blockedPress = false return true end
    return false
end

function Tutorial.blocksKey(key)
    if not (active and Tutorial.inAction()) then return false end
    local A = Tutorial.ACTIONS[curLine().action]
    local gated = { q = true, e = true, x = true, y = true }
    if gated[key] and not (A and A.keys[key]) then return true end
    return false
end

local overlay = { ownsNavigation = true }
function overlay:isVisible() return active ~= nil and not Tutorial.inAction() end
function overlay:hide() if active then finish(false) end end
function overlay:keypressed(key)
    if key == "return" or key == "kpenter" or key == "space" then
        Tutorial.advance()
    elseif key == "escape" then
        Tutorial.skipConversation()
    elseif key == "q" and active and active.def.id == "intro" and active.line == 1 then
        Tutorial.disable()
    end
end
function overlay:mousepressed(x, y, button)
    if button ~= 1 then return end
    if footerClick(x, y) then return end
    Tutorial.advance()
end
function overlay:mousereleased() end
Tutorial.overlay = overlay

return Tutorial
