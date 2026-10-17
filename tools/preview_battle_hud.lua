local M = {}

function M.run()
    require("src.ui.PixelCanvas").enableNearest()
    local I18n = require("src.i18n.I18n")
    I18n.init()

    local Game = require("src.core.Game")
    local HudManager = require("src.ui.HudManager")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local EnemyHud = require("src.ui.EnemyHud")

    local game = Game:new()
    game.selectedClass = "mage"
    game.player.health = 48
    game.player.maxHealth = 80
    game.player.mana = 2
    game.player.maxMana = 3
    local capMode = _G.PREVIEW_HUD_CAP
    game.player.armor = capMode and (game.player.maxArmor or 30) or 7
    game.player.strength = 3
    game.player.dexterity = 2
    game.player.buffs = {
        { name = "focus", stacks = 2, duration = 3 },
        { name = "thorn", stacks = 7, duration = 1 },
    }
    game.jokerSlots = {
        { id = "preview_regen",  name = "Regen",  effects = { { type = "regen_per_turn", value = 2 } } },
        { id = "preview_bleed",  name = "Sangria", effects = { { type = "damage_per_turn", value = 1 } } },
        { id = "preview_bastion", name = "Bastiao", effects = { { type = "retain_armor" } } },
        { id = "preview_vampire", name = "Vampiro", effects = { { type = "on_attack_heal", value = 3 } } },
    }
    game.player.orbs = {
        { type = "lightning", value = 4 },
        { type = "dark", value = 5 },
    }
    local orbMode = _G.PREVIEW_HUD_ORB
    local pulseMode = _G.PREVIEW_HUD_PULSE
    if _G.PREVIEW_HUD_ORBS then
        game.player.orbSlots = 6
        game.player.orbs = {
            { type = "lightning", value = 4 },
            { type = "ice",       value = 4 },
            { type = "fire",      value = 6 },
            { type = "dark",      value = 5 },
            { type = "holy",      value = 6 },
        }
    end
    if pulseMode then
        game.player.orbs = {
            { type = "lightning", value = 4 },
            { type = "ice", value = 4 },
            { type = "dark", value = 5 },
        }
    end
    if orbMode then
        game.player.orbs = {
            { type = "ice", value = 4 },
            { type = "lightning", value = 4 },
            { type = "dark", value = 5 },
        }
    end
    game.enemy.health = 34
    game.enemy.maxHealth = 55
    game.enemy.damage = 12
    game.enemy.statusEffects = {
        { name = "poison",     stacks = 3, duration = 2 },
        { name = "burn",       stacks = 4, duration = 2 },
        { name = "weak",       stacks = 1, duration = 2 },
        { name = "vulnerable", stacks = 1, duration = 1 },
        { name = "fury",       stacks = 2, duration = 9 },
        { name = "enraged",    stacks = 1, duration = 9 },
    }
    if os.getenv("PREVIEW_HUD_ECLIPSE") == "1" then
        table.insert(game.enemy.statusEffects, { name = "eclipse", stacks = 1, duration = 999 })
    end
    game.enemy.armor = 9
    game.enemy.attackPattern = "aggressive"

    local w, h = 1024, 768
    local canvas = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.08, 0.05, 0.04, 1)

    love.graphics.setColor(0.14, 0.10, 0.06, 1)
    love.graphics.rectangle("fill", 0, 0, w, h * 0.55)
    love.graphics.setColor(0.06, 0.04, 0.03, 1)
    love.graphics.rectangle("fill", 0, h * 0.55, w, h * 0.45)

    local enemyCx = math.floor(w / 2)
    local enemyCy = math.floor(h * 0.55)
    local bbox = EnemyRenderer.draw(game, enemyCx, enemyCy)
    if type(bbox) ~= "table" then
        love.graphics.setColor(0.30, 0.15, 0.20, 0.85)
        love.graphics.rectangle("fill", enemyCx - 60, enemyCy - 160, 120, 160)
        love.graphics.setColor(0.1, 0.05, 0.05, 1)
        love.graphics.rectangle("line", enemyCx - 60, enemyCy - 160, 120, 160)
        bbox = { cx = enemyCx, topY = enemyCy - 160, bottomY = enemyCy, width = 120, height = 160 }
    end
    EnemyHud.draw(game, bbox, enemyCx, enemyCy)

    if _G.PREVIEW_HUD_ORBS_EVOKE then
        game.hand = { { id = "fake_evoke", isHovered = true,
            effects = { { type = "evoke_all_orbs" } } } }
    end

    local hud = HudManager:new()
    hud:update(0.016)

    local PlayerBuffPills = require("src.ui.PlayerBuffPills")
    local StatusTooltip = require("src.ui.StatusTooltip")
    local pills = PlayerBuffPills.collect(game.player, game)
    local hoverIndex = 1
    for i, p in ipairs(pills) do
        if p.name == "thorn" then hoverIndex = i end
    end
    local pillSize = PlayerBuffPills.getPillSize(#pills, hud.playerPanel.x)
    local realMouse = love.mouse.getPosition
    local fakeX = hud.playerPanel.x + (hoverIndex - 1) * (pillSize + 8) + pillSize / 2
    local fakeY = PlayerBuffPills.getBandTop(hud.playerPanel.y) + pillSize / 2
    love.mouse.getPosition = function() return fakeX, fakeY end

    if _G.PREVIEW_HUD_ORBS_EVOKE then
        require("src.ui.OrbRow").update(0.016, game)
    end

    hud:draw(game)
    StatusTooltip.draw()

    if orbMode then
        local OrbRow = require("src.ui.OrbRow")
        local FloatingText = require("src.ui.FloatingText")
        OrbRow.notifyEvoke(1, { type = "ice", value = 4 }, "overflow")
        table.remove(game.player.orbs, 1)
        OrbRow.notifyChannel(3, { type = "fire", value = 4 })
        for _ = 1, 5 do
            OrbRow.update(1 / 30, game)
            FloatingText.update(1 / 30)
        end
        love.graphics.clear(0.08, 0.05, 0.04, 1)
        love.graphics.setColor(0.14, 0.10, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, w, h * 0.55)
        love.graphics.setColor(0.06, 0.04, 0.03, 1)
        love.graphics.rectangle("fill", 0, h * 0.55, w, h * 0.45)
        love.graphics.setColor(1, 1, 1, 1)
        EnemyRenderer.draw(game, enemyCx, enemyCy)
        EnemyHud.draw(game, bbox, enemyCx, enemyCy)
        hud:draw(game)
        FloatingText.draw()
    end

    if _G.PREVIEW_HUD_ORBS_ANIM then
        local OrbRow = require("src.ui.OrbRow")
        for _ = 1, 30 do OrbRow.update(1 / 60, game) end
        love.graphics.clear(0.08, 0.05, 0.04, 1)
        love.graphics.setColor(0.14, 0.10, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, w, h * 0.55)
        love.graphics.setColor(0.06, 0.04, 0.03, 1)
        love.graphics.rectangle("fill", 0, h * 0.55, w, h * 0.45)
        love.graphics.setColor(1, 1, 1, 1)
        EnemyRenderer.draw(game, enemyCx, enemyCy)
        EnemyHud.draw(game, bbox, enemyCx, enemyCy)
        hud:draw(game)
    end

    if pulseMode then
        local EffectSystem = require("src.systems.EffectSystem")
        local ParticlesManager = require("engine.ParticlesManager")
        local FloatingText = require("src.ui.FloatingText")
        local OrbRow = require("src.ui.OrbRow")
        ParticlesManager.clear()
        local CF = require("src.systems.CardFeel")
        local realBurst = CF.burst
        local emitted = {}
        CF.burst = function(theme, x, y, k)
            local inst = realBurst(theme, x, y, k)
            emitted[#emitted + 1] = { theme = theme, x = x, y = y, inst = inst }
            return inst
        end
        local ER = require("src.ui.EnemyRenderer")
        local realLastPos = ER.getLastPos
        ER.getLastPos = function() return enemyCx, enemyCy - 70 end

        EffectSystem.previewPulseLanding("lightning", 1)
        EffectSystem.previewPulseLanding("ice", 2)
        EffectSystem.previewPulseLanding("dark", 3)
        ER.getLastPos = realLastPos
        CF.burst = realBurst
        OrbRow.notifyPulse(1, "-3", "damage")
        OrbRow.notifyPulse(2, "+3", "armor")
        OrbRow.notifyPulse(3, "+2", "grow")
        for _ = 1, 9 do
            ParticlesManager.update(1 / 30)
            OrbRow.update(1 / 30, game)
            FloatingText.update(1 / 30)
        end
        love.graphics.clear(0.08, 0.05, 0.04, 1)
        love.graphics.setColor(0.14, 0.10, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, w, h * 0.55)
        love.graphics.setColor(0.06, 0.04, 0.03, 1)
        love.graphics.rectangle("fill", 0, h * 0.55, w, h * 0.45)
        love.graphics.setColor(1, 1, 1, 1)
        EnemyRenderer.draw(game, enemyCx, enemyCy)
        EnemyHud.draw(game, bbox, enemyCx, enemyCy)
        hud:draw(game)
        ParticlesManager.draw()
        FloatingText.draw()
    end

    love.mouse.getPosition = realMouse

    love.graphics.setCanvas()

    local img = canvas:newImageData()
    local out = (_G.PREVIEW_HUD_ORBS and _G.PREVIEW_HUD_ORBS_EVOKE)
            and "preview_battle_hud_orbs_evoke.png"
        or (_G.PREVIEW_HUD_ORBS and _G.PREVIEW_HUD_ORBS_ANIM)
            and "preview_battle_hud_orbs_anim.png"
        or _G.PREVIEW_HUD_ORBS and "preview_battle_hud_orbs.png"
        or orbMode and "preview_battle_hud_orb.png"
        or pulseMode and "preview_battle_hud_pulse.png"
        or "preview_battle_hud.png"
    img:encode("png", out)
    print("[preview] salvou", love.filesystem.getSaveDirectory() .. "/" .. out)
end

return M
