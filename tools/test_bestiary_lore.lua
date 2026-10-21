local M = {}
local TK = require("tools.testkit")

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }
local LORE_MAX = 280
local SIGNATURE_MAX = 210
local EPITHET_MAX = 36

local UI_KEYS = {
    "tab", "count", "act_header", "tier.common", "tier.elite", "tier.miniboss", "tier.boss",
    "unknown", "undiscovered", "moves", "moves_hidden", "signature", "lore",
    "stat_seen", "stat_defeated", "stat_killed_you", "new_creatures", "end_label", "tab_cards",
}

local PLACEHOLDERS = { "TODO", "TBD", "FIXME", "XXX", "[Ll]orem", "[Pp]laceholder", "%.%.%.%.", "{", "}" }

local function get(tbl, path)
    local cur = tbl
    for seg in path:gmatch("[^%.]+") do
        if type(cur) ~= "table" then return nil end
        cur = cur[seg]
    end
    return cur
end

local function ulen(s)
    local _, n = s:gsub("[^\128-\191]", "")
    return n
end

local function sentences(s)
    local n = 0
    for _ in (s .. " "):gmatch("[%.!?]+%s") do n = n + 1 end
    return n
end

local function words(s)
    local n = 0
    for _ in s:gmatch("%S+") do n = n + 1 end
    return n
end

local function placeholder(s)
    for _, p in ipairs(PLACEHOLDERS) do
        if s:find(p) then return p end
    end
    return nil
end

local function rosterIds()
    local Enemies = require("src.data.enemies")
    local ids, tierOf = {}, {}
    for act = 1, #Enemies.ROSTER do
        local a = Enemies.ROSTER[act]
        for _, tier in ipairs({ "battle", "elite", "mini_boss", "boss" }) do
            for _, id in ipairs(a[tier] or {}) do
                if not tierOf[id] then ids[#ids + 1] = id end
                tierOf[id] = tier
            end
        end
    end
    return ids, tierOf
end

function M.run()
    local t = TK.new("bestiário: epíteto, registro e assinatura de toda criatura")
    local ids, tierOf = rosterIds()
    t:check("roster tem 42 criaturas (" .. #ids .. ")", #ids == 42)

    for _, loc in ipairs(LOCALES) do
        package.loaded["src.i18n.locales.bestiary." .. loc] = nil
        package.loaded["src.i18n.locales." .. loc] = nil
        local data = require("src.i18n.locales." .. loc)
        local best = data.bestiary
        t:check(loc .. ": namespace bestiary registrado no locale", type(best) == "table")
        best = best or {}
        local bad = {}
        local function flag(msg) bad[#bad + 1] = msg end

        for _, k in ipairs(UI_KEYS) do
            local v = get(best, "ui." .. k)
            if type(v) ~= "string" or v == "" then flag("ui." .. k .. " ausente") end
        end
        local nc = get(best, "ui.new_creatures")
        if type(nc) == "string" and not nc:find("{n}", 1, true) then flag("ui.new_creatures sem {n}") end
        local ah = get(best, "ui.act_header")
        if type(ah) == "string" and not (ah:find("{n}", 1, true) and ah:find("{biome}", 1, true)) then
            flag("ui.act_header sem {n}/{biome}")
        end

        for _, id in ipairs(ids) do
            local c = get(best, "creature." .. id)
            local name = get(data, "end_screen.enemy." .. id)
            if type(name) ~= "string" or name == "" then flag(id .. ": sem nome em end_screen.enemy") end
            if type(c) ~= "table" then
                flag(id .. ": sem entrada")
            else
                local ep, lore, sig = c.epithet, c.lore, c.signature
                if type(ep) ~= "string" or ep == "" then
                    flag(id .. ": sem epíteto")
                else
                    local w = words(ep)
                    if w < 2 or w > 7 then flag(id .. ": epíteto com " .. w .. " palavras") end
                    if ulen(ep) > EPITHET_MAX then flag(id .. ": epíteto longo " .. ulen(ep)) end
                    if placeholder(ep) then flag(id .. ": epíteto com marcador " .. placeholder(ep)) end
                end
                if type(lore) ~= "string" or lore == "" then
                    flag(id .. ": sem registro")
                else
                    local n = sentences(lore)
                    if n < 2 or n > 4 then flag(id .. ": registro com " .. n .. " frases") end
                    if ulen(lore) > LORE_MAX then flag(id .. ": registro com " .. ulen(lore) .. " caracteres") end
                    if placeholder(lore) then flag(id .. ": registro com marcador " .. placeholder(lore)) end
                    if lore == id then flag(id .. ": registro igual ao id") end
                end
                if tierOf[id] == "boss" then
                    if type(sig) ~= "string" or sig == "" then
                        flag(id .. ": chefe sem assinatura")
                    else
                        if ulen(sig) > SIGNATURE_MAX then flag(id .. ": assinatura longa " .. ulen(sig)) end
                        if placeholder(sig) then flag(id .. ": assinatura com marcador") end
                    end
                elseif sig ~= nil then
                    flag(id .. ": assinatura em quem não é chefe")
                end
            end
        end

        for k in pairs(best.creature or {}) do
            if not tierOf[k] then flag("criatura fora do roster: " .. tostring(k)) end
        end

        for i = 1, math.min(8, #bad) do print("     " .. loc .. " " .. bad[i]) end
        t:eq(loc .. ": 42 fichas completas, sem marcador e no tamanho da ficha", #bad, 0)
    end

    for _, loc in ipairs(LOCALES) do
        local best = require("src.i18n.locales.bestiary." .. loc)
        local seen, dup = {}, 0
        for _, id in ipairs(ids) do
            local ep = best.creature[id] and best.creature[id].epithet
            if ep then
                if seen[ep] then dup = dup + 1; print("     " .. loc .. " epíteto repetido: " .. ep) end
                seen[ep] = true
            end
        end
        t:eq(loc .. ": epítetos únicos", dup, 0)
    end
    return t:done()
end

return M
