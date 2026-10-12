-- tools/test_enemy_axis.lua
-- HUD (intent, barra de vida, pills) centrado no CORPO de todo inimigo
-- (Out/2026, dono: "o 29 e a barra estão à esquerda do corpo").
--
--   love . test_one test_enemy_axis
--
-- O bbox que o EnemyRenderer devolve (e que o EnemyHud usa como cx) era o
-- centro do CANVAS do sprite — arma, cajado, capa ou margem de um lado só
-- tiravam o HUD do corpo em até 36px a 1080p. Agora é o EIXO DO CORPO
-- (EnemyRenderer.bodyAxis: automático, ou override `axisX` da pose).
-- Para TODO diretório de inimigo:
--   (a) o eixo cai dentro do conteúdo opaco do quadro 0
--   (b) o cx do HUD fica a <= 3 px DA ARTE do eixo do corpo desenhado
--   (c) o eixo do corpo cai no ponto pedido (âncora da cena) ± 1 px da arte

local TK = require("tools.testkit")
local M = {}

function M.run()
    local t = TK.new("HUD no eixo do corpo")
    local EnemyRenderer = require("src.ui.EnemyRenderer")

    local root = "assets/sprites/characters/enemies"
    local ids = {}
    for _, d in ipairs(love.filesystem.getDirectoryItems(root)) do
        if love.filesystem.getInfo(root .. "/" .. d .. "/animations/idle/south") then
            ids[#ids + 1] = d
        end
    end
    table.sort(ids)
    t:truthy("há inimigos pra medir (" .. #ids .. ")", #ids >= 20)

    local canvas = love.graphics.newCanvas(64, 64)
    -- sem a deriva lateral dos flutuantes (balanço, não posição): é ela que
    -- reducedMotion tira, e é a POSIÇÃO que se mede aqui
    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = true }
    local bad = 0
    for _, id in ipairs(ids) do
        EnemyRenderer.clearCache()
        EnemyRenderer.resetRun()
        local m = EnemyRenderer.debugClipMetrics(id, "idle")
        local axis = EnemyRenderer.bodyAxis(id)
        local l = m.w / 2 + m.off - m.cw / 2
        local inside = axis >= l - 0.5 and axis <= l + m.cw + 0.5
        local game = { enemy = { spriteId = id, isBoss = false, health = 10 } }
        love.graphics.setCanvas(canvas)
        local bbox = EnemyRenderer.draw(game, 960, 800, { sizeK = 1 })
        love.graphics.setCanvas()
        local f = EnemyRenderer.getLastFoot()
        local hudOff = (f.bodyX - bbox.cx) / f.scale
        local anchorOff = (f.bodyX - 960) / f.scale
        local ok = inside and math.abs(hudOff) <= 3 and math.abs(anchorOff) <= 1
        if not ok then
            bad = bad + 1
            print(string.format("  [eixo] %s: eixo=%.1f conteudo=[%.1f..%.1f] hud=%.2f ancora=%.2f (px da arte)",
                id, axis, l, l + m.cw, hudOff, anchorOff))
        end
    end
    _G.gameSettings = savedSettings
    t:truthy(string.format("HUD a <= 3 px da arte do corpo e corpo na âncora, em todos os %d inimigos (%d falhas)",
        #ids, bad), bad == 0)

    -- overrides declarados continuam valendo (o automático erra com escudo
    -- largo / quadrúpede de frente / orbe grande — conferido com régua)
    local axis, src = EnemyRenderer.bodyAxis("winter_monarch")
    t:eq("winter_monarch usa o eixo manual", src, "manual")
    t:eq("...56", axis, 56)

    EnemyRenderer.clearCache()
    EnemyRenderer.resetRun()
    return t:done()
end

return M
