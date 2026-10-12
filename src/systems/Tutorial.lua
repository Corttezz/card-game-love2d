-- src/systems/Tutorial.lua
-- ONBOARDING (Out/2026): dicas contextuais, UMA vez por perfil, ancoradas no
-- objeto que explicam.
--
-- Auditoria de jogabilidade: nada explicava mana, intent, "Jogar Cartas" ×
-- "Encerrar Turno", combos, coringas ativos × bancada, orbes, Bloqueio que
-- zera, o grimório de 2 cartas. Este módulo é o professor — leve, no estilo
-- StS/Balatro: a dica aparece quando o assunto aparece pela PRIMEIRA vez, em
-- cima da coisa, e some com um clique.
--
-- Peças:
--   CATALOGO (TIPS)   ordem = prioridade; cada dica diz em que estado vale,
--                     quando dispara (`when`) e onde ancora (`anchor`).
--   ÂNCORAS           quem desenha o objeto reporta o retângulo no draw
--                     (`Tutorial.anchor(id, x, y, w, h)`, convertido pra pixels
--                     reais com transformPoint — escala de UI não importa).
--   OVERLAY           `Tutorial.overlay` vai no InputFocus como o modal mais
--                     alto: enquanto a placa está na tela ela é dona do
--                     clique/teclado/pad (A/Enter/Espaço/clique fecham; Esc/B
--                     também). O combate congela por baixo (freezesCombat).
--   PERSISTÊNCIA      ProfileStats.tipsSeen (SaveManager.writeFile); liga/
--                     desliga em Configurações → Jogo (gameSettings.tipsEnabled).
--
-- Regras de ouro:
--   * dica só aparece com o combate PARADO (vez do jogador, nada na fila);
--   * uma de cada vez, com respiro entre elas, depois de a condição se manter
--     por um instante (nada de piscar numa condição de um quadro);
--   * sem âncora visível, a dica ESPERA — nunca aparece apontando pro nada.

local Tutorial = {}

local TipPlate = require("src.ui.TipPlate")

local STABLE_FOR = 0.35   -- condição precisa valer por este tempo (s)
local GAP_AFTER = 0.30    -- respiro depois de fechar uma dica (s)
local ANCHOR_TTL = 0.25   -- âncora reportada há mais que isto = sumiu

local anchors = {}        -- id -> { x, y, w, h, t }
local screens = {}        -- telas de estado (main.lua: setScreens)
local active = nil        -- { id, def, shownAt }
local pendingId, pendingSince = nil, 0
local cooldown = 0
local forceTest = false   -- testes: ignora gameSettings/headless

-- ===== Âncoras =====
function Tutorial.anchor(id, x, y, w, h)
    if not (x and y and w and h) then return end
    local g = love.graphics
    local x1, y1 = g.transformPoint(x, y)
    local x2, y2 = g.transformPoint(x + w, y + h)
    anchors[id] = { x = math.min(x1, x2), y = math.min(y1, y2),
        w = math.abs(x2 - x1), h = math.abs(y2 - y1), t = love.timer.getTime() }
end

function Tutorial.anchorRect(id)
    local a = anchors[id]
    if not a then return nil end
    if love.timer.getTime() - a.t > ANCHOR_TTL then return nil end
    if a.w < 2 or a.h < 2 then return nil end
    return a
end

function Tutorial.setScreens(t) screens = t or {} end

-- ===== Estado do jogo (predicados) =====
local function realDims()
    local ok, UiScale = pcall(require, "src.ui.UiScale")
    if ok and UiScale.realDimensions then return UiScale.realDimensions() end
    return love.graphics.getWidth(), love.graphics.getHeight()
end

local function uiK()
    local ok, UiScale = pcall(require, "src.ui.UiScale")
    if ok and UiScale.k then return UiScale.k() end
    return 1
end

-- Combate parado na vez do jogador: a única hora de ensinar.
local function battleIdle(game)
    if not game or game.gameState ~= "playing" then return false end
    if game.turn ~= "player" or game._enemyActing then return false end
    if not (game.enemy and game.enemy:isAlive() and game.player and game.player:isAlive()) then
        return false
    end
    local cs = game.combatAnimationSystem
    if cs and cs.isBlocking and cs:isBlocking() then return false end
    return #(game.hand or {}) > 0
end

-- A mão tem um combo montável? (mesma detecção do turno, sobre a mão toda)
local function handHasCombo(game)
    local ok, res = pcall(function()
        local TagSystem = require("src.systems.TagSystem")
        local ComboSystem = require("src.systems.ComboSystem")
        local hand = game.hand or {}
        local ctx = { tagCounts = TagSystem.countAllTags(hand), allSelectedCards = hand,
            snapshot = hand }
        return #ComboSystem.detect(ctx) > 0
    end)
    return ok and res
end

local function run(game)
    return game and game.runManager and game.runManager.currentRun
end

-- União dos retângulos de uma lista de botões/slots de uma tela ADOTADA pelo
-- UiScale (coordenadas virtuais) → pixels reais. É o OBJETO que a dica explica
-- (as opções do evento, as escolhas do acampamento, as cartas da vitrine).
local function unionVirtual(list)
    local x1, y1, x2, y2
    for _, b in pairs(list or {}) do
        local w, h = b.w or b.width, b.h or b.height
        if b.x and b.y and w and h and b.visible ~= false then
            x1 = math.min(x1 or b.x, b.x); y1 = math.min(y1 or b.y, b.y)
            x2 = math.max(x2 or (b.x + w), b.x + w); y2 = math.max(y2 or (b.y + h), b.y + h)
        end
    end
    if not x1 then return nil end
    local k = uiK()
    return { x = x1 * k, y = y1 * k, w = (x2 - x1) * k, h = (y2 - y1) * k }
end

local function screenOptions(name, field)
    return function()
        local sc = screens[name]
        if not (sc and sc.visible) then return nil end
        return unionVirtual(sc[field])
    end
end

local function forkRect()
    local ok, WorldRoad = pcall(require, "src.ui.WorldRoad")
    if not ok or not WorldRoad.isForkActive or not WorldRoad.isForkActive() then return nil end
    local f = WorldRoad._fork
    local x1, y1, x2, y2
    for _, b in pairs((f and f.markBoxes) or {}) do
        if b.x1 then
            x1 = math.min(x1 or b.x1, b.x1); y1 = math.min(y1 or b.y1, b.y1)
            x2 = math.max(x2 or b.x2, b.x2); y2 = math.max(y2 or b.y2, b.y2)
        end
    end
    if not x1 then return nil end
    return { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
end

local function enemyRect()
    local ok, ER = pcall(require, "src.ui.EnemyRenderer")
    if not ok or not ER.getLastPos then return nil end
    local x, y = ER.getLastPos()
    if not x then return nil end
    local k = uiK()
    return { x = x - 70 * k, y = y - 90 * k, w = 140 * k, h = 160 * k }
end

-- ===== Catálogo (ordem = prioridade) =====
-- state: currentState do main.lua em que a dica vale.
-- when(game, sc): condição de disparo. anchor(): retângulo real ou nil.
local function A(id) return function() return Tutorial.anchorRect(id) end end

Tutorial.TIPS = {
    -- Primeira batalha, em sequência (cada uma depende da anterior ter sido vista)
    { id = "battle_hand", state = "playing",
      when = function(g) return battleIdle(g) end, anchor = A("hand") },
    { id = "battle_mana", state = "playing", after = "battle_hand",
      when = function(g) return battleIdle(g) end, anchor = A("mana") },
    { id = "battle_intent", state = "playing", after = "battle_mana",
      when = function(g) return battleIdle(g) end, anchor = A("intent"),
      prefer = { "right", "left", "above", "below" } },   -- embaixo: a barra de vida
    { id = "battle_play", state = "playing", after = "battle_intent",
      when = function(g) return battleIdle(g) and #(g.selectedCards or {}) > 0 end,
      anchor = A("play") },
    { id = "battle_end_turn", state = "playing", after = "battle_play",
      when = function(g)
          return battleIdle(g) and #(g.selectedCards or {}) == 0
              and (g.player.mana or 0) < (g.player.maxMana or 3)
      end, anchor = A("end_turn") },
    -- Assuntos que chegam depois
    { id = "block", state = "playing", after = "battle_hand",
      when = function(g) return battleIdle(g) and (g.player.armor or 0) > 0 end,
      anchor = A("player_panel") },
    { id = "combo", state = "playing", after = "battle_hand",
      when = function(g) return battleIdle(g) and handHasCombo(g) end, anchor = A("hand") },
    { id = "orbs", state = "playing", after = "battle_hand",
      when = function(g) return battleIdle(g) and #((g.player and g.player.orbs) or {}) > 0 end,
      anchor = A("orbs") },
    { id = "jokers", state = "playing", after = "battle_hand",
      when = function(g)
          local r = run(g)
          return battleIdle(g) and r and #(r.jokers or {}) > 0
      end, anchor = A("jokers") },
    { id = "boss", state = "playing", after = "battle_hand",
      when = function(g)
          local r = run(g)
          return battleIdle(g) and r and r.currentNode and r.currentNode.type == "boss"
      end, anchor = enemyRect },
    -- Telas da jornada
    { id = "rewards", state = "cardReward",
      when = function(_, sc) return sc.cardReward and sc.cardReward.visible
          and sc.cardReward.mode == "rewards" end,
      anchor = screenOptions("cardReward", "cardPositions"), prefer = { "below", "right", "left", "above" } },
    { id = "shop", state = "cardReward",
      when = function(_, sc) return sc.cardReward and sc.cardReward.visible
          and sc.cardReward.mode == "shop" end,
      anchor = screenOptions("cardReward", "cardPositions"), prefer = { "below", "right", "left", "above" } },
    { id = "rest", state = "rest", when = function() return true end,
      anchor = screenOptions("rest", "buttons"), prefer = { "below", "right", "left", "above" } },
    { id = "event", state = "event", when = function() return true end,
      anchor = screenOptions("event", "buttons"), prefer = { "below", "right", "left", "above" } },
    { id = "fork", state = "mapSelection", when = function() return forkRect() ~= nil end,
      anchor = forkRect },
}

local function byId(id)
    for _, d in ipairs(Tutorial.TIPS) do if d.id == id then return d end end
end

-- ===== Persistência / ligar-desligar =====
local function PS() return require("engine.ProfileStats") end

function Tutorial.enabled()
    if forceTest then return true end
    if _G.HEADLESS_TOOL and not Tutorial._allowHeadless then return false end
    local gs = _G.gameSettings
    return not (gs and gs.tipsEnabled == false)
end

function Tutorial.isSeen(id) return PS().isTipSeen(id) end

function Tutorial.resetAll()
    active, pendingId, cooldown = nil, nil, 0
    return PS().resetTips()
end

-- ===== Ciclo =====
local function eligible(def, state, game)
    if def.state ~= state then return false end
    if Tutorial.isSeen(def.id) then return false end
    if def.after and not Tutorial.isSeen(def.after) then return false end
    local ok, res = pcall(def.when, game, screens)
    if not ok then
        print("[Tutorial] condicao da dica '" .. def.id .. "' falhou: " .. tostring(res))
        return false
    end
    return res and def.anchor() ~= nil
end

-- Chamado todo frame pelo main.lua (love.update).
function Tutorial.update(dt, state, game)
    if active then
        -- Âncora sumiu (troca de tela, morte): a dica fecha SEM marcar vista.
        if active.def.state ~= state or not active.def.anchor() then
            active = nil
            cooldown = GAP_AFTER
        end
        return
    end
    if not Tutorial.enabled() then pendingId = nil return end
    if cooldown > 0 then cooldown = cooldown - dt return end
    -- Outro modal aberto (pausa, deck, confirmação): espera.
    local IF = require("src.ui.InputFocus")
    local cap = IF.captor and IF.captor()
    if cap and cap ~= Tutorial.overlay then pendingId = nil return end

    local found
    for _, def in ipairs(Tutorial.TIPS) do
        if eligible(def, state, game) then found = def break end
    end
    if not found then pendingId = nil return end
    if pendingId ~= found.id then
        pendingId, pendingSince = found.id, 0
        return
    end
    pendingSince = pendingSince + dt
    if pendingSince >= STABLE_FOR then
        active = { id = found.id, def = found, shownAt = love.timer.getTime() }
        pendingId = nil
        pcall(function() require("src.systems.Sfx").play("menuOpen") end)
    end
end

function Tutorial.activeId() return active and active.id end

-- Fecha a dica visível e marca como vista.
function Tutorial.dismiss()
    if not active then return false end
    PS().markTipSeen(active.id)
    active = nil
    cooldown = GAP_AFTER
    return true
end

-- Testes/tools: mostra uma dica direto (sem esperar a condição).
function Tutorial._show(id)
    local def = byId(id)
    if not def then print("[Tutorial] dica desconhecida: " .. tostring(id)) return false end
    -- já "assentada" (sem o fade de entrada): captura/teste no 1º quadro
    active = { id = id, def = def, shownAt = love.timer.getTime() - 1 }
    return true
end
function Tutorial._forceForTests(b) forceTest = b and true or false end
function Tutorial._reset()
    active, pendingId, pendingSince, cooldown = nil, nil, 0, 0
    anchors = {}
end

-- Textos da dica (i18n tutorial.tips.<id>.title/.body) + rótulo de fechar.
function Tutorial.texts(id)
    local I18n = require("src.i18n.I18n")
    local title = I18n.t("tutorial.tips." .. id .. ".title", nil, id)
    local body = I18n.t("tutorial.tips." .. id .. ".body", nil, "")
    local dev = "mouse"
    local okNC, NC = pcall(require, "src.ui.NavCursor")
    if okNC and NC.device then dev = NC.device()
    elseif not Tutorial._navWarned then
        Tutorial._navWarned = true
        print("[Tutorial] AVISO: src.ui.NavCursor indisponível — rótulo de fechar fica no do mouse")
    end
    local hint = I18n.t("tutorial.dismiss_" .. (dev == "pad" and "pad" or "mouse"), nil, "OK")
    return title, body, hint
end

-- Zonas que a placa não cobre: a TopBar inteira.
function Tutorial.avoidZones()
    local W = realDims()
    return { { x = 0, y = 0, w = W, h = 80 * uiK() } }
end

-- Layout da dica ativa (puro, pros testes).
function Tutorial.layoutFor(id, anchor)
    local W, H = realDims()
    local k = uiK()
    local title, body, hint = Tutorial.texts(id)
    local size = TipPlate.measure(title, body, hint, k, W)
    local def = byId(id)
    return TipPlate.layout(anchor, size, W, H, k, Tutorial.avoidZones(), def and def.prefer),
        title, hint
end

-- Chamado pelo main.lua no fim do love.draw (pixels reais, fora do UiScale).
function Tutorial.draw()
    if not active then return end
    local anchor = active.def.anchor()
    if not anchor then return end
    local L, title, hint = Tutorial.layoutFor(active.id, anchor)
    local age = love.timer.getTime() - active.shownAt
    local alpha = math.min(1, age / 0.18)
    TipPlate.draw(L, title, hint, alpha)
end

-- ===== Overlay do InputFocus =====
-- Modal mais alto do registro: dono do clique/teclado/pad enquanto visível.
local overlay = { ownsNavigation = true }
function overlay:isVisible() return active ~= nil end
function overlay:hide() active = nil end
function overlay:keypressed(key)
    if key == "return" or key == "kpenter" or key == "space" or key == "escape" then
        Tutorial.dismiss()
    end
end
function overlay:mousepressed() Tutorial.dismiss() end
function overlay:mousereleased() end
Tutorial.overlay = overlay

return Tutorial
