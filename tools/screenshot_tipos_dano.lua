local M = {}

local W, H = 1920, 1080

local CROPS = {
    fire = { "warrior_immolate", "mage_fireball", "joker_boss_tyrant" },
    ice = { "mage_frost_nova", "mage_blizzard", "joker_boss_lich" },
    lightning = { "mage_zap", "mage_twin_bolts", "mage_electrodynamics" },
    dark = { "mage_doom_and_gloom", "mage_arcane_orb", "warrior_dark_embrace" },
    arcane = { "mage_arcane_torrent", "mage_mind_spike", "mage_crystal_shard" },
    poison = { "rogue_poison_dart", "rogue_twin_fangs", "rogue_toxin_master" },
    holy = { "mage_radiant_prayer", "mage_healing_drop", "mage_sacred_chalice" },
    physical = { "warrior_strike", "rogue_executioner", "warrior_flame_barrier" },
}
local CROP_ORDER = { "fire", "ice", "lightning", "dark", "arcane", "poison", "holy", "physical" }

local function outDir()
    local d = love.filesystem.getSource() .. "/tools/preview_out/tipos_dano/"
    os.execute('mkdir "' .. d:gsub("/", "\\") .. '" 2>nul')
    return d
end

local outs = {}

local function save(cv, dir, name)
    local data = cv:newImageData()
    local f = assert(io.open(dir .. name, "wb"))
    f:write(data:encode("png"):getString())
    f:close()
    data:release()
    outs[#outs + 1] = dir .. name
end

local function fakeWindow(w, h)
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    end
end

local ORDER = { basic = 1, warrior = 2, mage = 3, rogue = 4, boss = 5 }

local function allCards(db)
    local list = {}
    for id, cd in pairs(db:getAllCards()) do list[#list + 1] = cd end
    table.sort(list, function(a, b)
        local ca, cb = ORDER[a.class or "basic"] or 9, ORDER[b.class or "basic"] or 9
        if ca ~= cb then return ca < cb end
        local R = require("src.systems.Resistances")
        local ta, tb = R.badgeOf(a) or "~", R.badgeOf(b) or "~"
        if ta ~= tb then return ta < tb end
        return a.id < b.id
    end)
    return list
end

local function sheets(dir, db)
    local CardFrame = require("src.ui.CardFrame")
    local FontManager = require("src.ui.FontManager")
    local R = require("src.systems.Resistances")
    local list = allCards(db)
    local CW, CH, GAP, TOP = 96, 144, 4, 6
    local cols = math.floor((W - GAP) / (CW + GAP))
    local rows = math.floor((H - TOP) / (CH + 2 + GAP))
    local per = cols * rows
    local page = 0
    local i = 1
    while i <= #list do
        page = page + 1
        local cv = love.graphics.newCanvas(W, H)
        love.graphics.setCanvas(cv)
        love.graphics.clear(0.07, 0.05, 0.04, 1)
        local font = FontManager.getFont(8)
        love.graphics.setFont(font)
        for k = 0, per - 1 do
            local cd = list[i]
            if not cd then break end
            local col, row = k % cols, math.floor(k / cols)
            local x = GAP + col * (CW + GAP)
            local y = TOP + row * (CH + 2 + GAP)
            local inst = db:createCardInstance(cd)
            local img = CardFrame.displayImage(inst) or inst.image
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, x, y)
            i = i + 1
        end
        love.graphics.setCanvas()
        save(cv, dir, ("todas_cartas_%d_%dx%d.png"):format(page, W, H))
        cv:release()
        love.graphics.present()
    end
end

local function crops(dir, db)
    local CardFrame = require("src.ui.CardFrame")
    local S, GAP = 3, 12
    for _, el in ipairs(CROP_ORDER) do
        local ids = CROPS[el]
        local cw = #ids * (96 * S + GAP) + GAP
        local ch = 144 * S + GAP * 2
        local cv = love.graphics.newCanvas(cw, ch)
        cv:setFilter("nearest", "nearest")
        love.graphics.setCanvas(cv)
        love.graphics.clear(0.07, 0.05, 0.04, 1)
        for k, id in ipairs(ids) do
            local inst = db:createCardInstance(db:getCard(id))
            local img = inst.image
            img:setFilter("nearest", "nearest")
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, GAP + (k - 1) * (96 * S + GAP), GAP, 0, S, S)
        end
        love.graphics.setCanvas()
        save(cv, dir, ("recorte_3x_%s.png"):format(el))
        cv:release()
        love.graphics.present()
    end
end

local function collection(dir)
    local UiScale = require("src.ui.UiScale")
    local FontManager = require("src.ui.FontManager")
    local CardFrame = require("src.ui.CardFrame")
    local restore = fakeWindow(W, H)
    UiScale.force(nil)
    UiScale.adoptDefaults()
    FontManager.clearCache()
    local realMouse = love.mouse.getPosition
    local mx, my = -100, -100
    love.mouse.getPosition = function() return mx, my end
    local ok, err = pcall(function()
        require("src.systems.UnlockSystem").setRevealAll(true)
        local c = require("components.CollectionScreen"):new()
        c:show(function() end)
        for _ = 1, 400 do
            if c._buildDone then break end
            c:_buildInstances(1)
        end
        for _, f in ipairs({ "mage", "rogue", "warrior" }) do
            c.filter = f
            c:_applyFilter()
            c.scrollY = 0
            for _ = 1, 90 do
                CardFrame.update()
                c:update(1 / 30)
            end
            local cv = love.graphics.newCanvas(W, H)
            love.graphics.setCanvas(cv)
            love.graphics.clear(0.05, 0.04, 0.08, 1)
            c:draw()
            love.graphics.setCanvas()
            save(cv, dir, ("colecao_%s_%dx%d.png"):format(f, W, H))
            cv:release()
            love.graphics.present()
        end
        c:hide()
    end)
    love.mouse.getPosition = realMouse
    UiScale.reset()
    restore()
    FontManager.clearCache()
    if not ok then print("[screenshot_tipos_dano] FALHOU colecao: " .. tostring(err)) end
end

local function tooltips(dir, db)
    local CID = require("src.ui.CardInfoDisplay")
    local restore = fakeWindow(W, H)
    local cv = love.graphics.newCanvas(W, 420)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.07, 0.05, 0.04, 1)
    local d = CID:new()
    local x = 40
    for _, id in ipairs({ "mage_fireball", "rogue_poison_dart", "mage_radiant_prayer", "warrior_strike" }) do
        local inst = db:createCardInstance(db:getCard(id))
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(inst.image, x, 260, 0, 1, 1)
        d:draw(inst, x, 250, { minY = 10 })
        x = x + 470
    end
    love.graphics.setCanvas()
    save(cv, dir, "tooltip_tipo.png")
    cv:release()
    restore()
    love.graphics.present()
end

function M.run()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("pt_BR")
    require("src.ui.PixelCanvas").enableNearest()
    local dir = outDir()
    local db = require("src.systems.CardDatabase"):new()
    sheets(dir, db)
    crops(dir, db)
    tooltips(dir, db)
    collection(dir)
    for _, p in ipairs(outs) do print("[screenshot_tipos_dano] " .. p) end
    print("[screenshot_tipos_dano] TOTAL " .. #outs)
    return true
end

return M
