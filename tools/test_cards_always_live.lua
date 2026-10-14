-- tools/test_cards_always_live.lua
-- CARTA VISIVEL = CARTA VIVA (regra do dono, 13/Out/2026):
--   "a todo momento as cartas que estao sendo exibidas na tela eu quero que
--    elas fiquem com a animacao sendo mostrada. Elas nao podem estar
--    estaticas em NENHUM tipo de visualizacao em nenhum local."
-- Revoga o "idle = estatico, interacao = vivo" de Jul/2026.
--
-- O que esta suite trava:
--   1. A REGRA mora num lugar so (CardFrame.displayImage) e nenhuma tela
--      chama o mecanismo (liveImage) direto — assim o reducedMotion vale em
--      todo lugar de uma vez.
--   2. SEM hover, uma carta com icone animado desenha o quadro VIVO em
--      Card:draw (mao, espolios, loja, pacote, classe, voo do combate), no
--      CardGridRender (Deck Viewer, Gerenciador de Coringas) e na grade da
--      Colecao — e o quadro AVANCA com o relogio simulado.
--   3. reducedMotion REMOVE MOVIMENTO: com a opcao ligada a carta fica no
--      frame 0 (a arte estatica), com ou sem hover.
--   4. PARIDADE DAS CAMADAS: a animacao e composta como base + icone + chrome
--      (3 draws por frame em vez da carta inteira); o frame 0 composto assim
--      tem que ser pixel a pixel o render direto — senao a carta "pisca" a
--      cada volta do loop.
--   5. ORCAMENTO: dezenas de cartas pedindo vida no mesmo quadro ganham vida
--      em ondas (orcamento global por quadro), nunca todas num quadro so.
--
--   love . test_one test_cards_always_live

local TK = require("tools.testkit")

local M = {}

-- Textura de verdade por tras de um drawable (Mesh → sua textura).
local function textureOf(d)
    if type(d) == "userdata" and d.typeOf and d:typeOf("Mesh") then
        return d:getTexture()
    end
    return d
end

-- Executa fn com love.graphics.draw espiao; devolve o conjunto de texturas
-- desenhadas ({ [tex] = true }).
local function spyDraw(fn)
    local real = love.graphics.draw
    local seen = {}
    love.graphics.draw = function(d, ...)
        local tex = textureOf(d)
        if tex then seen[tex] = true end
        return real(d, ...)
    end
    local ok, err = pcall(fn)
    love.graphics.draw = real
    if not ok then error(err, 0) end
    return seen
end

-- Diferenca entre dois canvases: maior desvio de canal (0..255) e quantos
-- pixels divergem por mais de `tol` niveis em algum canal.
local function canvasDiff(a, b, tol)
    local da, db = a:newImageData(), b:newImageData()
    local w, h = da:getWidth(), da:getHeight()
    local maxd, count = 0, 0
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r1, g1, b1, a1 = da:getPixel(x, y)
            local r2, g2, b2, a2 = db:getPixel(x, y)
            local d = math.max(math.abs(r1 - r2), math.abs(g1 - g2),
                math.abs(b1 - b2), math.abs(a1 - a2)) * 255
            if d > maxd then maxd = d end
            if d > tol then count = count + 1 end
        end
    end
    return maxd, count, w * h
end

function M.run()
    local t = TK.new("cartas vivas em toda tela (regra 13/Out/2026)")
    TK.bootstrap()
    require("src.ui.PixelCanvas").enableNearest()

    local CardFrame = require("src.ui.CardFrame")
    local CardDatabase = require("src.systems.CardDatabase")
    local CardArt = require("src.ui.CardArt")
    local IconFramesLoader = require("src.ui.IconFramesLoader")
    local db = CardDatabase:new()

    -- ===================================================================
    -- 1. A REGRA num lugar so — travada no FONTE
    -- ===================================================================
    local function fonte(caminho)
        return love.filesystem.read(caminho) or ""
    end
    local telas = {
        "src/cards/base/Card.lua", "components/CollectionScreen.lua",
        "src/ui/CardGridRender.lua", "src/ui/CardDetailPanel.lua",
        "src/ui/shop/ShelfItem.lua", "src/ui/CardInspectModal.lua",
        "src/ui/UnlockReveal.lua", "components/UnlockShowcase.lua",
        "components/JokerSlot.lua", "components/CardRewardScreen.lua",
    }
    for _, path in ipairs(telas) do
        local src = fonte(path)
        t:truthy(path .. " pergunta a regra (CardFrame.displayImage)",
            src:find("CardFrame%.displayImage") ~= nil
            or src:find('require%("src%.ui%.CardFrame"%)%.displayImage') ~= nil)
        t:falsy(path .. " nao chama o mecanismo (liveImage) direto",
            src:find("%.liveImage%(") ~= nil)
        t:falsy(path .. " nao usa a regra antiga (imageFor/isInteracting)",
            src:find("imageFor") ~= nil or src:find("isInteracting") ~= nil)
    end
    -- varredura ampla: NENHUM arquivo de tela chama liveImage
    local function scan(dir, hits)
        for _, item in ipairs(love.filesystem.getDirectoryItems(dir)) do
            local p = dir .. "/" .. item
            local info = love.filesystem.getInfo(p)
            if info and info.type == "directory" then
                scan(p, hits)
            elseif item:match("%.lua$") and p ~= "src/ui/CardFrame.lua" then
                if fonte(p):find("%.liveImage%(") then hits[#hits + 1] = p end
            end
        end
    end
    local hits = {}
    scan("components", hits); scan("src", hits)
    t:eq("nenhum arquivo em components/ ou src/ chama CardFrame.liveImage (so CardFrame)",
        #hits, 0)
    if #hits > 0 then print("    chamadores: " .. table.concat(hits, ", ")) end
    t:falsy("CardFrame nao exporta mais a regra antiga", CardFrame.imageFor ~= nil
        or CardFrame.isInteracting ~= nil)

    -- ===================================================================
    -- Fixture: cartas animadas de cada tipo
    -- ===================================================================
    local byType, animated = {}, {}
    for _, cd in pairs(db:getAllCards()) do
        local art = CardArt.resolve(cd)
        if art.iconName and IconFramesLoader.has(art.iconName) then
            animated[#animated + 1] = cd
            byType[cd.type] = byType[cd.type] or {}
            table.insert(byType[cd.type], cd)
        end
    end
    table.sort(animated, function(a, b) return a.id < b.id end)
    for _, list in pairs(byType) do
        table.sort(list, function(a, b) return a.id < b.id end)
    end
    t:truthy("catalogo tem cartas animadas", #animated >= 10)
    t:truthy("fixture: ha coringa animado", byType.joker and #byType.joker > 0)

    -- Relogio SIMULADO: o indice do frame e o orcamento por quadro dependem
    -- dele; sob carga o relogio de parede mudaria o resultado de rodada pra
    -- rodada (licao do test_class_select).
    local realGetTime = love.timer.getTime
    local simNow = 1000
    love.timer.getTime = function() return simNow end
    local prevSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }

    -- avanca um quadro de jogo: love.update (CardFrame.update) + relogio
    local function tick()
        simNow = simNow + 1 / 60
        CardFrame.update()
    end
    -- pede a imagem viva ate o set ficar pronto (orcamento por quadro)
    local function warm(inst, maxFrames)
        for _ = 1, maxFrames or 200 do
            tick()
            if CardFrame.liveImage(inst) then return true end
        end
        return false
    end

    local okAll, errAll = pcall(function()
        -- ===============================================================
        -- 4. PARIDADE DAS CAMADAS (frame 0 composto == render direto)
        -- ===============================================================
        local amostras = {}
        for _, ty in ipairs({ "attack", "defense", "effect", "joker" }) do
            if byType[ty] and byType[ty][1] then amostras[#amostras + 1] = { cd = byType[ty][1], up = 0 } end
        end
        amostras[#amostras + 1] = { cd = animated[1], up = 2 }   -- gemas de forja no chrome
        for _, s in ipairs(amostras) do
            local inst = db:createCardInstance(s.cd)
            inst.upgrades = s.up
            CardFrame.invalidate(inst)
            local camadas = CardFrame.render(inst)            -- caminho da animacao (camadas)
            local direto = CardFrame._renderDirectForParity(inst)   -- carta inteira num canvas
            t:truthy(s.cd.id .. " +" .. s.up .. ": carta animada rende pelas camadas", direto ~= nil)
            if camadas then
                local maxd, n, total = canvasDiff(direto, camadas, 2)
                t:check(("%s +%d: frame 0 por camadas == render direto (max %d/255, %d de %d px fora de ±2)")
                    :format(s.cd.id, s.up, maxd, n, total), maxd <= 2 and n == 0)
            end
            CardFrame.invalidate(inst)
        end

        -- ===============================================================
        -- 2. SEM HOVER a carta e VIVA — e o quadro avanca com o relogio
        -- ===============================================================
        local cd = animated[1]
        local inst = db:createCardInstance(cd)
        inst.isHovered, inst.isSelected = false, false
        CardFrame.invalidate(inst)
        inst.image = CardFrame.render(inst)   -- estatico novo (invalidate nao toca instancias)
        t:truthy("set da carta fica pronto sob orcamento", warm(inst))
        local anim = CardFrame.getAnimation(inst)
        t:truthy("animacao tem mais de um frame", anim and #anim.canvases > 1)
        local fps = anim and anim.fps or 8
        local n = anim and #anim.canvases or 9

        -- instante cujo frame NAO e o 0 (o frame 0 E o canvas estatico)
        local function gotoFrame(idx)   -- idx 1-based
            simNow = math.floor(simNow) + (idx - 1 + 0.5) / fps
        end
        gotoFrame(3)
        local f3 = CardFrame.frameAt(anim, simNow)
        t:truthy("frame 3 existe e nao e o estatico", f3 ~= nil and f3 ~= inst.image)
        t:eq("displayImage sem hover devolve o frame corrente (3)", CardFrame.displayImage(inst), f3)
        t:eq("liveImage == displayImage sem reducedMotion", CardFrame.liveImage(inst), f3)

        -- Card:draw (mao, espolios, loja, pacote, classe, combate)
        local seen = spyDraw(function() inst:draw(200, 200, false, false) end)
        t:truthy("Card:draw SEM hover desenha o quadro vivo (frame 3)", seen[f3] == true)
        t:falsy("Card:draw SEM hover nao desenha a estatica", seen[inst.image] == true)
        t:eq("depois do draw, instance.image volta ao estatico (swap temporario)",
            inst.image, anim.canvases[1])

        gotoFrame(6)
        local f6 = CardFrame.frameAt(anim, simNow)
        t:truthy("relogio andou: frame 6 != frame 3", f6 ~= f3)
        seen = spyDraw(function() inst:draw(200, 200, false, false) end)
        t:truthy("Card:draw acompanha o relogio (frame 6)", seen[f6] == true)
        t:falsy("Card:draw nao segura o frame antigo", seen[f3] == true)

        -- hover CONTINUA valendo (nao tira nada)
        inst.isHovered = true
        seen = spyDraw(function() inst:draw(200, 200, false, false) end)
        t:truthy("Card:draw COM hover tambem desenha o quadro vivo", seen[f6] == true)
        inst.isHovered = false

        -- CardGridRender (Deck Viewer, Gerenciador de Coringas) em repouso
        local CardGridRender = require("src.ui.CardGridRender")
        gotoFrame(2)
        local f2 = CardFrame.frameAt(anim, simNow)
        seen = spyDraw(function()
            CardGridRender.draw(inst, 100, 100, 128, 192, 1.0, 1, { 0, 0 }, 0)
        end)
        t:truthy("CardGridRender em repouso desenha o quadro vivo", seen[f2] == true)
        t:falsy("CardGridRender em repouso nao desenha a estatica", seen[inst.image] == true)
        t:eq("CardGridRender restaura instance.image", inst.image, anim.canvases[1])

        -- loop fecha: n quadros depois, o mesmo frame
        gotoFrame(1)
        local f1 = CardFrame.frameAt(anim, simNow)
        simNow = simNow + n / fps
        t:eq("o loop fecha: n quadros depois volta ao mesmo frame", CardFrame.frameAt(anim, simNow), f1)
        t:truthy("o frame 0 (estatico) faz parte do loop", (function()
            for i = 0, n - 1 do
                if CardFrame.frameAt(anim, simNow + i / fps) == inst.image then return true end
            end
            return false
        end)())

        -- ===============================================================
        -- 3. reducedMotion REMOVE MOVIMENTO: frame 0, com ou sem hover
        -- ===============================================================
        _G.gameSettings.reducedMotion = true
        gotoFrame(4)
        t:falsy("reducedMotion: liveEnabled() e falso", CardFrame.liveEnabled())
        t:eq("reducedMotion: displayImage devolve a estatica", CardFrame.displayImage(inst), inst.image)
        seen = spyDraw(function() inst:draw(200, 200, false, false) end)
        t:truthy("reducedMotion: Card:draw desenha a estatica", seen[inst.image] == true)
        t:falsy("reducedMotion: Card:draw nao desenha frame animado",
            seen[CardFrame.frameAt(anim, simNow)] == true)
        inst.isHovered = true
        seen = spyDraw(function() inst:draw(200, 200, false, false) end)
        t:truthy("reducedMotion + hover: continua estatica (movimento nao volta)",
            seen[inst.image] == true and seen[CardFrame.frameAt(anim, simNow)] ~= true)
        inst.isHovered = false
        seen = spyDraw(function()
            CardGridRender.draw(inst, 100, 100, 128, 192, 1.0, 1, { 0, 0 }, 0)
        end)
        t:truthy("reducedMotion: CardGridRender desenha a estatica", seen[inst.image] == true)
        _G.gameSettings.reducedMotion = false
        t:eq("movimento de volta: displayImage volta ao quadro vivo",
            CardFrame.displayImage(inst), CardFrame.frameAt(anim, simNow))

        -- ===============================================================
        -- 5. ORCAMENTO: muitas cartas no mesmo quadro ganham vida em ondas
        -- ===============================================================
        CardFrame.clearCache()
        local N = math.min(#animated, 20)
        local insts = {}
        for i = 1, N do insts[i] = db:createCardInstance(animated[i]) end
        -- (createCardInstance ja renderizou o estatico de cada uma)
        local liveAfter = {}
        local frames = 0
        local allLive = false
        while frames < 400 and not allLive do
            tick()
            frames = frames + 1
            allLive = true
            local live = 0
            for i = 1, N do
                if CardFrame.liveImage(insts[i]) then live = live + 1 else allLive = false end
            end
            liveAfter[frames] = live
        end
        t:truthy(("%d cartas pedidas por quadro: todas vivas em %d quadros"):format(N, frames), allLive)
        t:truthy("nao e tudo num quadro so (orcamento espalha a montagem)",
            frames > 1 and (liveAfter[1] or 0) < N)
        -- por carta: n PNGs decodificados + (n-1) composicoes (+ camadas quando
        -- nao estao em cache), BUILD_PER_FRAME unidades por quadro; sob relogio
        -- simulado o teto de tempo nao morde (spent = 0), so a contagem
        local teto = math.ceil(N * 2 * n / CardFrame.BUILD_PER_FRAME) + N + 2
        t:truthy(("montagem termina dentro do teto do orcamento (%d <= %d quadros)"):format(frames, teto),
            frames <= teto)
        -- em uso no mesmo quadro: nenhuma e expulsa
        t:truthy("todas continuam vivas no quadro seguinte", (function()
            tick()
            for i = 1, N do if not CardFrame.liveImage(insts[i]) then return false end end
            return true
        end)())

        -- ===============================================================
        -- 2b. COLECAO: a grade inteira viva sem hover (desenho real da tela)
        -- ===============================================================
        local UnlockSystem = require("src.systems.UnlockSystem")
        if UnlockSystem.setRevealAll then UnlockSystem.setRevealAll(true) end
        local CollectionScreen = require("components.CollectionScreen")
        local screen = CollectionScreen:new()
        screen:show(function() end)
        for _ = 1, 400 do
            if screen._buildDone then break end
            screen:_buildInstances(1)
        end
        screen:_applyFilter()
        local realMouse = love.mouse.getPosition
        love.mouse.getPosition = function() return 2, 2 end   -- longe da grade
        local W, H = love.graphics.getDimensions()
        local canvas = love.graphics.newCanvas(W, H)
        local okC, errC = pcall(function()
            -- deixa as visiveis ganharem vida
            for _ = 1, 120 do
                tick()
                screen:update(1 / 60)
                love.graphics.setCanvas(canvas)
                screen:draw()
                love.graphics.setCanvas()
            end
            gotoFrame(5)
            local seenCol = spyDraw(function()
                screen:update(1 / 60)
                love.graphics.setCanvas(canvas)
                screen:draw()
                love.graphics.setCanvas()
            end)
            -- cartas animadas DESENHADAS neste quadro (algum canvas do set
            -- apareceu no draw): TODAS desenharam o frame corrente, NENHUMA
            -- a estatica
            local desenhadas, vivas, estaticas = 0, 0, 0
            for _, ci in ipairs(screen.filtered or {}) do
                local artC = CardArt.resolve(ci)
                if not ci._hidden and artC.iconName and IconFramesLoader.has(artC.iconName) then
                    local an = CardFrame.getAnimation(ci)
                    local drawn = false
                    if an then
                        for _, cv in ipairs(an.canvases) do
                            if seenCol[cv] then drawn = true end
                        end
                    end
                    if seenCol[ci.image] then drawn = true end
                    if drawn then
                        desenhadas = desenhadas + 1
                        local cur = an and CardFrame.frameAt(an, simNow)
                        if cur and seenCol[cur] then vivas = vivas + 1 end
                        if seenCol[ci.image] and cur ~= ci.image then estaticas = estaticas + 1 end
                    end
                end
            end
            t:truthy("colecao: ha cartas animadas desenhadas na grade", desenhadas >= 5)
            t:eq(("colecao sem hover: todas as %d desenhadas mostram o quadro vivo"):format(desenhadas),
                vivas, desenhadas)
            t:eq("colecao sem hover: nenhuma desenhou a estatica", estaticas, 0)
        end)
        love.mouse.getPosition = realMouse
        if UnlockSystem.setRevealAll then UnlockSystem.setRevealAll(false) end
        if screen.hide then pcall(screen.hide, screen) end
        if not okC then error(errC, 0) end
    end)

    love.timer.getTime = realGetTime
    _G.gameSettings = prevSettings
    CardFrame.clearCache()
    t:check("cenario roda sem excecao" .. (okAll and "" or (": " .. tostring(errAll))), okAll)

    return t:done()
end

return M
