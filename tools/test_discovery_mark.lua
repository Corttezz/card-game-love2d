-- tools/test_discovery_mark.lua
-- Carta INÉDITA na vitrine (src/ui/DiscoveryMark.lua):
--   * markDiscovered devolve true só na virada (e a lista da Coleção enche)
--   * a oferta (recompensa/loja) carrega isNew → instância isNewDiscovery
--   * pacote marca a instância inédita; evento só descobre o que ENTREGA
--   * o marcador desenha só com a flag; reducedMotion tira a varredura e
--     mantém o marcador; estado persiste no perfil
-- Perfil FALSO (ProfileStats._swapForTests), override de ferramenta desligado.

local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("descoberta: selo NOVA nas ofertas")
    TK.bootstrap()
    local ProfileStats = require("engine.ProfileStats")
    local UnlockSystem = require("src.systems.UnlockSystem")
    local DiscoveryMark = require("src.ui.DiscoveryMark")
    local CardDatabase = require("src.systems.CardDatabase")

    local prevOverride = UnlockSystem.isOverrideAll()
    local prevProfile = ProfileStats._swapForTests({ runs = 0, wins = 0 })
    UnlockSystem._resetForTests()
    local prevClock = DiscoveryMark.clock
    _G.gameSettings = _G.gameSettings or {}
    local prevReduced = _G.gameSettings.reducedMotion

    local ok, err = pcall(function()
        -- ===== Virada da descoberta =====
        t:falsy("perfil novo: carta não descoberta", UnlockSystem.isCardDiscovered("warrior_iron_wave"))
        t:truthy("1ª vista devolve true", UnlockSystem.markDiscovered("warrior_iron_wave"))
        t:falsy("2ª vista devolve false", UnlockSystem.markDiscovered("warrior_iron_wave"))
        t:truthy("agora descoberta", UnlockSystem.isCardDiscovered("warrior_iron_wave"))
        t:falsy("cardsSeen do perfil antigo conta como vista", (function()
            ProfileStats.get().cardsSeen.warrior_bash = true
            return UnlockSystem.markDiscovered("warrior_bash")
        end)())

        -- ===== Persistência =====
        local SaveManager = require("engine.SaveManager")
        local okSer, txt = pcall(SaveManager.serialize, ProfileStats.get())
        local reloaded = okSer and load("return " .. txt)() or nil
        t:truthy("perfil serializa", reloaded ~= nil)
        ProfileStats._swapForTests(reloaded)
        t:truthy("recarregado: segue descoberta", UnlockSystem.isCardDiscovered("warrior_iron_wave"))
        t:falsy("recarregado: não volta a ser inédita", UnlockSystem.markDiscovered("warrior_iron_wave"))

        -- ===== Coleção: pulsa uma vez =====
        local fresh = UnlockSystem.takeFreshInCollection()
        t:truthy("Coleção recebe a descoberta (persistida)", fresh.warrior_iron_wave)
        t:falsy("descoberta antiga (cardsSeen) não pulsa", fresh.warrior_bash)
        t:eq("2ª visita: lista vazia", next(UnlockSystem.takeFreshInCollection()), nil)

        -- ===== Oferta de recompensa/loja =====
        local game = TK.newRunGame("warrior")
        local reg = game.runManager.cardRegistry
        TK.seedRng(777)
        local picks = reg:generateCardRewards("warrior", 3, { stream = "card" })
        local anyNew = false
        for _, p in ipairs(picks) do
            if p.isNew then anyNew = true end
            t:truthy("oferta descobre a carta (" .. p.cardId .. ")", UnlockSystem.isCardDiscovered(p.cardId))
        end
        t:truthy("perfil novo: a recompensa traz inédita", anyNew)
        -- tudo já visto: nenhuma oferta é inédita
        for id in pairs(CardDatabase:new():getAllCards()) do UnlockSystem.markDiscovered(id) end
        local again = reg:generateCardRewards("warrior", 3, { stream = "card" })
        local anyAgain = false
        for _, p in ipairs(again) do if p.isNew then anyAgain = true end end
        t:truthy("re-oferta existe", #again > 0)
        t:falsy("catálogo visto: nenhuma oferta inédita", anyAgain)
        -- volta a um perfil com só as vistas de antes (o resto do teste
        -- precisa de cartas inéditas)
        local u = ProfileStats.get().unlocks
        u.discovered = { warrior_iron_wave = true }
        for _, p in ipairs(picks) do u.discovered[p.cardId] = true end

        -- evento: discover=false não descobre a candidata
        local ev = reg:pickRewardCard({ classId = "warrior", stream = "event", discover = false })
        if ev then
            t:falsy("evento: candidata NÃO vira vista", ev.isNew)
        end

        -- loja → instância
        local CardRewardScreen = require("components.CardRewardScreen")
        local screen = CardRewardScreen:new(game.shopSystem)
        screen:show(game, function() end, function() end, "shop")
        local first
        for _, o in ipairs(screen.shopOffers) do
            if o.type == "card" then o.isNew = (first == nil) or nil; first = first or o end
        end
        screen:createCardInstances()
        local flagged, plain = 0, 0
        for _, inst in ipairs(screen.cardInstances) do
            if inst.isNewDiscovery then flagged = flagged + 1 else plain = plain + 1 end
        end
        t:eq("loja: só a oferta inédita leva o selo", flagged, 1)
        t:truthy("loja: as outras não", plain >= 1)
        local exported = game.shopSystem:exportState()
        t:truthy("selo vai pro save da loja", exported.offers and (function()
            for _, o in ipairs(exported.offers) do if o.isNew then return true end end
        end)())
        screen:hide()

        -- ===== Evento entrega carta inédita: toast de descoberta =====
        local target
        for id, cd in pairs(CardDatabase:new():getAllCards()) do
            if cd.class == "warrior" and cd.type ~= "joker" and not UnlockSystem.isCardDiscovered(id) then
                target = id; break
            end
        end
        local msgs = {}
        local prevAdd = game.addMessage
        game.addMessage = function(_, text) msgs[#msgs + 1] = text end
        game:addCardToRun(target)
        game.addMessage = prevAdd
        local I18n = require("src.i18n.I18n")
        local want = I18n.t("messages.card_discovered", { name = I18n.cardName(target) })
        t:eq("evento: carta inédita anuncia a descoberta", msgs[1], want)

        -- ===== Desenho: marcador e varredura =====
        local db = CardDatabase:new()
        local card = db:createCardInstance(db:getCard("warrior_iron_wave"))
        card.currentScale = 2
        card.isDragging = true          -- sem o balanço idle (ambientY)
        local canvas = love.graphics.newCanvas(400, 480)
        local now = 0
        DiscoveryMark.clock = function() return now end
        -- TUDO no tempo simulado: o relógio do DiscoveryMark é injetado e o
        -- love.timer congela durante o draw (ícone animado, camada de
        -- animação da carta, wobble do shader). Antes o teste dependia do
        -- relógio de parede e falhava no test_all sob carga. reducedMotion
        -- explícito: outra suite pode ter deixado ligado.
        _G.gameSettings.reducedMotion = false
        local realGetTime = love.timer.getTime
        local function render()
            love.timer.getTime = function() return 1000 end
            love.graphics.push("all")
            love.graphics.setCanvas(canvas)
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.origin()
            local okD, errD = pcall(card.draw, card, 100, 120, false, true)
            love.graphics.setCanvas()
            love.graphics.pop()
            love.timer.getTime = realGetTime
            if not okD then error(errD, 0) end
            return canvas:newImageData()
        end
        local function aboveTop(img)
            local r = card.lastDrawRect
            local cx = math.floor(r.x + r.w / 2)
            local n = 0
            for y = math.max(0, math.floor(r.y) - 14), math.floor(r.y) - 3 do
                local _, _, _, a = img:getPixel(cx, y)
                if a > 0.5 then n = n + 1 end
            end
            return n
        end
        card.isNewDiscovery = nil
        t:eq("sem a flag: nada acima da carta", aboveTop(render()), 0)
        DiscoveryMark.reset()
        card.isNewDiscovery = true
        render()                         -- 1ª revelação em t=0
        now = 3.0
        local rest = render()
        t:truthy("com a flag: marcador NOVA acima da carta", aboveTop(rest) > 4)
        local function same(a, b)
            for y = 0, a:getHeight() - 1, 2 do
                for x = 0, a:getWidth() - 1, 2 do
                    local r1, g1, b1 = a:getPixel(x, y)
                    local r2, g2, b2 = b:getPixel(x, y)
                    if math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2) > 0.02 then return false end
                end
            end
            return true
        end
        now = DiscoveryMark.SWEEP_DELAY + DiscoveryMark.SWEEP_DUR * 0.45
        t:falsy("varredura acende no meio da revelação", same(render(), rest))
        _G.gameSettings.reducedMotion = true
        local reducedMid = render()
        t:truthy("reducedMotion: sem varredura", same(reducedMid, rest))
        t:truthy("reducedMotion: marcador fica", aboveTop(reducedMid) > 4)
        _G.gameSettings.reducedMotion = false

        -- Coleção: o pulso acontece e termina (uma vez só)
        now = 0
        love.graphics.setCanvas(canvas)
        local live = DiscoveryMark.drawCollectionPulse("x", card.image, 10, 10, 1)
        now = 0.6
        local mid = DiscoveryMark.drawCollectionPulse("x", card.image, 10, 10, 1)
        now = 5
        local done = DiscoveryMark.drawCollectionPulse("x", card.image, 10, 10, 1)
        love.graphics.setCanvas()
        t:truthy("Coleção: pulso ativo no começo", live and mid)
        t:falsy("Coleção: pulso termina", done)
    end)
    t:truthy("suite rodou sem erro" .. (ok and "" or (": " .. tostring(err))), ok)

    _G.gameSettings.reducedMotion = prevReduced
    DiscoveryMark.clock = prevClock
    DiscoveryMark.reset()
    UnlockSystem._resetForTests()
    UnlockSystem.setOverrideAll(prevOverride)
    ProfileStats._swapForTests(prevProfile)
    return t:done()
end

return M
