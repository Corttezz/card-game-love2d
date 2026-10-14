local M = {}

local function assinatura(cd)
    local partes = {}
    for _, e in ipairs(cd.effects or {}) do
        local campos = {}
        for k, v in pairs(e) do
            if k ~= "description" and type(v) ~= "table" and type(v) ~= "function" then
                campos[#campos + 1] = tostring(k) .. "=" .. tostring(v)
            end
        end
        table.sort(campos)
        partes[#partes + 1] = table.concat(campos, ",")
    end
    if #partes == 0 then return nil end
    table.sort(partes)
    return table.concat(partes, " | ")
end

function M.run()
    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    local cards = db.cards or db:getAllCards()

    local porAssinatura = {}
    local total = 0
    for id, cd in pairs(cards) do
        total = total + 1
        local sig = assinatura(cd)
        if sig then
            porAssinatura[sig] = porAssinatura[sig] or {}
            table.insert(porAssinatura[sig], { id = id, cd = cd })
        end
    end

    print(string.format("=== ASSINATURAS DE EFEITO REPETIDAS (%d cartas) ===", total))
    local grupos = 0
    local chaves = {}
    for sig in pairs(porAssinatura) do chaves[#chaves + 1] = sig end
    table.sort(chaves)

    for _, sig in ipairs(chaves) do
        local lista = porAssinatura[sig]
        if #lista > 1 then
            table.sort(lista, function(a, b) return a.id < b.id end)
            grupos = grupos + 1
            print("")
            print("  " .. sig)
            for _, item in ipairs(lista) do
                print(string.format("    %-28s %-8s %-8s custo %-2s  %s",
                    item.id, item.cd.type or "?", item.cd.rarity or "?",
                    tostring(item.cd.cost or 0), item.cd.name or "?"))
            end
        end
    end

    print("")
    print(string.format("%d grupo(s) com assinatura repetida.", grupos))

    love.event.quit(0)
    return true
end

return M
