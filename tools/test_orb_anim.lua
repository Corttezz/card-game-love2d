-- tools/test_orb_anim.lua
-- Trava do loop idle das GEMAS do mago (assets/sprites/orbs_anim/).
--
-- O pedido do dono foi "animações bem sutis, bem sutíssimas" numa arte que o
-- jogador usa como INFORMAÇÃO: a cor diz o elemento e a pedra fica colada na
-- placa do número que ele lê pra decidir. Então "sutil" aqui não é gosto, é
-- contrato, e contrato se mede. Cada bloco abaixo é uma forma de a animação
-- estragar a leitura, virada do avesso:
--
--   silhueta   nenhum pixel opaco vira transparente (nem o contrário) —
--              a gema nunca "muda de forma" nem respira de tamanho;
--   contorno   pixel escuro (a borda) é idêntico em todo frame — é a borda que
--              define a pedra contra o fundo escuro da HUD;
--   paleta     nenhuma cor nova em frame nenhum: a paleta do animado é
--              subconjunto da do parado, então a COR DO ELEMENTO não pode
--              derivar (foi exatamente assim que os frames de PixelLab
--              falharam — fogo desbotando pra pêssego);
--   emenda     frame 0 e último frame são o PNG estático, pixel a pixel: sem
--              pop na volta do loop e sem pop entre parado e vivo;
--   dosagem    teto de pixels que mudam no pior frame — é o número que impede
--              alguém re-assar com faixa larga e transformar "cintilar" em
--              "piscar".
--
-- Roda em tools/ como todas as suites: love . test_one test_orb_anim

local TK = require("tools.testkit")
local M = {}

-- Mesmo corte do tools/bake_orb_anim.lua (pixel de contorno nunca é tocado).
local MIN_LUM = 0.30
-- Teto de dosagem: no pior frame, no máximo 35% dos pixels opacos podem ter
-- mudado. A safra assada em Set/2026 vai de 16% (sombra) a 29% (sagrado); 35%
-- é folga pra ajuste fino sem abrir espaço pra faixa larga de novo.
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
            -- Sem frames não há o que medir; as outras asserções mentiriam.
            goto continua
        end

        local estatico = love.image.newImageData("assets/sprites/orbs/" .. el .. ".png")
        local W, H = estatico:getWidth(), estatico:getHeight()

        -- Paleta do parado + máscara de opacidade + quem é contorno.
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

        -- EMENDA: os dois extremos do ciclo são o PNG parado. Isso é mais forte
        -- que a regra de "diferença da emenda <= 1,6x a de um passo": aqui a
        -- diferença é ZERO, então não há emenda a medir — a faixa de luz nasce e
        -- morre fora da pedra.
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

    -- reducedMotion tira o MOVIMENTO, nunca a INFORMAÇÃO: sem relógio a gema
    -- continua sendo desenhada, congelada no quadro de repouso.
    local parada = OrbRow.gemImageAt("fire", nil)
    local anim = OrbRow.animationFor("fire")
    t:truthy("sem relógio (reducedMotion) a gema ainda existe", parada ~= nil)
    if anim then
        t:eq("sem relógio a gema é o frame de repouso", parada, anim.frames[1])
    end

    -- Tipo desconhecido não pode explodir nem inventar animação.
    t:eq("tipo inexistente não tem animação", OrbRow.animationFor("plasma"), nil)
    t:noerror("gemImageAt com tipo inexistente não lança",
        function() OrbRow.gemImageAt("plasma", 1.0) end)

    return t:done()
end

return M
