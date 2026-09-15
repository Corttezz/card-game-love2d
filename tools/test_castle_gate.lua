-- tools/test_castle_gate.lua
-- A abertura do castelo tem que ser COERENTE com a arte do castelo.
--
-- O defeito (Set/2026, palavras do dono):
--
--     "no ato 3 ta aparecendo uma porta do nada no castelo que tinha
--      porta de fogo"
--
-- A fortaleza do abismo não tem porta: tem um arco EM CHAMAS. Os frames da
-- cerimônia de entrada, porém, apagavam o fogo e desciam uma laje de pedra
-- no vão — uma porta nascendo do nada, exatamente ao contrário de entrar.
--
-- Nada no código percebia isso. `WorldRoad.drawCastle` troca a arte base
-- pelo frame da anim quando `doorK > 0.02` e desenha o que estiver lá; a
-- arte podia mostrar qualquer coisa. Duas travas, as duas medíveis:
--
--   1. A EMENDA — o frame 0 da abertura é a arte base do castelo. A troca
--      é seca; qualquer diferença vira um pulo no instante em que doorK
--      cruza 0.02.
--   2. O VÃO ABRE, NÃO FECHA.
--
-- A regra 2 é a difícil, e a primeira tentativa estava errada: medi "o vão
-- clareia" e três biomas reprovaram — com razão deles, não minha. O castelo
-- dos campos tem uma porta de madeira DE VERDADE, que abre pra um interior
-- escuro; ali escurecer é o certo. Brilho não distingue os dois casos.
--
-- O que distingue é MATERIAL. Uma passagem é um BURACO: atrás dela não tem
-- parede — tem escuridão (campos, planalto, gelo) ou tem fogo (abismo). Um
-- portão fechado é uma SUPERFÍCIE, feita da mesma alvenaria do muro ao
-- lado. Então a trava é: a cor do vão não pode CONVERGIR pra cor da parede
-- que o ladeia. Porta de madeira abrindo AFASTA (vira vazio escuro); a laje
-- de pedra descendo APROXIMA, porque a laje é o muro.
--
-- Medido, distância do vão à parede (frame 0 → último frame):
--
--   abyss ANTIGO (o defeito)  0,517 → 0,097   sobrou 19% — a pedra fechou
--   abyss novo                0,517 → 0,422   sobrou 82% — o arco abre
--   fields (porta de madeira) 0,090 → 0,143   SOBE: abriu pro escuro
--   frost                     0,048 → 0,169   SOBE
--   marsh                     0,114 → 0,384   SOBE
--
-- Repare que os biomas de porta de madeira todos SOBEM: a porta some e o
-- vazio atrás dela é o que mais destoa do muro. A mesma asserção aprova a
-- porta de madeira e reprova a laje de pedra, que é o ponto — o corte em
-- 60% da distância inicial fica larguinho entre 19% (defeito) e 82% (o
-- caso aprovado mais apertado).
--
-- Roda via: love . test_one test_castle_gate

local TK = require("tools.testkit")

local M = {}

local DIR_ANIM = "assets/sprites/world/anim/"
local DIR_ART  = "assets/sprites/world/"

-- O VÃO e as PAREDES QUE O LADEIAM, em coordenadas relativas da arte. Todo
-- castelo do jogo põe a entrada embaixo, no meio, com alvenaria dos dois
-- lados — é o vocabulário da silhueta de castelo, não detalhe de um bioma.
-- As janelas são folgadas de propósito: medem o portal e o muro, não um
-- pixel específico que a próxima arte pode mover.
local VAO      = { x0 = 0.43, x1 = 0.57, y0 = 0.76, y1 = 0.99 }
local PAREDE_E = { x0 = 0.28, x1 = 0.40, y0 = 0.76, y1 = 0.99 }
local PAREDE_D = { x0 = 0.60, x1 = 0.72, y0 = 0.76, y1 = 0.99 }

-- Cor média de uma região (pixel transparente não conta: fundo não é arte).
local function corMedia(imgData, reg)
    local w, h = imgData:getWidth(), imgData:getHeight()
    local x0 = math.max(0, math.floor(reg.x0 * w))
    local x1 = math.min(w - 1, math.floor(reg.x1 * w))
    local y0 = math.max(0, math.floor(reg.y0 * h))
    local y1 = math.min(h - 1, math.floor(reg.y1 * h))
    local sr, sg, sb, n = 0, 0, 0, 0
    for y = y0, y1 do
        for x = x0, x1 do
            local r, g, b, a = imgData:getPixel(x, y)
            if a > 0.5 then
                sr, sg, sb, n = sr + r, sg + g, sb + b, n + 1
            end
        end
    end
    if n == 0 then return 0, 0, 0 end
    return sr / n, sg / n, sb / n
end

-- Quão LONGE o vão está do material da parede ao lado. Alto = é um buraco
-- (vazio escuro ou fogo). Baixo = é alvenaria, ou seja, está fechado.
local function distanciaDoMuro(imgData)
    local vr, vg, vb = corMedia(imgData, VAO)
    local er, eg, eb = corMedia(imgData, PAREDE_E)
    local dr, dg, db = corMedia(imgData, PAREDE_D)
    local pr, pg, pb = (er + dr) / 2, (eg + dg) / 2, (eb + db) / 2
    return math.sqrt((vr - pr) ^ 2 + (vg - pg) ^ 2 + (vb - pb) ^ 2)
end

-- Fração de pixels que diferem de forma VISÍVEL entre duas artes do mesmo
-- tamanho. Contar pixels (em vez de somar erro) é o que importa aqui: um
-- tremular de brasa move muitos pixels MUITO pouco, uma arte diferente move
-- alguns pixels MUITO.
local function fracaoDiferente(a, b)
    local w, h = a:getWidth(), a:getHeight()
    local dif, n = 0, 0
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r1, g1, b1, a1 = a:getPixel(x, y)
            local r2, g2, b2, a2 = b:getPixel(x, y)
            local d = math.max(math.abs(r1 - r2), math.abs(g1 - g2),
                               math.abs(b1 - b2), math.abs(a1 - a2))
            if d > 0.12 then dif = dif + 1 end
            n = n + 1
        end
    end
    return dif / math.max(1, n)
end

local function framesDe(dir)
    if not love.filesystem.getInfo(dir) then return nil end
    local frames = {}
    for i = 0, 63 do
        local p = dir .. "/" .. i .. ".png"
        if not love.filesystem.getInfo(p) then break end
        frames[#frames + 1] = p
    end
    return frames
end

function M.run()
    local t = TK.new("test_castle_gate")

    local Biomes = require("src.data.biomes")
    local lista = Biomes.LIST or Biomes.BIOMES or Biomes
    local ids = {}
    for _, b in ipairs(lista) do
        if type(b) == "table" and b.id then ids[#ids + 1] = b.id end
    end
    t:truthy("achei os biomas pra varrer (" .. #ids .. ")", #ids >= 3)

    local conferidos = 0

    for _, bid in ipairs(ids) do
        local base = DIR_ART .. bid .. "_castle.png"
        local frames = framesDe(DIR_ANIM .. bid .. "_castle_door")

        if love.filesystem.getInfo(base) and frames then
            conferidos = conferidos + 1
            local nome = bid .. "_castle_door"

            t:truthy(nome .. ": tem frames suficientes pra animar (" ..
                #frames .. ")", #frames >= 4)

            local arte = love.image.newImageData(base)
            local aw, ah = arte:getWidth(), arte:getHeight()

            -- --- 1. dimensão: a anim substitui a arte, não convive com ela
            local tamanhoOk = true
            for _, p in ipairs(frames) do
                local f = love.image.newImageData(p)
                if f:getWidth() ~= aw or f:getHeight() ~= ah then
                    tamanhoOk = false
                end
            end
            t:truthy(nome .. ": todo frame tem o tamanho da arte base (" ..
                aw .. "x" .. ah .. ")", tamanhoOk)

            if tamanhoOk then
                -- --- 2. A EMENDA: frame 0 É a arte base
                local f0 = love.image.newImageData(frames[1])
                local dif = fracaoDiferente(arte, f0)
                t:truthy(string.format(
                    "%s: o frame 0 casa com o castelo (difere em %.1f%% dos " ..
                    "pixels; acima de 8%% o jogador ve um PULO quando a " ..
                    "cerimonia comeca)", nome, dif * 100), dif < 0.08)

                -- --- 3. O VÃO ABRE, NÃO FECHA
                local inicio = distanciaDoMuro(f0)
                local fim    = distanciaDoMuro(
                    love.image.newImageData(frames[#frames]))
                t:truthy(string.format(
                    "%s: no fim o vao ainda e um BURACO, nao alvenaria " ..
                    "(distancia ao muro %.3f -> %.3f; despencar significa " ..
                    "que uma porta de pedra desceu no lugar de abrir)",
                    nome, inicio, fim), fim >= inicio * 0.6)
            end
        end
    end

    -- Sem isto o teste passaria inteiro numa varredura que não achou nada.
    t:truthy("conferi pelo menos um castelo (" .. conferidos .. ")",
        conferidos >= 1)

    return t:done()
end

return M
