-- tools/test_upgrade_tile.lua
-- Trava do tile de RELIQUIA da loja (src/ui/UpgradeTile.lua) em tres frentes.
--
-- 1) GEOMETRIA POR CONSTRUCAO (memory/ui_layout_invariants.md, secao 1)
--    As bandas nome/arte/efeito nao podem se sobrepor nem escapar do
--    tile em NENHUM tamanho -- e a MOEDA de preco, que e overlay carimbado
--    na moldura, nao pode passar por cima do nome -- nem no slot largo de 1920x1080 nem no aperto
--    de 800x600. O defeito de origem desta familia (PackChoiceLayout) foi
--    exatamente dois elementos ancorados no mesmo Y sem saber um do outro.
--
-- 2) RESIZE (secao 2 -- "nascer grande != crescer")
--    A loja NASCE num tamanho e a janela MUDA com ela aberta. A janela e
--    FALSIFICADA (monkey-patch em love.graphics.getWidth/getHeight) porque
--    love.window.setMode repetido dentro de um tool nao retorna. O caminho
--    imitado e o do jogo (main.lua:love.resize): limpa FontManager/CardFrame
--    e chama updateLayout().
--
-- 3) I18N (memory/i18n_discipline.md)
--    As quatro camadas de texto da reliquia (name/effect/desc/flavor) tem que
--    existir nos 5 locales -- e o chip precisa interpolar {value}. A vitrine
--    ja mostrou "Reliquia" em PT no meio de uma tela em alemao porque a chave
--    so existia como fallback no codigo; isto impede a reincidencia.
--
-- 4) SOM DE HOVER DO SLOT (Set/2026, "o barulho de hover nos upgrades e nos
--    pacotes esta estranho")
--    O call site NAO pode cravar volume: opts.volume SUBSTITUI o baseVolume
--    do registro, e a calibracao do projeto mora no registro. E hover-enter
--    nao pode disparar enquanto a tela DESLIZA -- o slot passa por baixo de um
--    mouse parado e o som sai sozinho. As duas coisas sao travadas aqui com um
--    audioSystem falso que grava as chamadas.
--
-- 5) SPRITE ANIMADO COM FALLBACK
--    O tile consome assets/sprites_anim opcionais (vouchers_anim/<id>/
--    frame_NNN.png). A faixa de animacao pode nao existir -- e o codigo tem
--    que funcionar NOS DOIS ESTADOS. O teste exercita os dois de verdade:
--    escreve uma pasta de frames falsa no save dir (que o love.filesystem
--    monta por cima do source) e confere que o handle aparece; depois remove
--    e confere que volta pro PNG estatico sem erro nenhum.
--
--   love . test_one test_upgrade_tile
--   love . test_all

local TK = require("tools.testkit")
local M = {}

local UpgradeTile      = require("src.ui.UpgradeTile")
local I18n             = require("src.i18n.I18n")
local CardRewardScreen = require("components.CardRewardScreen")
local EventManager     = require("engine.EventManager")
local FontManager      = require("src.ui.FontManager")
local ShopEngraving    = require("src.ui.ShopEngraving")

-- ===== Janela falsa (mesmo padrao de tools/test_forge_resize.lua) =====
local realW, realH = love.graphics.getWidth, love.graphics.getHeight
local fakeW, fakeH = nil, nil
local function installFakeWindow()
    love.graphics.getWidth = function() return fakeW or realW() end
    love.graphics.getHeight = function() return fakeH or realH() end
end
local function restoreWindow()
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
end

local function pump(screen, secs)
    local dt = 1 / 60
    local elapsed = 0
    while elapsed < secs do
        EventManager.update(dt)
        screen:update(dt)
        elapsed = elapsed + dt
    end
end

-- O que o jogo REALMENTE faz no love.resize (main.lua). Espelhar isso importa:
-- um teste que limpa menos que o jogo acusa bug inexistente; que limpa mais,
-- deixa passar um que existe.
local function resizeTo(screen, w, h)
    fakeW, fakeH = w, h
    FontManager.clearCache()
    require("src.ui.CardFrame").clearCache()
    screen:updateLayout()
end

local SIZES = {
    { 800, 600 }, { 1024, 768 }, { 1280, 720 }, { 1366, 768 },
    { 1600, 900 }, { 1920, 1080 },
}

local UPGRADE_IDS = { "forge_card", "health_upgrade", "mana_upgrade" }

function M.run()
    TK.bootstrap()
    I18n.init()
    local t = TK.new("upgrade tile: zonas, resize e i18n da reliquia")

    -- ======================================================================
    -- 1. Geometria pura
    -- ======================================================================
    local RECTS = {
        { 0, 0, 206, 220 },   -- slot tipico em 1024x768
        { 40, 30, 260, 300 }, -- fullscreen
        { 5, 5, 120, 140 },   -- janela pequena
        { 0, 0, 90, 96 },     -- aperto extremo
        { 0, 0, 64, 60 },     -- degenerado: ainda nao pode quebrar
    }
    for _, r in ipairs(RECTS) do
        for _, cost in ipairs({ 5, 25, 120 }) do
            local bad = UpgradeTile.validate(r[1], r[2], r[3], r[4], cost)
            t:eq(("bandas validas em %dx%d por $%d (%s)"):format(r[3], r[4], cost,
                #bad > 0 and bad[1] or "ok"), #bad, 0)
        end
        -- Sem custo conhecido: reserva o pior caso; tambem tem que fechar.
        local bad = UpgradeTile.validate(r[1], r[2], r[3], r[4])
        t:eq(("bandas validas em %dx%d sem custo (%s)"):format(r[3], r[4],
            #bad > 0 and bad[1] or "ok"), #bad, 0)
    end

    -- Bandas obrigatorias existem SEMPRE; o efeito e o unico que pode cair.
    local tiny = UpgradeTile.layout(0, 0, 64, 60, 5)
    t:truthy("tile minusculo mantem a banda de nome", tiny.name ~= nil)
    t:truthy("tile minusculo mantem a banda de arte", tiny.art ~= nil)
    t:falsy("tile minusculo derruba a placa de efeito (o detalhe carrega o texto)",
        tiny.effect ~= nil)
    t:truthy("a moeda existe em qualquer tamanho", tiny.seal ~= nil)

    local roomy = UpgradeTile.layout(0, 0, 206, 220, 5)
    t:truthy("tile normal mantem a placa de efeito", roomy.effect ~= nil)
    t:truthy("arte e a maior banda do tile",
        roomy.art.h > roomy.name.h and roomy.art.h > roomy.effect.h)
    -- Quando a altura cresce, quem cresce e o CONTEUDO (a arte), nao o cromo.
    local tall = UpgradeTile.layout(0, 0, 206, 300, 5)
    t:truthy("altura extra vai pra arte, nao pro cromo",
        (tall.art.h - roomy.art.h) > (tall.effect.h - roomy.effect.h))

    -- O PRECO nao ocupa banda nenhuma: e moeda carimbada na moldura. A regra
    -- que substituiu a antiga "placa de preco embaixo da placa de efeito" --
    -- precisa continuar valendo pra nao voltar a empilhar dois retangulos
    -- iguais (o defeito "cara de IA" de Set/2026).
    t:falsy("preco nao e mais uma banda empilhada", roomy.price ~= nil)
    t:truthy("a moeda fica no canto superior DIREITO",
        roomy.seal.x > roomy.frame.x + roomy.frame.w * 0.5
        and roomy.seal.y < roomy.frame.y + roomy.frame.h * 0.5)
    t:truthy("o nome termina antes da moeda comecar",
        roomy.name.x + roomy.name.w <= roomy.seal.x)

    -- Moeda maior pra numero maior: e o que garante que o preco continua
    -- LEGIVEL. Com raio fixo, "$25" desabava pro minimo da fonte e virava dois
    -- pontinhos no disco (visto na captura antes da correcao).
    t:truthy("moeda de 2 digitos e maior que a de 1",
        ShopEngraving.sealRadius(206, 25) > ShopEngraving.sealRadius(206, 5))
    t:truthy("sem custo, o raio reserva o pior caso",
        ShopEngraving.sealRadius(206) >= ShopEngraving.sealRadius(206, 999))

    -- ======================================================================
    -- 2. i18n das quatro camadas, nos 5 locales
    -- ======================================================================
    local locales = I18n.getAvailable()
    for _, code in ipairs(locales) do
        I18n.setLocale(code)
        for _, id in ipairs(UPGRADE_IDS) do
            for _, field in ipairs({ "name", "effect", "desc", "flavor" }) do
                local key = "shop_items." .. id .. "." .. field
                local val = I18n.t(key, { value = 7 }, "__missing__")
                t:truthy(code .. " tem " .. key,
                    val ~= "__missing__" and val ~= key and val ~= "")
            end
        end
        for _, key in ipairs({ "reward.badge_relic", "reward.badge_pack",
                               "reward.detail_type_voucher", "reward.detail_type_pack",
                               "reward.instructions_shop", "reward.voucher_effect" }) do
            local val = I18n.t(key, nil, "__missing__")
            t:truthy(code .. " tem " .. key, val ~= "__missing__" and val ~= key)
        end
        -- O chip e etiqueta: caixa alta e curta o bastante pro tile.
        for _, id in ipairs({ "health_upgrade", "mana_upgrade" }) do
            local chip = UpgradeTile.effectLabel({ id = id, value = 7 })
            t:truthy(code .. "/" .. id .. ": chip interpola {value}",
                chip and chip:find("7", 1, true) ~= nil)
            t:truthy(code .. "/" .. id .. ": chip curto (<= 16 chars)",
                chip and #chip <= 16)
        end
    end
    I18n.setLocale("pt_BR")

    -- Oferta sem chave de efeito: o chip some, mas nada quebra.
    t:falsy("id desconhecido nao inventa chip",
        UpgradeTile.effectLabel({ id = "nao_existe", value = 1 }) ~= nil)

    -- Tema por EFEITO (data-driven), nunca por nome.
    local a = UpgradeTile.theme({ effect = "increase_max_health" })
    local b = UpgradeTile.theme({ effect = "increase_base_mana" })
    t:truthy("efeitos diferentes tem cores diferentes",
        a.accent[1] ~= b.accent[1] or a.accent[3] ~= b.accent[3])
    t:truthy("efeito desconhecido cai num tema valido",
        UpgradeTile.theme({ effect = "nada" }).accent ~= nil)

    -- ======================================================================
    -- 3. Som do hover no slot nao-carta (reliquia / pacote)
    -- ======================================================================
    do
        local rec = {}
        local realAudio = _G.audioSystem
        _G.audioSystem = {
            sources = { hoverCard = true, cardSelect = true },
            play = function(_, name, opts) rec[#rec + 1] = { name = name, opts = opts } end,
            playSound = function(_, name) rec[#rec + 1] = { name = name } end,
        }

        installFakeWindow()
        fakeW, fakeH = 1024, 768
        local okSfx, errSfx = pcall(function()
            local game = TK.newRunGame("warrior")
            if game.economySystem then game.economySystem.currentGold = 60 end
            local screen = CardRewardScreen:new(game.shopSystem)
            screen:show(game, function() end, function() end, "shop")
            pump(screen, 0.8)

            local slotOffer
            for _, o in ipairs(screen.shopOffers) do
                if o.type ~= "card" and not o.purchased then slotOffer = o break end
            end
            t:truthy("ha um slot nao-carta na vitrine", slotOffer ~= nil)
            if not slotOffer then return end

            -- (a) Enquanto a tela DESLIZA, hover-enter nao soa: o slot passou
            -- por baixo de um mouse parado, o jogador nao fez nada.
            rec = {}
            screen.slideOffsetY = -300
            screen.hoveredOffer = slotOffer
            for _, fx in pairs(screen.slotFx or {}) do fx._hot = false end
            screen:_updateSlotFx(1 / 60)
            t:eq("tela deslizando nao toca hover", #rec, 0)

            -- (b) Assentada, o hover-enter soa UMA vez...
            rec = {}
            screen.slideOffsetY = 0
            for _, fx in pairs(screen.slotFx or {}) do fx._hot = false end
            screen:_updateSlotFx(1 / 60)
            t:eq("hover-enter toca uma vez", #rec, 1)

            -- ...e NAO re-dispara com o mouse parado sobre o item (o suspeito
            -- classico de "estranho": som continuo em vez de na borda).
            for _ = 1, 30 do screen:_updateSlotFx(1 / 60) end
            t:eq("mouse parado sobre o slot nao re-dispara", #rec, 1)

            local call = rec[1]
            t:eq("usa a amostra de hover da carta (a referencia aprovada)",
                call.name, "hoverCard")
            t:falsy("call site NAO crava volume (quem manda e o registro)",
                call.opts and call.opts.volume ~= nil)
            t:truthy("pitch varia em torno da faixa da carta (0.95 +- 0.18)",
                call.opts and call.opts.pitch
                and call.opts.pitch >= 0.77 and call.opts.pitch <= 1.13)

            -- (c) Sair e voltar toca de novo -- a borda de entrada existe.
            rec = {}
            screen.hoveredOffer = nil
            screen:_updateSlotFx(1 / 60)
            t:eq("sair do slot nao toca nada", #rec, 0)
            screen.hoveredOffer = slotOffer
            screen:_updateSlotFx(1 / 60)
            t:eq("re-entrar toca de novo", #rec, 1)

            -- (d) SELECIONAR usa o som de selecao, nao o de hover a 16x.
            rec = {}
            screen:setSelectedOffer(slotOffer, slotOffer._slot)
            local sel
            for _, c in ipairs(rec) do
                if c.name == "cardSelect" or c.name == "hoverCard" then sel = c end
            end
            t:truthy("selecionar emite som", sel ~= nil)
            t:eq("selecao usa cardSelect, nao a amostra de hover",
                sel and sel.name, "cardSelect")
            t:falsy("selecao tambem nao crava volume",
                sel and sel.opts and sel.opts.volume ~= nil)

            screen:hide()
        end)
        restoreWindow()
        _G.audioSystem = realAudio
        t:truthy("suite de som rodou sem erro (" .. tostring(errSfx) .. ")", okSfx)
    end

    -- ======================================================================
    -- 4. Sprite animado do voucher: anima quando ha faixa, estatico quando nao
    -- ======================================================================
    -- A pasta de animacao e escrita no SAVE DIR: o love.filesystem procura ali
    -- antes do source, entao o loader enxerga como se o asset existisse no
    -- projeto -- sem sujar o repo e sem depender de arte que pode nao ter sido
    -- gerada ainda.
    do
        local FramesLoader = require("src.ui.IconFramesLoader")
        local FAKE = "nao_existe_de_verdade"
        local dir = UpgradeTile.ANIM_ROOT .. "/" .. FAKE

        FramesLoader.clearCache()
        t:falsy("sem pasta de animacao, nao ha handle",
            UpgradeTile.animationFor(FAKE) ~= nil)
        t:falsy("e sem PNG estatico tambem nao inventa imagem",
            (UpgradeTile.spriteFor(FAKE, true, 0)) ~= nil)
        -- Oferta REAL: com ou sem faixa de animacao gerada, SEMPRE sai imagem.
        -- Os dois estados sao validos e o teste nao exige nenhum dos dois --
        -- so que a escolha seja coerente com o que existe no disco.
        for _, id in ipairs(UPGRADE_IDS) do
            local img, animated = UpgradeTile.spriteFor(id, true, 0)
            t:truthy("voucher " .. id .. " sempre tem imagem", img ~= nil)
            local hasDir = love.filesystem.getInfo(
                UpgradeTile.ANIM_ROOT .. "/" .. id, "directory") ~= nil
            t:eq("voucher " .. id .. ": anima <=> existe faixa no disco",
                animated == true, hasDir)
            local idleImg, idleAnim = UpgradeTile.spriteFor(id, false, 0)
            t:truthy("voucher " .. id .. ": idle tem imagem", idleImg ~= nil)
            t:falsy("voucher " .. id .. ": idle nunca anima", idleAnim == true)
        end

        love.filesystem.createDirectory(dir)
        local data = love.image.newImageData(8, 8)
        for i = 0, 3 do
            love.filesystem.write(("%s/frame_%03d.png"):format(dir, i),
                data:encode("png"))
        end
        love.filesystem.write(dir .. "/meta.lua", "return { fps = 4 }")
        FramesLoader.clearCache()

        local anim = UpgradeTile.animationFor(FAKE)
        t:truthy("com pasta de frames, o handle aparece", anim ~= nil)
        if anim then
            t:eq("le os 4 frames", #anim.frames, 4)
            t:eq("meta.lua manda no fps", anim.fps, 4)
            -- fps 4, 4 frames: t=0 e t=0.5 caem em frames diferentes.
            t:truthy("frameAt anda no tempo",
                anim:frameAt(0) ~= anim:frameAt(0.5))
        end
        local frame, animated = UpgradeTile.spriteFor(FAKE, true, 0)
        t:truthy("spriteFor devolve o frame animado na interacao", frame ~= nil)
        t:truthy("e marca que veio da faixa", animated == true)
        -- IDLE e ESTATICO (regra do projeto): sem interacao, nem consulta a
        -- faixa. Aqui nao ha PNG estatico, entao cai no frame 0 -- que e o
        -- comportamento desejado: parado, nunca buraco.
        local idle, idleAnimated = UpgradeTile.spriteFor(FAKE, false, 0)
        t:falsy("idle nao anima", idleAnimated == true)
        t:truthy("idle ainda mostra alguma coisa", idle ~= nil)

        t:noerror("desenhar o tile com faixa animada nao lanca", function()
            UpgradeTile.draw({ id = FAKE, name = "Fake", cost = 7,
                               effect = "increase_max_health", value = 3 },
                { x = 0, y = 0, w = 206, h = 220 },
                { hover = 1, afford = true, time = 0.3 })
        end)

        for i = 0, 3 do
            love.filesystem.remove(("%s/frame_%03d.png"):format(dir, i))
        end
        love.filesystem.remove(dir .. "/meta.lua")
        love.filesystem.remove(dir)
        FramesLoader.clearCache()
        t:falsy("removida a pasta, o handle some de novo",
            UpgradeTile.animationFor(FAKE) ~= nil)
    end

    -- A placa gravada e cacheada como bitmap: o cache tem que aceitar ser
    -- zerado a qualquer momento (e o que o resize da loja faz) sem quebrar o
    -- desenho seguinte.
    t:noerror("clearCache no meio do uso nao quebra o proximo draw", function()
        ShopEngraving.effectStrip(0, 0, 180, 16, "+1 MANA MAX",
            { accent = { 0.5, 0.5, 0.5, 1 }, seed = 3 })
        ShopEngraving.clearCache()
        ShopEngraving.effectStrip(0, 0, 180, 16, "+1 MANA MAX",
            { accent = { 0.5, 0.5, 0.5, 1 }, seed = 3 })
    end)

    -- ======================================================================
    -- 5. Resize da loja com a reliquia na vitrine
    -- ======================================================================
    installFakeWindow()
    local okRun, err = pcall(function()
        local game = TK.newRunGame("warrior")
        if game.economySystem then game.economySystem.currentGold = 60 end

        fakeW, fakeH = 800, 600
        local screen = CardRewardScreen:new(game.shopSystem)
        screen:show(game, function() end, function() end, "shop")
        pump(screen, 0.5)

        -- Garante uma RELIQUIA na vitrine (o roll e 50/50 entre forja e pool).
        local voucher
        for _, o in ipairs(screen.shopOffers) do
            if o.type == "upgrade" then voucher = o break end
        end
        t:truthy("a vitrine da loja traz um upgrade", voucher ~= nil)

        local bad0 = screen:validateLayout()
        t:eq("800x600: layout limpo ao NASCER (" ..
            (#bad0 > 0 and bad0[1] or "ok") .. ")", #bad0, 0)

        -- Agora CRESCE/ENCOLHE com a tela aberta, sem recriar nada.
        for _, s in ipairs(SIZES) do
            resizeTo(screen, s[1], s[2])
            pump(screen, 0.1)
            local bad = screen:validateLayout()
            t:eq(("%dx%d apos resize (%s)"):format(s[1], s[2],
                #bad > 0 and bad[1] or "ok"), #bad, 0)
        end

        -- E com uma oferta SELECIONADA (o estado com mais geometria derivada:
        -- botoes de compra ancorados no rodape do painel de detalhe).
        if voucher then
            screen:setSelectedOffer(voucher, voucher._slot)
            for _, s in ipairs({ { 800, 600 }, { 1920, 1080 }, { 1024, 768 } }) do
                resizeTo(screen, s[1], s[2])
                pump(screen, 0.1)
                local bad = screen:validateLayout()
                t:eq(("%dx%d com reliquia selecionada (%s)"):format(s[1], s[2],
                    #bad > 0 and bad[1] or "ok"), #bad, 0)
            end
        end

        -- O tile e desenhavel em qualquer tamanho (o draw le as MESMAS bandas
        -- que o validate; um erro de nil aqui seria crash na loja real).
        if voucher then
            resizeTo(screen, 800, 600)
            local pos = screen.cardPositions[voucher._slot]
            t:noerror("draw do tile nao lanca", function()
                UpgradeTile.draw(voucher,
                    { x = pos.x, y = pos.y, w = pos.w, h = pos.h },
                    { hover = 0.5, afford = true, time = 1.0 })
            end)
        end
        screen:hide()
    end)
    restoreWindow()
    FontManager.clearCache()
    t:truthy("suite de resize rodou sem erro (" .. tostring(err) .. ")", okRun)

    return t:done()
end

return M
