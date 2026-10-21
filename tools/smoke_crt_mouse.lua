local M = {}

function M.run()
    local pass, fail = 0, 0
    local function check(name, cond)
        if cond then pass = pass + 1; print("  [ok] " .. name)
        else fail = fail + 1; print("  [FAIL] " .. name) end
    end

    print("---- smoke: mouse atraves do vidro (CRT) ----")

    local CRTShader = require("src.ui.CRTShader")
    CRTShader.load()
    CRTShader.setEnabled(true)
    CRTShader.setStrength(0.75)
    CRTShader.setPower(1)

    local w, h = love.graphics.getDimensions()

    CRTShader.setEnabled(false)
    local ix, iy = CRTShader.screenToContent(123, 456)
    check("CRT desligado: passthrough exato", ix == 123 and iy == 456)
    CRTShader.setEnabled(true)

    local cx, cy = CRTShader.screenToContent(w / 2, h / 2)
    check("centro fisico ~ centro do conteudo",
        math.abs(cx - w / 2) < 1 and math.abs(cy - h / 2) < 1)

    local _, topY = CRTShader.screenToContent(w / 2, 60)
    check("topo: conteudo mapeado ACIMA do pixel fisico", topY < 60)
    local _, botY = CRTShader.screenToContent(w / 2, h - 60)
    check("base: conteudo mapeado ABAIXO do pixel fisico", botY > h - 60)

    local points = {
        { w * 0.50, 60,       "topo-centro (filtros da Colecao)" },
        { w * 0.20, 110,      "topo-esquerda" },
        { w * 0.85, 110,      "topo-direita" },
        { w * 0.50, h - 40,   "base-centro (HintBar)" },
        { w * 0.08, h * 0.50, "meio-esquerda" },
        { w * 0.92, h * 0.50, "meio-direita" },
        { w * 0.50, h * 0.50, "centro" },
        { w * 0.05, h * 0.07, "canto sup-esq (painel de coringas)" },
        { w * 0.95, h * 0.07, "canto sup-dir (engrenagem)" },
        { w * 0.05, h * 0.93, "canto inf-esq (vida)" },
        { w * 0.95, h * 0.93, "canto inf-dir (orbe de mana)" },
        { w * 0.12, h * 0.15, "perto do canto sup-esq" },
        { w * 0.88, h * 0.85, "perto do canto inf-dir" },
    }

    for _, p in ipairs(points) do
        local px, py, label = p[1], p[2], p[3]

        CRTShader.beginScene()
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", px - 3, py - 3, 7, 7)
        CRTShader.endScene()

        local result = nil
        love.graphics.captureScreenshot(function(imageData)
            local sw, sh = imageData:getWidth(), imageData:getHeight()
            local sumX, sumY, n = 0, 0, 0
            for yy = 0, sh - 1 do
                for xx = 0, sw - 1 do
                    local _, g = imageData:getPixel(xx, yy)
                    if g > 0.5 then
                        sumX = sumX + xx + 0.5
                        sumY = sumY + yy + 0.5
                        n = n + 1
                    end
                end
            end
            if n > 0 then result = { sumX / n, sumY / n, n } end
        end)
        love.graphics.present()

        if not result then
            check(label .. ": marcador VISIVEL na tela", false)
        else
            local qx, qy = result[1], result[2]
            local rx, ry = CRTShader.screenToContent(qx, qy)
            local err = math.sqrt((rx - px) ^ 2 + (ry - py) ^ 2)
            local moved = math.sqrt((qx - px) ^ 2 + (qy - py) ^ 2)
            check(string.format(
                "%s: shader moveu %.1fpx, inverso erra %.2fpx (<=2.5)",
                label, moved, err), err <= 2.5)
        end
    end

    print(string.format("\n  TOTAL: %d pass / %d fail", pass, fail))
    return fail == 0
end

return M
