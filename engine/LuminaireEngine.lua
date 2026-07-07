-- engine/LuminaireEngine.lua
-- ============================================================================
-- LUMINAIREENGINE v1 — motor de props DECORATIVOS EMISSORES DE LUZ (Jul/2026)
-- ============================================================================
-- Pedido: "um motor específico para os elementos decorativos que emitem luz
-- (lanterna, pedras com fogo, fogueiras, postes)... reaproveitando as luzes,
-- com 2-3 adaptações por bioma... tem que parecer algo que pertence ao bioma".
--
-- O motor NÃO desenha o sprite do prop (isso é do painter do WorldRoad, que
-- respeita a REGRA DE PROFUNDIDADE). Ele é o dono de:
--
--   CATÁLOGO   — 2-3 tipos de luminária POR BIOMA, cada um com cor/raio/
--                núcleo/intensidade/estilo de flicker próprios (a lanterna
--                do pântano é verde-bruxaria; o braseiro da geleira é a
--                ÚNICA coisa quente do bioma — contraste é identidade).
--   LUZ        — submit no LightEngine (núcleo micro na chama + poça de
--                chão posterizada), com estilos de flicker além do
--                fire/pulse nativos: "wisp" (respiração lenta errante) e
--                "shimmer" (cintilação rápida de cristal) modulados AQUI.
--   ÂNCORA     — onde a chama vive no sprite. Detectada POR CONTEÚDO
--                (centróide dos pixels mais brilhantes do PNG — arte
--                PixelLab não precisa de âncora manual), com fallback do
--                catálogo pra arte procedural. Mesmo scan mede offX/footPad
--                (lição dos monstros: canvas com margem descentra o prop).
--   BRASAS     — partículas de fagulha DETERMINÍSTICAS (função do tempo,
--                zero estado — mesma doutrina do GrassField) desenhadas
--                pelo chamador no slot de profundidade do prop.
--
-- Zero stencil, zero shader novo — reusa LightEngine.submit/submitMicro.
-- ============================================================================

local LightEngine = require("engine.LightEngine")

local LuminaireEngine = {}

-- poça de chão só quando o prop está perto (t alto) — de longe vive entre
-- copas e o dither da poça quebrava a silhueta das árvores (lição F-1)
LuminaireEngine.POOL_MIN_T = 0.42

-- ----------------------------------------------------------------------------
-- CATÁLOGO por bioma. Campos por tipo:
--   size    — tamanho de mundo (KIND_SIZE do WorldRoad)
--   lane    — faixa na cunha [colado na estrada .. borda]; emissor vive na
--             BEIRA da estrada (a poça alcança o caminho)
--   anchor  — {xr, yr} fallback da chama (fração do sprite, y do topo)
--   light   — cor/raio(∝ altura na tela)/núcleo/intensidade/flicker
--   embers  — fagulhas subindo (cor própria; só tipos de FOGO vivo)
--   weight  — peso de spawn sugerido (biomes.lua referencia)
-- ----------------------------------------------------------------------------
local FIRE_AMBER  = { 1.00, 0.62, 0.25 }
local FIRE_ORANGE = { 1.00, 0.52, 0.18 }

local CATALOG = {
    -- Campos Arruinados: âmbar de fazenda — lampião, fogueira de beira de
    -- estrada, santuário de vela (mundo rural que ainda acende as luzes)
    fields = {
        lantern = { size = 4.2, face = 1, roadside = true,
            lane = { 0.0, 0.08 }, anchor = { 0.78, 0.46 },
            weight = 1.1,
            light = { color = FIRE_AMBER, radiusK = 1.35, coreK = 0.40,
                      intensity = 0.85, flicker = "fire" } },
        firepit = { size = 1.0, lane = { 0.02, 0.20 }, anchor = { 0.50, 0.30 },
            weight = 0.8,
            light = { color = FIRE_ORANGE, radiusK = 1.70, coreK = 0.55,
                      intensity = 0.90, flicker = "fire" },
            embers = { color = { 1.0, 0.70, 0.30 }, count = 3 } },
        shrine = { size = 1.6, roadside = true, lane = { 0.03, 0.15 }, anchor = { 0.50, 0.42 },
            weight = 0.5,
            light = { color = { 1.00, 0.75, 0.40 }, radiusK = 0.90,
                      coreK = 0.30, intensity = 0.65, flicker = "pulse" } },
    },

    -- Colinas da Torre: noite de lua — fogo ARCANO azul nos braseiros dos
    -- monólitos, runas acesas na pedra, e um lampião de ferro quente de
    -- viajante (único calor da noite fria)
    highlands = {
        brazier = { size = 1.50, roadside = true, lane = { 0.01, 0.12 }, anchor = { 0.50, 0.20 },
            weight = 0.9,
            light = { color = { 0.55, 0.70, 1.00 }, radiusK = 1.60,
                      coreK = 0.50, intensity = 0.85, flicker = "fire" },
            embers = { color = { 0.65, 0.80, 1.00 }, count = 2 } },
        runestone = { size = 1.5, lane = { 0.05, 0.35 }, anchor = { 0.50, 0.45 },
            weight = 0.7,
            light = { color = { 0.45, 0.62, 1.00 }, radiusK = 1.10,
                      coreK = 0.35, intensity = 0.70, flicker = "wisp" } },
        -- lanterna de FERRO de viajante apoiada no chão (arte PixelLab veio
        -- assim e ficou ótima — luminária baixa, não poste)
        lantern = { size = 0.9, roadside = true, lane = { 0.0, 0.08 }, anchor = { 0.50, 0.42 },
            weight = 0.6,
            light = { color = { 0.95, 0.72, 0.42 }, radiusK = 1.30,
                      coreK = 0.40, intensity = 0.80, flicker = "fire" } },
    },

    -- Estrada do Abismo: inferno — braseiro de pilar rugindo (referência),
    -- tocha de estaca carbonizada, fissura de brasa no chão
    abyss = {
        brazier = { size = 1.60, roadside = true, lane = { 0.01, 0.12 }, anchor = { 0.50, 0.18 },
            weight = 1.0,
            light = { color = { 1.00, 0.45, 0.12 }, radiusK = 1.80,
                      coreK = 0.60, intensity = 0.95, flicker = "fire" },
            embers = { color = { 1.00, 0.55, 0.18 }, count = 4 } },
        torch = { size = 1.4, roadside = true, lane = { 0.0, 0.10 }, anchor = { 0.50, 0.16 },
            weight = 0.8,
            light = { color = { 1.00, 0.55, 0.20 }, radiusK = 1.20,
                      coreK = 0.45, intensity = 0.85, flicker = "fire" },
            embers = { color = { 1.00, 0.60, 0.22 }, count = 2 } },
        fissure = { size = 0.9, lane = { 0.05, 0.50 }, anchor = { 0.50, 0.60 },
            weight = 0.6,
            light = { color = { 1.00, 0.35, 0.10 }, radiusK = 1.00,
                      coreK = 0.30, intensity = 0.75, flicker = "wisp" } },
    },

    -- Geleira Espectral: o braseiro QUENTE é o único calor do bioma
    -- (contraste); cristal de gelo e lanterna de pedra são a luz fria local
    frost = {
        brazier = { size = 1.50, roadside = true, lane = { 0.01, 0.12 }, anchor = { 0.50, 0.20 },
            weight = 0.8,
            light = { color = { 1.00, 0.58, 0.22 }, radiusK = 1.60,
                      coreK = 0.50, intensity = 0.90, flicker = "fire" },
            embers = { color = { 1.0, 0.68, 0.30 }, count = 3 } },
        crystal = { size = 1.1, lane = { 0.03, 0.40 }, anchor = { 0.50, 0.35 },
            weight = 0.8,
            light = { color = { 0.62, 0.85, 1.00 }, radiusK = 1.10,
                      coreK = 0.35, intensity = 0.70, flicker = "shimmer" } },
        lantern = { size = 1.6, roadside = true, lane = { 0.0, 0.08 }, anchor = { 0.50, 0.38 },
            weight = 0.6,
            light = { color = { 1.00, 0.68, 0.32 }, radiusK = 1.25,
                      coreK = 0.40, intensity = 0.80, flicker = "fire" } },
    },

    -- Pântano da Podridão: bruxaria — lampião torto de fogo-fátuo VERDE,
    -- cogumelos bioluminescentes, totem musgoso com chama espectral
    marsh = {
        lantern = { size = 4.2, face = 1, roadside = true,
            lane = { 0.0, 0.08 }, anchor = { 0.78, 0.46 },
            weight = 0.9,
            light = { color = { 0.55, 0.95, 0.45 }, radiusK = 1.35,
                      coreK = 0.40, intensity = 0.80, flicker = "wisp" } },
        mushroom = { size = 0.8, lane = { 0.0, 0.60 }, anchor = { 0.50, 0.40 },
            weight = 1.0,
            light = { color = { 0.45, 0.90, 0.60 }, radiusK = 0.80,
                      coreK = 0.30, intensity = 0.60, flicker = "pulse" } },
        totem = { size = 2.0, roadside = true, lane = { 0.02, 0.20 }, anchor = { 0.50, 0.18 },
            weight = 0.6,
            light = { color = { 0.62, 0.88, 0.50 }, radiusK = 1.20,
                      coreK = 0.40, intensity = 0.75, flicker = "wisp" } },
    },

    -- Campos do Crepúsculo: golden hour eterna — lampião dourado
    -- (referência), fogueira de colheita, santuário de velas no trigo
    dusk = {
        lantern = { size = 4.2, face = 1, roadside = true,
            lane = { 0.0, 0.08 }, anchor = { 0.78, 0.46 },
            weight = 1.1,
            light = { color = { 1.00, 0.72, 0.30 }, radiusK = 1.40,
                      coreK = 0.40, intensity = 0.85, flicker = "fire" } },
        firepit = { size = 1.1, lane = { 0.02, 0.20 }, anchor = { 0.50, 0.28 },
            weight = 0.8,
            light = { color = FIRE_ORANGE, radiusK = 1.80, coreK = 0.60,
                      intensity = 0.90, flicker = "fire" },
            embers = { color = { 1.0, 0.72, 0.32 }, count = 3 } },
        shrine = { size = 1.6, roadside = true, lane = { 0.03, 0.15 }, anchor = { 0.50, 0.42 },
            weight = 0.5,
            light = { color = { 1.00, 0.78, 0.45 }, radiusK = 0.95,
                      coreK = 0.30, intensity = 0.70, flicker = "pulse" } },
    },
}

-- conjunto global de kinds (qualquer bioma) — pro WorldRoad reconhecer
local KIND_SET = {}
for _, kinds in pairs(CATALOG) do
    for kind in pairs(kinds) do KIND_SET[kind] = true end
end

function LuminaireEngine.catalog(bid) return CATALOG[bid] or {} end
function LuminaireEngine.def(bid, kind)
    local c = CATALOG[bid]
    return c and c[kind] or nil
end
function LuminaireEngine.isLuminaire(kind) return KIND_SET[kind] == true end

-- ----------------------------------------------------------------------------
-- ÂNCORA POR CONTEÚDO: centróide dos pixels mais brilhantes do PNG (a chama
-- assada É o ponto mais claro da arte) + offX/footPad (margens do canvas).
-- Cache por chave; PNG ausente/procedural → fallback do catálogo.
-- ----------------------------------------------------------------------------
local anchorCache = {}

local function scanImage(path)
    local ok, data = pcall(love.image.newImageData, path)
    if not ok or not data then return nil end
    local w, h = data:getWidth(), data:getHeight()
    local minX, maxX, maxY = w, -1, -1
    local sumX, sumY, sumW = 0, 0, 0
    local peak = 0
    -- passada 1: bbox do conteúdo + pico de luminância
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r, g, b, a = data:getPixel(x, y)
            if a > 0.5 then
                if x < minX then minX = x end
                if x > maxX then maxX = x end
                if y > maxY then maxY = y end
                local lum = r * 0.3 + g * 0.55 + b * 0.15
                if lum > peak then peak = lum end
            end
        end
    end
    if maxX < 0 then return nil end
    -- passada 2: centróide dos pixels dentro de 88% do pico (a chama)
    local cut = peak * 0.88
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r, g, b, a = data:getPixel(x, y)
            if a > 0.5 then
                local lum = r * 0.3 + g * 0.55 + b * 0.15
                if lum >= cut then
                    sumX = sumX + x; sumY = sumY + y; sumW = sumW + 1
                end
            end
        end
    end
    local res = {
        offX = math.floor((minX + maxX) / 2 - w / 2 + 0.5),
        footPad = h - 1 - maxY,
    }
    if sumW > 0 then
        res.ax = (sumX / sumW) / w
        res.ay = (sumY / sumW) / h
    end
    return res
end

-- Retorna { ax, ay, offX, footPad } — ax/ay fração do sprite (y do topo).
function LuminaireEngine.anchor(bid, kind, variant, path)
    local key = bid .. "|" .. kind .. "|" .. tostring(variant)
    local hit = anchorCache[key]
    if hit then return hit end
    local def = LuminaireEngine.def(bid, kind)
    local res = path and scanImage(path) or nil
    if not res then res = { offX = 0, footPad = 0 } end
    if not res.ax and def then
        res.ax, res.ay = def.anchor[1], def.anchor[2]
    end
    anchorCache[key] = res
    return res
end

-- ----------------------------------------------------------------------------
-- LUZ: núcleo micro na chama + poça de chão. Flickers "fire"/"pulse" são
-- nativos do LightEngine; "wisp" e "shimmer" são modulados aqui (noise
-- contínuo, nunca random puro — doutrina do motor de luz).
-- a = { fx, fy (chama em coords de TELA pós-transform), gx, gy (pés),
--       sh (altura do sprite na tela), t, rel, seed }
-- ----------------------------------------------------------------------------
function LuminaireEngine.submit(bid, kind, a)
    local def = LuminaireEngine.def(bid, kind)
    if not def then return end
    local L = def.light
    local inten, radK = L.intensity, L.radiusK
    local flicker = L.flicker
    local time = love.timer.getTime()
    local seed = (a.seed or 0) % 1000
    if flicker == "wisp" then
        -- respiração lenta errante (fogo-fátuo): 2 noises lentos compostos
        local n = love.math.noise(time * 0.7, seed) * 0.65
            + love.math.noise(time * 2.1, seed + 53.7) * 0.35
        inten = inten * (0.70 + 0.40 * n)
        radK = radK * (0.90 + 0.16 * n)
        flicker = nil
    elseif flicker == "shimmer" then
        -- cintilação rápida e RASA (cristal): brilho quase fixo que faísca
        local n = love.math.noise(time * 6.0, seed)
        inten = inten * (0.88 + 0.12 * n)
        flicker = nil
    end
    -- v9.2: núcleo e poça escalam com a ALTURA DA CHAMA acima do chão
    -- (a.flameH), não com o sprite inteiro — poste 4.2 de mundo tinha
    -- sh enorme e a poça virava um disco que ditherizava o CÉU. capR
    -- (do chamador, ~30% da área) é o teto absoluto.
    local base = a.flameH or a.sh
    LightEngine.submitMicro(a.fx, a.fy,
        math.min(L.coreK * base, (a.capR or 1e9) * 0.5), L.color,
        0.9 * (inten / L.intensity), a.rel)
    if a.t >= LuminaireEngine.POOL_MIN_T then
        LightEngine.submit({
            x = a.gx, y = a.gy,
            radius = math.min(radK * base, a.capR or 1e9),
            color = L.color, intensity = inten,
            dither = true, flicker = flicker, seed = a.seed,
            z = a.rel,
        })
    end
end

-- ----------------------------------------------------------------------------
-- BRASAS: fagulhas subindo da chama. DETERMINÍSTICAS (função pura do tempo,
-- como o GrassField) — cada fagulha tem ciclo/fase próprios derivados do
-- seed; chamador desenha no slot de profundidade do prop (REGRA DE
-- PROFUNDIDADE: brasa na frente da árvore desenha depois dela).
-- fx, fy = chama na tela (coords locais do painter); sh = altura na tela.
-- ----------------------------------------------------------------------------
local function hash01(n)
    return (math.sin(n * 127.1 + 311.7) * 43758.5453) % 1
end

function LuminaireEngine.drawEmbers(bid, kind, fx, fy, sh, seed)
    local def = LuminaireEngine.def(bid, kind)
    local em = def and def.embers
    if not em or sh < 14 then return end   -- longe demais = 1px, não desenha
    local time = love.timer.getTime()
    local c = em.color
    for i = 1, em.count do
        local h1 = hash01(seed * 7.13 + i * 13.7)
        local h2 = hash01(seed * 3.71 + i * 29.3)
        local cycle = 1.1 + h1 * 0.9
        local life = (time / cycle + h2) % 1
        local rise = life * sh * 0.55
        local wob = math.sin(time * 2.2 + h1 * 6.28 + life * 5.0)
            * sh * 0.05
        local aK = (1 - life) * (1 - life) * math.min(1, life * 6)
        if aK > 0.05 then
            local sz = math.max(1, math.floor(sh * 0.03 * (1 - life * 0.5)))
            love.graphics.setColor(c[1], c[2], c[3], aK)
            love.graphics.rectangle("fill",
                math.floor(fx + wob), math.floor(fy - rise), sz, sz)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return LuminaireEngine
