-- tools/preview_battle_hud.lua
-- Renderiza um frame simulado de batalha pra validar o novo HUD visual.
-- Usar: love . preview_battle_hud → saída em ~/.local/share/love/card-game/preview_battle_hud.png
--
-- MODOS:
--   (sem arg) HUD em repouso    →  preview_battle_hud.png
--   cap       Bloqueio no teto  →  preview_battle_hud.png
--   orb       CANALIZAÇÃO em voo + orbe SAINDO por overflow, no meio da
--             animação → preview_battle_hud_orb.png. É o único caminho visual
--             pro pedido "deixar claro se está dando dano ou canalizando":
--             mostra o cometa do elemento ENTRANDO na fileira e o fantasma do
--             orbe expulso SAINDO dela, ao mesmo tempo, para comparar os dois
--             sentidos num quadro só.
--   pulse     ONDE cada pulso de fim de turno ATERRISSA →
--             preview_battle_hud_pulse.png. COMPOSIÇÃO deliberada: no jogo os
--             três pulsos são beats sequenciais (0,40s cada), aqui os três
--             caem no mesmo quadro de propósito, porque o que se valida é o
--             LUGAR — raio no inimigo, gelo no painel do herói, sombra no
--             próprio orbe. Um quadro por elemento não deixaria comparar.

local M = {}

function M.run()
    require("src.ui.PixelCanvas").enableNearest()
    local I18n = require("src.i18n.I18n")
    I18n.init()

    local Game = require("src.core.Game")
    local HudManager = require("src.ui.HudManager")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local EnemyHud = require("src.ui.EnemyHud")

    -- Setup fake game state
    local game = Game:new()
    game.selectedClass = "mage"  -- chip da passiva + OrbRow (fileira de orbes)
    game.player.health = 48
    game.player.maxHealth = 80
    game.player.mana = 2
    game.player.maxMana = 3
    -- Bloqueio: 7 por padrão. `love . preview_battle_hud cap` sobe pro TETO,
    -- que é o único jeito de ver o "/30" e o halo âmbar do cap (o indicador
    -- só aparece a partir de 70% — abaixo disso ele seria ruído).
    local capMode = _G.PREVIEW_HUD_CAP
    game.player.armor = capMode and (game.player.maxArmor or 30) or 7
    game.player.strength = 3
    game.player.dexterity = 2
    game.player.buffs = {
        { name = "focus", stacks = 2, duration = 3 },
        -- Reflexo de CARTA (Barreira de Fogo & cia): buff com duração.
        { name = "thorn", stacks = 7, duration = 1 },
    }
    -- Coringas ATIVOS: estados contínuos que vivem no joker e não no player.
    -- O PlayerBuffPills deriva pill+tooltip deles (regen/sangria/retenção/
    -- roubo de vida) — antes eram completamente invisíveis.
    game.jokerSlots = {
        { id = "preview_regen",  name = "Regen",  effects = { { type = "regen_per_turn", value = 2 } } },
        { id = "preview_bleed",  name = "Sangria", effects = { { type = "damage_per_turn", value = 1 } } },
        { id = "preview_bastion", name = "Bastiao", effects = { { type = "retain_armor" } } },
        { id = "preview_vampire", name = "Vampiro", effects = { { type = "on_attack_heal", value = 3 } } },
    }
    -- OrbRow (Jul/2026): 2 orbes + 1 slot vazio — valida numero com Foco,
    -- marcador FIFO e o aro apagado do cap.
    game.player.orbs = {
        { type = "lightning", value = 4 },
        { type = "dark", value = 5 },
    }
    -- Modo `orb`: a fileira CHEIA é o estado que produz overflow — é nele que
    -- o jogador perde o fio ("um orbe sumiu e eu não vi por quê").
    local orbMode = _G.PREVIEW_HUD_ORB
    local pulseMode = _G.PREVIEW_HUD_PULSE
    -- Modo `orbs`: os CINCO tipos lado a lado, no tamanho de uso e sobre o
    -- fundo real. E o unico jeito de saber se eles se distinguem ENTRE SI --
    -- um de cada vez, ampliado, engana (ui_layout_invariants / doutrina §5).
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
        -- Um de cada destino, pra comparar os três lugares no mesmo quadro.
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
        -- QUEIMADURA ao lado do VENENO de proposito: os dois sao DoT e o
        -- defeito que criou este status foi justamente confundi-los. Validar
        -- lado a lado e a unica forma de saber se a distincao funciona
        -- (doutrina de defeitos, 5 e 7).
        { name = "burn",       stacks = 4, duration = 2 },
        { name = "weak",       stacks = 1, duration = 2 },
        { name = "vulnerable", stacks = 1, duration = 1 },
        -- FURIA e ENFURECIDO junto de propósito: com VULNERAVEL e QUEIMADURA
        -- sao QUATRO pills laranja na mesma row do inimigo. Se elas competirem,
        -- e aqui que se ve -- e o remedio e FORMA, nao matiz (laranja e a cor
        -- certa pra fogo e pra raiva; clarear troca identidade por metrica).
        { name = "fury",       stacks = 2, duration = 9 },
        { name = "enraged",    stacks = 1, duration = 9 },
    }
    -- Estados do inimigo que eram invisíveis: armadura (o dano sumia sem
    -- explicação) e o modo agressivo abaixo de 30% de vida (×1.5 de dano).
    game.enemy.armor = 9
    game.enemy.attackPattern = "aggressive"

    local w, h = 1024, 768
    local canvas = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.08, 0.05, 0.04, 1)

    -- Fundo tipo arena (retângulos simples pra simular cenário)
    love.graphics.setColor(0.14, 0.10, 0.06, 1)
    love.graphics.rectangle("fill", 0, 0, w, h * 0.55)
    love.graphics.setColor(0.06, 0.04, 0.03, 1)
    love.graphics.rectangle("fill", 0, h * 0.55, w, h * 0.45)

    -- Inimigo (sprite pode não existir; bbox cai no fallback)
    local enemyCx = math.floor(w / 2)
    local enemyCy = math.floor(h * 0.55)
    local bbox = EnemyRenderer.draw(game, enemyCx, enemyCy)
    -- Se bbox veio false (sem sprite), desenha um placeholder quadrado pra visualizar
    if type(bbox) ~= "table" then
        love.graphics.setColor(0.30, 0.15, 0.20, 0.85)
        love.graphics.rectangle("fill", enemyCx - 60, enemyCy - 160, 120, 160)
        love.graphics.setColor(0.1, 0.05, 0.05, 1)
        love.graphics.rectangle("line", enemyCx - 60, enemyCy - 160, 120, 160)
        bbox = { cx = enemyCx, topY = enemyCy - 160, bottomY = enemyCy, width = 120, height = 160 }
    end
    EnemyHud.draw(game, bbox, enemyCx, enemyCy)

    -- Mao FALSIFICADA com uma carta de Evocar sob o mouse: exercita o caminho
    -- REAL do preview (OrbRow.update le game.hand e acende previewMode), que e
    -- onde os numeros viram valor de EVOKE e o glifo da sombra vira DANO.
    if _G.PREVIEW_HUD_ORBS_EVOKE then
        game.hand = { { id = "fake_evoke", isHovered = true,
            effects = { { type = "evoke_all_orbs" } } } }
    end

    -- HUD player panel + mana orb
    local hud = HudManager:new()
    hud:update(0.016)

    -- Hover FALSIFICADO sobre a pill de Espinhos: exercita o caminho REAL
    -- (StatusPill.drawRow detecta o hover → StatusTooltip.show → draw), então
    -- a captura também prova que o tooltip do estado novo resolve no i18n.
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

    -- OrbRow.update ZERA previewMode e so o preenche se receber `game` -- e o
    -- hud:update acima roda sem ele. Entao o preview tem que ser armado DEPOIS,
    -- imediatamente antes do draw (mesma ordem do jogo real, onde a cena passa
    -- o game nos dois).
    if _G.PREVIEW_HUD_ORBS_EVOKE then
        require("src.ui.OrbRow").update(0.016, game)
    end

    hud:draw(game)
    StatusTooltip.draw()

    -- ===== Modo `orb`: captura a ANIMAÇÃO, não o repouso =====
    -- O primeiro hud:draw acima existe pra popular OrbRow.slotPos (as
    -- notificações ancoram no slot e sem posição não desenham nada). Só então
    -- disparamos os dois acontecimentos e adiantamos o relógio até o meio do
    -- voo, para o quadro mostrar o gesto e não o resultado.
    if orbMode then
        local OrbRow = require("src.ui.OrbRow")
        local FloatingText = require("src.ui.FloatingText")
        -- 1) o orbe mais antigo é EXPULSO (fileira cheia abrindo vaga)
        OrbRow.notifyEvoke(1, { type = "ice", value = 4 }, "overflow")
        table.remove(game.player.orbs, 1)
        -- 2) o novo orbe VIAJA do feitiço até o slot livre
        OrbRow.notifyChannel(3, { type = "fire", value = 4 })
        for _ = 1, 5 do                    -- ~0.17s: cometa no meio do caminho
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

    -- ===== Modo `pulse`: onde cada pulso deixa marca =====
    -- O primeiro hud:draw acima existe pra popular OrbRow.slotPos (o burst de
    -- sombra ancora no orbe). Disparamos as três aterrissagens direto pelo
    -- EffectSystem (mesma função que o beat chama) e adiantamos as partículas.
    if pulseMode then
        local EffectSystem = require("src.systems.EffectSystem")
        local ParticlesManager = require("engine.ParticlesManager")
        local FloatingText = require("src.ui.FloatingText")
        local OrbRow = require("src.ui.OrbRow")
        ParticlesManager.clear()
        -- Âncora do inimigo FALSIFICADA (mesmo idioma do hover falso de mouse
        -- acima): o estado fake não tem sprite, então EnemyRenderer.getLastPos
        -- devolve nil e o burst no inimigo — justamente o que se quer ver —
        -- nunca sairia. Emprestamos o centro que a própria ferramenta usou pro
        -- placeholder, e o caminho REAL de landPulse roda inteiro.
        -- As particulas sao pequenas (1-3px) de proposito: e a mesma linguagem
        -- do impacto de carta. Entao a ferramenta tambem IMPRIME onde cada
        -- burst nasceu — a captura confirma o gesto, o texto confirma o LUGAR.
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

        EffectSystem.previewPulseLanding("lightning", 1)   -- -> inimigo
        EffectSystem.previewPulseLanding("ice", 2)         -- -> painel do herói
        EffectSystem.previewPulseLanding("dark", 3)        -- -> o próprio orbe
        ER.getLastPos = realLastPos
        CF.burst = realBurst
        print("[preview] emissores de particula:", ParticlesManager.activeCount())
        OrbRow.notifyPulse(1, "-3", "damage")
        OrbRow.notifyPulse(2, "+3", "armor")
        OrbRow.notifyPulse(3, "+2", "grow")
        for _ = 1, 9 do                    -- ~0.3s: partículas espalhadas
            ParticlesManager.update(1 / 30)
            OrbRow.update(1 / 30, game)
            FloatingText.update(1 / 30)
        end
        for _, e in ipairs(emitted) do
            print(string.format("[preview] burst %-10s em (%d,%d) com %d particulas",
                e.theme, e.x, e.y, e.inst and #e.inst.particles or -1))
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

    -- Salva PNG
    local img = canvas:newImageData()
    local out = (_G.PREVIEW_HUD_ORBS and _G.PREVIEW_HUD_ORBS_EVOKE)
            and "preview_battle_hud_orbs_evoke.png"
        or _G.PREVIEW_HUD_ORBS and "preview_battle_hud_orbs.png"
        or orbMode and "preview_battle_hud_orb.png"
        or pulseMode and "preview_battle_hud_pulse.png"
        or "preview_battle_hud.png"
    img:encode("png", out)
    print("[preview] salvou", love.filesystem.getSaveDirectory() .. "/" .. out)
end

return M
