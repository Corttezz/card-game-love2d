local M = {}

local CARDS = {
    { id = "warrior_adrenaline_rush", label = "rara (glow)" },
    { id = "joker_001",               label = "coringa lendario" },
    { id = "joker_boss_carrion",      label = "coringa do chefe" },
}

local POSES = {
    { label = "repouso" },
    { label = "hover topo",        rx = 0.5,  ry = 0.05 },
    { label = "hover base",        rx = 0.5,  ry = 0.95 },
    { label = "hover sup. esq.",   rx = 0.05, ry = 0.05 },
    { label = "hover inf. dir.",   rx = 0.95, ry = 0.95 },
    { label = "hover lateral dir", rx = 0.95, ry = 0.5 },
}

function M.run()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    local FontManager = require("src.ui.FontManager")
    require("src.ui.HoloShader").load()
    local Card = require("src.cards.base.Card")
    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()

    local tag = os.getenv("BORDAS_TAG") or "atual"
    local W, H = 1600, 900
    local SCALE = 1.5
    local canvas = love.graphics.newCanvas(W, H)
    local realGetTime = love.timer.getTime
    love.timer.getTime = function() return 2.0 end
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.11, 0.09, 0.08, 1)
    love.graphics.setFont(FontManager.getFont(12))
    local colW = W / #POSES
    local rowH = H / #CARDS
    for r, c in ipairs(CARDS) do
        for p, pose in ipairs(POSES) do
            local inst = db:createCardInstance(db:getCard(c.id))
            inst.baseScale, inst.currentScale, inst.targetScale = SCALE, SCALE, SCALE
            inst.deferTooltip = true
            inst._ambientSeed = 0
            if pose.rx then
                local ht = Card.hoverTilt(pose.rx, pose.ry)
                inst.isHovered, inst.hoverStrength = true, 1
                inst.tiltX, inst.tiltY = ht.tiltX, ht.tiltY
                inst.perspectiveRotation = 0
                inst.noHoverLift = true
            else
                inst.isHovered, inst.hoverStrength = false, 0
                inst.tiltX, inst.tiltY = 0, 0
                inst.isDragging = true
            end
            local cx = colW * (p - 1) + colW / 2
            local left = math.floor(cx - 96 * SCALE / 2)
            local top = math.floor(rowH * (r - 1) + 40)
            love.graphics.setColor(1, 1, 1, 1)
            inst:draw(left, top, false, true)
            love.graphics.setColor(0.9, 0.85, 0.7, 1)
            love.graphics.print(c.label .. " / " .. pose.label, colW * (p - 1) + 8, rowH * (r - 1) + 10)
        end
    end
    love.graphics.pop()
    love.timer.getTime = realGetTime
    local name = "bordas_cartas_" .. tag .. ".png"
    canvas:newImageData():encode("png", name)
    print("[bordas_cartas] " .. love.filesystem.getSaveDirectory() .. "/" .. name)
    return true
end

return M
