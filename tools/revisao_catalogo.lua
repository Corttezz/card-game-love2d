local M = {}

function M.run(arg)
    require("src.ui.PixelCanvas").enableNearest()
    local WorldRoad = require("src.ui.WorldRoad")
    local biomes = require("src.data.biomes")
    local clutter = require("src.data.ground_clutter").biomes
    local K = 4
    love.filesystem.createDirectory("revisao_catalogo")
    local font = love.graphics.getFont()
    local saved = 0
    for _, b in ipairs(biomes) do
        if not arg or arg == "" or arg == b.id then
            local items = {}
            local names = {}
            for k in pairs(b.propWeights or {}) do names[#names + 1] = k end
            table.sort(names)
            for _, k in ipairs(names) do
                for v = 0, 2 do
                    local _, img = WorldRoad.treeAnim(b.id, k, v)
                    if img and (v == 0 or img ~= items[#items].img) then
                        items[#items + 1] = { name = k .. "_" .. v, img = img }
                    end
                end
            end
            for _, e in ipairs(clutter[b.id] or {}) do
                for v = 0, (e.n or 1) - 1 do
                    local _, img = WorldRoad.treeAnim(b.id, e.kind, v)
                    if img then items[#items + 1] = { name = "chao:" .. e.kind .. "_" .. v, img = img } end
                end
            end
            local W, x, y, rowH = 1900, 8, 8, 0
            local placed = {}
            for _, it in ipairs(items) do
                local iw, ih = it.img:getWidth() * K, it.img:getHeight() * K
                if x + iw > W then x = 8; y = y + rowH + 24; rowH = 0 end
                placed[#placed + 1] = { it = it, x = x, y = y, h = ih }
                x = x + iw + 12
                rowH = math.max(rowH, ih)
            end
            local H = y + rowH + 32
            local cv = love.graphics.newCanvas(W, H)
            love.graphics.setCanvas(cv)
            love.graphics.clear(0.50, 0.38, 0.38, 1)
            for _, p in ipairs(placed) do
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(p.it.name, p.x, p.y)
                love.graphics.draw(p.it.img, p.x, p.y + 16, 0, K, K)
            end
            love.graphics.setCanvas()
            local data = cv:newImageData()
            data:encode("png", "revisao_catalogo/" .. b.id .. ".png")
            data:release()
            cv:release()
            saved = saved + 1
        end
    end
    print(love.filesystem.getSaveDirectory() .. "/revisao_catalogo " .. saved)
    love.event.quit()
    return true
end

return M
