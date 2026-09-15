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

    return t:done()
end

return M
