-- src/data/boss_auras.lua
-- ============================================================================
-- AURA ASSINATURA DE CADA CHEFE — dados puros, desenhados por src/ui/BossAura.
-- ============================================================================
-- Queixa do dono (Out/2026): "o boss 2 é meio estático flutuando, não
-- intimida"; "o boss 1 não tem nada de especial". Um chefe precisa de algo
-- que só ELE tem em volta dele. Cada entrada abaixo é o tema do chefe dito
-- em camadas baratas de pixel art (retângulos inteiros na grade do PIXEL DA
-- ARTE do sprite — nunca círculo liso, nunca partícula subpixel).
--
-- Unidades (todas no espaço do CANVAS DO IDLE do chefe — olhe o PNG com
-- régua antes de mexer, doutrina do projeto):
--   u, v      fração da largura/altura do canvas (0,0 = topo-esquerda)
--   r, ru, rv raio em PIXELS DA ARTE (glow) ou fração (órbita: ru de w, rv de h)
--   vx, vy    velocidade em pixels da arte por segundo
--   area      { u0, v0, u1, v1 } de onde o emissor nasce
--
-- Camadas:
--   glows   brilho posterizado aditivo nos pixels que já são luz na arte
--           (mesmas âncoras de enemy_emissives — no salão o LightEngine não
--           tem lightmap e o olho/orbe pintado ficava apagado)
--   orbit   (ou `orbits`, lista) n corpos girando numa elipse; metade de trás desenha ATRÁS do
--           sprite e a da frente NA FRENTE (regra de profundidade)
--   emit    emissores (pena, alma, fagulha, fumaça, esporo, gota, pétala,
--           sopro); `back = true` desenha atrás do sprite; `big` = chance
--           de nascer com 2 pixels da arte (variação de tamanho)
--   px      tamanho do BLOCO (pixels da arte por pixel do efeito). Chefe a
--           ~2x na tela tem pixel da arte de ~2px: efeito de 1 bloco virava
--           cisco invisível (medido nas salas a 1024x768). 2 = legível e
--           ainda múltiplo inteiro da grade do sprite.
--   floor   círculo rúnico no chão (só o lich: diz "ele paira SOBRE algo")
--   corona  disco do eclipse atrás da cabeça (só a rainha)
--   rim     contorno da silhueta na cor do tema (1 pixel da arte, atrás do
--           corpo) — o tirano usa contorno ESCURO: a sala dele é lava
--           clara e ele precisa recortar, não brilhar
--   glint   brilho que percorre a borda externa da silhueta (asas da rainha)
--
-- `reducedMotion`: órbitas congelam, emissores param, coroa/círculo param de
-- girar — MOVIMENTO sai. Brilho, círculo e coroa ficam: são a identidade do
-- chefe (informação), não enfeite.
-- ============================================================================

return {
    -- Ato 1 — Rei-carniça. Corvos rondando, penas caindo, coração de brasa
    -- batendo em DUAS pancadas (tum-tum) no peito de costelas.
    carrion_king = {
        rim = { color = { 1.00, 0.46, 0.12 }, a = 0.45, pulse = 1.6 },
        glows = {
            { u = 0.446, v = 0.464, r = 10, color = { 1.00, 0.52, 0.12 },
              a = 0.55, beat = 1.25 },                       -- coração
            { u = 0.435, v = 0.240, r = 4, color = { 1.00, 0.60, 0.15 }, a = 0.45 },
            { u = 0.545, v = 0.240, r = 4, color = { 1.00, 0.60, 0.15 }, a = 0.45 },
            { u = 0.461, v = 0.568, r = 5, color = { 0.96, 0.72, 0.30 }, a = 0.30,
              pulse = 1.7 },                                 -- amuleto do cinto
        },
        orbit = { kind = "crow", n = 4, px = 3, cu = 0.50, cv = 0.16, ru = 0.56,
                  rv = 0.10, speed = 0.55, color = { 0.13, 0.10, 0.20 },
                  color2 = { 0.58, 0.50, 0.90 } },
        emit = {
            { kind = "feather", px = 2, rate = 2.2, area = { 0.08, 0.28, 0.92, 0.62 },
              vx = { -3, 3 }, vy = { 5, 9 }, sway = 5, life = { 2.6, 3.6 },
              color = { 0.20, 0.16, 0.32 }, color2 = { 0.58, 0.50, 0.90 } },
            { kind = "ember", px = 2, rate = 2.4, big = 0.3, area = { 0.40, 0.42, 0.50, 0.50 },
              vx = { -4, 4 }, vy = { -14, -8 }, life = { 0.8, 1.4 },
              color = { 1.00, 0.70, 0.20 }, color2 = { 0.85, 0.25, 0.05 } },
        },
    },

    -- Ato 2 — Lich da Torre. Paira SOBRE um círculo rúnico que gira no chão,
    -- o orbe do cajado pulsa com faíscas arcanas em órbita e almas sobem da
    -- barra do manto.
    tower_lich = {
        rim = { color = { 0.45, 0.85, 1.00 }, a = 0.50, pulse = 1.1 },
        floor = { ru = 0.36, rv = 0.060, speed = 0.35, a = 0.60,
                  color = { 0.45, 0.80, 1.00 }, color2 = { 0.66, 0.52, 1.00 } },
        glows = {
            { u = 0.190, v = 0.240, r = 13, color = { 0.55, 0.82, 1.00 },
              a = 0.55, pulse = 1.6 },                       -- orbe do cajado
            { u = 0.455, v = 0.260, r = 3, color = { 0.38, 0.83, 0.95 }, a = 0.55 },
            { u = 0.495, v = 0.260, r = 3, color = { 0.38, 0.83, 0.95 }, a = 0.55 },
            { u = 0.467, v = 0.463, r = 4, color = { 0.44, 0.77, 0.91 }, a = 0.30,
              pulse = 2.1 },
        },
        orbits = {
            { kind = "mote", n = 6, px = 2, cu = 0.190, cv = 0.240, ru = 0.10,
              rv = 0.045, speed = 2.3, color = { 0.80, 0.96, 1.00 },
              color2 = { 0.55, 0.70, 1.00 } },
            -- runas de gelo girando na cintura: o "feitiço" em volta dele
            { kind = "rune", n = 5, px = 2, cu = 0.50, cv = 0.62, ru = 0.56,
              rv = 0.07, speed = 0.7, color = { 0.62, 0.90, 1.00 },
              color2 = { 0.50, 0.42, 0.95 } },
        },
        emit = {
            { kind = "wisp", px = 2, rate = 4.5, big = 0.35, area = { 0.30, 0.74, 0.80, 0.86 },
              vx = { -2, 2 }, vy = { -16, -10 }, sway = 4, life = { 1.6, 2.4 },
              color = { 0.70, 0.92, 1.00 }, color2 = { 0.42, 0.50, 0.95 } },
        },
    },

    -- Ato 3 — Tirano do abismo (o dono gostou: só realça). Fagulhas do
    -- inferno saindo da fornalha do peito e fumaça rasteira nas garras.
    abyss_tyrant = {
        rim = { color = { 0.10, 0.02, 0.02 }, a = 0.85 },
        glows = {
            { u = 0.496, v = 0.621, r = 12, color = { 1.00, 0.50, 0.10 },
              a = 0.55, pulse = 2.4 },                       -- fornalha
            { u = 0.451, v = 0.258, r = 3, color = { 1.00, 0.75, 0.15 }, a = 0.5 },
            { u = 0.534, v = 0.259, r = 3, color = { 1.00, 0.75, 0.15 }, a = 0.5 },
            { u = 0.244, v = 0.467, r = 6, color = { 0.95, 0.44, 0.03 }, a = 0.35,
              pulse = 3.1 },
            { u = 0.749, v = 0.469, r = 6, color = { 0.94, 0.43, 0.04 }, a = 0.35,
              pulse = 2.7 },
        },
        emit = {
            { kind = "spark", px = 2, rate = 13, big = 0.3, area = { 0.30, 0.42, 0.70, 0.68 },
              vx = { -8, 8 }, vy = { -30, -16 }, life = { 0.6, 1.2 },
              color = { 1.00, 0.86, 0.32 }, color2 = { 0.86, 0.22, 0.05 } },
            -- CINZA escura subindo: a sala 3 é lava laranja — fagulha
            -- laranja some no fundo, cinza preta recorta
            { kind = "feather", px = 1, rate = 4, area = { 0.15, 0.20, 0.85, 0.70 },
              vx = { -4, 4 }, vy = { -12, -6 }, sway = 4, life = { 1.8, 2.8 },
              color = { 0.10, 0.06, 0.06 }, color2 = { 0.30, 0.12, 0.08 } },
            { kind = "smoke", px = 2, back = true, rate = 1.6,
              area = { 0.18, 0.90, 0.82, 0.97 }, vx = { -3, 3 }, vy = { -4, -2 },
              life = { 2.0, 3.0 }, a = 0.45,
              color = { 0.14, 0.08, 0.08 }, color2 = { 0.30, 0.10, 0.06 } },
        },
    },

    -- Ato 4 — Monarca do inverno. Redemoinho de neve girando em volta,
    -- sopro gelado de tempos em tempos e névoa rasteira nos pés.
    winter_monarch = {
        rim = { color = { 0.70, 0.92, 1.00 }, a = 0.45, pulse = 0.9 },
        glows = {
            { u = 0.156, v = 0.178, r = 12, color = { 0.50, 0.80, 1.00 },
              a = 0.55, pulse = 1.4 },                       -- orbe do cajado
            { u = 0.425, v = 0.238, r = 3, color = { 0.55, 0.85, 1.00 }, a = 0.55 },
            { u = 0.468, v = 0.238, r = 3, color = { 0.55, 0.85, 1.00 }, a = 0.55 },
        },
        orbit = { kind = "flake", n = 30, px = 2, cu = 0.47, cv = 0.55, ru = 0.62,
                  rv = 0.10, speed = 0.9, rise = 0.05,
                  color = { 0.94, 0.98, 1.00 }, color2 = { 0.62, 0.80, 1.00 } },
        emit = {
            { kind = "breath", px = 2, every = 3.6, burst = 8, area = { 0.44, 0.27, 0.45, 0.28 },
              vx = { -16, -6 }, vy = { 2, 6 }, life = { 0.9, 1.4 }, a = 0.5,
              color = { 0.88, 0.95, 1.00 }, color2 = { 0.62, 0.78, 1.00 } },
            { kind = "smoke", px = 2, back = true, rate = 1.4,
              area = { 0.12, 0.92, 0.88, 0.99 }, vx = { -4, 4 }, vy = { -2, -1 },
              life = { 2.2, 3.2 }, a = 0.30,
              color = { 0.70, 0.86, 1.00 }, color2 = { 0.45, 0.62, 0.90 } },
            { kind = "sparkle", px = 2, every = 2.3, burst = 1,
              area = { 0.10, 0.10, 0.22, 0.26 }, life = { 0.5, 0.5 },
              color = { 1.00, 1.00, 1.00 }, color2 = { 0.60, 0.85, 1.00 } },
        },
    },

    -- Ato 5 — Colosso podre. Esporos subindo dos ombros, moscas zumbindo em
    -- volta da cabeça e gosma pingando das mãos até o chão.
    rot_colossus = {
        rim = { color = { 0.45, 0.95, 0.35 }, a = 0.40, pulse = 1.3 },
        glows = {
            { u = 0.300, v = 0.190, r = 7, color = { 0.47, 0.90, 0.44 }, a = 0.35,
              pulse = 1.3 },
            { u = 0.651, v = 0.173, r = 7, color = { 0.47, 0.90, 0.44 }, a = 0.35,
              pulse = 1.1 },
            { u = 0.420, v = 0.280, r = 3, color = { 0.30, 0.90, 0.95 }, a = 0.5 },
            { u = 0.550, v = 0.280, r = 3, color = { 0.30, 0.90, 0.95 }, a = 0.5 },
        },
        orbit = { kind = "fly", n = 7, px = 2, cu = 0.48, cv = 0.26, ru = 0.46,
                  rv = 0.20, speed = 4.5, color = { 0.04, 0.05, 0.03 },
                  color2 = { 0.30, 0.40, 0.25 } },
        emit = {
            { kind = "spore", px = 2, rate = 5.5, big = 0.35, area = { 0.22, 0.10, 0.75, 0.26 },
              vx = { -3, 3 }, vy = { -10, -5 }, sway = 5, life = { 2.2, 3.2 },
              color = { 0.58, 0.96, 0.46 }, color2 = { 0.30, 0.60, 0.22 } },
            { kind = "drip", px = 2, rate = 1.6, big = 0.5,
              points = { { 0.17, 0.78 }, { 0.80, 0.78 }, { 0.36, 0.62 } },
              gravity = 70, life = { 3.0, 3.0 },
              color = { 0.44, 0.66, 0.22 }, color2 = { 0.24, 0.40, 0.12 } },
        },
    },

    -- Ato 6 — Rainha do eclipse (o dono gostou: realça sem trocar). Disco do
    -- eclipse com coroa de luz atrás da cabeça, pétalas de sombra no ar e um
    -- brilho que corre pela borda das asas.
    eclipse_queen = {
        rim = { color = { 0.95, 0.30, 0.70 }, a = 0.50, pulse = 0.8 },
        corona = { u = 0.50, v = 0.24, r = 23, speed = 0.18,
                   color = { 0.96, 0.38, 0.72 }, color2 = { 0.55, 0.22, 0.85 },
                   dark = { 0.02, 0.01, 0.04 } },
        glows = {
            { u = 0.414, v = 0.263, r = 3, color = { 0.95, 0.35, 0.65 }, a = 0.55 },
            { u = 0.472, v = 0.272, r = 3, color = { 0.95, 0.35, 0.65 }, a = 0.55 },
            { u = 0.495, v = 0.205, r = 4, color = { 0.74, 0.59, 0.91 }, a = 0.45,
              pulse = 1.2 },
        },
        glint = { period = 3.2, v0 = 0.04, v1 = 0.72, color = { 1.00, 0.62, 0.92 } },
        emit = {
            { kind = "petal", px = 2, rate = 3.0, big = 0.4, area = { -0.05, 0.00, 1.05, 0.45 },
              vx = { 4, 9 }, vy = { 6, 11 }, sway = 6, life = { 3.2, 4.4 },
              color = { 0.30, 0.06, 0.30 }, color2 = { 0.62, 0.18, 0.52 } },
            { kind = "petal", px = 2, back = true, rate = 2.0, big = 0.3, area = { -0.05, 0.00, 1.05, 0.40 },
              vx = { 3, 7 }, vy = { 5, 9 }, sway = 6, life = { 3.2, 4.4 },
              color = { 0.20, 0.04, 0.22 }, color2 = { 0.42, 0.12, 0.38 } },
        },
    },
}
