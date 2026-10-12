-- src/systems/UnlockQueue.lua
-- FILA DE REVELAÇÕES do menu (Out/2026, pedido do dono: "igual ao Balatro:
-- terminou a run e voltou pro menu, mostra tudo o que desbloqueou").
--
-- Quem ENCHE a fila:
--   * UnlockSystem.onRunEnded  → addRunResult(result): classes novas, cada
--     nível de maestria seguido das cartas do pacote dele, as demais cartas
--     liberadas e o Selo novo (vitória, derrota, abandono, endless — toda run
--     termina por lá);
--   * AchievementSystem.unlock → addAchievement(id), na hora em que acontece.
-- Quem ESVAZIA: components/UnlockShowcase.lua, um painel por vez no menu.
--
-- A fila mora no PERFIL (`pendingReveals`) e vai pro disco a cada mudança:
-- fechar o jogo (ou ele cair) antes de ver as revelações não as perde — elas
-- aparecem no próximo boot, quando o menu abrir.
--
-- Item: { kind = "card"|"class"|"mastery"|"seal"|"achievement",
--         id = <carta|classe|conquista>, classId = ..., level = n, n = selo }

local ProfileStats = require("engine.ProfileStats")

local UnlockQueue = {}

-- Teto: uma fila de revelações não é histórico. Um perfil migrado (ou uma
-- ferramenta que desbloqueia tudo) não pode empilhar 200 painéis.
UnlockQueue.MAX = 40

local function list()
    local s = ProfileStats.get()
    if type(s.pendingReveals) ~= "table" then s.pendingReveals = {} end
    return s.pendingReveals
end

local function keyOf(it)
    return table.concat({ it.kind or "?", tostring(it.id or it.classId or ""),
        tostring(it.level or it.n or "") }, ":")
end
UnlockQueue.keyOf = keyOf

function UnlockQueue.items() return list() end
function UnlockQueue.count() return #list() end
function UnlockQueue.peek() return list()[1] end

-- Acrescenta sem repetir (mesma carta liberada por dois caminhos, conquista
-- que o teste desbloqueia duas vezes...). Não grava: quem chama decide.
local function add(q, it)
    if type(it) ~= "table" or not it.kind then
        print("[UnlockQueue] AVISO: item invalido ignorado: " .. tostring(it))
        return false
    end
    local k = keyOf(it)
    for _, e in ipairs(q) do
        if keyOf(e) == k then return false end
    end
    if #q >= UnlockQueue.MAX then
        print("[UnlockQueue] AVISO: fila cheia (" .. UnlockQueue.MAX .. "), descartado " .. k)
        return false
    end
    q[#q + 1] = it
    return true
end

function UnlockQueue.push(it)
    local ok = add(list(), it)
    if ok then ProfileStats.flush() end
    return ok
end

-- Tira o primeiro (o painel que acabou de ser visto) e grava.
function UnlockQueue.pop()
    local q = list()
    local it = table.remove(q, 1)
    ProfileStats.flush()
    return it
end

-- "Pular tudo": esvazia e grava.
function UnlockQueue.clear()
    local s = ProfileStats.get()
    s.pendingReveals = {}
    ProfileStats.flush()
end

function UnlockQueue.addAchievement(id)
    if not id then return false end
    return UnlockQueue.push({ kind = "achievement", id = id })
end

-- Resultado de UnlockSystem.onRunEnded → itens, na ordem em que se leem:
-- classe nova (o maior evento), cada nível de maestria com as cartas do
-- pacote dele logo atrás, as cartas restantes (marcos), o Selo novo.
function UnlockQueue.addRunResult(result)
    if type(result) ~= "table" then return 0 end
    local q = list()
    local n0 = #q
    for _, c in ipairs(result.newClasses or {}) do
        add(q, { kind = "class", id = c })
    end
    local newSet, placed = {}, {}
    for _, id in ipairs(result.newCards or {}) do newSet[id] = true end
    local byLevel = {}
    for _, b in ipairs(result.bundles or {}) do byLevel[b.level] = b end
    local lo = result.before and result.before.level
    local hi = result.after and result.after.level
    local levels = {}
    if lo and hi then
        for lvl = lo + 1, hi do levels[#levels + 1] = lvl end
    else
        for _, b in ipairs(result.bundles or {}) do levels[#levels + 1] = b.level end
    end
    for _, lvl in ipairs(levels) do
        add(q, { kind = "mastery", classId = result.classId, level = lvl })
        local b = byLevel[lvl] or {}
        for _, id in ipairs(b.cards or {}) do
            if newSet[id] and not placed[id] then
                placed[id] = true
                add(q, { kind = "card", id = id })
            end
        end
    end
    for _, id in ipairs(result.newCards or {}) do
        if not placed[id] then
            placed[id] = true
            add(q, { kind = "card", id = id })
        end
    end
    if result.sealUnlocked and result.classId then
        add(q, { kind = "seal", classId = result.classId, n = result.sealUnlocked })
    end
    local added = #q - n0
    if added > 0 then ProfileStats.flush() end
    return added
end

return UnlockQueue
