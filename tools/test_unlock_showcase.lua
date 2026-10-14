local TK = require("tools.testkit")

local M = {}

local P = "tu_showcase_profile.lua"

local function clean()
    for _, f in ipairs({ P, P .. ".bak", P .. ".tmp" }) do
        if love.filesystem.getInfo(f) then love.filesystem.remove(f) end
    end
end

local function kinds(q)
    local out = {}
    for _, it in ipairs(q) do out[#out + 1] = it.kind .. ":" .. tostring(it.id or it.level or it.n) end
    return table.concat(out, ",")
end

function M.run()
    local t = TK.new("unlock showcase")
    TK.bootstrap()
    local PS = require("engine.ProfileStats")
    local SaveManager = require("engine.SaveManager")
    local UQ = require("src.systems.UnlockQueue")
    local US = require("src.systems.UnlockSystem")
    local Showcase = require("components.UnlockShowcase")
    local I18n = require("src.i18n.I18n")

    local ok, err = pcall(function()
        clean()
        if SaveManager.quarantined then SaveManager.quarantined[P] = nil end
        PS._setPathForTests(P)

        UQ.clear()
        t:truthy("conquista entra na fila quando acontece", UQ.addAchievement("primeiro_chefe"))
        t:falsy("a mesma conquista nao entra duas vezes", UQ.addAchievement("primeiro_chefe"))
        local added = UQ.addRunResult({
            classId = "warrior", newClasses = { "mage" },
            newCards = { "carta_marco", "carta_a", "carta_b" },
            bundles = { { level = 2, cards = { "carta_a", "carta_b" } } },
            before = { level = 1 }, after = { level = 3 },
            sealUnlocked = 1,
        })
        t:eq("itens da run acrescentados", added, 7)
        t:eq("ordem de leitura da fila", kinds(UQ.items()),
            "achievement:primeiro_chefe,class:mage,mastery:2,card:carta_a,card:carta_b,"
            .. "mastery:3,card:carta_marco,seal:1")

        PS._setPathForTests(P)
        t:eq("a fila sobrevive a fechar o jogo", UQ.count(), 8)
        t:eq("e na mesma ordem", UQ.peek().kind, "achievement")

        local s = Showcase:new()
        s:watch("playing", 5)
        t:falsy("fora do menu nao abre", s:isVisible())
        s:watch("menu", 0.1)
        t:falsy("respira antes de abrir (intro do menu)", s:isVisible())
        s:watch("menu", 1)
        t:truthy("no menu com fila: abre sozinho", s:isVisible())
        t:eq("primeiro painel = primeiro da fila", s.item.kind, "achievement")
        t:eq("contador 1 de 8", s.idx .. "/" .. s.total, "1/8")
        s:keypressed("return")
        t:eq("Enter no instante da entrada e ignorado", UQ.count(), 8)
        s:update(0.3)
        s:keypressed("return")
        t:eq("Enter (A) continua: o visto sai da fila", UQ.count(), 7)
        t:eq("segundo painel: classe", s.item.kind .. ":" .. s.item.id, "class:mage")
        t:eq("contador 2 de 8", s.idx .. "/" .. s.total, "2/8")
        s:update(0.3)
        local L = Showcase.layout(love.graphics.getWidth(), love.graphics.getHeight())
        local b = L.buttons[1]
        local bx, by = b.x + b.w / 2, b.y + b.h / 2
        s:mousepressed(bx, by, 1)
        s:mousereleased(bx, by, 1)
        t:eq("clique em Continuar avanca", s.item.kind .. ":" .. tostring(s.item.level), "mastery:2")
        s:update(0.3)
        local sk = L.buttons[2]
        s:mousepressed(sk.x + 2, sk.y + 2, 1)
        s:mousereleased(bx, by, 1)
        t:eq("press em um botao e release em outro nao faz nada", UQ.count(), 6)
        s:keypressed("right")
        t:eq("seta muda o foco pro Pular tudo", s.focus, 2)
        s:keypressed("left")
        s:keypressed("escape")
        t:falsy("Esc (B) pula tudo e fecha", s:isVisible())
        t:eq("pular tudo esvazia a fila", UQ.count(), 0)
        PS._setPathForTests(P)
        t:eq("fila vazia tambem no disco", UQ.count(), 0)
        s:watch("menu", 5)
        t:falsy("fila vazia: nao reabre", s:isVisible())
        local gp = (love.filesystem.read("main.lua") or "")
        t:truthy("registrado no InputFocus (modal: pad/teclado chegam nele)",
            gp:find('IF.register("unlockShowcase", _G.unlockShowcase)', 1, true))
        t:truthy("navega sozinho (B vira Esc, A vira Enter)", Showcase.ownsNavigation)

        clean()
        PS._setPathForTests(P)
        US._resetForTests()
        US.setOverrideAll(false)
        local res = US.onRunEnded({ classId = "warrior", victory = true, actNumber = 6,
            floorInAct = 8, score = 1000, seal = 0 })
        local q = UQ.items()
        local has = {}
        for _, it in ipairs(q) do has[it.kind] = (has[it.kind] or 0) + 1 end
        t:truthy(("vitoria de perfil novo: niveis de maestria na fila (%d)"):format(has.mastery or 0),
            (has.mastery or 0) == (res.levelsGained or 0) and (has.mastery or 0) > 0)
        t:eq("cartas do pacote na fila", has.card or 0, #(res.newCards or {}))
        t:eq("selo 1 liberado na fila", has.seal, 1)
        PS._setPathForTests(P)
        t:eq("fila do fim de run gravada no perfil", UQ.count(), #q)

        local canvas = love.graphics.newCanvas(1024, 768)
        UQ.clear()
        UQ.push({ kind = "achievement", id = "primeiro_chefe" })
        local s2 = Showcase:new()
        local saw = {}
        for _, it in ipairs(q) do UQ.push(it) end
        s2:watch("menu", 1)
        local n = 0
        while s2:isVisible() and n < 50 do
            n = n + 1
            saw[s2.item.kind] = true
            for _ = 1, 3 do
                s2:update(0.2)
                love.graphics.setCanvas(canvas)
                s2:draw()
                love.graphics.setCanvas()
            end
            s2:keypressed("return")
        end
        t:truthy("desenhou carta, maestria, selo e conquista",
            saw.card and saw.mastery and saw.seal and saw.achievement)
        t:eq("Continuar ate o fim esvazia a fila", UQ.count(), 0)

        do
            UQ.clear()
            UQ.push({ kind = "card", id = "warrior_bastion" })
            UQ.push({ kind = "achievement", id = "primeiro_chefe" })
            local s3 = Showcase:new()
            s3:watch("menu", 1)
            t:eq("painel da carta aberto", s3.item.kind, "card")
            local realMouse = love.mouse.getPosition
            local mx, my = 1, 1
            love.mouse.getPosition = function() return mx, my end
            local function frame(n)
                for _ = 1, (n or 1) do
                    s3:update(1 / 30)
                    love.graphics.setCanvas(canvas)
                    s3:draw()
                    love.graphics.setCanvas()
                end
            end
            local okI, errI = pcall(function()
                frame(12)
                local inst, r = s3:_card(), s3._cardBox
                t:truthy("carta montada e posicionada no palco", inst ~= nil and r ~= nil)
                t:truthy("carta e alvo de hover (isRewardCard: sobe)", inst and inst.isRewardCard)
                mx, my = r.x + r.w / 2, r.y + r.h * 0.6
                frame(12)
                t:truthy("mouse na carta: hover", inst.isHovered)
                t:truthy("hover levanta a carta", (inst.liftOffset or 0) < 0)
                t:truthy("hover abre o tooltip (CardInfoDisplay)",
                    inst.cardInfoDisplay and inst.cardInfoDisplay.lastRect ~= nil)
                s3:mousepressed(mx, my, 1); s3:mousereleased(mx, my, 1)
                t:truthy("clique na carta abre a inspecao", s3.inspectModal:isVisible())
                t:eq("inspecao na carta revelada", s3.inspectModal.card, inst)
                frame(2)
                t:falsy("inspecao aberta: a carta nao segue o mouse", inst.isHovered)
                s3:keypressed("escape")
                t:falsy("Esc fecha a inspecao", s3.inspectModal:isVisible())
                t:truthy("...e o painel continua aberto", s3:isVisible())
                t:eq("...sem esvaziar a fila", UQ.count(), 2)
                frame(6)
                s3:mousepressed(mx, my, 2)
                t:truthy("botao direito inspeciona", s3.inspectModal:isVisible())
                s3:keypressed("escape")
                frame(6)
                s3:keypressed("i")
                t:truthy("tecla I (gatilho) inspeciona a carta em hover", s3.inspectModal:isVisible())
                s3:keypressed("escape")
                mx, my = 1, 1
                frame(6)
                s3:keypressed("up")
                t:truthy("seta pra cima foca a carta", s3.cardFocus)
                frame(6)
                t:truthy("carta em foco se comporta como em hover", inst.isHovered)
                s3:keypressed("return")
                t:truthy("Enter (A) com a carta em foco inspeciona", s3.inspectModal:isVisible())
                s3:keypressed("escape")
                s3:keypressed("down")
                t:falsy("seta pra baixo devolve o foco aos botoes", s3.cardFocus)
                frame(6)
                local L3 = Showcase.layout(love.graphics.getWidth(), love.graphics.getHeight())
                local b1 = L3.buttons[1]
                mx, my = b1.x + b1.w / 2, b1.y + b1.h / 2
                frame(2)
                s3:mousepressed(mx, my, 1); s3:mousereleased(mx, my, 1)
                t:eq("Continuar avanca pro proximo painel", s3.item.kind, "achievement")
                s3:update(0.3)
                s3:keypressed("escape")
                t:falsy("Esc sem inspecao: pula tudo e fecha", s3:isVisible())
            end)
            love.mouse.getPosition = realMouse
            UQ.clear()
            t:truthy("4b sem excecao" .. (okI and "" or (": " .. tostring(errI))), okI)
        end

        for _, sz in ipairs({ { 1024, 768 }, { 1280, 720 }, { 1366, 768 }, { 1280, 800 } }) do
            local probs = Showcase.validate(Showcase.layout(sz[1], sz[2]), sz[1], sz[2])
            t:eq(("layout %dx%d valido%s"):format(sz[1], sz[2],
                #probs > 0 and (": " .. probs[1]) or ""), #probs, 0)
        end
        local prev = I18n.current
        local items = {
            { kind = "card", id = "warrior_golpe" }, { kind = "class", id = "mage" },
            { kind = "mastery", classId = "rogue", level = 2 }, { kind = "seal", classId = "mage", n = 3 },
            { kind = "achievement", id = "primeiro_chefe" },
        }
        for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
            I18n.setLocale(loc, true)
            local bad = {}
            for _, it in ipairs(items) do
                local tx = Showcase.texts(it)
                for _, f in ipairs({ "title", "name", "sub" }) do
                    local v = tx[f] or ""
                    if v == "" or v:find("unlock_showcase.", 1, true) or v:find("seals.", 1, true) then
                        bad[#bad + 1] = it.kind .. "." .. f
                    end
                end
            end
            t:eq(loc .. ": textos de todo tipo de item" .. (#bad > 0 and (" (" .. bad[1] .. ")") or ""), #bad, 0)
        end
        I18n.setLocale(prev or "pt_BR", true)
    end)
    PS._setPathForTests(nil)
    US.setOverrideAll(true)
    clean()
    t:truthy("suite sem erro" .. (ok and "" or (": " .. tostring(err))), ok)
    return t:done()
end

return M
