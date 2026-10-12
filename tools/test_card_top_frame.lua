-- tools/test_card_top_frame.lua
-- O TOPO DA CARTA NÃO PODE SUMIR (dono, Out/2026: "o topo das cartas está
-- cortado — não é só na loja"). Duas réguas:
--
--   1. CANVAS (CardFrame): as 3 linhas do topo, no vão do banner do nome,
--      são a MOLDURA — idênticas a um render só da CardBorder. Antes o banner
--      nascia em y=0 e cobria a faixa de nó (y=1); a gema de custo colava na
--      borda. Vale pra carta comum e pra coringa.
--   2. TELA (Card:draw): a carta desenhada em escala inteira, em repouso, tem
--      as linhas do topo do canvas presentes no lugar certo — nenhum
--      recorte/deslocamento no caminho de desenho (mesh/shader, lift, escala).
--
--   love . test_one test_card_top_frame

local TK = require("tools.testkit")

local M = {}

local function px(img, x, y)
    local r, g, b, a = img:getPixel(x, y)
    return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5), math.floor(a * 255 + 0.5)
end

local function same(a, b, x, y, tol)
    local r1, g1, b1, a1 = px(a, x, y)
    local r2, g2, b2, a2 = px(b, x, y)
    tol = tol or 2
    return math.abs(r1 - r2) <= tol and math.abs(g1 - g2) <= tol
        and math.abs(b1 - b2) <= tol and math.abs(a1 - a2) <= tol
end

function M.run()
    TK.bootstrap()
    local t = TK.new("topo da carta (moldura visível)")
    require("src.ui.PixelCanvas").enableNearest()
    local CardFrame = require("src.ui.CardFrame")
    local CardBorder = require("src.ui.card.components.CardBorder")
    local PixelCanvas = require("src.ui.PixelCanvas")
    local db = require("src.systems.CardDatabase"):new()
    db:loadData()
    local W, H = CardFrame.WIDTH, CardFrame.HEIGHT
    local inset = CardFrame.TOP_INSET or 0
    t:truthy("CardFrame.TOP_INSET >= 3", inset >= 3)

    local ok, err = pcall(function()
        for _, id in ipairs({ "warrior_iron_wave", "warrior_strike", "basic_strike" }) do
            local cd = db:getCard(id)
            if cd then
                local inst = db:createCardInstance(cd)
                local full = inst.image:newImageData()
                -- só a moldura
                local bc = PixelCanvas.new(W, H)
                PixelCanvas.beginDraw(bc)
                CardBorder.draw(W, H, inst.type, inst.rarity or "common", inst.id)
                PixelCanvas.endDraw()
                local border = bc:newImageData()
                local bad = 0
                for y = 0, 2 do   -- 3 linhas fixas: com o banner em y=0 isto falha
                    for x = 16, W - 17 do   -- vão do banner (bx=15, bw=w-30)
                        if not same(full, border, x, y) then bad = bad + 1 end
                    end
                end
                t:eq(id .. ": linhas do topo no vão do banner = moldura (pixels diferentes)", bad, 0)

                -- 2. Card:draw em escala 2, repouso: topo presente e alinhado
                local s = 2
                inst.baseScale, inst.currentScale, inst.targetScale = s, s, s
                inst.isHovered, inst.hoverStrength = false, 0
                local cv = love.graphics.newCanvas(W * s + 80, H * s + 80)
                love.graphics.setCanvas(cv)
                love.graphics.clear(0, 0, 0, 0)
                inst:draw(40, 40, false, true)
                love.graphics.setCanvas()
                local shot = cv:newImageData()
                local r = inst.lastDrawRect
                local ox, oy = math.floor(r.x + 0.5), math.floor(r.y + 0.5)
                local miss = 0
                for y = 0, inset + 2 do
                    for x = 16, W - 17 do
                        local sx, sy = ox + x * s + 1, oy + y * s + 1
                        local r1, g1, b1 = px(full, x, y)
                        local r2, g2, b2 = px(shot, sx, sy)
                        if math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2) > 24 then
                            miss = miss + 1
                        end
                    end
                end
                t:truthy(("%s: Card:draw mostra as linhas do topo do canvas (%d pixels fora)"):format(id, miss),
                    miss <= 4)
            end
        end
        -- 3. ENQUADRAMENTO (dono: "onde começa a sombra do título ela corta"):
        --    NENHUMA linha do sujeito pode ficar acima do topo do slot — a
        --    primeira linha com conteúdo do ícone (bbox) cai dentro do slot;
        --    o corte do cover-fit vai pro pé. Exceção declarada: carta com
        --    artOffsetY/artScale no atlas (sujeito no pé da arte).
        do
            local CardArtSlot = require("src.ui.card.components.CardArtSlot")
            local CardArt = require("src.ui.CardArt")
            local bad, n = {}, 0
            for cid, ccd in pairs(db:getAllCards()) do
                local inst = db:createCardInstance(ccd)
                local art = CardArt.resolve(inst)
                if art and art.icon and art.icon.size and not art.artScale
                    and (art.artOffsetY or 0) == 0 then
                    n = n + 1
                    local ax, ay, aw, ah = CardFrame.artSlotBounds(inst)
                    local _, iy, sc = CardArtSlot.layout(art.icon.size.w, art.icon.size.h,
                        ax, ay, aw, ah, art, art.icon)
                    local subjectTop = iy + CardArtSlot.contentTop(art.icon) * sc
                    if subjectTop < ay then bad[#bad + 1] = cid .. "(" .. (ay - subjectTop) .. "px)" end
                end
            end
            table.sort(bad)
            t:truthy(("ilustração: o topo do sujeito fica dentro do slot em %d cartas (fora: %s)")
                :format(n, #bad == 0 and "nenhuma" or table.concat(bad, ", ")), n > 50 and #bad == 0)
        end

        -- coringa
        for id, cd in pairs(db:getAllCards()) do
            if cd.type == "joker" then
                local inst = db:createCardInstance(cd)
                local full = inst.image:newImageData()
                local opaque = 0
                for x = 14, W - 15 do
                    local _, _, _, a = px(full, x, 1)
                    if a > 0 then opaque = opaque + 1 end
                end
                t:truthy((cd.id or id) .. " (coringa): moldura presente na linha 1 acima do banner",
                    opaque > (W - 29) * 0.5)
                break
            end
        end
    end)
    if not ok then print("  ERRO: " .. tostring(err)) end
    t:truthy("nenhuma excecao", ok)
    return t:done()
end

return M
