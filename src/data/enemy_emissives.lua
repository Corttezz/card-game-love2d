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
        -- sem glow pintado na arte (skull de osso, palha não é emissivo).
        -- candidato a ganhar olhos de brasa numa re-arte futura.
    },
    carrion_king = {
        { xr = 0.435, yr = 0.24, r = 0.045, color = { 1.00, 0.60, 0.15 } }, -- olho esq
        { xr = 0.545, yr = 0.24, r = 0.045, color = { 1.00, 0.60, 0.15 } }, -- olho dir
        { xr = 0.446, yr = 0.464, r = 0.090, color = { 0.93, 0.62, 0.18 },
          intensity = 0.45 },                                               -- coração da caixa torácica
        { xr = 0.461, yr = 0.568, r = 0.050, color = { 0.96, 0.72, 0.30 },
          intensity = 0.25 },                                               -- amuleto do cinto
    },
    grave_slime = {
        { xr = 0.50, yr = 0.60, r = 0.110, color = { 0.95, 0.25, 0.20 },
          intensity = 0.30 },                                               -- núcleo vermelho
    },
    stone_golem = {
        { xr = 0.494, yr = 0.204, r = 0.100, color = { 0.90, 0.62, 0.22 },
          intensity = 0.45 },                                               -- cabeça-fornalha
        { xr = 0.450, yr = 0.394, r = 0.060, color = { 0.88, 0.61, 0.22 },
          intensity = 0.30 },                                               -- fissura do peito
    },

    -- Ato 2 ------------------------------------------------------------
    moon_gargoyle = {
        { xr = 0.42, yr = 0.45, r = 0.050, color = { 0.75, 0.45, 1.00 } },  -- olho esq
        { xr = 0.53, yr = 0.45, r = 0.050, color = { 0.75, 0.45, 1.00 } },  -- olho dir
    },
    rune_golem = {
        { xr = 0.422, yr = 0.478, r = 0.110, color = { 0.76, 0.20, 0.94 },
          intensity = 0.45 },                                               -- runa central
        { xr = 0.161, yr = 0.452, r = 0.070, color = { 0.78, 0.27, 0.93 } },-- runa ombro esq
        { xr = 0.689, yr = 0.456, r = 0.070, color = { 0.81, 0.24, 0.97 } },-- runa ombro dir
        { xr = 0.336, yr = 0.265, r = 0.070, color = { 0.83, 0.24, 0.94 } },-- runa do elmo
    },
    tower_lich = {
        { xr = 0.190, yr = 0.240, r = 0.090, color = { 0.62, 0.81, 0.92 },
          intensity = 0.50 },                                               -- orbe do cajado
        { xr = 0.476, yr = 0.261, r = 0.050, color = { 0.38, 0.83, 0.95 } },-- olhos
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
    },
    obsidian_sentinel = {
        { xr = 0.175, yr = 0.347, r = 0.070, color = { 0.93, 0.40, 0.04 } },-- ombro esq
        { xr = 0.493, yr = 0.330, r = 0.070, color = { 0.95, 0.48, 0.04 } },-- peitoral alto
        { xr = 0.341, yr = 0.465, r = 0.090, color = { 0.95, 0.33, 0.02 },
          intensity = 0.45 },                                               -- magma do torso
        { xr = 0.340, yr = 0.710, r = 0.080, color = { 0.88, 0.45, 0.02 },
          intensity = 0.30 },                                               -- magma da saia
    },
    abyss_tyrant = {
        { xr = 0.496, yr = 0.621, r = 0.100, color = { 0.96, 0.51, 0.10 },
          intensity = 0.50 },                                               -- fornalha do peito
        { xr = 0.244, yr = 0.467, r = 0.065, color = { 0.95, 0.44, 0.03 } },-- fissura ombro esq
        { xr = 0.749, yr = 0.469, r = 0.065, color = { 0.94, 0.43, 0.04 } },-- fissura ombro dir
    },
    abyss_wraith = {
        { xr = 0.52, yr = 0.235, r = 0.040, color = { 1.00, 0.20, 0.15 } }, -- olho vermelho único
    },

    -- Endless: Frost ----------------------------------------------------
    frost_wight = {
        { xr = 0.47, yr = 0.17, r = 0.060, color = { 0.62, 0.80, 0.93 },
          intensity = 0.25 },                                               -- rosto espectral
        { xr = 0.435, yr = 0.347, r = 0.070, color = { 0.62, 0.77, 0.90 },
          intensity = 0.25 },                                               -- cristal do peito
    },
    glacier_knight = {
        { xr = 0.49, yr = 0.18, r = 0.055, color = { 0.45, 0.85, 1.00 } },  -- fresta do visor
    },
    winter_monarch = {
        { xr = 0.156, yr = 0.178, r = 0.090, color = { 0.48, 0.76, 0.95 },
          intensity = 0.50 },                                               -- orbe do cajado
        { xr = 0.644, yr = 0.317, r = 0.055, color = { 0.63, 0.80, 0.92 },
          intensity = 0.25 },                                               -- cristal do ombro
    },

    -- Endless: Marsh ----------------------------------------------------
    bog_ghoul = {
        -- intensidade acima do padrão: verde-sobre-verde some no ambiente
        -- do marsh (revisão visual Jul/2026)
        { xr = 0.42, yr = 0.245, r = 0.045, color = { 0.50, 0.95, 0.55 },
          intensity = 0.50 },                                               -- olho esq
        { xr = 0.52, yr = 0.245, r = 0.045, color = { 0.50, 0.95, 0.55 },
          intensity = 0.50 },                                               -- olho dir
    },
    mire_hag = {
        { xr = 0.485, yr = 0.32, r = 0.040, color = { 0.85, 0.50, 0.90 },
          intensity = 0.30 },                                               -- olho esq
        { xr = 0.545, yr = 0.32, r = 0.040, color = { 0.85, 0.50, 0.90 },
          intensity = 0.30 },                                               -- olho dir
        { xr = 0.655, yr = 0.444, r = 0.060, color = { 0.89, 0.79, 0.23 } },-- poção na mão
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
        { xr = 0.59, yr = 0.21, r = 0.065, color = { 0.70, 0.64, 0.90 } },  -- rosto/capuz
        { xr = 0.595, yr = 0.473, r = 0.075, color = { 0.72, 0.65, 0.91 } },-- mão espectral
        { xr = 0.372, yr = 0.128, r = 0.055, color = { 0.64, 0.64, 0.88 },
          intensity = 0.25 },                                               -- fiapo de fumaça
    },
    blood_duke = {
        { xr = 0.465, yr = 0.15, r = 0.040, color = { 1.00, 0.20, 0.15 } }, -- olho esq
        { xr = 0.535, yr = 0.15, r = 0.040, color = { 1.00, 0.20, 0.15 } }, -- olho dir
    },
    eclipse_queen = {
        { xr = 0.495, yr = 0.205, r = 0.045, color = { 0.74, 0.59, 0.91 } },-- gema da coroa
        { xr = 0.599, yr = 0.269, r = 0.050, color = { 0.88, 0.26, 0.60 } },-- gema do rosto
        { xr = 0.561, yr = 0.600, r = 0.045, color = { 0.64, 0.74, 0.91 },
          intensity = 0.28 },                                               -- mão esq
        { xr = 0.409, yr = 0.619, r = 0.045, color = { 0.59, 0.67, 0.88 },
          intensity = 0.28 },                                               -- mão dir
    },
}
