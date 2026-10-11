-- src/ui/AchievementIcons.lua
-- Emblemas das conquistas: assets/sprites/achievements/<id>.png (liberada) e
-- <id>_locked.png (bloqueada — silhueta escurecida, derivada do emblema por
-- tools/achievement_icons.py, a MESMA receita que exporta pra Steam).
--
-- Cache por caminho, filtro nearest. Arquivo ausente AVISA (uma vez por id)
-- e cai num medalhao procedural — nunca some em silencio.

local AchievementIcons = {}

AchievementIcons.DIR = "assets/sprites/achievements/"
AchievementIcons.SIZE = 64

local cache = {}
local warned = {}

function AchievementIcons.path(id, locked)
    return AchievementIcons.DIR .. id .. (locked and "_locked" or "") .. ".png"
end

-- Image ou nil (com aviso).
function AchievementIcons.get(id, locked)
    local p = AchievementIcons.path(id, locked)
    local hit = cache[p]
    if hit ~= nil then return hit or nil end
    if love.filesystem.getInfo(p) then
        local ok, img = pcall(love.graphics.newImage, p)
        if ok then
            img:setFilter("nearest", "nearest")
            cache[p] = img
            return img
        end
        print("[AchievementIcons] AVISO: falha ao carregar " .. p .. ": " .. tostring(img))
    elseif not warned[p] then
        warned[p] = true
        print("[AchievementIcons] AVISO: emblema ausente " .. p)
    end
    cache[p] = false
    return nil
end

-- Desenha o emblema centrado em (cx, cy) com lado `size`. Fallback: disco.
function AchievementIcons.draw(id, locked, cx, cy, size, alpha)
    local img = AchievementIcons.get(id, locked)
    alpha = alpha or 1
    if img then
        local s = size / img:getWidth()
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(img, math.floor(cx - size / 2), math.floor(cy - size / 2), 0, s, s)
    else
        love.graphics.setColor(0.25, 0.2, 0.15, alpha)
        love.graphics.circle("fill", cx, cy, size * 0.45)
    end
end

return AchievementIcons
