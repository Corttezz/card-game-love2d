-- tools/test_card_live_hover.lua
-- ROBUSTEZ do cache de animação das cartas (CardFrame.liveImage / update).
--
-- Histórico: nasceu em Set/2026 pra travar "a carta anima no HOVER em toda
-- tela" (o Deck Viewer não animava). Em 13/Out/2026 o dono revogou a regra
-- "idle = estático": toda carta VISÍVEL é viva — essa regra agora mora em
-- CardFrame.displayImage e é travada por tools/test_cards_always_live.lua.
-- O que SOBRA aqui é o mecanismo, que não mudou de contrato:
--   • render estubado (tools/balance_sim.setup vazando) nunca estoura e AVISA
--     — o set nascia {nil, c2..c9} e test_class_select caía em draw(nil) uma
--     vez a cada nove rodadas, por horário (memory/card_icon_animation.md);
--   • render real: set inteiro sem buraco;
--   • relógio não-finito não vira índice NaN;
--   • teto MACIO do cache: MAX_LIVE+ cartas vivas no MESMO quadro não se
--     expulsam (thrash piscava o estático); o excesso só sai quando PARADO.
--
--   love . test_one test_card_live_hover

local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("cache de animação das cartas: robustez e teto macio")
    TK.bootstrap()

    local CardFrame = require("src.ui.CardFrame")
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

    -- Relógio SIMULADO (o índice do frame, o orçamento por quadro e a janela
    -- "parada" dependem dele). Cada tick = um love.update.
    local realGetTime, realPrint = love.timer.getTime, print
    local now, avisos = 0, 0
    love.timer.getTime = function() return now end
    print = function(...)
        local s = tostring((...))
        if s:find("[CardFrame]", 1, true) then avisos = avisos + 1 end
        realPrint(...)
    end
    local function tick()
        now = now + 1 / 60
        CardFrame.update()
    end
    -- pede até o set ficar pronto (orçamento por quadro)
    local function warm(inst, maxFrames)
        local got
        for _ = 1, maxFrames or 200 do
            tick()
            got = CardFrame.liveImage(inst)
            if got then return got end
        end
        return nil
    end

    local okSec, errSec = pcall(function()
        local card = db:createCardInstance(animated[1])
        CardFrame.invalidate(card)

        -- (a) render estubado como no balance_sim: nunca estoura, fica no estático
        local realRender = CardFrame.render
        local shared = love.graphics.newCanvas(96, 144)
        CardFrame.render = function() return shared end
        local okAll, live = true, nil
        for _ = 1, 40 do
            tick()
            local ok, res = pcall(CardFrame.liveImage, card)
            okAll = okAll and ok
            live = live or res
        end
        CardFrame.render = realRender
        t:truthy("render estubado: liveImage nunca estoura", okAll)
        t:falsy("render estubado: sem canvas vivo (carta segue estática)", live)
        t:truthy("render estubado: AVISOU (fallback silencioso é proibido)", avisos >= 1)

        -- (b) com o render de verdade o vivo volta — set inteiro, sem buraco
        CardFrame.invalidate(card)
        local got = warm(card)
        t:truthy("render real: liveImage devolve o quadro vivo", got ~= nil)
        local anim = CardFrame.getAnimation(card)
        local holes = 0
        if anim then
            for i = 1, #anim.canvases do
                if anim.canvases[i] == nil then holes = holes + 1 end
            end
        end
        t:eq("set de frames sem buraco", holes, 0)
        t:truthy("o quadro devolvido É um canvas do set", (function()
            for i = 1, #anim.canvases do if anim.canvases[i] == got then return true end end
            return false
        end)())

        -- (c) relógio não-finito nunca vira índice NaN
        now = 1 / 0
        t:truthy("relógio infinito: liveImage segue de pé", (pcall(CardFrame.liveImage, card)))
        now = 0

        -- (d) teto MACIO: MAX_LIVE+ cartas vivas no MESMO quadro ficam todas
        local N = math.min(#animated - 1, CardFrame.MAX_LIVE + 6)
        local insts = {}
        for i = 1, N do insts[i] = db:createCardInstance(animated[i]) end
        local allLive = false
        for _ = 1, 600 do
            tick()
            allLive = true
            for i = 1, N do
                if not CardFrame.liveImage(insts[i]) then allLive = false end
            end
            if allLive then break end
        end
        t:truthy(N .. " cartas animadas pedidas no mesmo quadro: todas vivas (sem thrash)", allLive)
        t:truthy("cache passa do teto enquanto todas estão em uso",
            CardFrame._liveCount() >= N)
        -- paradas por mais de STALE_SECS, o excesso sai no próximo tick
        now = now + CardFrame.STALE_SECS * 4
        CardFrame.update()
        t:truthy("paradas: cache volta ao teto", CardFrame._liveCount() <= CardFrame.MAX_LIVE)
        -- quem continua em uso não é descartada pelo teto: pede uma que ainda
        -- está no cache (vira "fresca"), monta uma animação NOVA (estoura o
        -- teto de novo) — sai uma PARADA, nunca a fresca
        now = now + CardFrame.STALE_SECS * 4
        local kept
        for i = 1, N do
            if CardFrame.liveImage(insts[i]) then kept = insts[i]; break end
        end
        t:truthy("fixture: sobrou carta viva no cache", kept ~= nil)
        local keptAnim = kept and CardFrame.getAnimation(kept)
        local extra = db:createCardInstance(animated[N + 1])
        for _ = 1, 60 do
            tick()
            CardFrame.liveImage(kept)   -- segue em uso
            if CardFrame.liveImage(extra) then break end
        end
        t:truthy("carta em uso sobrevive ao teto (sai a parada)",
            kept ~= nil and CardFrame.getAnimation(kept) == keptAnim
            and CardFrame.liveImage(kept) ~= nil)
        t:truthy("cache no teto depois de montar a nova",
            CardFrame._liveCount() <= CardFrame.MAX_LIVE)
    end)
    love.timer.getTime, print = realGetTime, realPrint
    CardFrame.clearCache()
    t:check("robustez: sem exceção" .. (okSec and "" or (": " .. tostring(errSec))), okSec)

    return t:done()
end

return M
