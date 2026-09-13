-- src/data/scene_anchors.lua
-- ============================================================================
-- ÂNCORA DE CHÃO DAS CENAS DE FUNDO (interiores)
-- ============================================================================
-- Defeito que originou a tabela (Set/2026): o inimigo era ancorado em
-- `height * 0.68` — um número fixo, igual pra TODA cena. No `castle_hall_2`
-- essa linha cai na PAREDE, acima da laje: o chefe do ato 2 ficava pairando
-- no meio do salão com uma sombra de contato embaixo.
--
-- 0.68 nunca foi "a altura do chão": era a altura do chão de UMA arte, herdada
-- por todas as outras. Cada PNG tem o horizonte onde o artista pôs — então a
-- linha de piso é DADO DA CENA, não constante do renderer.
--
-- `yr` está em coordenadas NORMALIZADAS DA PNG, não da tela: o
-- `SceneBackground` desenha em cover-fit e, em telas largas (16:9), CORTA a
-- imagem na vertical. Converter via `SceneBackground.getCoverTransform`
-- mantém o pé no mesmo ponto do piso em qualquer resolução.
--
-- REFERÊNCIA DE ENQUADRAMENTO: na estrada o inimigo pisa em
-- `WorldRoad.getRoadAnchor(BATTLE_REL, ...)` ≈ 76% da altura da tela. Os
-- interiores ficam perto disso — quando a arte permite. O `castle_hall_2`
-- tem a laje mais baixa que os outros dois e por isso pede um valor maior;
-- forçá-lo aos 0.76 dos irmãos é exatamente o bug que começou tudo.
--
-- Campos:
--   xr, yr        ponto do chão onde o inimigo pisa (0..1 na PNG)
--   shadowA       opacidade base da sombra de contato nessa cena
--   lightXr       x normalizado da fonte de luz dominante da arte; a sombra
--                 de quem FLUTUA se desloca pro lado oposto (ver
--                 [[enemy_poses]] · [[shadow_engine]])
--   lightBehind   true = luz vem do fundo da sala → sombra cai pro primeiro
--                 plano (pra baixo na tela)
--
-- Ver [[ui_layout_invariants]] regra 3: cena sem entrada aqui usa o padrão
-- e AVISA no console.
-- ============================================================================

local SceneBackground = require("src.ui.SceneBackground")

local SceneAnchors = {}

-- Padrão conservador: meio da tela, 76% de altura (a linha da estrada).
SceneAnchors.DEFAULT = {
    xr = 0.5, yr = 0.76,
    shadowA = 1.0, lightXr = 0.5, lightBehind = true,
}

SceneAnchors.BY_SCENE = {
    -- ATO 1 — salão de pedra clara. Piso pálido do fundo (após os degraus)
    -- até a frente; 0.78 fica no meio da laje, sobre o tapete vermelho.
    -- Tochas nas duas paredes + vitral ao fundo → sombra curta e definida.
    castle_hall_1 = { xr = 0.50, yr = 0.78,
                      shadowA = 1.00, lightXr = 0.5, lightBehind = true },

    -- ATO 2 — catedral roxa. A laje começa BEM mais baixa que nos irmãos
    -- (a parede e a porta ocupam até ~0.78): 0.83 é o primeiro ponto em que
    -- o pé realmente encosta na pedra. É a cena do defeito original.
    castle_hall_2 = { xr = 0.50, yr = 0.83,
                      shadowA = 0.92, lightXr = 0.5, lightBehind = true },

    -- ATO 3 — salão de lava. Chão alto e aberto; a luz vem DE BAIXO (as
    -- fendas incandescentes nas laterais), então a sombra de contato é
    -- fraca — chão que brilha não projeta sombra escura.
    castle_hall_3 = { xr = 0.50, yr = 0.78,
                      shadowA = 0.45, lightXr = 0.5, lightBehind = false },

    -- Cenas legadas do SceneLayer (fallback por ato quando o hall não
    -- existe, e caminho antigo de SCENE_MODE ~= "worldroad").
    catacumbs   = { xr = 0.50, yr = 0.80, shadowA = 0.95,
                    lightXr = 0.5, lightBehind = true },
    stone_tower = { xr = 0.50, yr = 0.82, shadowA = 0.90,
                    lightXr = 0.5, lightBehind = true },
    abyss       = { xr = 0.50, yr = 0.80, shadowA = 0.60,
                    lightXr = 0.5, lightBehind = false },
    gameplay    = { xr = 0.50, yr = 0.76, shadowA = 1.00,
                    lightXr = 0.5, lightBehind = true },
}

local warned = {}

function SceneAnchors.get(scene)
    local a = scene and SceneAnchors.BY_SCENE[scene]
    if not a then
        if scene and not warned[scene] then
            warned[scene] = true
            print("[scene_anchors] AVISO: cena '" .. tostring(scene)
                .. "' sem linha de chão declarada — usando o padrão "
                .. "(yr=0.76). Declare em src/data/scene_anchors.lua.")
        end
        return SceneAnchors.DEFAULT
    end
    return a
end

-- Ponto de CHÃO da cena em pixels de tela, passando pelo MESMO cover-fit que
-- `SceneBackground.draw` usa (em 16:9 a PNG é cortada na vertical — ignorar
-- isso desancora o pé conforme o aspecto da janela).
-- Retorna (x, y). Cai no padrão relativo à tela se a PNG não existir.
function SceneAnchors.groundAnchor(scene, width, height)
    local a = SceneAnchors.get(scene)
    local tr = SceneBackground.getCoverTransform(scene, width, height)
    if not tr then
        return math.floor(width * a.xr), math.floor(height * a.yr)
    end
    return math.floor(tr.ox + a.xr * tr.dw),
           math.floor(tr.oy + a.yr * tr.dh)
end

return SceneAnchors
