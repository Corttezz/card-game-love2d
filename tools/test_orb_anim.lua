local TK = require("tools.testkit")
local M = {}

local MIN_LUM = 0.30
local TETO_DOSAGEM = 0.35

local function lumOf(r, g, b) return 0.299 * r + 0.587 * g + 0.114 * b end

local function chave(r, g, b)
    return string.format("%d,%d,%d", math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

function M.run()
    local t = TK.new("orb anim (gemas vivas)")
    local OrbRow = require("src.ui.OrbRow")

    for _, el in ipairs({ "lightning", "ice", "fire", "dark", "holy" }) do
        local anim = OrbRow.animationFor(el)
        if not t:truthy(el .. ": tem frames em " .. OrbRow.ANIM_ROOT, anim ~= nil) then
            goto continua
        end

        local estatico = love.image.newImageData("assets/sprites/orbs/" .. el .. ".png")
        local W, H = estatico:getWidth(), estatico:getHeight()

        local paleta, opacos = {}, 0
        for y = 0, H - 1 do
            for x = 0, W - 1 do
                local r, g, b, a = estatico:getPixel(x, y)
                if a > 0.5 then
                    opacos = opacos + 1
                    paleta[chave(r, g, b)] = true
                end
            end
        end

        local quadros = {}
        for i = 0, #anim.frames - 1 do
            quadros[i] = love.image.newImageData(
                string.format("%s/%s/frame_%03d.png", OrbRow.ANIM_ROOT, el, i))
        end

        local mesmoTamanho, silhuetaOk, contornoOk, paletaOk = true, true, true, true
        local piorMudanca = 0
        for i = 0, #quadros do
            local fd = quadros[i]
            if not fd then break end
            if fd:getWidth() ~= W or fd:getHeight() ~= H then
                mesmoTamanho = false
            else
                local mudados = 0
                for y = 0, H - 1 do
                    for x = 0, W - 1 do
                        local r0, g0, b0, a0 = estatico:getPixel(x, y)
                        local r, g, b, a = fd:getPixel(x, y)
                        if (a0 > 0.5) ~= (a > 0.5) then silhuetaOk = false end
                        if a > 0.5 and not paleta[chave(r, g, b)] then paletaOk = false end
                        if a0 > 0.5 then
                            local mudou = (r ~= r0 or g ~= g0 or b ~= b0)
                            if mudou then
                                mudados = mudados + 1
                                if lumOf(r0, g0, b0) < MIN_LUM then contornoOk = false end
                            end
                        end
                    end
                end
                piorMudanca = math.max(piorMudanca, mudados)
            end
        end

        t:truthy(el .. ": todo frame tem o tamanho da arte (" .. W .. "x" .. H .. ")",
            mesmoTamanho)
        t:truthy(el .. ": silhueta idêntica em todo frame", silhuetaOk)
        t:truthy(el .. ": contorno (lum < " .. MIN_LUM .. ") nunca muda", contornoOk)
        t:truthy(el .. ": nenhuma cor fora da paleta do PNG estático", paletaOk)

        local function igualAoEstatico(fd)
            if not fd then return false end
            for y = 0, H - 1 do
                for x = 0, W - 1 do
                    local r0, g0, b0, a0 = estatico:getPixel(x, y)
                    local r, g, b, a = fd:getPixel(x, y)
                    if r ~= r0 or g ~= g0 or b ~= b0 or (a0 > 0.5) ~= (a > 0.5) then
                        return false
                    end
                end
            end
            return true
        end
        t:truthy(el .. ": frame 0 == arte estática (sem pop ao começar a animar)",
            igualAoEstatico(quadros[0]))
        t:truthy(el .. ": último frame == arte estática (emenda do loop = 0)",
            igualAoEstatico(quadros[#anim.frames - 1]))

        local prop = piorMudanca / math.max(1, opacos)
        t:check(string.format(
            "%s: dosagem no pior frame %.1f%% dos px opacos (teto %.0f%%)",
            el, prop * 100, TETO_DOSAGEM * 100), prop <= TETO_DOSAGEM)

        ::continua::
    end

    local parada = OrbRow.gemImageAt("fire", nil)
    local anim = OrbRow.animationFor("fire")
    t:truthy("sem relógio (reducedMotion) a gema ainda existe", parada ~= nil)
    if anim then
        t:eq("sem relógio a gema é o frame de repouso", parada, anim.frames[1])
    end

    t:eq("tipo inexistente não tem animação", OrbRow.animationFor("plasma"), nil)
    t:noerror("gemImageAt com tipo inexistente não lança",
        function() OrbRow.gemImageAt("plasma", 1.0) end)

    return t:done()
end

return M
