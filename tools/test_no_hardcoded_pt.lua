local TK = require("tools.testkit")

local M = {}

local DIRS = {
    "components", "src/ui", "src/ui/card", "src/ui/card/components",
    "src/systems", "src/core", "src/data", "src/scenes", "engine",
}
local FILES = { "main.lua" }

local DEV_PATTERNS = {
    "print%s*%(", "Debug%.%w+%s*%(", "error%s*%(", "assert%s*%(",
    "io%.write", "love%.filesystem%.append",
    "warn%w*%s*%(",
    "return%s+%w+%s*,%s*\"",
}

local ALLOW = {
    ["src/data/decks.lua"] =
        "modo clássico (legado): decks estáticos nunca exibidos na UI de run",
    ["src/data/keywords.lua"] =
        "palavras-GATILHO do glossário por locale (casadas contra a desc traduzida, nunca desenhadas); o texto exibido mora em keyword.<id>.name/text",
    ["src/data/biomes.lua"] =
        "biomes[].name não é lido por ninguém — só o .id é usado (WorldRoad/Roteiro)",
    ["src/ui/PackThemes.lua"] =
        "território do agente de pacotes (PackOpenScreen/PackSleeve) — reportado, não editado",
}

local MATH_SIGNS = { [151] = true, [183] = true }
local function hasAccent(str)
    local i = str:find("\195", 1, true)
    while i do
        local nxt = str:byte(i + 1)
        if not (nxt and MATH_SIGNS[nxt]) then return true end
        i = str:find("\195", i + 1, true)
    end
    return false
end

local function stripComment(line)
    local inStr = false
    local i = 1
    while i <= #line do
        local c = line:sub(i, i)
        if c == '"' and line:sub(i - 1, i - 1) ~= "\\" then
            inStr = not inStr
        elseif not inStr and c == "-" and line:sub(i + 1, i + 1) == "-" then
            return line:sub(1, i - 1)
        end
        i = i + 1
    end
    return line
end

local function isDevLine(line)
    for _, p in ipairs(DEV_PATTERNS) do
        if line:find(p) then return true end
    end
    return false
end

local function isI18nFallback(line)
    return line:find("I18n%.t%s*%(") ~= nil
        or line:find("I18nMod%.t%s*%(") ~= nil
        or line:find("%f[%w]t%s*%(\"") ~= nil and line:find("i18n") ~= nil
end

local function parenDelta(code)
    local d, inStr = 0, false
    for i = 1, #code do
        local c = code:sub(i, i)
        if c == '"' and code:sub(i - 1, i - 1) ~= "\\" then
            inStr = not inStr
        elseif not inStr then
            if c == "(" then d = d + 1 elseif c == ")" then d = d - 1 end
        end
    end
    return d
end

local function scanFile(path)
    local content = love.filesystem.read(path)
    if not content then return nil end
    local hits = {}
    local n = 0
    local buf, bufLine, depth = nil, 0, 0
    local function flush()
        if not buf then return end
        if buf:find('"') and hasAccent(buf)
            and not isDevLine(buf) and not isI18nFallback(buf) then
            for lit in buf:gmatch('"([^"]*)"') do
                if hasAccent(lit) then
                    table.insert(hits, { line = bufLine, text = lit })
                end
            end
        end
        buf, depth = nil, 0
    end
    for line in (content .. "\n"):gmatch("(.-)\r?\n") do
        n = n + 1
        local code = stripComment(line)
        if buf then buf = buf .. " " .. code else buf, bufLine = code, n end
        depth = depth + parenDelta(code)
        if depth <= 0 then flush() end
    end
    flush()
    return hits
end

local function listLua(dir)
    local out = {}
    local items = love.filesystem.getDirectoryItems(dir)
    for _, name in ipairs(items) do
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
    local t = TK.new("i18n: sem PT cravado em UI")

    local targets = {}
    for _, d in ipairs(DIRS) do
        for _, p in ipairs(listLua(d)) do table.insert(targets, p) end
    end
    for _, f in ipairs(FILES) do table.insert(targets, f) end

    local offenders, allowedHits, scanned = {}, 0, 0
    for _, path in ipairs(targets) do
        local hits = scanFile(path)
        if hits then
            scanned = scanned + 1
            if #hits > 0 then
                if ALLOW[path] then
                    allowedHits = allowedHits + #hits
                else
                    table.insert(offenders, { path = path, hits = hits })
                end
            end
        end
    end

    t:truthy("varreu os arquivos de UI (" .. scanned .. ")", scanned > 40)

    if #offenders > 0 then
        print("\n  Literais em português fora do i18n:")
        for _, o in ipairs(offenders) do
            for _, h in ipairs(o.hits) do
                print(("    %s:%d  \"%s\""):format(o.path, h.line, h.text))
            end
        end
        print("    -> mande pro i18n (5 locales) ou, se for saída de dev,")
        print("       use print/Debug.*; se for exceção real, registre em ALLOW.")
    end
    t:eq("nenhum literal acentuado em caminho de desenho", #offenders, 0)

    for path in pairs(ALLOW) do
        local hits = scanFile(path)
        if hits and #hits == 0 then
            print("    -> ALLOW obsoleto (arquivo já limpo): " .. path)
        end
    end
    t:truthy("exceções auditadas ainda em uso (" .. allowedHits .. " ocorrências)",
        allowedHits > 0)

    return t:done()
end

return M
