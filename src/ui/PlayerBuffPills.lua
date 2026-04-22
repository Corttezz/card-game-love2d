-- src/ui/PlayerBuffPills.lua
-- Row horizontal de pills mostrando os buffs/stats ativos do jogador.
-- Delega renderização pro StatusPill (mesmo componente usado por EnemyHud).
--
-- Fontes de dado:
--   player.strength   (int) — pill só aparece se > 0
--   player.dexterity  (int) — idem
--   player.buffs      (tabela {name, duration, stacks})
--
-- Posicionamento: logo acima do HudPlayerPanel (caller passa coords do painel).

local StatusPill = require("src.ui.StatusPill")

local PlayerBuffPills = {}
PlayerBuffPills.__index = PlayerBuffPills

local BADGE_SIZE = 36
local BADGE_SPACING = 8

function PlayerBuffPills:new()
    local instance = setmetatable({}, PlayerBuffPills)
    instance.animTime = 0
    return instance
end

function PlayerBuffPills:update(dt)
    self.animTime = self.animTime + (dt or 0)
end

-- Coleta lista unificada de "buffs visíveis" do player.
local function collectBuffs(player)
    local list = {}
    if (player.strength or 0) > 0 then
        table.insert(list, { name = "strength", stacks = player.strength, duration = 0 })
    end
    if (player.dexterity or 0) > 0 then
        table.insert(list, { name = "dexterity", stacks = player.dexterity, duration = 0 })
    end
    for _, b in ipairs(player.buffs or {}) do
        table.insert(list, { name = b.name, stacks = b.stacks or 1, duration = b.duration or 1 })
    end
    return list
end

function PlayerBuffPills:draw(player, panelX, panelY, panelW)
    if not player then return end
    local buffs = collectBuffs(player)
    if #buffs == 0 then return end

    local startX = math.floor(panelX)
    local y = math.floor(panelY - BADGE_SIZE - 6)

    StatusPill.drawRow(buffs, startX, y, {
        size = BADGE_SIZE,
        spacing = BADGE_SPACING,
        animTime = self.animTime,
        pulseHalo = true,           -- buffs pulsam pra chamar atenção
        showStacksAlways = true,    -- valor numérico é a info principal (Força 3)
    })
end

return PlayerBuffPills
