-- tools/test_card_live_hover.lua
-- A carta ANIMA quando o jogador mexe nela — em TODA tela que desenha carta.
--
-- O defeito (Set/2026, dono jogando): "na tela de seu deck dentro do jogo, ao
-- fazer hover ou clicar em uma carta, nao fica com animacao".
--
-- A regra do projeto e "idle = estatico, interacao = vivo" (CLAUDE.md §14), e
-- a documentacao LISTAVA o deck viewer entre as telas cobertas. O codigo nao
-- cobria: a troca pela imagem viva morava INLINE na CollectionScreen, com os
-- limiares cravados como numeros magicos, e nunca foi extraida para o
-- `CardGridRender` — que e justamente o renderizador COMPARTILHADO do Deck
-- Viewer e do Gerenciador de Coringas.
--
-- O detalhe que fez isso durar: o cabecalho do CardGridRender AFIRMA que o
-- caminho e "IDENTICO ao drawCardMini da CollectionScreen", com "icone vivo"
-- na lista. Comentario que promete paridade nao a garante — so o codigo
-- garante, e so o teste prova.
--
--   love . test_one test_card_live_hover

local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("carta viva no hover")
    TK.bootstrap()

    local CardFrame = require("src.ui.CardFrame")

    -- ===================================================================
    -- 1. O PREDICADO — a regra num lugar so
    -- ===================================================================
    t:falsy("parada: sem hover e sem forca",
        CardFrame.isInteracting(1.0, 0))
    t:falsy("ruido de easing nao conta como interacao",
        CardFrame.isInteracting(1.0005, 0.01))
    t:truthy("hover pela ESCALA (grid levanta a carta)",
        CardFrame.isInteracting(1.08, 0))
    t:truthy("hover pela FORCA (warp/tilt ja rodando)",
        CardFrame.isInteracting(1.0, 0.5))
    t:truthy("argumentos ausentes nao estouram",
        CardFrame.isInteracting(1.2) == true and CardFrame.isInteracting() == false)

    -- ===================================================================
    -- 2. `imageFor` devolve a VIVA na interacao e a ESTATICA em repouso
    -- ===================================================================
    -- Carta sem animacao: nunca pode deixar de desenhar. O fallback pra
    -- `card.image` e o que garante isso — sem ele, carta sem frames sumiria
    -- da tela no hover, trocando um defeito visual por um pior.
    -- O `liveImage` real e estubado nos dois casos DE PROPOSITO. A primeira
    -- versao deste teste usou uma carta falsa achando que ela "nao teria
    -- animacao" — e o `CardArt.resolve` caiu num icone por TIPO que TEM
    -- frames, entao o teste recebeu um Canvas onde esperava a estatica. O
    -- fixture e que estava errado, nao o codigo: aqui se testa a REGRA
    -- (quando pedir o vivo), nao o catalogo de arte.
    local liveOriginal = CardFrame.liveImage

    local semAnim = { id = "tk_sem_anim", image = "IMG_ESTATICA" }
    CardFrame.liveImage = function() return nil end
    t:eq("carta sem animacao: parada devolve a estatica",
        CardFrame.imageFor(semAnim, 1.0, 0), "IMG_ESTATICA")
    t:eq("carta sem animacao: no hover TAMBEM devolve a estatica (nao some)",
        CardFrame.imageFor(semAnim, 1.08, 0.5), "IMG_ESTATICA")
    t:eq("carta nula nao estoura", CardFrame.imageFor(nil, 1.08, 0.5), nil)

    -- Carta COM animacao: o vivo so aparece na interacao.
    local viva = { id = "tk_com_anim", image = "IMG_ESTATICA" }
    CardFrame.liveImage = function(c)
        return (c and c.id == "tk_com_anim") and "IMG_VIVA" or nil
    end

    t:eq("carta animada em REPOUSO desenha a estatica (idle = estatico)",
        CardFrame.imageFor(viva, 1.0, 0), "IMG_ESTATICA")
    t:eq("carta animada no HOVER desenha a VIVA",
        CardFrame.imageFor(viva, 1.08, 0), "IMG_VIVA")
    t:eq("carta animada com warp rodando desenha a VIVA",
        CardFrame.imageFor(viva, 1.0, 0.5), "IMG_VIVA")

    CardFrame.liveImage = liveOriginal

    -- ===================================================================
    -- 3. PARIDADE ENTRE AS TELAS — a trava que o defeito pedia
    -- ===================================================================
    -- O Deck Viewer e o Gerenciador de Coringas desenham por
    -- `CardGridRender`; a Colecao tem o seu proprio `drawCardMini`. As DUAS
    -- rotas tem que consultar a mesma regra. Conferido no FONTE porque
    -- exercitar o desenho exige contexto grafico — e o que importa aqui e
    -- que ninguem volte a cravar o limiar inline.
    local function fonte(caminho)
        local f = love.filesystem.read(caminho)
        return f or ""
    end

    local grid = fonte("src/ui/CardGridRender.lua")
    t:truthy("CardGridRender pergunta a regra (imageFor/isInteracting)",
        grid:find("CardFrame%.imageFor") ~= nil
            or grid:find("CardFrame%.isInteracting") ~= nil)
    t:truthy("CardGridRender restaura a imagem original depois de desenhar",
        grid:find("_prevImage") ~= nil)

    local colecao = fonte("components/CollectionScreen.lua")
    t:truthy("CollectionScreen pergunta a MESMA regra",
        colecao:find("CardFrame%.imageFor") ~= nil
            or colecao:find("CardFrame%.isInteracting") ~= nil)

    -- E o limiar nao pode voltar a viver cravado nas telas.
    t:falsy("o limiar 1.001 nao esta cravado no CardGridRender",
        grid:find("1%.001") ~= nil)
    t:falsy("o limiar 1.001 nao esta cravado na CollectionScreen",
        colecao:find("1%.001") ~= nil)

    -- ===================================================================
    -- 4. ROBUSTEZ DO CANVAS VIVO (Out/2026) — a trava do flake
    -- ===================================================================
    -- test_class_select caia em CardFrame.lua:423 ("Drawable expected, got
    -- nil") uma vez a cada ~nove rodadas do test_all: tools/balance_sim.setup
    -- (test_instant_parity / test_balance_pipeline) trocava CardFrame.render
    -- por um stub que devolve um canvas compartilhado SEM preencher o cache
    -- do CardFrame. O set de frames nascia {nil, c2..c9}, `#` dizia 9 e o
    -- blit caia no slot vazio quando floor(t*fps) % 9 == 0 — relogio de
    -- parede, por isso "flake". Aqui: render estubado nunca estoura e avisa;
    -- render real anima; relogio nao-finito nao vira indice NaN; e o teto do
    -- cache e MACIO (MAX_LIVE+ cartas em uso no mesmo quadro nao se expulsam).
    local CardDatabase = require("src.systems.CardDatabase")
    local CardArt = require("src.ui.CardArt")
    local IconFramesLoader = require("src.ui.IconFramesLoader")
    local db = CardDatabase:new()
    local animated = {}
    for _, cd in pairs(db:getAllCards()) do
        local art = CardArt.resolve(cd)
        if art.iconName and IconFramesLoader.has(art.iconName) then
            animated[#animated + 1] = cd
        end
    end
    table.sort(animated, function(a, b) return a.id < b.id end)
    t:truthy(("catalogo tem mais cartas animadas que o teto do cache (%d > %d)")
        :format(#animated, CardFrame.MAX_LIVE), #animated > CardFrame.MAX_LIVE)

    local realGetTime, realPrint = love.timer.getTime, print
    local now, avisos = 0, 0
    love.timer.getTime = function() return now end
    print = function(...)
        local s = tostring((...))
        if s:find("[CardFrame]", 1, true) then avisos = avisos + 1 end
        realPrint(...)
    end
    local okSec, errSec = pcall(function()
        local card = db:createCardInstance(animated[1])
        CardFrame.invalidate(card)

        -- (a) render estubado como no balance_sim: nunca estoura, fica no estatico
        local realRender = CardFrame.render
        local shared = love.graphics.newCanvas(96, 144)
        CardFrame.render = function() return shared end
        local okAll, live = true, nil
        for _ = 1, 40 do
            local ok, res = pcall(CardFrame.liveImage, card)
            okAll = okAll and ok
            live = live or res
        end
        CardFrame.render = realRender
        t:truthy("render estubado: liveImage nunca estoura", okAll)
        t:falsy("render estubado: sem canvas vivo (carta segue estatica)", live)
        t:truthy("render estubado: AVISOU (fallback silencioso e proibido)", avisos >= 1)

        -- (b) com o render de verdade o vivo volta — set inteiro, sem buraco
        CardFrame.invalidate(card)
        local got
        for _ = 1, 60 do
            got = CardFrame.liveImage(card)
            if got then break end
        end
        t:truthy("render real: liveImage devolve o canvas vivo", got ~= nil)
        local anim = CardFrame.getAnimation(card)
        local holes = 0
        if anim then
            for i = 1, #anim.canvases do
                if anim.canvases[i] == nil then holes = holes + 1 end
            end
        end
        t:eq("set de frames sem buraco", holes, 0)

        -- (c) relogio nao-finito nunca vira indice NaN
        now = 1 / 0
        t:truthy("relogio infinito: liveImage segue de pe", (pcall(CardFrame.liveImage, card)))
        now = 0

        -- (d) teto MACIO: MAX_LIVE+ cartas vivas no MESMO quadro ficam todas
        local N = math.min(#animated - 1, CardFrame.MAX_LIVE + 6)
        local insts = {}
        for i = 1, N do insts[i] = db:createCardInstance(animated[i]) end
        local allLive = false
        for _ = 1, 80 do
            allLive = true
            for i = 1, N do
                if not CardFrame.liveImage(insts[i]) then allLive = false end
            end
            if allLive then break end
        end
        t:truthy(N .. " cartas animadas pedidas no mesmo quadro: todas vivas (sem thrash)", allLive)
        t:truthy("cache passa do teto enquanto todas estao em uso",
            CardFrame._liveCount() >= N)
        -- paradas por mais de STALE_SECS, o excesso sai no proximo tick
        now = now + CardFrame.STALE_SECS * 4
        CardFrame.update()
        t:truthy("paradas: cache volta ao teto", CardFrame._liveCount() <= CardFrame.MAX_LIVE)
        -- quem continua em uso nao e descartada pelo teto: pede uma que ainda
        -- esta no cache (vira "fresca"), monta uma animacao NOVA (estoura o
        -- teto de novo) — sai uma PARADA, nunca a fresca
        now = now + CardFrame.STALE_SECS * 4
        local kept, fresh
        for i = 1, N do
            local l = CardFrame.liveImage(insts[i])
            if l then kept, fresh = insts[i], l; break end
        end
        t:truthy("fixture: sobrou carta viva no cache", kept ~= nil)
        local extra = db:createCardInstance(animated[N + 1])
        for _ = 1, 40 do
            if CardFrame.liveImage(extra) then break end
        end
        t:truthy("carta em uso sobrevive ao teto (sai a parada)",
            kept ~= nil and CardFrame.liveImage(kept) == fresh)
        t:truthy("cache no teto depois de montar a nova",
            CardFrame._liveCount() <= CardFrame.MAX_LIVE)
    end)
    love.timer.getTime, print = realGetTime, realPrint
    CardFrame.clearCache()
    t:check("robustez: sem excecao" .. (okSec and "" or (": " .. tostring(errSec))), okSec)

    return t:done()
end

return M
