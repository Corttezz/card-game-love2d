-- tools/orb_zoom.lua — recorta a fileira de orbes de uma captura e amplia.
local M = {}
function M.run(src, escala)
    src = src or "preview_battle_hud_orbs.png"
    escala = tonumber(escala) or 4
    local ok, data = pcall(love.image.newImageData, src)
    if not ok then print("[orb_zoom] nao abriu " .. src); love.event.quit(1); return false end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    -- a fileira fica no terco inferior esquerdo do HUD falso
    local x, y, w, h = 0, math.floor(data:getHeight() * 0.71), math.floor(data:getWidth() * 0.45), math.floor(data:getHeight() * 0.13)
    local cv = love.graphics.newCanvas(w * escala, h * escala)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.10, 0.08, 0.07, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, -x * escala, -y * escala, 0, escala, escala)
    love.graphics.setCanvas()
    cv:newImageData():encode("png", "orb_zoom.png")
    print("[orb_zoom] orb_zoom.png (" .. w * escala .. "x" .. h * escala .. ")")
    love.event.quit(0)
    return true
end
return M
