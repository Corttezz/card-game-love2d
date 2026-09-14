-- tools/preview_coinburst.lua
-- Congela a chuva de moedas em 4 instantes e salva um contact sheet.
-- Números provam que a moeda converge; só a imagem prova que ela tem o
-- tamanho e a cor certos na tela.
--   love . preview_coinburst

local M = {}

function M.run()
    local CoinBurst = require("src.ui.CoinBurst")
    local W, H = 420, 260
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false

    local instantes = { 0.10, 0.35, 0.70, 1.20 }
    local canvases = {}

    CoinBurst.clear()
    CoinBurst.spawn(40, W * 0.5, 26, W * 0.5, 190)

    local t, idx = 0, 1
    while idx <= #instantes do
        CoinBurst.update(1 / 60)
        t = t + 1 / 60
        if t >= instantes[idx] then
            local cv = love.graphics.newCanvas(W, H)
            love.graphics.setCanvas(cv)
            love.graphics.clear(0.10, 0.08, 0.07, 1)
            -- marca o destino (o contador da TopBar)
            love.graphics.setColor(0.35, 0.30, 0.22, 1)
            love.graphics.rectangle("fill", 0, 0, W, 40)
            love.graphics.setColor(0.95, 0.80, 0.28, 1)
            love.graphics.circle("line", W * 0.5, 26, 12)
            love.graphics.setColor(1, 1, 1, 1)
            CoinBurst.draw()
            love.graphics.setCanvas()
            canvases[#canvases + 1] = { cv = cv, t = instantes[idx],
                                        n = CoinBurst.count() }
            idx = idx + 1
        end
        if t > 4 then break end
    end

    local sheet = love.graphics.newCanvas(W * #canvases, H)
    love.graphics.setCanvas(sheet)
    love.graphics.clear(0, 0, 0, 1)
    for i, c in ipairs(canvases) do
        love.graphics.draw(c.cv, (i - 1) * W, 0)
    end
    love.graphics.setCanvas()
    sheet:newImageData():encode("png", "coinburst.png")

    for i, c in ipairs(canvases) do
        print(string.format("  t=%.2fs  %d moedas vivas", c.t, c.n))
    end
    print("coinburst.png salvo no diretorio de save")
    love.event.quit(0)
    return true
end

return M
