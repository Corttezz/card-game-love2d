-- src/data/enemy_poses.lua
-- ============================================================================
-- POSE DOS INIMIGOS — apoiado no chão × flutuando de propósito
-- ============================================================================
-- Defeito que originou a tabela (Set/2026, reportado pelo dono): criatura
-- pairando no ar COM sombra elíptica de contato embaixo. A sombra afirma
-- "estou apoiado"; a pose afirma "estou no ar". As duas juntas não leem
-- como nada — leem como bug.
--
-- A correção NÃO é colar todo mundo no chão. É CLASSIFICAR:
--
--   grounded  — tem pernas/pés/base. Pé do CONTEÚDO cravado no chão
--               (EnemyRenderer já faz isso via clipMetrics.pad) e sombra
--               de CONTATO: grande, próxima, opaca.
--
--   floating  — espectro, aparição, criatura alada sem pé de apoio. Sobe
--               `hover` (fração da altura do sprite) e balança `bob`.
--               Sombra de ALTURA: menor, mais difusa, mais fraca e
--               deslocada na direção oposta à luz — a linguagem visual de
--               "isto está no ar", não "isto está apoiado".
--
-- A classificação saiu de OLHAR os 21 sprites (assets/sprites/characters/
-- enemies/<id>/animations/idle/south/0.png) — doutrina do projeto. O
-- critério é literal: dá pra ver o PÉ tocando a linha de base? Bota,
-- garra, casco, pata, base de lodo = grounded. Barra de manto que afina,
-- farrapo que se desfaz, garra pendurada de asa aberta = floating.
--
-- Campos (todos opcionais fora de `pose`):
--   pose      "grounded" | "floating"
--   hover     altura de repouso, fração da ALTURA DO SPRITE na tela
--   bob       amplitude do balanço vertical, mesma unidade
--   bobSpeed  rad/s do balanço (criatura pesada = lenta)
--   shadowK   escala da sombra (largura); < 1 = mais longe do chão
--   shadowA   multiplicador de opacidade da sombra
--
-- ACESSIBILIDADE: com `reducedMotion` o `bob` some, o `hover` PERMANECE.
-- Altura é informação (diz o que a criatura é), balanço é enfeite.
--
-- Ver [[shadow_engine]] · [[ui_layout_invariants]] (regra 3: nada de
-- fallback silencioso — id fora da tabela cai em grounded e AVISA).
-- ============================================================================

local EnemyPoses = {}

-- Padrão de quem tem pé no chão.
local GROUNDED = {
    pose = "grounded",
    hover = 0, bob = 0, bobSpeed = 0,
    shadowK = 1.0, shadowA = 1.0,
}
EnemyPoses.GROUNDED = GROUNDED

-- ---------------------------------------------------------------------------
-- OS 21 DO ROSTER (+ legados grave_slime / stone_golem / abyss_wraith)
-- ---------------------------------------------------------------------------
EnemyPoses.BY_ID = {
    -- === APOIADOS ============================================================
    abyss_tyrant      = { pose = "grounded" },  -- garras blindadas plantadas
    blood_duke        = { pose = "grounded" },  -- botas sob o manto
    bog_ghoul         = { pose = "grounded" },  -- pés palmados
    cursed_scarecrow  = { pose = "grounded" },  -- botas de couro
    ember_imp         = { pose = "grounded" },  -- quadrúpede, patas no chão
    frost_wight       = { pose = "grounded" },  -- botas de gelo
    glacier_knight    = { pose = "grounded" },  -- soleretes + espada no chão
    grave_slime       = { pose = "grounded" },  -- base de lodo assentada
    harvest_reaper    = { pose = "grounded" },  -- botas
    mire_hag          = { pose = "grounded" },  -- botas de pântano
    moon_gargoyle     = { pose = "grounded" },  -- agachada nas garras
    obsidian_sentinel = { pose = "grounded" },  -- botas de placas
    rot_colossus      = { pose = "grounded" },  -- pés de três dedos
    rune_golem        = { pose = "grounded" },  -- pés de pedra
    stone_golem       = { pose = "grounded" },  -- pernas de pedra
    winter_monarch    = { pose = "grounded" },  -- botas sob a capa

    -- === FLUTUANTES ==========================================================
    -- Espectro puro: manto que AFINA até virar nada. Sobe mais alto e
    -- balança mais — nada nele sugere peso.
    abyss_wraith = { pose = "floating",
                     hover = 0.10, bob = 0.022, bobSpeed = 0.85,
                     shadowK = 0.55, shadowA = 0.45 },

    -- Aparição encapuzada de farrapos que se desfazem em fumaça roxa.
    dusk_shade   = { pose = "floating",
                     hover = 0.09, bob = 0.020, bobSpeed = 0.95,
                     shadowK = 0.58, shadowA = 0.48 },

    -- Rei-carniça: asas ABERTAS e talões PENDURADOS (dedos curvados, sem
    -- sola). Paira baixo e rápido — é batida de asa, não deriva etérea.
    carrion_king = { pose = "floating",
                     hover = 0.07, bob = 0.016, bobSpeed = 1.35,
                     shadowK = 0.68, shadowA = 0.58 },

    -- Lich da Torre: o sprite TEM botas, entao pelo criterio literal da
    -- tabela ele seria apoiado — e era. Vira flutuante por DECISAO DE
    -- DESIGN do dono (Set/2026): "quero que o boss do ato 2 fique meio que
    -- flutuando, sem sombra no pe, indo pra cima e pra baixo lentamente".
    --
    -- Registrado assim, com a excecao explicita, porque o criterio da tabela
    -- continua valendo pros outros 20: quem quebra a regra tem que dizer por
    -- que, senao a proxima pessoa "corrige" isto de volta pra grounded
    -- achando que foi engano.
    --
    -- Numeros: hover BAIXO e bob LENTO (0.55 rad/s, o mais lento da tabela).
    -- Ele nao e um espectro esvoacante — e um morto-vivo coroado que paira
    -- porque despreza o chao. Pressa quebraria a leitura.
    tower_lich   = { pose = "floating",
                     hover = 0.075, bob = 0.014, bobSpeed = 0.55,
                     shadowK = 0.62, shadowA = 0.50 },

    -- Rainha do eclipse: capa imensa que se abre num leque, sem pé algum.
    -- Realeza não treme — deriva lenta e larga.
    eclipse_queen = { pose = "floating",
                      hover = 0.06, bob = 0.013, bobSpeed = 0.62,
                      shadowK = 0.66, shadowA = 0.55 },
}

local warned = {}

-- Resolve a pose de um spriteId. Id desconhecido cai em `grounded` e
-- AVISA uma vez (invariante 3 de ui_layout_invariants: sem fallback mudo).
function EnemyPoses.get(spriteId)
    if not spriteId then return GROUNDED end
    local p = EnemyPoses.BY_ID[spriteId]
    if not p then
        if not warned[spriteId] then
            warned[spriteId] = true
            print("[enemy_poses] AVISO: '" .. tostring(spriteId)
                .. "' sem pose declarada — assumindo 'grounded'. "
                .. "Declare em src/data/enemy_poses.lua.")
        end
        return GROUNDED
    end
    return {
        pose     = p.pose or "grounded",
        hover    = p.hover or 0,
        bob      = p.bob or 0,
        bobSpeed = p.bobSpeed or 1.0,
        shadowK  = p.shadowK or 1.0,
        shadowA  = p.shadowA or 1.0,
    }
end

function EnemyPoses.isFloating(spriteId)
    local p = EnemyPoses.BY_ID[spriteId]
    return (p and p.pose == "floating") or false
end

return EnemyPoses
