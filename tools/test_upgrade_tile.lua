-- tools/test_upgrade_tile.lua
-- Trava do tile de RELIQUIA da loja (src/ui/UpgradeTile.lua) em tres frentes.
--
-- 1) GEOMETRIA POR CONSTRUCAO (memory/ui_layout_invariants.md, secao 1)
--    As bandas nome/arte/chip/preco nao podem se sobrepor nem escapar do
--    tile em NENHUM tamanho -- nem no slot largo de 1920x1080 nem no aperto
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
--   love . test_one test_upgrade_tile
--   love . test_all

local TK = require("tools.testkit")
local M = {}

local UpgradeTile      = require("src.ui.UpgradeTile")
local I18n             = require("src.i18n.I18n")
local CardRewardScreen = require("components.CardRewardScreen")
local EventManager     = require("engine.EventManager")
local FontManager      = require("src.ui.FontManager")

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
        local bad = UpgradeTile.validate(r[1], r[2], r[3], r[4])
        t:eq(("bandas validas em %dx%d (%s)"):format(r[3], r[4],
            #bad > 0 and bad[1] or "ok"), #bad, 0)
    end

    -- Bandas obrigatorias existem SEMPRE; o chip e o unico que pode cair.
    local tiny = UpgradeTile.layout(0, 0, 64, 60)
    t:truthy("tile minusculo mantem a banda de nome", tiny.name ~= nil)
    t:truthy("tile minusculo mantem a banda de preco", tiny.price ~= nil)
    t:truthy("tile minusculo mantem a banda de arte", tiny.art ~= nil)
    t:falsy("tile minusculo derruba o chip (o detalhe carrega o texto)",
        tiny.chip ~= nil)

    local roomy = UpgradeTile.layout(0, 0, 206, 220)
    t:truthy("tile normal mantem o chip do efeito", roomy.chip ~= nil)
    t:truthy("arte e a maior banda do tile",
        roomy.art.h > roomy.name.h and roomy.art.h > roomy.price.h)
    -- Quando a altura cresce, quem cresce e o CONTEUDO (a arte), nao o cromo.
    local tall = UpgradeTile.layout(0, 0, 206, 300)
    t:truthy("altura extra vai pra arte, nao pro cromo",
        (tall.art.h - roomy.art.h) > (tall.price.h - roomy.price.h))

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
    -- 3. Resize da loja com a reliquia na vitrine
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
