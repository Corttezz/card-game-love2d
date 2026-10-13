-- tools/jsonlite.lua
-- Encoder JSON minimo pros registros da bateria de balanceamento
-- (tools/balance_sim.lua → tools/balance.py). So ENCODE: quem le e o Python.
--
-- Regras: tabela com [1] ou vazia = array; senao objeto com chaves em string
-- (chave numerica vira "n"). NaN/inf viram null. Chaves ordenadas pra saida
-- estavel (diff de dois relatorios da mesma seed e vazio).

local J = {}

local function esc(s)
    return s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' end
        if c == "\\" then return "\\\\" end
        if c == "\n" then return "\\n" end
        if c == "\r" then return "\\r" end
        if c == "\t" then return "\\t" end
        return string.format("\\u%04x", c:byte())
    end)
end

local function isArray(t)
    if next(t) == nil then return true end
    local n = #t
    if n == 0 then return false end
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then return false end
    end
    return true
end

local encode
local function encodeTable(t, out, depth)
    if depth > 40 then out[#out + 1] = '"<fundo>"' return end
    if isArray(t) then
        out[#out + 1] = "["
        for i = 1, #t do
            if i > 1 then out[#out + 1] = "," end
            encode(t[i], out, depth + 1)
        end
        out[#out + 1] = "]"
        return
    end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    out[#out + 1] = "{"
    for i, ks in ipairs(keys) do
        if i > 1 then out[#out + 1] = "," end
        out[#out + 1] = '"' .. esc(ks) .. '":'
        local v = t[ks]
        if v == nil then v = t[tonumber(ks)] end
        encode(v, out, depth + 1)
    end
    out[#out + 1] = "}"
end

encode = function(v, out, depth)
    local tv = type(v)
    if tv == "nil" then out[#out + 1] = "null"
    elseif tv == "boolean" then out[#out + 1] = v and "true" or "false"
    elseif tv == "number" then
        if v ~= v or v == math.huge or v == -math.huge then out[#out + 1] = "null"
        elseif v == math.floor(v) and math.abs(v) < 1e15 then out[#out + 1] = string.format("%d", v)
        else out[#out + 1] = string.format("%.6g", v) end
    elseif tv == "string" then out[#out + 1] = '"' .. esc(v) .. '"'
    elseif tv == "table" then encodeTable(v, out, depth)
    else out[#out + 1] = '"' .. esc(tostring(v)) .. '"' end
end

function J.encode(v)
    local out = {}
    encode(v, out, 0)
    return table.concat(out)
end

return J
