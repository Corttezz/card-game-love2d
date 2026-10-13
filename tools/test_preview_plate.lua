-- tools/test_preview_plate.lua
-- A PLACA da previa de dano (src/ui/DamagePreviewPanel, Out/2026): resumo
-- por padrao, detalhes sob demanda, lembrado em settings, e as bandas nunca
-- se sobrepoem em nenhum tamanho de janela.
--
-- Historico: o painel nasceu mostrando a conta inteira (carta a carta, fichas,
-- combos, coringas) o tempo todo — o dono: "grande e confuso". Agora:
--   • RESUMO (default): dano, Bloqueio, LETAL + fichas de combo/coringa;
--   • DETALHES: a conta inteira — clique na placa, tecla V (main.lua) ou
--     foco + A no pad (a placa e alvo do NavCursor);
--   • a escolha persiste em `previewDetails` (SaveManager/SettingsMenu).
--
-- O que trava aqui:
--   • Panel.layout + Panel.validate em 6 tamanhos (janela falsificada), pelo
--     caminho REAL (Panel.draw com uma leva de verdade), resumo e detalhes;
--   • resumo e mais BAIXO que detalhes com a mesma leva;
--   • toggle persiste no arquivo de settings (sandbox *.tool.lua);
--   • clique dentro da placa alterna; fora nao; sem draw no quadro, nao;
--   • chaves i18n nos 5 locales.
--
--   love . test_one test_preview_plate

local TK = require("tools.testkit")

local M = {}

local realW, realH = love.graphics.getWidth, love.graphics.getHeight
local fakeW, fakeH
local function fakeWindow(w, h)
    fakeW, fakeH = w, h
    love.graphics.getWidth = function() return fakeW or realW() end
    love.graphics.getHeight = function() return fakeH or realH() end
    require("src.ui.FontManager").clearCache()
end
local function restoreWindow()
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
    require("src.ui.FontManager").clearCache()
end

-- Ancora do JOGAR como GameplayScene.updatePlayButtonPosition a calcula.
local function playAnchor()
    local Config = require("src.core.Config")
    local bw = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
    local bx = (love.graphics.getWidth() - bw) / 1.05
    local by = love.graphics.getHeight() * 0.62
    return { x = bx, y = by, w = bw }
end

local function drawPlate(game, Panel)
    local cv = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.push("all")
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 1)
    local ok, err = pcall(Panel.draw, game, playAnchor(), 60)
    love.graphics.pop()
    cv:release()
    if not ok then error(err, 0) end
    return Panel.lastRect
end

function M.run()
    local t = TK.new("placa da previa: resumo/detalhes, bandas, persistencia, clique, i18n")
    TK.bootstrap()
    local Panel = require("src.ui.DamagePreviewPanel")
    local SM = require("engine.SaveManager")
    local I18n = require("src.i18n.I18n")

    -- leva de verdade: 5 golpes do guerreiro (Saraivada + Par), 2 de Forca
    TK.seedRng(4242)
    local game = TK.newRunGame("warrior")
    local db = require("src.systems.CardDatabase"):new()
    db:loadData()
    game.hand = {}
    for _, id in ipairs({ "warrior_strike", "warrior_strike", "warrior_twin_strike",
            "warrior_bash", "warrior_defend" }) do
        game.hand[#game.hand + 1] = db:createCardInstance(db:getCard(id))
    end
    game.player.mana, game.player.maxMana = 10, 10
    game.player.strength = 2
    game.enemy.maxHealth, game.enemy.health = 200, 200
    game.selectedCards, game.turn = {}, "player"
    for i = 1, 5 do game:selectCard(game.hand[i]) end
    game.jokerSlots = { db:createCardInstance(db:getCard("joker_001")) }

    local okRun, err = pcall(function()
        -- 1. default = resumo
        _G.gameSettings = _G.gameSettings or {}
        _G.gameSettings.previewDetails = nil
        t:falsy("default: detalhes desligados", Panel.detailsOn())

        -- 2. bandas validas em 6 tamanhos, resumo e detalhes
        local sizes = { { 640, 480 }, { 800, 600 }, { 1024, 768 }, { 1366, 768 },
            { 1920, 1080 }, { 2560, 1440 } }
        for _, sz in ipairs(sizes) do
            fakeWindow(sz[1], sz[2])
            Panel.update(game, nil, 1 / 60)
            local R = Panel.current()
            t:truthy(sz[1] .. "x" .. sz[2] .. ": previa existe", R and R.damage > 0)
            t:truthy(sz[1] .. "x" .. sz[2] .. ": leva tem combo", R and #R.combos > 0)
            _G.gameSettings.previewDetails = false
            local compact = drawPlate(game, Panel)
            local okC, why = Panel.validate(compact.layout, compact.metrics)
            t:truthy(sz[1] .. "x" .. sz[2] .. " resumo: bandas validas" .. (okC and "" or (" (" .. tostring(why) .. ")")), okC)
            t:truthy(sz[1] .. "x" .. sz[2] .. " resumo: so fichas/hover (nenhuma linha de carta)",
                (function()
                    for _, r in ipairs(compact.layout.bands.rows) do
                        if r.kind == "card" or r.kind == "combo" or r.kind == "joker" then return false end
                    end
                    return true
                end)())
            t:truthy(sz[1] .. "x" .. sz[2] .. " resumo: fichas de combo presentes",
                compact.layout.bands.rows[1] and compact.layout.bands.rows[1].kind == "chips")
            _G.gameSettings.previewDetails = true
            local full = drawPlate(game, Panel)
            local okF, whyF = Panel.validate(full.layout, full.metrics)
            t:truthy(sz[1] .. "x" .. sz[2] .. " detalhes: bandas validas" .. (okF and "" or (" (" .. tostring(whyF) .. ")")), okF)
            t:truthy(sz[1] .. "x" .. sz[2] .. ": resumo mais baixo que detalhes (" .. compact.h .. " < " .. full.h .. ")",
                compact.h < full.h)
            t:truthy(sz[1] .. "x" .. sz[2] .. " resumo: cabe acima do JOGAR",
                compact.y + compact.h <= playAnchor().y)
        end
        restoreWindow()

        -- 3. toggle persiste (sandbox: settings.tool.lua)
        Panel.setDetails(false)
        t:falsy("setDetails(false)", Panel.detailsOn())
        Panel.toggleDetails()
        t:truthy("toggle liga", Panel.detailsOn())
        t:truthy("persistiu no arquivo de settings", (SM.loadSettings() or {}).previewDetails == true)
        Panel.toggleDetails()
        t:falsy("toggle desliga", Panel.detailsOn())
        t:truthy("persistiu o desligar", (SM.loadSettings() or {}).previewDetails == false)
        t:truthy("DEFAULT_SETTINGS conhece previewDetails", SM.DEFAULT_SETTINGS.previewDetails == false)

        -- 4. clique: dentro alterna, fora nao, sem draw nao
        fakeWindow(1024, 768)
        Panel.update(game, nil, 1 / 60)
        local rect = drawPlate(game, Panel)
        t:truthy("draw publica hitRect", Panel.hitRect ~= nil)
        local hr = Panel.hitRect
        t:falsy("clique fora da placa: nao consome", Panel.mousepressed(hr.x - 20, hr.y - 20, 1))
        t:falsy("botao direito: nao consome", Panel.mousepressed(hr.x + hr.w / 2, hr.y + hr.h / 2, 2))
        local before = Panel.detailsOn()
        t:truthy("clique na placa: consome", Panel.mousepressed(hr.x + hr.w / 2, hr.y + hr.h / 2, 1))
        t:truthy("clique na placa: alternou", Panel.detailsOn() ~= before)
        Panel.setDetails(false)
        Panel.update(game, nil, 1 / 60)   -- sem draw depois: retangulo some
        t:falsy("update sem draw: hitRect vazio", Panel.hitRect)
        t:falsy("sem draw no quadro: clique nao consome", Panel.mousepressed(hr.x + 5, hr.y + 5, 1))
        restoreWindow()

        -- 5. main.lua: tecla V e clique roteados (fonte)
        local src = love.filesystem.read("main.lua") or ""
        t:truthy("main.lua: tecla V alterna", src:find('key == "v" and currentState == "playing"', 1, true) ~= nil)
        t:truthy("main.lua: clique na placa antes da cena",
            src:find('require("src.ui.DamagePreviewPanel").mousepressed(x, y, button)', 1, true) ~= nil)
        -- (sem linha em Configuracoes: a aba Jogo tem altura fixa e 5 linhas
        -- — test_pause_menu trava isso; a placa e a tecla V sao o controle)
        local sm = love.filesystem.read("components/SettingsMenu.lua") or ""
        t:truthy("SettingsMenu: snapshot persiste previewDetails", sm:find("previewDetails = g.previewDetails", 1, true) ~= nil)

        -- 6. i18n nos 5 locales
        local cur = I18n.getLocale()
        for _, loc in ipairs({ "pt_BR", "en", "es", "de", "fr" }) do
            I18n.setLocale(loc, true)
            for _, key in ipairs({ "damage_preview.details_show", "damage_preview.details_hide" }) do
                local v = I18n.t(key, nil, "__missing__")
                t:truthy(loc .. ": " .. key, v ~= "__missing__" and v ~= key and v ~= "")
            end
        end
        I18n.setLocale(cur, true)
    end)
    restoreWindow()
    t:check("sem excecao" .. (okRun and "" or (": " .. tostring(err))), okRun)
    return t:done()
end

return M
