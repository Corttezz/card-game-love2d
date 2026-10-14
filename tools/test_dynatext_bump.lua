local TK = require("tools.testkit")

local M = {}

local RATE = 2.666

local function yOff(i, t, phase, amount)
    local s = (5 + RATE) * math.sin(RATE * t + phase * i) - 3 - RATE
    return -amount * 7 * math.max(0, s)
end

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

local SCAN = {
    "components", "src/ui", "src/scenes",
}

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

    local dg, ds = measure(19, 200, 1.0)
    t:truthy("default (200) espalha: 3+ grupos separados numa palavra longa",
        dg >= 3)
    t:truthy("default (200) salta o span inteiro entre vizinhas (~14px, obtido "
        .. string.format("%.1f", ds) .. ")", ds > 12)

    local wg, ws = measure(19, 0.42, 0.45)
    t:truthy("onda (0.42) agrupa: no máximo 2 grupos (obtido " .. wg .. ")",
        wg <= 2)
    t:truthy("onda (0.42) tem degrau suave entre vizinhas (<6px, obtido "
        .. string.format("%.1f", ws) .. ")", ws < 6)
    t:truthy("onda espalha menos que o default", wg < dg and ws < ds)

    local sg = measure(5, 0.42, 0.45)
    t:eq("palavra curta é um grupo só", sg, 1)

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
