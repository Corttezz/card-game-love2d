-- src/data/enemy_emissives.lua
-- EMISSIVOS POR MONSTRO (LightEngine) — dados puros, sem lógica.
--
-- Cada inimigo lista âncoras de luz sobre pixels que a ARTE pintou como
-- emissivos (olhos, chamas, cristais, runas, orbes). O EnemyRenderer emite
-- uma micro-luz sutil por âncora (pulso lento, some na morte).
--
-- Campos por âncora:
--   xr, yr      posição relativa ao sprite (fração da largura/altura, y do topo)
--   r           raio da luz em FRAÇÃO DA ALTURA do sprite (0.05 olho, ~0.10 orbe)
--   color       {r,g,b} — cor do pixel emissivo (média do cluster)
--   intensity   opcional (default 0.35) — SUTIL é a regra; 0.5 só pra núcleos
--
-- PIPELINE PADRÃO (novo monstro): rode
--   python3 tools/extract_enemy_emissives.py <enemy_id>
-- revise a folha anotada (tools/preview_out/enemy_emissives_sheet.png) —
-- o detector confunde DOURADO/PALHA com emissivo — e adicione a entrada
-- aqui à mão. Regra: só ganha luz o que BRILHA na arte; skull de osso com
-- órbita escura NÃO ganha olho de luz. Ver memory/lighting_engine.md.

return {
    -- Ato 1 ------------------------------------------------------------
    cursed_scarecrow = {
        { xr = 0.45, yr = 0.30, r = 0.055, color = { 1.00, 0.72, 0.20 } },  -- olho esq
        { xr = 0.57, yr = 0.29, r = 0.055, color = { 1.00, 0.72, 0.20 } },  -- olho dir
        { xr = 0.51, yr = 0.355, r = 0.050, color = { 0.96, 0.62, 0.13 },
          intensity = 0.25 },                                               -- sorriso
    },
    harvest_reaper = {
        -- REGRA (Jul/2026): todo monstro tem OLHOS emitindo na cor deles —
        -- órbitas escuras de caveira ganham brasa (posição medida no osso)
        { xr = 0.445, yr = 0.170, r = 0.042, color = { 1.00, 0.55, 0.15 },
          intensity = 0.40 },                                               -- olho esq
        { xr = 0.503, yr = 0.170, r = 0.042, color = { 1.00, 0.55, 0.15 },
          intensity = 0.40 },                                               -- olho dir
    },
    carrion_king = {
        { xr = 0.435, yr = 0.24, r = 0.045, color = { 1.00, 0.60, 0.15 },
          intensity = 0.45 },                                               -- olho esq
        { xr = 0.545, yr = 0.24, r = 0.045, color = { 1.00, 0.60, 0.15 },
          intensity = 0.45 },                                               -- olho dir
        { xr = 0.446, yr = 0.464, r = 0.090, color = { 0.93, 0.62, 0.18 },
          intensity = 0.45 },                                               -- coração da caixa torácica
        { xr = 0.461, yr = 0.568, r = 0.050, color = { 0.96, 0.72, 0.30 },
          intensity = 0.25 },                                               -- amuleto do cinto
    },
    grave_slime = {
        -- a caveira tem UMA órbita grande — luz única centrada nela
        -- (dois olhos criavam brilho nas bordas do crânio, lia estranho)
        { xr = 0.50, yr = 0.26, r = 0.060, color = { 0.60, 0.95, 0.40 },
          intensity = 0.40 },                                               -- órbita ciclope
        { xr = 0.50, yr = 0.60, r = 0.110, color = { 0.95, 0.25, 0.20 },
          intensity = 0.30 },                                               -- núcleo vermelho
    },
    stone_golem = {
        { xr = 0.494, yr = 0.204, r = 0.100, color = { 0.90, 0.62, 0.22 },
          intensity = 0.45 },                                               -- cabeça-fornalha
        { xr = 0.450, yr = 0.394, r = 0.060, color = { 0.88, 0.61, 0.22 },
          intensity = 0.30 },                                               -- fissura do peito
        { xr = 0.462, yr = 0.215, r = 0.040, color = { 1.00, 0.75, 0.25 },
          intensity = 0.40 },                                               -- olho esq
        { xr = 0.527, yr = 0.215, r = 0.040, color = { 1.00, 0.75, 0.25 },
          intensity = 0.40 },                                               -- olho dir
    },

    -- Ato 2 ------------------------------------------------------------
    moon_gargoyle = {
        { xr = 0.428, yr = 0.400, r = 0.045, color = { 0.75, 0.45, 1.00 },
          intensity = 0.50 },                                               -- olho esq (medido)
        { xr = 0.578, yr = 0.400, r = 0.045, color = { 0.75, 0.45, 1.00 },
          intensity = 0.50 },                                               -- olho dir (medido)
    },
    rune_golem = {
        { xr = 0.422, yr = 0.478, r = 0.110, color = { 0.76, 0.20, 0.94 },
          intensity = 0.45 },                                               -- runa central
        { xr = 0.161, yr = 0.452, r = 0.070, color = { 0.78, 0.27, 0.93 } },-- runa ombro esq
        { xr = 0.689, yr = 0.456, r = 0.070, color = { 0.81, 0.24, 0.97 } },-- runa ombro dir
        { xr = 0.336, yr = 0.265, r = 0.070, color = { 0.83, 0.24, 0.94 } },-- runa do elmo
        { xr = 0.490, yr = 0.255, r = 0.038, color = { 0.80, 0.30, 0.95 },
          intensity = 0.45 },                                               -- olho esq (visor)
        { xr = 0.535, yr = 0.255, r = 0.038, color = { 0.80, 0.30, 0.95 },
          intensity = 0.45 },                                               -- olho dir (visor)
    },
    tower_lich = {
        { xr = 0.190, yr = 0.240, r = 0.090, color = { 0.62, 0.81, 0.92 },
          intensity = 0.50 },                                               -- orbe do cajado
        { xr = 0.455, yr = 0.260, r = 0.040, color = { 0.38, 0.83, 0.95 },
          intensity = 0.45 },                                               -- olho esq
        { xr = 0.495, yr = 0.260, r = 0.040, color = { 0.38, 0.83, 0.95 },
          intensity = 0.45 },                                               -- olho dir
        { xr = 0.467, yr = 0.463, r = 0.045, color = { 0.44, 0.77, 0.91 },
          intensity = 0.25 },                                               -- broche do peito
    },

    -- Ato 3 ------------------------------------------------------------
    ember_imp = {
        { xr = 0.50, yr = 0.12, r = 0.130, color = { 0.95, 0.40, 0.05 },
          intensity = 0.50 },                                               -- juba de fogo
        { xr = 0.84, yr = 0.13, r = 0.065, color = { 0.95, 0.45, 0.06 } },  -- chama da cauda
        { xr = 0.36, yr = 0.54, r = 0.065, color = { 0.95, 0.45, 0.06 } },  -- bola de fogo
        { xr = 0.554, yr = 0.474, r = 0.075, color = { 0.92, 0.42, 0.05 },
          intensity = 0.30 },                                               -- fissuras do peito
        { xr = 0.390, yr = 0.424, r = 0.040, color = { 1.00, 0.25, 0.10 },
          intensity = 0.45 },                                               -- olho esq
        { xr = 0.530, yr = 0.420, r = 0.040, color = { 1.00, 0.25, 0.10 },
          intensity = 0.45 },                                               -- olho dir
    },
    obsidian_sentinel = {
        { xr = 0.175, yr = 0.347, r = 0.070, color = { 0.93, 0.40, 0.04 } },-- ombro esq
        { xr = 0.493, yr = 0.330, r = 0.070, color = { 0.95, 0.48, 0.04 } },-- peitoral alto
        { xr = 0.341, yr = 0.465, r = 0.090, color = { 0.95, 0.33, 0.02 },
          intensity = 0.45 },                                               -- magma do torso
        { xr = 0.340, yr = 0.710, r = 0.080, color = { 0.88, 0.45, 0.02 },
          intensity = 0.30 },                                               -- magma da saia
        { xr = 0.475, yr = 0.315, r = 0.038, color = { 1.00, 0.45, 0.12 },
          intensity = 0.45 },                                               -- olho esq (visor)
        { xr = 0.515, yr = 0.315, r = 0.038, color = { 1.00, 0.45, 0.12 },
          intensity = 0.45 },                                               -- olho dir (visor)
    },
    abyss_tyrant = {
        { xr = 0.451, yr = 0.258, r = 0.042, color = { 1.00, 0.75, 0.15 },
          intensity = 0.45 },                                               -- olho esq
        { xr = 0.534, yr = 0.259, r = 0.042, color = { 1.00, 0.75, 0.15 },
          intensity = 0.45 },                                               -- olho dir
        { xr = 0.496, yr = 0.621, r = 0.100, color = { 0.96, 0.51, 0.10 },
          intensity = 0.50 },                                               -- fornalha do peito
        { xr = 0.244, yr = 0.467, r = 0.065, color = { 0.95, 0.44, 0.03 } },-- fissura ombro esq
        { xr = 0.749, yr = 0.469, r = 0.065, color = { 0.94, 0.43, 0.04 } },-- fissura ombro dir
    },
    abyss_wraith = {
        -- dois olhos MEDIDOS (1px cada); raio pequeno — raio 0.04 tingia
        -- a caveira branca inteira de rosa ("lugar estranho")
        { xr = 0.461, yr = 0.250, r = 0.028, color = { 1.00, 0.20, 0.15 },
          intensity = 0.45 },                                               -- olho esq
        { xr = 0.526, yr = 0.250, r = 0.028, color = { 1.00, 0.20, 0.15 },
          intensity = 0.45 },                                               -- olho dir
    },

    -- Endless: Frost ----------------------------------------------------
    frost_wight = {
        { xr = 0.43, yr = 0.21, r = 0.042, color = { 0.62, 0.85, 1.00 },
          intensity = 0.45 },                                               -- olho esq (medido)
        { xr = 0.49, yr = 0.21, r = 0.042, color = { 0.62, 0.85, 1.00 },
          intensity = 0.45 },                                               -- olho dir
        { xr = 0.435, yr = 0.347, r = 0.070, color = { 0.62, 0.77, 0.90 },
          intensity = 0.25 },                                               -- cristal do peito
    },
    glacier_knight = {
        { xr = 0.49, yr = 0.18, r = 0.055, color = { 0.45, 0.85, 1.00 } },  -- fresta do visor
        { xr = 0.448, yr = 0.818, r = 0.060, color = { 0.62, 0.85, 1.00 },
          intensity = 0.22 },                                               -- lâmina de gelo (glint)
    },
    winter_monarch = {
        { xr = 0.156, yr = 0.178, r = 0.090, color = { 0.48, 0.76, 0.95 },
          intensity = 0.50 },                                               -- orbe do cajado
        { xr = 0.644, yr = 0.317, r = 0.055, color = { 0.63, 0.80, 0.92 },
          intensity = 0.25 },                                               -- cristal do ombro
        { xr = 0.425, yr = 0.238, r = 0.040, color = { 0.55, 0.85, 1.00 },
          intensity = 0.45 },                                               -- olho esq
        { xr = 0.468, yr = 0.238, r = 0.040, color = { 0.55, 0.85, 1.00 },
          intensity = 0.45 },                                               -- olho dir
    },

    -- Endless: Marsh ----------------------------------------------------
    bog_ghoul = {
        -- intensidade acima do padrão: verde-sobre-verde some no ambiente
        -- do marsh (revisão visual Jul/2026)
        { xr = 0.410, yr = 0.245, r = 0.045, color = { 0.50, 0.95, 0.55 },
          intensity = 0.55 },                                               -- olho esq (medido)
        { xr = 0.505, yr = 0.255, r = 0.045, color = { 0.50, 0.95, 0.55 },
          intensity = 0.55 },                                               -- olho dir (medido)
    },
    mire_hag = {
        { xr = 0.487, yr = 0.315, r = 0.040, color = { 0.55, 0.95, 0.45 },
          intensity = 0.45 },                                               -- olho esq (verde-bruxa)
        { xr = 0.541, yr = 0.315, r = 0.040, color = { 0.55, 0.95, 0.45 },
          intensity = 0.45 },                                               -- olho dir
        { xr = 0.655, yr = 0.444, r = 0.060, color = { 0.89, 0.79, 0.23 },
          intensity = 0.45 },                                               -- poção na mão
    },
    rot_colossus = {
        { xr = 0.42, yr = 0.28, r = 0.050, color = { 0.30, 0.90, 0.95 } },  -- olho esq
        { xr = 0.55, yr = 0.28, r = 0.050, color = { 0.30, 0.90, 0.95 } },  -- olho dir
        { xr = 0.30, yr = 0.19, r = 0.060, color = { 0.47, 0.90, 0.44 },
          intensity = 0.22 },                                               -- miasma ombro esq
        { xr = 0.651, yr = 0.173, r = 0.060, color = { 0.47, 0.90, 0.44 },
          intensity = 0.22 },                                               -- miasma ombro dir
    },

    -- Endless: Dusk -----------------------------------------------------
    dusk_shade = {
        { xr = 0.339, yr = 0.198, r = 0.038, color = { 0.92, 0.90, 1.00 },
          intensity = 0.50 },                                               -- olho esq (medido)
        { xr = 0.411, yr = 0.198, r = 0.038, color = { 0.92, 0.90, 1.00 },
          intensity = 0.50 },                                               -- olho dir
        { xr = 0.595, yr = 0.473, r = 0.075, color = { 0.72, 0.65, 0.91 } },-- mão espectral
        { xr = 0.372, yr = 0.128, r = 0.055, color = { 0.64, 0.64, 0.88 },
          intensity = 0.25 },                                               -- fiapo de fumaça
    },
    blood_duke = {
        { xr = 0.465, yr = 0.15, r = 0.040, color = { 1.00, 0.20, 0.15 } }, -- olho esq
        { xr = 0.535, yr = 0.15, r = 0.040, color = { 1.00, 0.20, 0.15 } }, -- olho dir
    },
    eclipse_queen = {
        { xr = 0.414, yr = 0.263, r = 0.036, color = { 0.95, 0.35, 0.65 },
          intensity = 0.45 },                                               -- olho esq
        { xr = 0.472, yr = 0.272, r = 0.036, color = { 0.95, 0.35, 0.65 },
          intensity = 0.45 },                                               -- olho dir
        { xr = 0.495, yr = 0.205, r = 0.045, color = { 0.74, 0.59, 0.91 } },-- gema da coroa
        { xr = 0.599, yr = 0.269, r = 0.050, color = { 0.88, 0.26, 0.60 } },-- gema do rosto
        { xr = 0.561, yr = 0.600, r = 0.045, color = { 0.64, 0.74, 0.91 },
          intensity = 0.35 },                                               -- mão esq
        { xr = 0.409, yr = 0.619, r = 0.045, color = { 0.59, 0.67, 0.88 },
          intensity = 0.35 },                                               -- mão dir
        { xr = 0.510, yr = 0.410, r = 0.045, color = { 0.64, 0.74, 0.91 },
          intensity = 0.30 },                                               -- gema do peito (medida)
    },

    -- LEVA NOVA (Out/2026) — 4 por ato (tools/pixellab_new_enemies.py).
    -- Olhos medidos por scan de pixel no south.png (= idle quadro 0).
    -- Ato 1 · campos ---------------------------------------------------
    hollow_farmer = {
        { xr = 0.484, yr = 0.279, r = 0.040, color = { 0.95, 0.50, 0.20 } },  -- olho esq
        { xr = 0.562, yr = 0.289, r = 0.040, color = { 0.95, 0.50, 0.20 } },  -- olho dir
    },
    plague_rats = {
        -- olhinhos vermelhos dos ratos — SUTIS, é a ninhada que lê, não a luz
        { xr = 0.748, yr = 0.287, r = 0.035, color = { 0.85, 0.18, 0.15 },
          intensity = 0.25 },                                               -- rato do topo
        { xr = 0.431, yr = 0.526, r = 0.035, color = { 0.85, 0.18, 0.15 },
          intensity = 0.25 },                                               -- rato do meio
        { xr = 0.507, yr = 0.554, r = 0.035, color = { 0.85, 0.18, 0.15 },
          intensity = 0.25 },                                               -- rato do meio dir
    },
    blight_bull = {
        { xr = 0.409, yr = 0.403, r = 0.045, color = { 0.95, 0.62, 0.25 },
          intensity = 0.40 },                                               -- olho esq
        { xr = 0.554, yr = 0.404, r = 0.045, color = { 0.95, 0.62, 0.25 },
          intensity = 0.40 },                                               -- olho dir
    },
    wicker_effigy = {
        { xr = 0.465, yr = 0.298, r = 0.035, color = { 0.98, 0.55, 0.15 },
          intensity = 0.40 },                                               -- olho esq do crânio
        { xr = 0.535, yr = 0.298, r = 0.035, color = { 0.98, 0.55, 0.15 },
          intensity = 0.40 },                                               -- olho dir do crânio
        { xr = 0.495, yr = 0.553, r = 0.100, color = { 0.96, 0.52, 0.14 },
          intensity = 0.50 },                                               -- fogo do peito
        { xr = 0.321, yr = 0.343, r = 0.080, color = { 0.96, 0.62, 0.19 },
          intensity = 0.30 },                                               -- chama ombro esq
        { xr = 0.669, yr = 0.336, r = 0.080, color = { 0.95, 0.56, 0.17 },
          intensity = 0.30 },                                               -- chama ombro dir
    },
    -- Ato 2 · planaltos ------------------------------------------------
    ram_cultist = {
        -- órbitas do crânio de carneiro: brasa violeta (cor do culto)
        { xr = 0.474, yr = 0.220, r = 0.040, color = { 0.70, 0.45, 0.90 } },  -- órbita esq
        { xr = 0.578, yr = 0.220, r = 0.040, color = { 0.70, 0.45, 0.90 } },  -- órbita dir
    },
    spectral_knight = {
        { xr = 0.415, yr = 0.199, r = 0.040, color = { 0.72, 0.43, 0.85 },
          intensity = 0.40 },                                               -- olho esq do elmo
        { xr = 0.469, yr = 0.202, r = 0.040, color = { 0.72, 0.43, 0.85 },
          intensity = 0.40 },                                               -- olho dir do elmo
        { xr = 0.292, yr = 0.549, r = 0.080, color = { 0.61, 0.33, 0.81 },
          intensity = 0.30 },                                               -- lâmina violeta
    },
    storm_griffin = {
        { xr = 0.492, yr = 0.356, r = 0.040, color = { 0.80, 0.95, 1.00 },
          intensity = 0.40 },                                               -- olho (perfil)
        { xr = 0.772, yr = 0.112, r = 0.050, color = { 0.51, 0.85, 0.87 },
          intensity = 0.30 },                                               -- faísca asa dir
        { xr = 0.773, yr = 0.450, r = 0.050, color = { 0.54, 0.93, 0.95 },
          intensity = 0.30 },                                               -- faísca asa dir baixo
        { xr = 0.223, yr = 0.661, r = 0.050, color = { 0.40, 0.78, 0.81 },
          intensity = 0.30 },                                               -- faísca asa esq
    },
    -- Ato 3 · abismo ---------------------------------------------------
    hellhound = {
        { xr = 0.161, yr = 0.330, r = 0.040, color = { 0.95, 0.50, 0.12 },
          intensity = 0.40 },                                               -- olho cabeça esq
        { xr = 0.484, yr = 0.309, r = 0.040, color = { 0.95, 0.50, 0.12 },
          intensity = 0.40 },                                               -- olho cabeça dir
        { xr = 0.346, yr = 0.296, r = 0.090, color = { 0.94, 0.42, 0.08 },
          intensity = 0.35 },                                               -- crina de fogo
        { xr = 0.380, yr = 0.560, r = 0.090, color = { 0.92, 0.43, 0.09 },
          intensity = 0.30 },                                               -- fissura do peito
    },
    abyss_acolyte = {
        { xr = 0.500, yr = 0.167, r = 0.040, color = { 0.95, 0.58, 0.26 },
          intensity = 0.40 },                                               -- olho esq (no breu do capuz)
        { xr = 0.552, yr = 0.167, r = 0.040, color = { 0.95, 0.58, 0.26 },
          intensity = 0.40 },                                               -- olho dir
        { xr = 0.243, yr = 0.250, r = 0.090, color = { 0.92, 0.39, 0.12 },
          intensity = 0.45 },                                               -- chama do grimório
    },
    pit_brute = {
        { xr = 0.469, yr = 0.218, r = 0.035, color = { 0.98, 0.60, 0.15 },
          intensity = 0.40 },                                               -- olho esq
        { xr = 0.549, yr = 0.218, r = 0.035, color = { 0.98, 0.60, 0.15 },
          intensity = 0.40 },                                               -- olho dir
        { xr = 0.507, yr = 0.382, r = 0.090, color = { 0.97, 0.70, 0.15 },
          intensity = 0.45 },                                               -- fornalha do peito
    },
    -- Ato 4 · gelo -----------------------------------------------------
    frost_wolf = {
        { xr = 0.266, yr = 0.317, r = 0.035, color = { 0.70, 0.90, 1.00 } },  -- olho esq
        { xr = 0.380, yr = 0.317, r = 0.035, color = { 0.70, 0.90, 1.00 } },  -- olho dir
    },
    rime_shaman = {
        { xr = 0.484, yr = 0.339, r = 0.035, color = { 0.80, 0.92, 1.00 } },  -- olho esq
        { xr = 0.568, yr = 0.339, r = 0.035, color = { 0.80, 0.92, 1.00 } },  -- olho dir
        { xr = 0.816, yr = 0.156, r = 0.090, color = { 0.55, 0.84, 0.94 },
          intensity = 0.45 },                                               -- cristal do totem
    },
    frost_troll = {
        -- órbitas fundas sob a sobrancelha: brilho gelado (regra dos olhos)
        { xr = 0.603, yr = 0.307, r = 0.035, color = { 0.70, 0.90, 1.00 } },  -- olho esq
        { xr = 0.683, yr = 0.307, r = 0.035, color = { 0.70, 0.90, 1.00 } },  -- olho dir
    },
    ice_wyrm = {
        { xr = 0.666, yr = 0.188, r = 0.040, color = { 0.41, 0.95, 0.94 },
          intensity = 0.45 },                                               -- olho ciano
        { xr = 0.817, yr = 0.306, r = 0.080, color = { 0.70, 0.88, 0.95 },
          intensity = 0.30 },                                               -- nuvem do sopro
    },
    storm_harpy = {
        { xr = 0.465, yr = 0.457, r = 0.035, color = { 0.80, 0.90, 1.00 } },  -- olho esq
        { xr = 0.525, yr = 0.457, r = 0.035, color = { 0.80, 0.90, 1.00 } },  -- olho dir
    },
    abyss_watcher = {
        { xr = 0.501, yr = 0.330, r = 0.070, color = { 0.95, 0.46, 0.11 },
          intensity = 0.50 },                                               -- olho central
        { xr = 0.415, yr = 0.405, r = 0.050, color = { 0.94, 0.43, 0.10 },
          intensity = 0.35 },                                               -- olho baixo esq
        { xr = 0.583, yr = 0.404, r = 0.050, color = { 0.94, 0.40, 0.10 },
          intensity = 0.35 },                                               -- olho baixo dir
        { xr = 0.383, yr = 0.232, r = 0.035, color = { 0.90, 0.46, 0.15 },
          intensity = 0.25 },                                               -- olho alto esq
        { xr = 0.601, yr = 0.241, r = 0.035, color = { 0.93, 0.44, 0.07 },
          intensity = 0.25 },                                               -- olho alto dir
    },
    -- Ato 5 · pântano --------------------------------------------------
    plague_toad = {
        { xr = 0.340, yr = 0.130, r = 0.035, color = { 0.80, 0.90, 0.25 } },  -- olho esq
        { xr = 0.515, yr = 0.115, r = 0.035, color = { 0.80, 0.90, 0.25 } },  -- olho dir
        { xr = 0.712, yr = 0.181, r = 0.080, color = { 0.71, 0.83, 0.13 },
          intensity = 0.45 },                                               -- pústula do ombro
        { xr = 0.670, yr = 0.448, r = 0.070, color = { 0.75, 0.87, 0.12 },
          intensity = 0.40 },                                               -- pústula do flanco
        { xr = 0.509, yr = 0.268, r = 0.050, color = { 0.76, 0.87, 0.13 },
          intensity = 0.30 },                                               -- baba tóxica
    },
    leech_horror = {
        -- sem olhos na arte: brasa vermelha FUNDA na goela da ventosa
        -- central faz o papel de "olho" (regra dos olhos, adaptada)
        { xr = 0.479, yr = 0.224, r = 0.050, color = { 0.85, 0.20, 0.15 },
          intensity = 0.30 },                                               -- goela central
    },
    croc_warrior = {
        { xr = 0.402, yr = 0.134, r = 0.035, color = { 0.95, 0.80, 0.30 } },  -- olho esq (réptil)
        { xr = 0.469, yr = 0.156, r = 0.035, color = { 0.95, 0.80, 0.30 } },  -- olho dir
    },
    spore_mother = {
        { xr = 0.504, yr = 0.364, r = 0.035, color = { 0.55, 0.95, 0.62 },
          intensity = 0.40 },                                               -- olho esq (sob o chapéu)
        { xr = 0.582, yr = 0.368, r = 0.035, color = { 0.55, 0.95, 0.62 },
          intensity = 0.40 },                                               -- olho dir
        { xr = 0.289, yr = 0.386, r = 0.070, color = { 0.51, 0.89, 0.58 },
          intensity = 0.30 },                                               -- esporos das lamelas esq
        { xr = 0.746, yr = 0.409, r = 0.070, color = { 0.53, 0.92, 0.60 },
          intensity = 0.30 },                                               -- esporos das lamelas dir
    },
    -- Ato 6 · crepúsculo -----------------------------------------------
    dusk_bat = {
        { xr = 0.475, yr = 0.620, r = 0.035, color = { 0.95, 0.20, 0.20 },
          intensity = 0.40 },                                               -- olho esq
        { xr = 0.554, yr = 0.620, r = 0.035, color = { 0.95, 0.20, 0.20 },
          intensity = 0.40 },                                               -- olho dir
    },
    grave_thrall = {
        { xr = 0.444, yr = 0.146, r = 0.035, color = { 0.62, 0.45, 0.85 } },  -- órbita esq
        { xr = 0.510, yr = 0.141, r = 0.035, color = { 0.62, 0.45, 0.85 } },  -- órbita dir
    },
    dullahan = {
        { xr = 0.526, yr = 0.164, r = 0.110, color = { 0.44, 0.14, 0.82 },
          intensity = 0.45 },                                               -- chama do pescoço
        { xr = 0.704, yr = 0.373, r = 0.070, color = { 0.53, 0.29, 0.82 },
          intensity = 0.35 },                                               -- chama da cabeça na mão
        { xr = 0.656, yr = 0.430, r = 0.035, color = { 0.80, 0.27, 0.38 },
          intensity = 0.40 },                                               -- olho do elmo na mão
    },
    fallen_angel = {
        { xr = 0.481, yr = 0.242, r = 0.035, color = { 0.92, 0.92, 1.00 },
          intensity = 0.40 },                                               -- olho esq
        { xr = 0.519, yr = 0.242, r = 0.035, color = { 0.92, 0.92, 1.00 },
          intensity = 0.40 },                                               -- olho dir
    },
}
