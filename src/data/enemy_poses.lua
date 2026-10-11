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
--   drift     deriva HORIZONTAL do flutuante, mesma unidade do bob (só
--             chefes: pairar parado lia "estático", Out/2026)
--   idle      { fps, cycle = true } — idle assado em LOOP fechado (os 6
--             chefes: tools/bake_boss_idle.py). Sem o campo: ping-pong no
--             IDLE_FPS padrão do EnemyRenderer.
--   axisX     coluna (px do canvas do idle) do EIXO DO CORPO. O renderer
--             centra pelo bbox do conteúdo; quando cajado de um lado e capa
--             do outro desequilibram o bbox, o corpo sai do centro e o
--             chefe lê TORTO (winter_monarch, Out/2026).
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
    abyss_tyrant      = { pose = "grounded",    -- garras blindadas plantadas
                          idle = { fps = 6, cycle = true } },
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
    rot_colossus      = { pose = "grounded",    -- pés de três dedos
                          idle = { fps = 5, cycle = true } },
    rune_golem        = { pose = "grounded" },  -- pés de pedra
    stone_golem       = { pose = "grounded" },  -- pernas de pedra
    -- botas sob a capa. "Meio torto" (dono, Out/2026): o cajado pra fora à
    -- esquerda (x 7-30) e a capa esvoaçando à direita (até x 120) puxavam o
    -- centro do bbox pra x 63.5 — mas coroa, caveira, cinto e o meio das
    -- botas estão em x ~56. Centrado pelo bbox, o CORPO ficava 8px de arte
    -- (~20px de tela) à esquerda da porta, da barra de vida e do palco.
    winter_monarch    = { pose = "grounded", axisX = 56,
                          idle = { fps = 6, cycle = true } },

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
    -- Out/2026 ("não tem nada de especial"): o bob agora bate NA FREQUÊNCIA
    -- da asa (idle de 12 quadros a 8fps = 1.5s → 4.19 rad/s) — o corpo sobe
    -- a cada batida, como quem se sustenta no ar.
    carrion_king = { pose = "floating",
                     hover = 0.07, bob = 0.012, bobSpeed = 4.19,
                     drift = 0.010,
                     shadowK = 0.68, shadowA = 0.58,
                     idle = { fps = 8, cycle = true } },

    -- Lich da Torre: virou flutuante por DECISAO DE DESIGN do dono (Set/2026,
    -- 1a leva): "quero que o boss do ato 2 fique meio que flutuando, sem
    -- sombra no pe, indo pra cima e pra baixo lentamente". Na epoca ele era
    -- a UNICA excecao ao criterio literal da tabela — o sprite tinha botas
    -- de sola chata plantada e so o DADO dizia que ele flutuava.
    --
    -- Set/2026, 2a leva: "o pezinho dele precisa parecer que ele esta
    -- realmente flutuando, entao ele precisa ficar inclinado para baixo. A
    -- capa tambem precisa ficar mexendo um pouquinho". A ARTE foi corrigida
    -- pra casar com o dado: as botas agora PENDEM com o bico pra baixo (pe
    -- relaxado de quem nao pisa) nos tres clips (idle/hurt/death), e o idle
    -- ganhou 6 frames com ondulacao de pano assada por deslocamento a partir
    -- de UM frame base. Ou seja: ele nao e mais excecao ao criterio literal
    -- ("da pra ver o pe tocando a linha de base?" — agora nao da), e SEGUE
    -- valendo o registro do porque, pra ninguem "corrigir" de volta.
    --
    -- Numeros: hover BAIXO e bob LENTO (0.55 rad/s, o mais lento da tabela).
    -- Ele nao e um espectro esvoacante — e um morto-vivo coroado que paira
    -- porque despreza o chao. Pressa quebraria a leitura. O balanco RAPIDO
    -- dele mora na capa (ciclo ~1.4s no clip), nao no corpo: quem decide
    -- ondular o pano nao precisa acelerar o bob.
    --
    -- Out/2026, 3a leva: "o boss 2 e meio estatico flutuando, nao intimida".
    -- 0.55 rad/s era um ciclo de 11s com 1.4% da altura: na pratica PARADO.
    -- Agora ciclo de ~5.7s com o dobro da amplitude e deriva lateral lenta,
    -- capa assada em 12 quadros com atraso entre as abas (bake_boss_idle) e
    -- o circulo runico girando no chao (BossAura) — o vao entre ele e o
    -- circulo e o que diz "paira".
    tower_lich   = { pose = "floating",
                     hover = 0.075, bob = 0.028, bobSpeed = 1.10,
                     drift = 0.016,
                     shadowK = 0.62, shadowA = 0.50,
                     idle = { fps = 6, cycle = true } },

    -- Rainha do eclipse: capa imensa que se abre num leque, sem pé algum.
    -- Realeza não treme — deriva lenta e larga.
    eclipse_queen = { pose = "floating",
                      hover = 0.06, bob = 0.020, bobSpeed = 0.90,
                      drift = 0.010,
                      shadowK = 0.66, shadowA = 0.55,
                      idle = { fps = 5, cycle = true } },
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
        drift    = p.drift or 0,
        idle     = p.idle,
        axisX    = p.axisX,
    }
end

function EnemyPoses.isFloating(spriteId)
    local p = EnemyPoses.BY_ID[spriteId]
    return (p and p.pose == "floating") or false
end

return EnemyPoses
