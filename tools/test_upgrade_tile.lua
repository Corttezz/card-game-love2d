local TK = require("tools.testkit")
local M = {}

local UpgradeTile      = require("src.ui.UpgradeTile")
local I18n             = require("src.i18n.I18n")
local CardRewardScreen = require("components.CardRewardScreen")
local EventManager     = require("engine.EventManager")
local FontManager      = require("src.ui.FontManager")
local ShopEngraving    = require("src.ui.ShopEngraving")

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

local function resizeTo(screen, w, h)
    fakeW, fakeH = w, h
    FontManager.clearCache()
    require("src.ui.CardFrame").clearCache()
    screen:updateLayout()
end

local SIZES = {
    { 800, 600 }, { 1024, 768 }, { 1280, 720 }, { 1366, 768 },
    { 1600, 900 }, { 1920, 1080 }, { 2560, 1440 },
}

local UPGRADE_IDS = { "forge_card", "health_upgrade", "mana_upgrade" }

function M.run()
    TK.bootstrap()
    I18n.init()
    local t = TK.new("upgrade tile: zonas, resize e i18n da reliquia")

    local RECTS = {
        { 0, 0, 206, 220 },
        { 40, 30, 260, 300 },
        { 5, 5, 120, 140 },
        { 0, 0, 90, 96 },
        { 0, 0, 64, 60 },
    }
    for _, r in ipairs(RECTS) do
        for _, cost in ipairs({ 5, 25, 120 }) do
            local bad = UpgradeTile.validate(r[1], r[2], r[3], r[4], cost)
            t:eq(("bandas validas em %dx%d por $%d (%s)"):format(r[3], r[4], cost,
                #bad > 0 and bad[1] or "ok"), #bad, 0)
        end
        local bad = UpgradeTile.validate(r[1], r[2], r[3], r[4])
        t:eq(("bandas validas em %dx%d sem custo (%s)"):format(r[3], r[4],
            #bad > 0 and bad[1] or "ok"), #bad, 0)
    end

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
    local tall = UpgradeTile.layout(0, 0, 206, 300, 5)
    t:truthy("altura extra vai pra arte, nao pro cromo",
        (tall.art.h - roomy.art.h) > (tall.effect.h - roomy.effect.h))

    t:falsy("preco nao e mais uma banda empilhada", roomy.price ~= nil)
    t:truthy("a moeda fica no canto superior DIREITO",
        roomy.seal.x > roomy.frame.x + roomy.frame.w * 0.5
        and roomy.seal.y < roomy.frame.y + roomy.frame.h * 0.5)
    t:truthy("o nome termina antes da moeda comecar",
        roomy.name.x + roomy.name.w <= roomy.seal.x)

    t:truthy("moeda de 2 digitos e maior que a de 1",
        ShopEngraving.sealRadius(206, 25) > ShopEngraving.sealRadius(206, 5))
    t:truthy("sem custo, o raio reserva o pior caso",
        ShopEngraving.sealRadius(206) >= ShopEngraving.sealRadius(206, 999))

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
        for _, key in ipairs({ "reward.detail_type_voucher", "reward.detail_type_pack",
                               "reward.instructions_shop", "reward.voucher_effect" }) do
            local val = I18n.t(key, nil, "__missing__")
            t:truthy(code .. " tem " .. key, val ~= "__missing__" and val ~= key)
        end
        for _, id in ipairs({ "health_upgrade", "mana_upgrade" }) do
            local chip = UpgradeTile.effectLabel({ id = id, value = 7 })
            t:truthy(code .. "/" .. id .. ": chip interpola {value}",
                chip and chip:find("7", 1, true) ~= nil)
            t:truthy(code .. "/" .. id .. ": chip curto (<= 16 chars)",
                chip and #chip <= 16)
        end
    end
    I18n.setLocale("pt_BR")

    t:falsy("id desconhecido nao inventa chip",
        UpgradeTile.effectLabel({ id = "nao_existe", value = 1 }) ~= nil)

    local a = UpgradeTile.theme({ effect = "increase_max_health" })
    local b = UpgradeTile.theme({ effect = "increase_base_mana" })
    t:truthy("efeitos diferentes tem cores diferentes",
        a.accent[1] ~= b.accent[1] or a.accent[3] ~= b.accent[3])
    t:truthy("efeito desconhecido cai num tema valido",
        UpgradeTile.theme({ effect = "nada" }).accent ~= nil)

    do
        local FramesLoader = require("src.ui.IconFramesLoader")
        local FAKE = "nao_existe_de_verdade"
        local dir = UpgradeTile.ANIM_ROOT .. "/" .. FAKE

        FramesLoader.clearCache()
        t:falsy("sem pasta de animacao, nao ha handle",
            UpgradeTile.animationFor(FAKE) ~= nil)
        t:falsy("e sem PNG estatico tambem nao inventa imagem",
            (UpgradeTile.spriteFor(FAKE, true, 0)) ~= nil)
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
            t:truthy("frameAt anda no tempo",
                anim:frameAt(0) ~= anim:frameAt(0.5))
        end
        local frame, animated = UpgradeTile.spriteFor(FAKE, true, 0)
        t:truthy("spriteFor devolve o frame animado na interacao", frame ~= nil)
        t:truthy("e marca que veio da faixa", animated == true)
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

    t:noerror("clearCache no meio do uso nao quebra o proximo draw", function()
        ShopEngraving.effectStrip(0, 0, 180, 16, "+1 MANA MAX",
            { accent = { 0.5, 0.5, 0.5, 1 }, seed = 3 })
        ShopEngraving.clearCache()
        ShopEngraving.effectStrip(0, 0, 180, 16, "+1 MANA MAX",
            { accent = { 0.5, 0.5, 0.5, 1 }, seed = 3 })
    end)

    installFakeWindow()
    local okRun, err = pcall(function()
        local game = TK.newRunGame("warrior")
        if game.economySystem then game.economySystem.currentGold = 60 end

        fakeW, fakeH = 800, 600
        local screen = CardRewardScreen:new(game.shopSystem)
        screen:show(game, function() end, function() end, "shop")
        pump(screen, 0.5)

        local voucher
        for _, o in ipairs(screen.shopOffers) do
            if o.type == "upgrade" then voucher = o break end
        end
        t:truthy("a vitrine da loja traz um upgrade", voucher ~= nil)

        local bad0 = screen:validateLayout()
        t:eq("800x600: layout limpo ao NASCER (" ..
            (#bad0 > 0 and bad0[1] or "ok") .. ")", #bad0, 0)

        for _, s in ipairs(SIZES) do
            resizeTo(screen, s[1], s[2])
            pump(screen, 0.1)
            local bad = screen:validateLayout()
            t:eq(("%dx%d apos resize (%s)"):format(s[1], s[2],
                #bad > 0 and bad[1] or "ok"), #bad, 0)
        end

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

        screen:clearSelection()
        for _, code in ipairs(I18n.getAvailable()) do
            I18n.setLocale(code)
            fakeW, fakeH = 800, 600
            local s2 = CardRewardScreen:new(game.shopSystem)
            s2:show(game, function() end, function() end, "shop")
            pump(s2, 0.3)
            for _, s in ipairs(SIZES) do
                resizeTo(s2, s[1], s[2])
                local sel = s2.shopOffers[1]
                if sel then s2:setSelectedOffer(sel, sel._slot) end
                pump(s2, 0.05)
                local bad = s2:validateLayout()
                t:eq(("%s %dx%d loja tela cheia (%s)"):format(code, s[1], s[2],
                    #bad > 0 and bad[1] or "ok"), #bad, 0)
            end
            s2:hide()
        end
        I18n.setLocale("pt_BR")

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

    do
        local UT = require("src.ui.UpgradeTile")
        local comAnim = nil
        for _, id in ipairs({ "forge_card", "health_upgrade", "mana_upgrade",
                              "damage_upgrade", "defense_upgrade",
                              "card_draw_upgrade" }) do
            if UT.animationFor(id) then comAnim = id; break end
        end

        if comAnim then
            local a = UT.spriteFor(comAnim, true, 0.0)
            local b = UT.spriteFor(comAnim, true, 0.5)
            t:truthy("voucher com animacao resolve sprite", a ~= nil)
            t:truthy("o frame MUDA ao longo do tempo (anima de verdade)", a ~= b)

            local est = UT.spriteFor(comAnim, false, 0.5)
            t:truthy("frame estatico ainda existe", est ~= nil)
        else
            t:truthy("nenhum voucher tem pasta de animacao instalada", false)
        end

        t:noerror("voucher sem animacao nao estoura ao animar", function()
            UT.spriteFor("voucher_inexistente_xyz", true, 0.3)
        end)
    end

    return t:done()
end

return M
