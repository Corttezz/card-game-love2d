-- src/ui/PlayerBuffPills.lua
-- Row horizontal de pills mostrando os estados ativos do jogador.
-- Delega renderização pro StatusPill (mesmo componente usado por EnemyHud).
--
-- Fontes de dado:
--   player.strength   (int) — pill só aparece se > 0
--   player.dexterity  (int) — idem
--   player.buffs      (tabela {name, duration, stacks}) — focus, thorn, ...
--   game.jokerSlots   (DERIVADOS) — efeitos contínuos que vivem no joker e não
--                     no player, mas mudam a regra da batalha inteira
--                     (reflexo, cura/dano por turno, Bloqueio retido).
--
-- POR QUE OS DERIVADOS (Set/2026, pedido do dono sobre "Barreira de Fogo"):
-- reflexo de dano, regeneração, sangria e retenção de Bloqueio decidem o turno
-- do jogador e não apareciam em LUGAR NENHUM — só no texto da carta que já
-- saiu da mão. Agora todo estado que altera regra tem pill + tooltip.
--
-- LAYOUT POR ZONAS (memory/ui_layout_invariants.md §1): esta row ocupa uma
-- BANDA de altura fixa (BAND_HEIGHT) logo acima do HudPlayerPanel. Quando há
-- pills demais quem cede é a ESCALA das pills — a banda nunca cresce nem
-- quebra linha, então o OrbRow (banda de cima) nunca é invadido. O OrbRow lê
-- BAND_HEIGHT/BAND_GAP daqui em vez de repetir números mágicos.

local StatusPill = require("src.ui.StatusPill")

local PlayerBuffPills = {}
PlayerBuffPills.__index = PlayerBuffPills

local BADGE_SIZE = 36
local BADGE_SPACING = 8

-- Contrato de zona lido pelo OrbRow.
PlayerBuffPills.BAND_HEIGHT = BADGE_SIZE
PlayerBuffPills.BAND_GAP = 6

-- Buff com duração >= isto é, na prática, "a batalha inteira" (o código usa 99
-- pra focus e afins). Mostrar "dura 99 turnos" é um dado falso com cara de
-- verdade — estes viram a variante `desc_permanent` no tooltip.
local PERMANENT_THRESHOLD = 90

-- Efeito de joker ativo → nome da pill.
-- `on_defend_damage` NÃO entra aqui de propósito: desde Set/2026 o reflexo é um
-- ESTADO ARMADO — a carta/joker chama player:addBuff("thorn", 1, v) e o dano só
-- sai quando o inimigo bate. O buff já representa o total (carta + joker), então
-- derivar do joker TAMBÉM contaria o mesmo reflexo duas vezes na pill.
local JOKER_DERIVED = {
    on_attack_heal   = "lifesteal",
    regen_per_turn   = "regen",
    damage_per_turn  = "bleed",
    retain_armor     = "retain_armor",
}

-- Estados cuja descrição tem variante permanente (i18n: desc + desc_permanent).
local HAS_PERMANENT_DESC = {
    thorn = true, lifesteal = true, regen = true, bleed = true, retain_armor = true,
}

-- Ordem canônica: pill não dança de lugar entre frames.
local ORDER = {
    "strength", "dexterity", "focus",
    "thorn", "lifesteal", "regen", "bleed", "retain_armor",
}
local ORDER_INDEX = {}
for i, name in ipairs(ORDER) do ORDER_INDEX[name] = i end

function PlayerBuffPills:new()
    local instance = setmetatable({}, PlayerBuffPills)
    instance.animTime = 0
    return instance
end

function PlayerBuffPills:update(dt)
    self.animTime = self.animTime + (dt or 0)
end

-- Coleta a lista unificada de estados visíveis do player.
-- Exposta (não-local) porque o teste tools/test_status_pills.lua audita esta
-- lista sem desenhar nada.
function PlayerBuffPills.collect(player, game)
    if not player then return {} end
    local byName, order = {}, {}

    local function entry(name)
        local e = byName[name]
        if not e then
            e = { name = name, stacks = 0, duration = 0, showStacks = true }
            byName[name] = e
            order[#order + 1] = e
        end
        return e
    end

    if (player.strength or 0) > 0 then
        entry("strength").stacks = player.strength
    end
    if (player.dexterity or 0) > 0 then
        entry("dexterity").stacks = player.dexterity
    end

    -- Buffs nomeados do player (focus, thorn de carta, o que vier).
    for _, b in ipairs(player.buffs or {}) do
        local e = entry(b.name)
        e.stacks = e.stacks + (b.stacks or 1)
        local d = b.duration or 1
        if d > 0 and d < PERMANENT_THRESHOLD then
            e.duration = math.max(e.duration, d)
            e.timed = true
        end
    end

    -- Derivados dos coringas ATIVOS (jokerSlots = só os ativos; bancada não
    -- conta, ver memory/jokers_and_hand_layout.md).
    for _, joker in ipairs((game and game.jokerSlots) or {}) do
        for _, eff in ipairs(joker.effects or {}) do
            local pill = JOKER_DERIVED[eff.type]
            if pill then
                local e = entry(pill)
                e.stacks = e.stacks + (eff.value or 0)
            end
        end
    end

    for _, e in ipairs(order) do
        if HAS_PERMANENT_DESC[e.name] and not e.timed then
            e.variant = "permanent"
        end
        -- Bloqueio Retido é liga/desliga: número nenhum a mostrar.
        if e.name == "retain_armor" then
            e.showStacks = false
            e.stacks = 1
        end
        if e.duration <= 0 then e.duration = 1 end
    end

    table.sort(order, function(a, b)
        local ia = ORDER_INDEX[a.name] or (#ORDER + 1)
        local ib = ORDER_INDEX[b.name] or (#ORDER + 1)
        if ia ~= ib then return ia < ib end
        return a.name < b.name
    end)

    return order
end

-- Topo da banda de pills (o OrbRow empilha a partir daqui).
function PlayerBuffPills.getBandTop(panelY)
    return math.floor(panelY - PlayerBuffPills.BAND_GAP - PlayerBuffPills.BAND_HEIGHT)
end

-- Largura disponível pra banda: do painel até a metade da tela. O resto da
-- faixa é do ManaOrb (canto inf-direito) e das cartas da mão.
local function availableWidth(panelX)
    return math.max(120, love.graphics.getWidth() * 0.5 - panelX)
end

-- Tamanho efetivo das pills neste frame (encolhe só quando não cabe).
function PlayerBuffPills.getPillSize(count, panelX)
    return StatusPill.fitSize(count, availableWidth(panelX), BADGE_SIZE, BADGE_SPACING)
end

function PlayerBuffPills:draw(player, panelX, panelY, panelW, game)
    if not player then return end
    local buffs = PlayerBuffPills.collect(player, game)
    if #buffs == 0 then return end

    local startX = math.floor(panelX)
    local size = PlayerBuffPills.getPillSize(#buffs, startX)
    -- Pill encolhida fica ancorada no RODAPÉ da banda: o TOPO da banda é fixo,
    -- que é o que o OrbRow usa pra não colidir.
    local y = PlayerBuffPills.getBandTop(panelY) + (PlayerBuffPills.BAND_HEIGHT - size)

    StatusPill.drawRow(buffs, startX, y, {
        size = size,
        spacing = BADGE_SPACING,
        animTime = self.animTime,
        pulseHalo = true,           -- buffs pulsam pra chamar atenção
        showStacksAlways = true,    -- valor numérico é a info principal (Força 3)
    })
end

return PlayerBuffPills
