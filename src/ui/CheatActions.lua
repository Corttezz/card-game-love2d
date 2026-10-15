local I18n = require("src.i18n.I18n")

local CheatActions = {}

local function CM() return require("src.systems.CheatMode") end

local function always() return true end
local function inRun() return CM().inRun() end
local function inBattle() return CM().inBattle() end

local function nodeLabel(t)
    return function() return require("src.systems.MapManager").labelFor(t) end
end

local function text(key, vars)
    return function() return I18n.t(key, vars) end
end

local NODE_KEYS = {
    { "battle", "b" }, { "elite", "e" }, { "mini_boss", "m" }, { "boss", "c" },
    { "shop", "l" }, { "rest", "d" }, { "event", "v" },
}

local list = nil

local function build()
    local out = {}
    local function add(a) out[#out + 1] = a; return a end

    add({ id = "kill", section = "combat", key = "f2", label = text("cheat.btn.kill"),
          when = inBattle, run = function() CM().kill() end })
    add({ id = "win", section = "combat", key = "f3", label = text("cheat.btn.win"),
          when = inBattle, run = function() CM().winInstant() end })
    add({ id = "die", section = "combat", key = "f4", label = text("cheat.btn.die"),
          when = inBattle, run = function() CM().die() end })
    add({ id = "heal", section = "combat", key = "f5", label = text("cheat.btn.heal"),
          when = inRun, run = function() CM().fullHeal() end })
    add({ id = "god", section = "combat", key = "f6", label = text("cheat.btn.god"),
          when = always, run = function() CM().toggleGod() end,
          on = function() return CM().god end })
    add({ id = "mana", section = "combat", key = "f7", label = text("cheat.btn.mana"),
          when = always, run = function() CM().toggleMana() end,
          on = function() return CM().infiniteMana end })
    add({ id = "hand", section = "combat", key = "f8", label = text("cheat.btn.hand"),
          when = inBattle, run = function() CM().newHand() end })

    for _, nk in ipairs(NODE_KEYS) do
        local t = nk[1]
        add({ id = "node_" .. t, section = "nodes", key = nk[2], ctrl = true,
              label = nodeLabel(t), when = inRun,
              run = function() CM().jumpTo(t) end })
    end
    add({ id = "advance", section = "route", key = "f9", label = text("cheat.btn.advance"),
          when = inRun, run = function() CM().advanceFloor() end })
    add({ id = "act_boss", section = "route", key = "f10", label = text("cheat.btn.act_boss"),
          when = inRun, run = function() CM().goToActBoss() end })
    add({ id = "campaign", section = "route", key = "f11", label = text("cheat.btn.campaign"),
          when = inRun, run = function() CM().winCampaign() end })

    local total = require("src.core.Config").TotalActs or 6
    for n = 1, total do
        add({ id = "act_" .. n, section = "acts", key = tostring(n), ctrl = true,
              label = function() return tostring(n) end, when = inRun,
              run = function() CM().goToAct(n, false) end })
    end
    for n = 1, total do
        add({ id = "act_boss_" .. n, section = "act_bosses", key = tostring(n), ctrl = true,
              shift = true, label = function() return tostring(n) end, when = inRun,
              run = function() CM().goToAct(n, true) end })
    end

    add({ id = "gold", section = "resources", key = "g", ctrl = true,
          label = function() return I18n.t("cheat.btn.gold", { n = CM().GOLD_STEP }) end,
          when = inRun, run = function() CM().addGold() end })
    add({ id = "rare_joker", section = "resources", key = "j", ctrl = true,
          label = text("cheat.btn.rare_joker"), when = inRun,
          run = function() CM().giveRareJoker() end })
    add({ id = "boss_joker", section = "resources", key = "h", ctrl = true,
          label = text("cheat.btn.boss_joker"), when = inRun,
          run = function() CM().giveBossJoker() end })
    add({ id = "force_joker", section = "resources", key = "r", ctrl = true,
          label = text("cheat.btn.force_joker"), when = inRun,
          run = function() CM().forceRareJoker() end,
          on = function() return require("src.systems.ShopSystem").forceNextRewardJoker == true end })

    add({ id = "rush", section = "rush", key = "f12", label = text("cheat.btn.rush"),
          when = always, run = function() CM().toggleRush() end,
          on = function() return CM().rush end })
    return out
end

function CheatActions.list()
    if not list then list = build() end
    return list
end

function CheatActions.byId(id)
    for _, a in ipairs(CheatActions.list()) do
        if a.id == id then return a end
    end
    return nil
end

function CheatActions.forKey(key, ctrl, shift)
    for _, a in ipairs(CheatActions.list()) do
        if a.key == key and (a.ctrl or false) == (ctrl or false)
            and (a.shift or false) == (shift or false) then
            return a
        end
    end
    return nil
end

function CheatActions.isAvailable(a)
    return a ~= nil and (a.when == nil or a.when())
end

function CheatActions.keyLabel(a)
    local k = a.key:upper()
    if a.ctrl and a.shift then return I18n.t("cheat.key.ctrl_shift", { k = k }) end
    if a.ctrl then return I18n.t("cheat.key.ctrl", { k = k }) end
    return k
end

local function ofSection(id)
    local out = {}
    for _, a in ipairs(CheatActions.list()) do
        if a.section == id then out[#out + 1] = a end
    end
    return out
end

function CheatActions.sections(st)
    local cm = CM()
    local inRunNow = cm.inRun()
    local left, right = {}, {}
    if st == "playing" and inRunNow then
        left[#left + 1] = { id = "combat", title = I18n.t("cheat.section.combat"),
            rows = { { per = 2, actions = ofSection("combat") } } }
    end
    if inRunNow then
        left[#left + 1] = { id = "resources", title = I18n.t("cheat.section.resources"),
            rows = { { per = 2, actions = ofSection("resources") } } }
        right[#right + 1] = { id = "run", title = I18n.t("cheat.section.run"), rows = {
            { per = 2, actions = ofSection("nodes") },
            { per = 2, actions = ofSection("route") },
            { per = 6, header = I18n.t("cheat.row.acts"), actions = ofSection("acts") },
            { per = 6, header = I18n.t("cheat.row.act_bosses"), actions = ofSection("act_bosses") },
        } }
    end
    if inRunNow then
        left[#left + 1] = { id = "rush", title = I18n.t("cheat.section.rush"),
            rows = { { per = 1, actions = ofSection("rush") } } }
    end
    if st == "playing" then return { left, right } end
    for _, sec in ipairs(right) do left[#left + 1] = sec end
    return { left }
end

return CheatActions
