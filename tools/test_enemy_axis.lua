local TK = require("tools.testkit")
local M = {}

function M.run()
    local t = TK.new("HUD no eixo do corpo")
    local EnemyRenderer = require("src.ui.EnemyRenderer")

    local root = "assets/sprites/characters/enemies"
    local ids = {}
    for _, d in ipairs(love.filesystem.getDirectoryItems(root)) do
        if love.filesystem.getInfo(root .. "/" .. d .. "/animations/idle/south") then
            ids[#ids + 1] = d
        end
    end
    table.sort(ids)
    t:truthy("há inimigos pra medir (" .. #ids .. ")", #ids >= 20)

    local canvas = love.graphics.newCanvas(64, 64)
    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = true }
    local bad = 0
    for _, id in ipairs(ids) do
        EnemyRenderer.clearCache()
        EnemyRenderer.resetRun()
        local m = EnemyRenderer.debugClipMetrics(id, "idle")
        local axis = EnemyRenderer.bodyAxis(id)
        local l = m.w / 2 + m.off - m.cw / 2
        local inside = axis >= l - 0.5 and axis <= l + m.cw + 0.5
        local game = { enemy = { spriteId = id, isBoss = false, health = 10 } }
        love.graphics.setCanvas(canvas)
        local bbox = EnemyRenderer.draw(game, 960, 800, { sizeK = 1 })
        love.graphics.setCanvas()
        local f = EnemyRenderer.getLastFoot()
        local hudOff = (f.bodyX - bbox.cx) / f.scale
        local anchorOff = (f.bodyX - 960) / f.scale
        local ok = inside and math.abs(hudOff) <= 3 and math.abs(anchorOff) <= 1
        if not ok then
            bad = bad + 1
            print(string.format("  [eixo] %s: eixo=%.1f conteudo=[%.1f..%.1f] hud=%.2f ancora=%.2f (px da arte)",
                id, axis, l, l + m.cw, hudOff, anchorOff))
        end
    end
    _G.gameSettings = savedSettings
    t:truthy(string.format("HUD a <= 3 px da arte do corpo e corpo na âncora, em todos os %d inimigos (%d falhas)",
        #ids, bad), bad == 0)

    local axis, src = EnemyRenderer.bodyAxis("winter_monarch")
    t:eq("winter_monarch usa o eixo manual", src, "manual")
    t:eq("...56", axis, 56)

    EnemyRenderer.clearCache()
    EnemyRenderer.resetRun()
    return t:done()
end

return M
