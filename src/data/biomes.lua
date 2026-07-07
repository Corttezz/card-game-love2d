-- src/data/biomes.lua
-- DADOS dos biomas do mundo rolante (WorldRoad). Tabela pura, sem lógica.
--
-- Técnica estudada do Path of Kings (referência): cada bioma tem cor-assinatura,
-- paleta de terreno, props variados e um marco no fim (castelo). Biomas 1-3
-- mapeiam pros ATOS da run; 4-6 ciclam no endless.
--
-- Arte: WorldRoad procura PNG override em assets/sprites/world/<id>_<prop>_<i>.png
-- (futuro PixelLab). Sem PNG, gera sprite procedural com a paleta abaixo.
--
-- `grassPattern`/`roadPattern`: nomes de assets/sprites/backgrounds/patterns/
-- (os MESMOS 64×64 tileáveis das cartas) — usados como textura modo-7 do chão.
-- `propWeights`: kinds disponíveis: tree, pine, deadtree, bush, rock, stump,
-- fence, sign, flowers, ruin.

local biomes = {
    -- Ato 1 — Campos Arruinados: sépia esverdeado, fazendas mortas
    {
        id = "fields",
        celestial = { kind = "sun",  xr = 0.79, yr = 0.14, r = 19, color = { 0.99, 0.86, 0.55 } },
        ambient = { style = "leaf",  rate = 0.25, color = { 0.55, 0.50, 0.20 } },
        name = "Campos Arruinados",
        skyTop = { 0.13, 0.12, 0.16 },
        skyHorizon = { 0.55, 0.42, 0.28 },
        cloud = { 0.72, 0.62, 0.48, 0.55 },
        hillsFar = { 0.24, 0.20, 0.22 },
        hillsNear = { 0.19, 0.17, 0.16 },
        grassA = { 0.12, 0.24, 0.12 },   -- #1E3E1F (verde floresta escuro)
        grassB = { 0.095, 0.195, 0.10 },
        roadA = { 0.48, 0.34, 0.20 },
        roadB = { 0.42, 0.29, 0.17 },
        roadEdge = { 0.20, 0.14, 0.09 },
        fog = { 0.55, 0.42, 0.28, 0.55 },
        -- LightEngine: dia dourado — quase neutro, luzes discretas
        lightAmbient = { 0.96, 0.92, 0.87 },
        lightDay   = { 0.99, 0.97, 0.94 },   -- manhã dourada (andar 1)
        lightNight = { 0.55, 0.46, 0.62 },   -- crepúsculo da REFERÊNCIA (boss)
        lightWindows = { { 0.50, 0.48 }, { 0.27, 0.43 }, { 0.73, 0.66 } },
        grassPattern = "soft",
        roadPattern = "stone",
        grassTint = { 0.72, 0.70, 0.42 },
        roadTint = { 1.00, 0.78, 0.52 },
        accent = { 0.78, 0.58, 0.25 },        -- flores douradas
        canopy = { 0.28, 0.34, 0.16 }, canopyDark = { 0.18, 0.23, 0.10 },
        trunk = { 0.30, 0.20, 0.12 },
        bush = { 0.25, 0.30, 0.14 }, bushDark = { 0.16, 0.21, 0.09 },
        rock = { 0.38, 0.35, 0.30 }, rockDark = { 0.24, 0.22, 0.19 },
        landmark = { 0.35, 0.32, 0.28 }, landmarkDark = { 0.22, 0.20, 0.17 },
        propDensity = 1.15,
        -- v9 LuminaireEngine: 3 luminárias por bioma, rate ↑ ("hoje custa
        -- aparecer uma") — kinds/luz definidos em engine/LuminaireEngine.lua
        propWeights = { tree = 3, bush = 3, flowers = 2, fence = 0.45,
                        sign = 0.5, rock = 1, stump = 0.8,
                        lantern = 1.1, firepit = 0.8, shrine = 0.5 },
    },

    -- Ato 2 — Colinas da Torre: azul-violeta frio, pinheiros e monólitos
    {
        id = "highlands",
        celestial = { kind = "moon", xr = 0.74, yr = 0.24, r = 15, color = { 0.88, 0.88, 0.97 } },
        ambient = { style = "mote",  rate = 0.18, color = { 0.62, 0.62, 0.82 } },
        name = "Colinas da Torre",
        skyTop = { 0.09, 0.09, 0.16 },
        skyHorizon = { 0.38, 0.34, 0.48 },
        cloud = { 0.58, 0.55, 0.68, 0.5 },
        hillsFar = { 0.18, 0.17, 0.26 },
        hillsNear = { 0.14, 0.13, 0.20 },
        grassA = { 0.20, 0.33, 0.35 },   -- #335559 (ardósia verde-azulado)
        grassB = { 0.16, 0.27, 0.29 },
        roadA = { 0.38, 0.33, 0.30 },
        roadB = { 0.32, 0.28, 0.26 },
        roadEdge = { 0.14, 0.12, 0.12 },
        fog = { 0.38, 0.34, 0.48, 0.6 },
        -- LightEngine: noite azulada de lua — braseiros aquecem a estrada
        lightAmbient = { 0.67, 0.69, 0.86 },
        lightDay   = { 0.84, 0.84, 0.95 },   -- entardecer azulado
        lightNight = { 0.67, 0.69, 0.86 },   -- noite de lua
        lightWindows = { { 0.75, 0.34 }, { 0.25, 0.33 }, { 0.48, 0.59 },
                         { 0.52, 0.88 } },
        grassPattern = "ghost",
        roadPattern = "stone",
        grassTint = { 0.48, 0.55, 0.50 },
        roadTint = { 0.80, 0.72, 0.66 },
        accent = { 0.45, 0.55, 0.78 },        -- flores arcanas azuis
        canopy = { 0.16, 0.24, 0.20 }, canopyDark = { 0.10, 0.16, 0.14 },
        trunk = { 0.22, 0.16, 0.12 },
        bush = { 0.15, 0.21, 0.18 }, bushDark = { 0.09, 0.14, 0.12 },
        rock = { 0.36, 0.34, 0.42 }, rockDark = { 0.22, 0.21, 0.28 },
        landmark = { 0.32, 0.30, 0.38 }, landmarkDark = { 0.19, 0.18, 0.25 },
        propDensity = 1.0,
        propWeights = { pine = 3, rock = 2.5, ruin = 1, bush = 1,
                        sign = 0.4, deadtree = 0.6, flowers = 0.8,
                        brazier = 0.9, runestone = 0.7, lantern = 0.6 },
    },

    -- Ato 3 — Estrada do Abismo: vermelho-âmbar infernal, terra morta
    {
        id = "abyss",
        celestial = { kind = "sun",  xr = 0.68, yr = 0.34, r = 26, color = { 0.82, 0.32, 0.16 } },
        ambient = { style = "ember", rate = 0.35, color = { 0.95, 0.45, 0.15 } },
        name = "Estrada do Abismo",
        skyTop = { 0.10, 0.05, 0.08 },
        skyHorizon = { 0.55, 0.20, 0.10 },
        cloud = { 0.45, 0.22, 0.15, 0.5 },
        hillsFar = { 0.22, 0.10, 0.10 },
        hillsNear = { 0.16, 0.08, 0.08 },
        grassA = { 0.22, 0.12, 0.10 },
        grassB = { 0.18, 0.09, 0.08 },
        roadA = { 0.30, 0.22, 0.18 },
        roadB = { 0.25, 0.18, 0.15 },
        roadEdge = { 0.10, 0.06, 0.05 },
        fog = { 0.55, 0.20, 0.10, 0.55 },
        -- LightEngine: penumbra infernal — brasas e braseiros dominam
        lightAmbient = { 0.73, 0.56, 0.52 },
        lightDay   = { 0.86, 0.72, 0.65 },   -- brasa alta
        lightNight = { 0.73, 0.56, 0.52 },   -- penumbra infernal
        lightWindows = { { 0.50, 0.84 }, { 0.25, 0.69 }, { 0.74, 0.52 },
                         { 0.55, 0.52 } },
        lightWindowColor = { 1.00, 0.45, 0.18 },   -- janelas de brasa
        grassPattern = "rage",
        roadPattern = "blood",
        grassTint = { 0.55, 0.32, 0.26 },
        roadTint = { 0.70, 0.48, 0.40 },
        accent = { 0.85, 0.40, 0.15 },        -- brasas
        canopy = { 0.28, 0.14, 0.10 }, canopyDark = { 0.18, 0.08, 0.06 },
        trunk = { 0.16, 0.10, 0.08 },
        bush = { 0.24, 0.12, 0.08 }, bushDark = { 0.15, 0.07, 0.05 },
        rock = { 0.30, 0.20, 0.18 }, rockDark = { 0.18, 0.11, 0.10 },
        landmark = { 0.28, 0.16, 0.14 }, landmarkDark = { 0.16, 0.09, 0.08 },
        propDensity = 1.0,
        propWeights = { deadtree = 3, rock = 2.5, ruin = 1.2, stump = 0.6,
                        bush = 0.8, flowers = 0.7,
                        brazier = 1.0, torch = 0.8, fissure = 0.6 },
    },

    -- Endless 1 — Geleira Espectral: aço gelado, pinheiros escuros
    {
        id = "frost",
        celestial = { kind = "sun",  xr = 0.80, yr = 0.26, r = 15, color = { 0.92, 0.94, 0.98 } },
        ambient = { style = "snow",  rate = 0.45, color = { 0.92, 0.95, 1.00 } },
        name = "Geleira Espectral",
        skyTop = { 0.08, 0.10, 0.14 },
        skyHorizon = { 0.45, 0.50, 0.58 },
        cloud = { 0.65, 0.70, 0.78, 0.5 },
        hillsFar = { 0.26, 0.29, 0.34 },
        hillsNear = { 0.20, 0.23, 0.28 },
        grassA = { 0.30, 0.33, 0.36 },
        grassB = { 0.26, 0.29, 0.32 },
        roadA = { 0.40, 0.38, 0.36 },
        roadB = { 0.34, 0.33, 0.31 },
        roadEdge = { 0.15, 0.15, 0.16 },
        fog = { 0.55, 0.60, 0.68, 0.6 },
        -- LightEngine: dia gelado — neutro frio, luz de fogo contrasta
        lightAmbient = { 0.88, 0.92, 1.00 },
        lightDay   = { 0.97, 0.99, 1.00 },   -- dia gelado
        lightNight = { 0.76, 0.83, 0.98 },   -- anoitecer polar
        lightWindows = { { 0.51, 0.57 }, { 0.34, 0.60 }, { 0.68, 0.76 },
                         { 0.51, 0.37 } },
        lightWindowColor = { 0.70, 0.85, 1.00 },   -- janelas espectrais frias
        grassPattern = "ice",
        roadPattern = "stone",
        grassTint = { 0.62, 0.68, 0.75 },
        roadTint = { 0.78, 0.76, 0.72 },
        accent = { 0.70, 0.82, 0.92 },        -- cristais de gelo
        canopy = { 0.14, 0.20, 0.20 }, canopyDark = { 0.08, 0.13, 0.13 },
        trunk = { 0.20, 0.15, 0.12 },
        bush = { 0.22, 0.27, 0.28 }, bushDark = { 0.13, 0.17, 0.18 },
        rock = { 0.45, 0.48, 0.52 }, rockDark = { 0.28, 0.30, 0.34 },
        landmark = { 0.38, 0.40, 0.45 }, landmarkDark = { 0.23, 0.25, 0.29 },
        propDensity = 0.9,
        propWeights = { pine = 3, rock = 3, deadtree = 1, stump = 0.6,
                        flowers = 0.6,
                        brazier = 0.8, crystal = 0.8, lantern = 0.6 },
    },

    -- Endless 2 — Pântano da Podridão: verde-veneno turvo
    {
        id = "marsh",
        celestial = { kind = "moon", xr = 0.72, yr = 0.27, r = 17, color = { 0.78, 0.85, 0.62 } },
        ambient = { style = "spore", rate = 0.30, color = { 0.65, 0.72, 0.35 } },
        name = "Pântano da Podridão",
        skyTop = { 0.09, 0.11, 0.08 },
        skyHorizon = { 0.38, 0.40, 0.24 },
        cloud = { 0.50, 0.52, 0.38, 0.5 },
        hillsFar = { 0.16, 0.19, 0.13 },
        hillsNear = { 0.12, 0.15, 0.10 },
        grassA = { 0.37, 0.50, 0.15 },   -- #5E7F27 (verde-musgo oliva)
        grassB = { 0.30, 0.41, 0.12 },
        roadA = { 0.30, 0.27, 0.16 },
        roadB = { 0.25, 0.23, 0.13 },
        roadEdge = { 0.10, 0.10, 0.06 },
        fog = { 0.38, 0.42, 0.24, 0.65 },
        -- LightEngine: podridão verde-escura — vagalumes e lanternas
        lightAmbient = { 0.62, 0.70, 0.58 },
        lightDay   = { 0.78, 0.85, 0.72 },   -- névoa diurna do brejo
        lightNight = { 0.62, 0.70, 0.58 },   -- podridão fechada
        lightWindows = { { 0.50, 0.80 }, { 0.50, 0.45 }, { 0.50, 0.25 } },
        lightWindowColor = { 0.55, 0.95, 0.45 },   -- janelas de bruxaria verde
        grassPattern = "poison",
        roadPattern = "wave",
        grassTint = { 0.45, 0.55, 0.30 },
        roadTint = { 0.62, 0.58, 0.38 },
        accent = { 0.72, 0.62, 0.35 },        -- cogumelos
        canopy = { 0.20, 0.26, 0.10 }, canopyDark = { 0.12, 0.17, 0.06 },
        trunk = { 0.20, 0.14, 0.09 },
        bush = { 0.19, 0.24, 0.10 }, bushDark = { 0.11, 0.15, 0.06 },
        rock = { 0.30, 0.30, 0.22 }, rockDark = { 0.18, 0.18, 0.13 },
        landmark = { 0.27, 0.28, 0.20 }, landmarkDark = { 0.16, 0.17, 0.12 },
        propDensity = 1.3,
        propWeights = { deadtree = 2.5, bush = 3.5, flowers = 1.5, stump = 1,
                        rock = 0.7,
                        lantern = 0.9, mushroom = 1.0, totem = 0.6 },
    },

    -- Endless 3 — Campos do Crepúsculo: âmbar dourado, fim de jornada
    {
        id = "dusk",
        celestial = { kind = "sun",  xr = 0.30, yr = 0.38, r = 30, color = { 0.98, 0.80, 0.42 } },
        ambient = { style = "leaf",  rate = 0.28, color = { 0.88, 0.66, 0.25 } },
        name = "Campos do Crepúsculo",
        skyTop = { 0.16, 0.10, 0.14 },
        skyHorizon = { 0.72, 0.48, 0.22 },
        cloud = { 0.80, 0.62, 0.42, 0.55 },
        hillsFar = { 0.28, 0.18, 0.20 },
        hillsNear = { 0.22, 0.14, 0.15 },
        grassA = { 0.365, 0.25, 0.295 },   -- #5D404B (vinho acinzentado crepuscular)
        grassB = { 0.30, 0.205, 0.24 },
        roadA = { 0.50, 0.38, 0.22 },
        roadB = { 0.44, 0.32, 0.18 },
        roadEdge = { 0.20, 0.14, 0.09 },
        fog = { 0.72, 0.48, 0.22, 0.5 },
        -- LightEngine: o entardecer da referência — roxo frio × lanternas
        lightAmbient = { 0.56, 0.47, 0.60 },
        lightDay   = { 0.74, 0.62, 0.66 },   -- golden hour
        lightNight = { 0.56, 0.47, 0.60 },   -- crepúsculo fundo
        lightWindows = { { 0.50, 0.84 }, { 0.49, 0.63 }, { 0.50, 0.30 },
                         { 0.43, 0.52 } },
        grassPattern = "soft",
        roadPattern = "stone",
        grassTint = { 0.80, 0.62, 0.36 },
        roadTint = { 1.00, 0.80, 0.50 },
        accent = { 0.95, 0.75, 0.30 },        -- trigo dourado
        canopy = { 0.42, 0.30, 0.12 }, canopyDark = { 0.28, 0.19, 0.07 },
        trunk = { 0.26, 0.17, 0.10 },
        bush = { 0.38, 0.28, 0.12 }, bushDark = { 0.25, 0.18, 0.07 },
        rock = { 0.42, 0.36, 0.30 }, rockDark = { 0.26, 0.22, 0.18 },
        landmark = { 0.42, 0.36, 0.28 }, landmarkDark = { 0.26, 0.22, 0.17 },
        propDensity = 1.15,
        propWeights = { tree = 3, flowers = 2.5, fence = 0.45, bush = 2,
                        sign = 0.5, rock = 0.8,
                        lantern = 1.1, firepit = 0.8, shrine = 0.5 },
    },
}

return biomes
