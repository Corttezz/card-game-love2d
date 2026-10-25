local M = {}

local W, H = 1920, 1080

local PER_ELEMENT = {
    { "fire", "mage_fireball" },
    { "ice", "mage_frost_nova" },
    { "lightning", "mage_zap" },
    { "dark", "mage_doom_and_gloom" },
    { "arcane", "mage_arcane_torrent" },
    { "poison", "rogue_poison_dart" },
    { "holy", "mage_radiant_prayer" },
    { "physical", "warrior_strike" },
}

local function outDir()
    local d = love.filesystem.getSource() .. "/tools/preview_out/tipos_dano/v2/"
    os.execute('mkdir "' .. d:gsub("/", "\\") .. '" 2>nul')
    return d
end

local outs = {}

local function saveData(data, dir, name)
    local f = assert(io.open(dir .. name, "wb"))
    f:write(data:encode("png"):getString())
    f:close()
    outs[#outs + 1] = dir .. name
end

local function save(cv, dir, name)
    local data = cv:newImageData()
    saveData(data, dir, name)
    data:release()
end

local function crop3x(data, dir, name, x, y, w, h)
    local S = 3
    local iw, ih = data:getDimensions()
    x, y = math.max(0, math.floor(x)), math.max(0, math.floor(y))
    w, h = math.min(w, iw - x), math.min(h, ih - y)
    local out = love.image.newImageData(w * S, h * S)
    for py = 0, h - 1 do
        for px = 0, w - 1 do
            local r, g, b, a = data:getPixel(x + px, y + py)
            for dy = 0, S - 1 do
                for dx = 0, S - 1 do out:setPixel(px * S + dx, py * S + dy, r, g, b, a) end
            end
        end
    end
    saveData(out, dir, name)
    out:release()
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
    for _, cd in pairs(db:getAllCards()) do list[#list + 1] = cd end
    table.sort(list, function(a, b)
        local ca, cb = ORDER[a.class or "basic"] or 9, ORDER[b.class or "basic"] or 9
        if ca ~= cb then return ca < cb end
        return a.id < b.id
    end)
    return list
end

local function sheets(dir, db)
    local CardFrame = require("src.ui.CardFrame")
    local list = allCards(db)
    local CW, CH, GAP, TOP = 96, 144, 4, 6
    local cols = math.floor((W - GAP) / (CW + GAP))
    local rows = math.floor((H - TOP) / (CH + 2 + GAP))
    local per = cols * rows
    local page, i = 0, 1
    while i <= #list do
        page = page + 1
        local cv = love.graphics.newCanvas(W, H)
        love.graphics.setCanvas(cv)
        love.graphics.clear(0.07, 0.05, 0.04, 1)
        for k = 0, per - 1 do
            local cd = list[i]
            if not cd then break end
            local x = GAP + (k % cols) * (CW + GAP)
            local y = TOP + math.floor(k / cols) * (CH + 2 + GAP)
            local inst = db:createCardInstance(cd)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(inst.image, x, y)
            i = i + 1
        end
        love.graphics.setCanvas()
        save(cv, dir, ("cartas_limpas_%d_%dx%d.png"):format(page, W, H))
        cv:release()
        love.graphics.present()
    end
    local cv = love.graphics.newCanvas(3 * (96 * 3 + 12) + 12, 144 * 3 + 24)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.07, 0.05, 0.04, 1)
    for k, id in ipairs({ "mage_fireball", "rogue_poison_dart", "joker_boss_lich" }) do
        local inst = db:createCardInstance(db:getCard(id))
        inst.image:setFilter("nearest", "nearest")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(inst.image, 12 + (k - 1) * (96 * 3 + 12), 12, 0, 3, 3)
    end
    love.graphics.setCanvas()
    save(cv, dir, "cartas_limpas_recorte_3x.png")
    cv:release()
end

local function tooltips(dir, db)
    local CID = require("src.ui.CardInfoDisplay")
    local restore = fakeWindow(W, H)
    local cv = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.07, 0.05, 0.04, 1)
    local rects = {}
    for k, pe in ipairs(PER_ELEMENT) do
        local col, row = (k - 1) % 4, math.floor((k - 1) / 4)
        local x, y = 60 + col * 470, 300 + row * 520
        local inst = db:createCardInstance(db:getCard(pe[2]))
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(inst.image, x + 20, y, 0, 1.333, 1.333)
        local d = CID:new()
        d:draw(inst, x, y - 10, { minY = 10 + row * 520 })
        rects[k] = d.lastElementRect
    end
    love.graphics.setCanvas()
    local data = cv:newImageData()
    saveData(data, dir, ("tooltip_por_elemento_%dx%d.png"):format(W, H))
    for k, pe in ipairs(PER_ELEMENT) do
        local r = rects[k]
        if r then crop3x(data, dir, ("tooltip_linha_3x_%s.png"):format(pe[1]), r.x - 4, r.y - 4, 260, 24) end
    end
    data:release()
    cv:release()
    restore()
    love.graphics.present()
end

local function inspects(dir, db)
    local UiScale = require("src.ui.UiScale")
    local FontManager = require("src.ui.FontManager")
    local CardFrame = require("src.ui.CardFrame")
    local restore = fakeWindow(W, H)
    UiScale.force(nil)
    UiScale.adoptDefaults()
    FontManager.clearCache()
    local realMouse = love.mouse.getPosition
    love.mouse.getPosition = function() return -100, -100 end
    local ok, err = pcall(function()
        require("src.systems.UnlockSystem").setRevealAll(true)
        local c = require("components.CollectionScreen"):new()
        c:show(function() end)
        for _ = 1, 400 do
            if c._buildDone then break end
            c:_buildInstances(1)
        end
        for _, pe in ipairs(PER_ELEMENT) do
            local inst = db:createCardInstance(db:getCard(pe[2]))
            c.inspectedCard, c.inspectAnim = inst, 1
            for _ = 1, 20 do
                CardFrame.update()
                c:update(1 / 30)
            end
            c.inspectAnim = 1
            local cv = love.graphics.newCanvas(W, H)
            love.graphics.setCanvas(cv)
            love.graphics.clear(0.05, 0.04, 0.08, 1)
            c:draw()
            love.graphics.setCanvas()
            local data = cv:newImageData()
            saveData(data, dir, ("colecao_inspecao_%s_%dx%d.png"):format(pe[1], W, H))
            local r = c._elementRect
            if r then
                crop3x(data, dir, ("colecao_inspecao_linha_3x_%s.png"):format(pe[1]),
                    (r.sx or r.x) - 8, (r.sy or r.y) - 8, 460, 40)
            end
            data:release()
            cv:release()
            love.graphics.present()
        end
        c.inspectedCard, c.inspectAnim = nil, 0
        c:hide()
    end)
    love.mouse.getPosition = realMouse
    UiScale.reset()
    restore()
    FontManager.clearCache()
    if not ok then print("[screenshot_tipos_dano] FALHOU inspecao: " .. tostring(err)) end
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
    tooltips(dir, db)
    inspects(dir, db)
    for _, p in ipairs(outs) do print("[screenshot_tipos_dano] " .. p) end
    print("[screenshot_tipos_dano] TOTAL " .. #outs)
    return true
end

return M
