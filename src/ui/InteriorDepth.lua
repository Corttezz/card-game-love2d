-- src/ui/InteriorDepth.lua
-- CONTATO do chefe com o chão do salão (Out/2026, dono: "o tirano parece
-- flutuar"). A sombra de contato do EnemyRenderer é uma elipse lisa e fraca;
-- sobre pedra escura ela some e o pé fica sem peso. Aqui entra a oclusão de
-- ambiente que jogo 2D usa pra vender contato: uma POÇA ESCURA em degraus,
-- na grade da arte, achatada no plano do chão, densa logo sob os pés e se
-- abrindo pra frente quando a luz vem do fundo da sala (sombra projetada
-- no piso, não um disco).
--
-- Só quem APOIA (pose grounded). Flutuante já tem a sombra deslocada do
-- EnemyRenderer — poça sob quem paira contradiria a pose.
--
-- Desenhado ANTES do chefe (o pé cobre a parte de cima da poça). A largura
-- vem do bbox do quadro anterior (o chefe não muda de largura de um quadro
-- pro outro); no primeiro quadro não há poça.

local SceneBackground = require("src.ui.SceneBackground")
local SceneAnchors    = require("src.data.scene_anchors")
local EnemyPoses      = require("src.data.enemy_poses")

local InteriorDepth = {}

-- Força da poça por salão (piso claro pede menos, pedra escura pede a cor
-- mais funda pra ainda separar). Cor = tinta quase preta da paleta grimório.
InteriorDepth.STRENGTH = {
    [1] = 0.55, [2] = 0.50, [3] = 0.70, [4] = 0.50, [5] = 0.60, [6] = 0.55,
}
local INK = { 0.04, 0.02, 0.03 }

local lastW = nil

-- Guarda a largura útil do chefe a partir do bbox do EnemyRenderer.
function InteriorDepth.noteBbox(bbox)
    if bbox and bbox.width and bbox.height then
        -- o canvas do sprite tem margem transparente: o pé ocupa ~40% dele
        lastW = math.min(bbox.width * 0.40, bbox.height * 0.32)
    end
end

function InteriorDepth.reset() lastW = nil end

-- Níveis da poça (distância elíptica normalizada → alpha relativo)
local function level(d)
    if d < 0.45 then return 1.0 end
    if d < 0.75 then return 0.62 end
    if d < 1.0 then return 0.30 end
    return 0
end

function InteriorDepth.drawContact(hall, spriteId, footX, footY)
    if not lastW or EnemyPoses.isFloating(spriteId) then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local key = "castle_hall_" .. hall
    local tr = SceneBackground.getCoverTransform(key, w, h)
    if not tr then return end
    local s = tr.scale
    local strength = InteriorDepth.STRENGTH[hall] or 0.55
    local anchor = SceneAnchors.get(key)

    -- em pixels da ARTE
    local ax = (footX - tr.ox) / s
    local ay = (footY - tr.oy) / s
    local rx = math.max(4, lastW / s * 0.5)
    local ryBack = math.max(1.5, rx * 0.16)                 -- atrás do pé: curta
    local ryFront = ryBack * ((anchor.lightBehind ~= false) and 2.0 or 1.2)
    local x0, x1 = math.floor(ax - rx), math.ceil(ax + rx)
    local y0, y1 = math.floor(ay - ryBack), math.ceil(ay + ryFront)

    -- corridas horizontais de mesmo nível: poucos retângulos por linha
    for y = y0, y1 do
        local dy = (y + 0.5) - ay
        local ry = dy < 0 and ryBack or ryFront
        local runStart, runLvl = nil, 0
        for x = x0, x1 + 1 do
            local lv = 0
            if x <= x1 then
                local dx = ((x + 0.5) - ax) / rx
                lv = level(math.sqrt(dx * dx + (dy / ry) ^ 2))
            end
            if lv ~= runLvl then
                if runStart and runLvl > 0 then
                    love.graphics.setColor(INK[1], INK[2], INK[3], strength * runLvl)
                    love.graphics.rectangle("fill",
                        math.floor(tr.ox + runStart * s), math.floor(tr.oy + y * s),
                        math.ceil((x - runStart) * s), math.ceil(s))
                end
                runStart, runLvl = x, lv
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return InteriorDepth
