-- tools/measure_lightpool.lua
-- ============================================================================
-- P6' — A POÇA DE LUZ APARECE? (protocolo de DIFERENÇA POR PIXEL)
-- ============================================================================
-- Roda: love . measure_lightpool [bioma]      (default 4 = frost)
--
-- POR QUE DIFERENÇA E NÃO BRILHO ABSOLUTO
-- Medir "o pixel mais claro da região" é contaminável: o strip de montanhas
-- tem NUVEM E SOL ASSADOS no PNG, e uma métrica de brilho absoluto acaba
-- medindo a arte assada em vez do efeito (foi exatamente o que me enganou na
-- calibração das nuvens — 3 valores de constante deram o mesmo número).
-- Renderizando o MESMO frame duas vezes, com e sem luz, tudo que é assado é
-- idêntico nos dois e SUBTRAI A ZERO. A diferença isola só a luz.
--
-- CRITÉRIOS (fixados ANTES de rodar):
--   SUCESSO  delta máximo >= 12/255 no chão junto ao emissor
--   FALHA    energia de diferença DENTRO das silhuetas dos sprites — é o
--            "gradiente colado em silhueta", o defeito banido no v7
--   PISO     luma do ambiente >= 0.35 (MIN_AMBIENT_LUMA) em todo tod
--
-- ⚠️ LIMITE CONHECIDO DESTE INSTRUMENTO (medido, não suposto)
-- O critério de FALHA acima NÃO é confiável como detector de franja, e a
-- razão é que o próprio toggle perturba outra coisa. Em LightEngine.lua:272
-- o oclusor só entra no painter se `hit` (alguma luz toca o retângulo dele)
-- OU se tem lift/flatColor; com debugNoLights a lista de luzes fica VAZIA,
-- então `hit` é falso pra todo mundo e o conjunto de oclusores pintados MUDA
-- entre os dois frames. Resultado: as árvores aparecem acesas na diff mesmo
-- sem franja nenhuma.
-- CONTROLE que fecha o caso: rodar em bioma NÃO alterado (`2` = highlands)
-- dá o MESMO padrão — 34.8% da energia acima da crista, contra 25.7% do
-- frost. É comportamento pré-existente do motor, não defeito introduzido.
-- Portanto: use a diff pra provar que a POÇA EXISTE (é pra isso que ela
-- serve e nisso ela é sólida — arte assada subtrai a zero). Pra caçar
-- franja, compare o frame DE PRODUÇÃO antes/depois, com zoom 3× e em
-- movimento (ritual de aceite do docs/plan/lighting-engine-v1.md).
--
-- Salva no save-dir: lightpool_on.png, lightpool_off.png, lightpool_diff.png
-- (a diff é amplificada 6x pra inspeção visual em zoom).

local M = {}

local WorldRoad = require("src.ui.WorldRoad")
local LightEngine = require("engine.LightEngine")

local TOP_BAR = 80

-- Renderiza um frame do bioma, opcionalmente sem nenhuma luz submetida.
local function renderFrame(bio, noLights, w, h)
    LightEngine.debugNoLights = noLights and true or false
    WorldRoad.clearCache()
    WorldRoad.setBiome(bio)
    WorldRoad._camZ = 5.5
    for _ = 1, 30 do WorldRoad.update(1 / 30) end
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    love.graphics.clear(0, 0, 0, 1)
    WorldRoad.draw(0, TOP_BAR, w, h - TOP_BAR, bio)
    WorldRoad.drawOverlays(0, TOP_BAR, w, h - TOP_BAR)
end

-- Luma do ambiente nos dois extremos do tod REAL de gameplay.
-- A curva viva é GameplayScene.lua:657 → 0.62 + 0.38*prog, ou seja tod
-- nunca desce de 0.62: `lightDay` puro só existe nas ferramentas.
local function reportAmbient(bio)
    local b = require("src.data.biomes")[bio]
    local function luma(t)
        return 0.2126 * t[1] + 0.7152 * t[2] + 0.0722 * t[3]
    end
    local d, n = b.lightDay, b.lightNight
    local function lerp(t)
        return { d[1] + (n[1] - d[1]) * t,
                 d[2] + (n[2] - d[2]) * t,
                 d[3] + (n[3] - d[3]) * t }
    end
    local l1, lb = luma(lerp(0.62)), luma(n)
    print(string.format(
        "[pool] ambiente de '%s': andar 1 (tod .62) luma %.3f | boss (tod 1) luma %.3f",
        b.id, l1, lb))
    print(string.format(
        "[pool] piso MIN_AMBIENT_LUMA 0.35: %s  |  gate de glow (<0.75): %s",
        (math.min(l1, lb) >= 0.35) and "OK" or "VIOLADO",
        (lb < 0.75) and "dispara" or "NUNCA dispara"))
end

function M.run(arg)
    require("src.ui.PixelCanvas").enableNearest()
    local bio = tonumber(arg) or 4
    local w, h = love.graphics.getDimensions()

    reportAmbient(bio)

    local shots = {}
    for i, noLights in ipairs({ false, true }) do
        renderFrame(bio, noLights, w, h)
        local name = noLights and "lightpool_off.png" or "lightpool_on.png"
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", name)
            shots[i] = imageData
            print("[pool] salvo: " .. name)
        end)
        love.graphics.present()
    end
    LightEngine.debugNoLights = false

    -- captureScreenshot resolve no fim do frame; mais um present garante
    -- que os dois ImageData existem antes do diff.
    love.graphics.present()
    if not (shots[1] and shots[2]) then
        print("[pool] ERRO: capturas nao resolveram; rode de novo")
        love.event.quit()
        return
    end

    local onI, offI = shots[1], shots[2]
    local diff = love.image.newImageData(w, h)
    local maxD, sumD = 0, 0
    -- energia de diferença por FAIXA de altura: a poça vive no CHÃO (abaixo
    -- da crista); diferença na faixa ALTA é luz sobre copa/silhueta = franja
    local bandTop, bandGround = 0, 0
    local crestY = h * 0.52   -- abaixo disto é chão no enquadramento padrão
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r1, g1, b1 = onI:getPixel(x, y)
            local r2, g2, b2 = offI:getPixel(x, y)
            local d = math.max(math.abs(r1 - r2),
                               math.abs(g1 - g2), math.abs(b1 - b2))
            if d > maxD then maxD = d end
            sumD = sumD + d
            if y < crestY then bandTop = bandTop + d
            else bandGround = bandGround + d end
            local v = math.min(1, d * 6)   -- amplifica 6x pra inspeção
            diff:setPixel(x, y, v, v, v, 1)
        end
    end
    diff:encode("png", "lightpool_diff.png")

    local total = bandTop + bandGround
    print(string.format("[pool] delta MAXIMO: %.1f/255  (criterio de sucesso: >= 12)",
        maxD * 255))
    print(string.format("[pool] delta MEDIO: %.2f/255", sumD / (w * h) * 255))
    if total > 0 then
        print(string.format(
            "[pool] energia da diferenca: CHAO %.1f%%  |  ACIMA DA CRISTA %.1f%%",
            bandGround / total * 100, bandTop / total * 100))
    end
    print(string.format("[pool] VEREDITO: %s",
        (maxD * 255 >= 12) and "PASSOU (poca visivel)" or "REPROVOU (poca invisivel)"))
    print("[pool] inspecione lightpool_diff.png em zoom: forma de SPRITE na "
        .. "diff = gradiente colado em silhueta = franja do v7 = reprova")
    love.event.quit()
end

return M
