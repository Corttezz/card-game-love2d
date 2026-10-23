local Debug = require("src.core.Debug")

local RoadVariants = {}

RoadVariants.IDS = { "atual", "A", "B", "C" }
RoadVariants.id = "atual"

RoadVariants.NAMES = {
    fields = { A = "A_trilha_gasta", B = "B_terra_com_meio_fio", C = "C_pocas_e_pegadas" },
    highlands = { A = "A_trilha_de_cascalho", B = "B_lajes_irregulares", C = "C_lajes_molhadas_e_folhas" },
    abyss = { A = "A_trilha_de_cinza", B = "B_basalto_com_brasa", C = "C_cinza_soprada_e_brasas" },
    frost = { A = "A_neve_pisada", B = "B_neve_com_trilho_de_treno", C = "C_neve_soprada_e_gelo" },
    marsh = { A = "A_lama_com_sulcos", B = "B_passarela_de_tabuas", C = "C_lama_com_agua_e_juncos" },
    dusk = { A = "A_trilha_de_folhas", B = "B_estrada_antiga_com_musgo", C = "C_folhas_sopradas_e_pocas" },
}

local function norm(id)
    if not id or id == "" then return nil end
    local head = tostring(id):sub(1, 1):upper()
    if tostring(id):lower() == "atual" then return "atual" end
    for _, v in ipairs(RoadVariants.IDS) do
        if v == head then return v end
    end
    return nil
end

function RoadVariants.use(id)
    local v = norm(id)
    if not v then
        Debug.warn("[RoadVariants] variante inexistente: " .. tostring(id))
        return false
    end
    if v ~= RoadVariants.id then
        RoadVariants.id = v
        RoadVariants.stamp = (RoadVariants.stamp or 0) + 1
    end
    return true
end

function RoadVariants.cycle(dir)
    local list, cur = RoadVariants.IDS, 1
    for i, id in ipairs(list) do if id == RoadVariants.id then cur = i end end
    local nxt = (cur - 1 + (dir or 1)) % #list + 1
    RoadVariants.use(list[nxt])
    return RoadVariants.id
end

function RoadVariants.label(bid)
    local id = RoadVariants.id
    if id == "atual" then return "atual" end
    local t = RoadVariants.NAMES[bid or "fields"]
    return (t and t[id]) or id
end

function RoadVariants.active()
    return RoadVariants.id ~= "atual"
end

RoadVariants.stamp = 0

do
    local want = os.getenv("CARDGAME_ROAD")
    if want and want ~= "" then
        local okR, Release = pcall(require, "src.core.Release")
        if okR and Release.isDev and Release.isDev() then RoadVariants.use(want) end
    end
end

return RoadVariants
