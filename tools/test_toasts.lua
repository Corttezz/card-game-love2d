local TK = require("tools.testkit")
local FontManager = require("src.ui.FontManager")

local M = {}

local SIZES = { { 800, 600 }, { 1024, 768 }, { 1920, 1080 }, { 2560, 1440 } }

function M.run(arg)
    TK.bootstrap()
    local t = TK.new("toasts em placa")
    local I18n = require("src.i18n.I18n")
    local MessageSystem = require("src.systems.MessageSystem")
    local realW, realH = love.graphics.getWidth, love.graphics.getHeight
    local savedLocale = I18n.getLocale()

    local ok, err = pcall(function()
        for _, loc in ipairs({ "pt_BR", "de" }) do
            I18n.setLocale(loc)
            for _, sz in ipairs(SIZES) do
                local w, h = sz[1], sz[2]
                love.graphics.getWidth = function() return w end
                love.graphics.getHeight = function() return h end
                FontManager.clearCache()
                local ms = MessageSystem:new()
                ms.maxMessages = 8
                ms:addMessage(I18n.t("messages.armor_capped", { max = 30, wasted = 6 }, "Bloqueio no maximo"), "warning")
                ms:addMessage("Golpe Duplo + Investida: combo de ataque! Dano x1.4 nesta carta e na seguinte", "success")
                ms:addMessage("Sem mana", "error")
                ms:addMessage(I18n.t("messages.act_complete", { n = 2 }, "Ato completo"), "info")
                for _ = 1, 4 do ms:addMessage("Mensagem extra para encher a zona dos avisos", "info") end
                ms:update(0.5)
                local plates, font, zone = ms:layout()
                local tag = ("%s %dx%d"):format(loc, w, h)
                t:truthy(tag .. ": ha placas", #plates > 0)
                for i, p in ipairs(plates) do
                    t:truthy(tag .. " placa " .. i .. " dentro da zona",
                        p.x >= 0 and p.y >= zone.y and p.y + p.h <= zone.y + zone.h + 0.5
                        and p.x + p.w <= w)
                    for _, line in ipairs(p.lines) do
                        if font:getWidth((line:gsub("%s+$", ""))) > p.w - p.padX * 2 - 4 then
                            t:check(tag .. " linha cabe na placa: " .. line, false)
                        end
                    end
                    local nxt = plates[i + 1]
                    if nxt then t:truthy(tag .. " placas " .. i .. "/" .. (i + 1) .. " sem sobrepor",
                        p.y + p.h <= nxt.y) end
                end
                t:eq(tag .. ": a mais NOVA sempre aparece", plates[#plates].m, ms.messages[#ms.messages])

                if arg == "shots" then
                    local canvas = love.graphics.newCanvas(w, h)
                    love.graphics.setCanvas(canvas)
                    love.graphics.clear(0.55, 0.50, 0.40, 1)
                    love.graphics.setColor(0.2, 0.15, 0.1, 1)
                    love.graphics.rectangle("fill", 0, h * 0.62, w, h * 0.38)
                    ms:update(0.3)
                    ms:draw()
                    love.graphics.setCanvas()
                    local name = ("toasts_%dx%d_%s.png"):format(w, h, loc)
                    canvas:newImageData():encode("png", name)
                    print("[toasts] " .. name)
                end
            end
        end
    end)
    if not ok then print("  ERRO: " .. tostring(err)) end
    t:truthy("nenhuma excecao", ok)
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
    FontManager.clearCache()
    I18n.setLocale(savedLocale)
    return t:done()
end

return M
