-- tools/screenshot_forge.lua
-- Valida a BIGORNA (RestScreen no modo picker): grade de CARTAS REAIS com
-- hover 3D, painel de preview de ganho ancorado na carta, e a CERIMÔNIA de
-- forja — pose herói + 3 marteladas + PLACA DE DELTA ("ATQ 8 -> 10").
--
--   love . screenshot_forge
--     → forge_idle.png         grade ociosa
--     → forge_hover.png        mouse sobre uma carta: lift + painel de preview
--     → forge_anticipation.png carta subindo pra pose herói, placa com o ANTES
--     → forge_clang.png        1a martelada (decalque + faíscas)
--     → forge_turn.png         A VIRADA: valor antigo cede, novo em pop dourado
--     → forge_stamp.png        3a martelada: o selo "+N" carimba
--     → forge_settled.png      assentado e legível
--
-- Timeline esperada (t = 0 no clique; constantes FORGE_T do RestScreen):
--   0.34 lift completo · 0.46 clang1 · 0.74 clang2 = VIRADA
--   1.00 clang3 = selo · 1.22 settle · ~2.57 fecha
--
-- Padrão herdado de tools/screenshot_rewards.lua: o DRAW roda a cada frame
-- simulado porque Card:draw MUTA estado da carta (grava self.x/y) — sem
-- desenhar por frame o simulador não reproduz feedback loops de layout.
--
-- Arg de ferramenta seta _G.HEADLESS_TOOL=true (main.lua) → saves vão pra
-- *.tool.lua e o run.save.lua do jogador não é tocado.

local M = {}

local Game           = require("src.core.Game")
local RestScreen     = require("components.RestScreen")
local CRTShader      = require("src.ui.CRTShader")
local DissolveShader = require("src.ui.DissolveShader")
local FlashShader    = require("src.ui.FlashShader")
local ScreenShake    = require("src.systems.ScreenShake")
local EventManager   = require("engine.EventManager")
local FloatingText   = require("src.ui.FloatingText")
local CardParticles  = require("src.systems.CardParticles")
local I18n           = require("src.i18n.I18n")

-- Mouse "virtual": o simulador headless não move o cursor de verdade, então
-- monkey-patcha love.mouse.getPosition (é o que RestScreen:update consulta).
local fakeMouse = { x = -999, y = -999 }
local function installFakeMouse()
    local orig = love.mouse.getPosition
    love.mouse.getPosition = function()
        if fakeMouse.x >= 0 then return fakeMouse.x, fakeMouse.y end
        return orig()
    end
end

-- love . screenshot_forge [largura altura]
-- O tamanho é OPCIONAL e aplicado UMA ÚNICA VEZ, antes de qualquer desenho.
-- memory/ui_layout_invariants.md registra que setMode REPETIDO dentro de um
-- tool trava (e pedir janela maior que o desktop trava na 1ª chamada), então
-- aqui é uma chamada só e o valor é clampado à área útil.
local function applyWindowSize(w, h)
    if not w or not h then return end
    local _, _, flags = love.window.getMode()
    local dw, dh = love.window.getDesktopDimensions(flags and flags.display or 1)
    w = math.min(w, (dw or w) - 80)
    h = math.min(h, (dh or h) - 120)
    love.window.setMode(w, h, { resizable = true })
    require("src.ui.FontManager").clearCache()
    print(("[forge] janela: %dx%d"):format(
        love.graphics.getWidth(), love.graphics.getHeight()))
end

-- argW/argH: tamanho da janela (opcional). locale: nil (pt_BR) | en/es/fr/de.
-- O locale explicito existe pra VALIDAR A TRADUCAO: e em idioma estrangeiro
-- que o PT cravado aparece — capturar so em pt_BR esconde justamente o defeito
-- que se quer pegar. (E preciso passar explicitamente: tool de screenshot
-- forca pt_BR, senao o sandbox herdaria settings.tool.lua em qualquer idioma.)
function M.run(argW, argH, locale)
    applyWindowSize(tonumber(argW), tonumber(argH))
    I18n.init()
    I18n.setLocale(locale or "pt_BR")
    print("[forge] locale: " .. tostring(I18n.current))
    require("src.ui.PixelCanvas").enableNearest()
    CRTShader.load(); DissolveShader.load(); FlashShader.load(); ScreenShake.install()
    installFakeMouse()

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game

    -- Deck de teste: o starter tem só 2 cartas. Injeta cartas FORJÁVEIS do
    -- catálogo (ordenadas por id pra a captura ser determinística) até ter
    -- material suficiente pra grade — e uma já forjada, pra validar o selo
    -- "+N" e a linha "Forja +1 -> +2" do painel de hover.
    local CardDatabase = require("src.systems.CardDatabase")
    local run = game.runManager.currentRun
    local pool = {}
    for id in pairs(CardDatabase:getAllCards()) do table.insert(pool, id) end
    table.sort(pool)
    local added = 0
    for _, id in ipairs(pool) do
        if added >= 6 then break end
        -- Joker NUNCA entra em currentDeck (invariante do projeto: vive em
        -- currentRun.jokers via Game:addJokerToRun).
        local cd = CardDatabase:getCard(id)
        if cd and cd.type ~= "joker" and game.runManager:canUpgrade(id) then
            game.runManager:addCardToDeck(id)
            added = added + 1
        end
    end
    -- CÓPIAS REPETIDAS do MESMO id: a queixa do dono ("se eu tiver duas
    -- cartas iguais, na tela de forjar só aparece uma"). O deck de teste
    -- carrega 3 cópias de warrior_strike de propósito — a grade tem que
    -- mostrar as TRÊS, e forjar uma não pode mexer nas outras duas.
    game.runManager:addCardToDeck("warrior_strike")
    game.runManager:addCardToDeck("warrior_strike")

    -- Uma carta já forjada (mostra o selo +1 e o preview partindo de +1).
    -- É a PRIMEIRA cópia de warrior_strike: com o nível por cópia, a grade
    -- mostra "+1" em UMA das três e "+0" nas outras duas.
    local firstIdx = nil
    for i, entry in ipairs(run.currentDeck) do
        local id = type(entry) == "table" and entry.id or entry
        if id and game.runManager:canUpgrade(id) then firstIdx = i; break end
    end
    if firstIdx then game.runManager:upgradeCardAt(firstIdx) end

    local screen = RestScreen:new()
    screen:show(game, function() print("[forge] onClose") end, "forge")

    print(("[forge] cartas forjaveis=%d  paginas=%d  na pagina=%d"):format(
        #screen.cardList, screen.pageCount, #screen.cardEntries))
    for i, e in ipairs(screen.cardEntries) do
        print(("  entry[%d] id=%s lvl=%d  x=%d y=%d w=%.0f h=%.0f"):format(
            i, tostring(e.id), e.level or 0, e.x, e.y, e.w, e.h))
    end

    local stepDt = 1 / 60
    local function simulate(secs)
        local t = 0
        while t < secs do
            EventManager.update(stepDt)
            FloatingText.update(stepDt)
            ScreenShake.update(stepDt)
            FlashShader.update(stepDt)
            CardParticles.update(stepDt)
            screen:update(stepDt)
            love.graphics.clear(0, 0, 0, 1)
            screen:draw()
            t = t + stepDt
        end
    end

    local sfx = (locale and locale ~= "pt_BR") and ("_" .. locale) or ""
    local function capture(name)
        name = name:gsub("%.png$", sfx .. ".png")
        CRTShader.setEnabled(true); CRTShader.setStrength(0.85); CRTShader.setPower(1)
        CRTShader.beginScene()
        screen:draw()
        CardParticles.draw()
        FloatingText.draw()
        FlashShader.draw()
        CRTShader.endScene()
        love.graphics.captureScreenshot(function(id)
            id:encode("png", name)
            print("[forge] " .. name .. " salvo")
        end)
        love.graphics.present()
    end

    simulate(0.5)
    capture("forge_idle.png")

    -- Hover na ULTIMA copia de warrior_strike (a 3a das tres injetadas acima).
    -- E de proposito uma COPIA REPETIDA: a cerimonia que vem a seguir forja
    -- ESSA, e as outras duas tem que ficar paradas onde estavam.
    local target = nil
    for k = #screen.cardEntries, 1, -1 do
        if screen.cardEntries[k].id == "warrior_strike" then
            target = screen.cardEntries[k]; break
        end
    end
    target = target or screen.cardEntries[2] or screen.cardEntries[1]
    if not target then
        print("[forge] ERRO: nenhuma carta forjavel na pagina - nada a validar")
        love.event.quit()
        return
    end
    -- Niveis das TRES copias antes da forja (a prova do "por copia").
    local function dumpCopies(tag)
        local out = {}
        for k, e in ipairs(screen.cardEntries) do
            if e.id == "warrior_strike" then
                table.insert(out, ("entry[%d] idx=%s lvl=%d")
                    :format(k, tostring(e.idx),
                        game.runManager:getUpgradesAt(e.idx)))
            end
        end
        print(("[forge] copias de warrior_strike %s: %s")
            :format(tag, table.concat(out, " | ")))
    end
    dumpCopies("ANTES")
    fakeMouse.x = math.floor(target.x + target.w / 2)
    fakeMouse.y = math.floor(target.y + target.h / 2)
    simulate(0.6)
    print(("[forge] hoverIdx=%s (esperado: a carta sob o mouse)"):format(
        tostring(screen._hoverIdx)))
    capture("forge_hover.png")

    -- Confirma a forja na carta em hover.
    -- getUpgradesAt (a COPIA) e nao getUpgrades (o maior entre as copias do
    -- mesmo id) — senao a linha mentiria: outra copia ja estava em +1.
    local beforeLvl = game.runManager:getUpgradesAt(target.idx)
    screen:mousereleased(fakeMouse.x, fakeMouse.y, 1)
    print(("[forge] forjou %s (copia idx=%s): nivel %d -> %d  (busy=%s forge=%s)"):format(
        tostring(target.id), tostring(target.idx), beforeLvl,
        game.runManager:getUpgradesAt(target.idx),
        tostring(screen.busy), tostring(screen.forge ~= nil)))
    dumpCopies("DEPOIS")

    local f = screen.forge
    if f then
        print(("[forge] pose heroi: x=%d y=%d scale=%.2f (grade scale=%.2f)"):format(
            f.heroX, f.heroY, f.heroScale, target.w / 96))
        print(("[forge] placa: x=%d y=%d w=%d h=%d  linhas=%d"):format(
            f.plate.x, f.plate.y, f.plate.w, f.plate.h, #f.lines))
        for i, ln in ipairs(f.lines) do
            print(("  linha[%d] %s: %s -> %s  (delta %s)"):format(
                i, ln.label, ln.old, ln.new, ln.delta))
        end
    end

    -- `target` é a MESMA table guardada em screen.cardEntries, e a cerimônia
    -- troca entry.inst/entry.level in-place — então isto observa o swap.
    local function beat(label)
        local ln = f and f.lines[1]
        print(("[forge] %s: scale=%.2f veil=%.2f plateA=%.2f glow=%.2f "
            .. "oldA=%.2f newA=%.2f newS=%.2f hot=%.2f stampA=%.2f clangs=%d lvl=%s"):format(
            label, f.scale, f.veil, f.plateA, f.glow,
            ln and ln.oldA or -1, ln and ln.newA or -1,
            ln and ln.newS or -1, ln and ln.hot or -1,
            f.stampA, #f.clangs, tostring(target.level)))
    end

    simulate(0.30)   -- t=0.30: subindo pra pose herói, placa mostra o ANTES
    beat("antecipacao")
    capture("forge_anticipation.png")

    simulate(0.22)   -- t=0.52: depois da 1a martelada
    beat("clang1")
    capture("forge_clang.png")

    simulate(0.30)   -- t=0.82: logo após A VIRADA (newS ainda em pop)
    beat("virada")
    capture("forge_turn.png")

    simulate(0.25)   -- t=1.07: 3a martelada carimbou o selo
    beat("selo")
    capture("forge_stamp.png")

    simulate(0.55)   -- t=1.62: assentado, tudo legível
    beat("assentado")
    capture("forge_settled.png")

    love.event.quit()
end

return M
