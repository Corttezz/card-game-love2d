-- tools/test_dynatext_bump.lua
-- TRAVA do bump do DynaText: título que salta tem que ONDULAR, não ESPALHAR.
--
-- O DEFEITO, três vezes
-- O dono reclamou do "Pacote Bufão" com o P muito acima do resto. A causa é o
-- default `bump_phase = 200`: 200 rad em módulo 2π dá ~-1,06 rad de defasagem
-- entre letras VIZINHAS, o que espalha o texto em vez de propagar uma onda.
-- Corrigido no pacote, o MESMO defeito continuou no `RoundEvalScreen`
-- ("RUND E NAUSW E RTUNG") e nas `EndScreens` — porque consertar ocorrências
-- não impede a próxima. Isto impede.
--
-- A MÉTRICA
-- Amplitude sozinha não separa os dois casos: a curva tem `max(0, ...)`, então
-- a transição "no ar" → "na linha" é abrupta nos dois. O que o olho enxerga é
-- CONTIGUIDADE — quantos GRUPOS separados de letras estão no ar ao mesmo
-- tempo. Onda = um grupo que viaja; espalhamento = letras soltas em pontos
-- distintos da palavra. Medido numa palavra de 19 letras:
--
--   bump_phase = 200  (default) → até 4 grupos, degrau de 14px entre vizinhas
--   bump_phase = 0.42           → até 2 grupos, degrau de ~5px
--
--   love . test_one test_dynatext_bump
--   love . test_all

local TK = require("tools.testkit")

local M = {}

local RATE = 2.666   -- DynaText.bump_rate default

-- Réplica da curva de DynaText:draw (mantida em sincronia de propósito: o
-- teste mede a MATEMÁTICA da animação, que não dá pra observar num PNG).
local function yOff(i, t, phase, amount)
    local s = (5 + RATE) * math.sin(RATE * t + phase * i) - 3 - RATE
    return -amount * 7 * math.max(0, s)
end

-- Ao longo de 12s: maior nº de grupos separados de letras no ar, e maior
-- degrau de altura entre letras VIZINHAS.
local function measure(n, phase, amount)
    local maxGroups, maxStep = 0, 0
    local t = 0
    while t < 12 do
        local groups, prev = 0, false
        local ys = {}
        for i = 0, n - 1 do
            ys[i] = yOff(i, t, phase, amount)
            local up = ys[i] < -0.001
            if up and not prev then groups = groups + 1 end
            prev = up
        end
        for i = 0, n - 2 do
            local step = math.abs(ys[i] - ys[i + 1])
            if step > maxStep then maxStep = step end
        end
        if groups > maxGroups then maxGroups = groups end
        t = t + 1 / 240
    end
    return maxGroups, maxStep
end

-- ===== Varredura de consumidores ==========================================
-- Qualquer DynaText com bump ligado precisa DECLARAR bump_phase. Sem isso cai
-- no default histórico e espalha — que é como as três ocorrências nasceram.
local SCAN = {
    "components", "src/ui", "src/scenes",
}

-- Extrai o bloco `DynaText.new({ ... })` contando chaves.
local function blocksIn(content)
    local out = {}
    local init = 1
    while true do
        local s = content:find("DynaText%.new%s*%(%s*{", init)
        if not s then break end
        local i = content:find("{", s)
        local depth, j = 0, i
        repeat
            local c = content:sub(j, j)
            if c == "{" then depth = depth + 1
            elseif c == "}" then depth = depth - 1 end
            j = j + 1
        until depth == 0 or j > #content
        table.insert(out, {
            body = content:sub(i, j),
            line = select(2, content:sub(1, s):gsub("\n", "")) + 1,
        })
        init = j
    end
    return out
end

local function listLua(dir)
    local out = {}
    for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local p = dir .. "/" .. name
        local info = love.filesystem.getInfo(p)
        if info and info.type == "file" and name:sub(-4) == ".lua" then
            table.insert(out, p)
        end
    end
    table.sort(out)
    return out
end

function M.run()
    TK.bootstrap()
    local t = TK.new("DynaText: bump ondula, não espalha")

    -- ===== 1. A matemática: o default É o defeito =====
    local dg, ds = measure(19, 200, 1.0)
    t:truthy("default (200) espalha: 3+ grupos separados numa palavra longa",
        dg >= 3)
    t:truthy("default (200) salta o span inteiro entre vizinhas (~14px, obtido "
        .. string.format("%.1f", ds) .. ")", ds > 12)

    -- ===== 2. A calibração usada nas telas: onda =====
    local wg, ws = measure(19, 0.42, 0.45)
    t:truthy("onda (0.42) agrupa: no máximo 2 grupos (obtido " .. wg .. ")",
        wg <= 2)
    t:truthy("onda (0.42) tem degrau suave entre vizinhas (<6px, obtido "
        .. string.format("%.1f", ws) .. ")", ws < 6)
    t:truthy("onda espalha menos que o default", wg < dg and ws < ds)

    -- Palavra curta continua bem comportada (títulos tipo "SIEG!").
    local sg = measure(5, 0.42, 0.45)
    t:eq("palavra curta é um grupo só", sg, 1)

    -- ===== 3. A trava: nenhum consumidor no default =====
    local offenders, checked = {}, 0
    for _, dir in ipairs(SCAN) do
        for _, path in ipairs(listLua(dir)) do
            local content = love.filesystem.read(path)
            if content then
                for _, b in ipairs(blocksIn(content)) do
                    if b.body:find("bump%s*=%s*true") then
                        checked = checked + 1
                        if not b.body:find("bump_phase") then
                            table.insert(offenders,
                                path .. ":" .. b.line)
                        end
                    end
                end
            end
        end
    end

    t:truthy("achou os DynaText com bump ligado (" .. checked .. ")", checked >= 3)
    if #offenders > 0 then
        print("\n  DynaText com bump=true e SEM bump_phase (cai no default 200):")
        for _, o in ipairs(offenders) do print("    " .. o) end
        print("    -> declare bump_phase (0.42 é a calibração das telas de"
            .. " título) ou desligue o bump se o texto for INFORMAÇÃO.")
    end
    t:eq("nenhum DynaText com bump no default histórico", #offenders, 0)

    return t:done()
end

return M
