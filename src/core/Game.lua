local Player = require("src.entities.Player")
local Enemy = require("src.entities.Enemy")
local MessageSystem = require("src.systems.MessageSystem")
local DeckManager = require("src.systems.DeckManager")
local EffectSystem = require("src.systems.EffectSystem")
local RunManager = require("src.systems.RunManager")
local CombatSequence = require("src.systems.CombatSequence")
local CombatBeats = require("src.systems.CombatBeats")
local EconomySystem = require("src.systems.EconomySystem")
local ShopSystem = require("src.systems.ShopSystem")
local TagSystem = require("src.systems.TagSystem")
local ComboSystem = require("src.systems.ComboSystem")
local DamagePreview = require("src.systems.DamagePreview")
local ScoreSystem = require("src.systems.ScoreSystem")
local AchievementSystem = require("src.systems.AchievementSystem")
local UnlockSystem = require("src.systems.UnlockSystem")
local ActSystem = require("src.systems.ActSystem")
local BossMechanics = require("src.systems.BossMechanics")
local Config = require("src.core.Config")
local Sfx = require("src.systems.Sfx")
local Debug = require("src.core.Debug")

local I18nMod = require("src.i18n.I18n")
local function msg(key, vars, fallback)
    return I18nMod.t("messages." .. key, vars, fallback)
end

local Game = {}
Game.__index = Game

Game.DEATH_HOLD = 1.1


function Game:new()
    local instance = setmetatable({}, Game)
    instance.deck = {}
    instance.hand = {}
    instance.selectedCards = {}
    instance.player = Player:new()
    instance.enemy = Enemy:new(Config.Game.ENEMY_BASE_HEALTH, Config.Game.ENEMY_BASE_DAMAGE)
    instance.turn = "player"
    instance.gameState = "menu"
    instance.currentPhase = 1
    instance.jokerSlots = {}
    instance.maxJokerSlots = Config.Game.MAX_JOKER_SLOTS
    instance.score = 0
    instance.messageSystem = MessageSystem:new()
    instance._exhaustedThisBattle = {}
    instance.discard = {}
    instance._deathPauseTimer = 0
    instance._deathHandled = false
    instance._deathStaged = false

    instance.deckManager = DeckManager:new()
    instance.effectSystem = EffectSystem:new()
    instance.runManager = RunManager:new()
    instance.combatAnimationSystem = CombatSequence:new()

    instance.economySystem = EconomySystem:new()
    instance.shopSystem = ShopSystem:new()

    instance.scoreSystem = ScoreSystem:new()

    instance.selectedClass = nil
    instance.isRunMode = false

    return instance
end

function Game:initializeDeck()
    Sfx.play("deckStart")

    if self.isRunMode and self.runManager:hasActiveRun() then
        self.deck = self.runManager:buildPlayableDeck()
    else
        self.deckManager:setCurrentDeck("starter")
        self.deck = self.deckManager:buildCurrentDeckCards()
    end

    self:shuffleDeck()
end

function Game:shuffleDeck()
    local rng = require("src.systems.Rng").get()
    for i = #self.deck, 2, -1 do
        local j = rng:random("misc", i)
        self.deck[i], self.deck[j] = self.deck[j], self.deck[i]
    end
end

function Game:startGame()
    CombatBeats.clear()
    self._enemyActing = false
    self.gameState = "playing"
    self.currentPhase = 1
    self.score = 0
    self.player = Player:new(self.isRunMode and self.selectedClass or nil)
    self.enemy = Enemy:new(Config.Game.ENEMY_BASE_HEALTH, Config.Game.ENEMY_BASE_DAMAGE)
    local EnemyRendererModule = require("src.ui.EnemyRenderer")
    self.enemy.spriteId = EnemyRendererModule.resolveSpriteId(1, "battle")
    self.turn = "player"
    self.hand = {}
    self.selectedCards = {}
    self.jokerSlots = {}
    self.discard = {}
    self._exhaustedThisBattle = {}
    self._deathHandled = false
    self._deathStaged = false
    self._deathPauseTimer = 0
    self._saveDeleted = false
    self._victoryRecorded = false
    self.battleTurn = 0
    self.scoreSystem:reset()
    self.scoreSystem:startBattle()
    self:applyClassBattleStartPassive()

    self.economySystem:resetForNewRun()
    self.economySystem.currentGold = require("src.systems.RunModifiers").startingGold(
        self.isRunMode and self.runManager and self.runManager.currentRun, 10)

    self:syncArmorCap()
    self:syncInterestCap()
    self:initializeDeck()
    self:recomputeMaxJokerSlots()

    self:_syncJokersFromRun()
    self:syncJokerFlags()

    self:promoteInnateCardsToTop()

    for i = 1, Config.Game.INITIAL_HAND_SIZE + self:getShopServiceCount("card_draw_upgrade") do
        self:drawCard((i - 1) * 0.08)
    end
    if not self._resumingRun then self:noteBestiary("seen") end
end

function Game:noteBestiary(kind)
    if not self.isRunMode then return false end
    local run = self.runManager and self.runManager.currentRun
    local e = self.enemy
    if not (run and e) then return false end
    return require("src.systems.Bestiary").onFight(run, e.spriteId, kind)
end

function Game:promoteInnateCardsToTop()
    local innates = {}
    local rest = {}
    for _, c in ipairs(self.deck) do
        if c.innate then
            table.insert(innates, c)
        else
            table.insert(rest, c)
        end
    end
    self.deck = {}
    for _, c in ipairs(innates) do table.insert(self.deck, c) end
    for _, c in ipairs(rest) do table.insert(self.deck, c) end
end

function Game:getDeckOrigin()
    if not love.graphics then return 0, 0 end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    return w * 0.92, h * 0.82
end

function Game:drawCard(staggerDelay)
    if #self.deck == 0 and #self.discard > 0 then
        for _, c in ipairs(self.discard) do
            table.insert(self.deck, c)
        end
        self.discard = {}
        self:shuffleDeck()
        self:promoteInnateCardsToTop()
        Sfx.play("deckStart")
    end
    if #self.deck > 0 then
        local card = table.remove(self.deck, 1)
        if card.cancelDissolveAnim then
            card:cancelDissolveAnim()
        else
            card.dissolve = 0
            card._removed = false
        end
        card._flip = 0
        card.isHovered = false

        local EM = _G.EventManager
        if EM and card.setRenderPos then
            local dx, dy = self:getDeckOrigin()
            card:setRenderPos(dx, dy)
            card.dissolve = 1
            local delay = staggerDelay or 0
            EM.after(delay, function()
                if card.start_materialize then
                    card:start_materialize(nil, true, 0.35)
                else
                    card.dissolve = 0
                end
                local Sfx = require("src.systems.Sfx")
                pcall(Sfx.playWithVariation, "cardDraw", 1.0, 0.15)
            end)
        end

        table.insert(self.hand, card)
    end
end

function Game:drawForTurn()
    self._toxinAppliedThisTurn = false
    self._attacksThisTurn = 0
    self._impetusFiredThisTurn = false
    self._toxinGrowFiredThisTurn = false
    self._jokerThornFiredThisTurn = {}
    self._echoFiredThisTurn = false
    local baseDraw = (Config.Game.CARDS_PER_TURN or 5)
        + self:getShopServiceCount("card_draw_upgrade")
    local sealBonus = self._sealDrawBonus or 0
    self._sealDrawBonus = 0
    local total = baseDraw + sealBonus

    if sealBonus > 0 then
        self:addMessage(msg("blue_seal", { value = sealBonus }), "info")
    end

    for i = 1, total do
        self:drawCard((i - 1) * 0.08)
    end
end

function Game:applyJokerEffects(card, baseValue, turnContext)
    return self.effectSystem:applyJokerEffects(self, card, baseValue, turnContext)
end

function Game:setDeck(deckId)
    self.currentDeckId = deckId
end

function Game:getCurrentDeckInfo()
    return self.deckManager:getDeckInfo(self.currentDeckId)
end

function Game:getAvailableDecks()
    return self.deckManager:getAvailableDecks()
end

function Game:getDeckStats()
    return self.deckManager:getDeckStats(self.currentDeckId)
end

function Game:hasCardInDeck(cardId)
    if self.isRunMode and self.runManager:hasActiveRun() then
        local runDeck = self.runManager:getCurrentDeck()
        for _, id in ipairs(runDeck) do
            if id == cardId then return true end
        end
        return false
    else
        for _, card in ipairs(self.deck) do
            if card.id == cardId then return true end
        end
        return false
    end
end

function Game:startNewRun(classId, opts)
    self.isRunMode = true
    self.selectedClass = classId

    UnlockSystem.ensure()
    self.unlockResult = nil

    local runData = self.runManager:startNewRun(classId, opts)
    require("src.systems.Bestiary").resetRun(runData)

    require("engine.ProfileStats").recordRunStart(classId)
    UnlockSystem.onRunStarted(classId, runData.currentDeck)
    AchievementSystem.onRunStarted(self, classId)

    return runData
end

function Game:addCardToRun(cardId, meta)
    if not self.isRunMode then
        self:addMessage(msg("not_in_run"), "error")
        return false
    end

    UnlockSystem.markDiscovered(cardId)
    AchievementSystem.onCardSeen(self, cardId)

    local cardData = self.deckManager.cardDatabase:getCard(cardId)
    if cardData and cardData.type == "joker" then
        return self:addJokerToRun(cardId, meta)
    end

    local success = self.runManager:addCardToDeck(cardId, meta)

    if success then
        self:synchronizeRunDeck()

        self:shuffleDeck()

        return true
    else
        self:addMessage(msg("card_add_failed"), "error")
        return false
    end
end

function Game:canAcceptJoker()
    return self.isRunMode == true
end

function Game:syncJokerFlags()
    local retain = false
    for _, j in ipairs(self.jokerSlots or {}) do
        for _, e in ipairs(j.effects or {}) do
            if e.type == "retain_armor" then retain = true end
        end
    end
    self.player.retainArmor = retain
end

function Game:addJokerToRun(cardId, meta)
    if not self.isRunMode then
        self:addMessage(msg("not_in_run"), "error")
        return false
    end

    local cardData = self.deckManager.cardDatabase:getCard(cardId)
    if not cardData or cardData.type ~= "joker" then
        Debug.warn("[Game:addJokerToRun] cardId não é joker: " .. tostring(cardId))
        return false
    end

    local _, activated = self.runManager:addJokerToRun(cardId, meta)
    self:rebuildJokerSlots()

    if activated then
        Sfx.play("jokerActivate")
    else
        self:addMessage(msg("joker_benched",
            { name = I18nMod.cardName(cardData) }), "info")
        Sfx.play("cardSelect")
    end
    return true
end

function Game:rebuildJokerSlots()
    self.jokerSlots = {}
    if self.isRunMode and self.runManager:hasActiveRun() then
        local instances = self.runManager:buildJokerInstances()
        for _, inst in ipairs(instances) do
            table.insert(self.jokerSlots, inst)
        end
    end
    self:syncJokerFlags()
end

function Game:setJokerActive(ownedIndex, active)
    if not (self.isRunMode and self.runManager:hasActiveRun()) then
        return false, "no_run"
    end
    local ok, reason = self.runManager:setJokerActive(ownedIndex, active)
    if ok then
        self:rebuildJokerSlots()
        local run = self.runManager.currentRun
        if run and run.stage ~= "battle" and self.checkpointRun then
            self:checkpointRun()
        elseif self.runManager.saveRun then
            self.runManager:saveRun()
        end
    end
    return ok, reason
end

function Game:_syncJokersFromRun()
    if not self.isRunMode or not self.runManager:hasActiveRun() then return end
    self:rebuildJokerSlots()
end

function Game:synchronizeRunDeck()
    if self.isRunMode and self.runManager:hasActiveRun() then
        self.deck = self.runManager:buildPlayableDeck()
    end
end

function Game:removeCardFromRun(cardId)
    if not self.isRunMode then return false end

    return self.runManager:removeCardFromDeck(cardId)
end

function Game:getCurrentRunStats()
    return self.runManager:getCurrentRunStats()
end

function Game:endCurrentRun(victory)
    if not self.isRunMode then return nil end

    local finalStats = self.runManager:endRun(victory)
    self.isRunMode = false
    self.selectedClass = nil

    if self.runManager.deleteSave then self.runManager:deleteSave() end

    return finalStats
end

function Game:isInRunMode()
    return self.isRunMode and self.runManager:hasActiveRun()
end

function Game:getCurrentClassInfo()
    return self.runManager:getCurrentClassInfo()
end

function Game:getAvailableClasses()
    return self.runManager.cardRegistry:getAllClasses()
end

function Game:isCardSelected(card)
    for _, selected in ipairs(self.selectedCards) do
        if selected == card then
            return true
        end
    end
    return false
end

function Game:canPlayCard(card)
    if card.frozen then return false end
    return self.player.mana >= card.cost
end

function Game:selectCard(card)
    local seq = self.combatAnimationSystem
    if seq and (seq.active or (seq.isBlocking and seq:isBlocking())) then
        return false
    end

    if self:isCardSelected(card) then
        for i, selected in ipairs(self.selectedCards) do
            if selected == card then
                table.remove(self.selectedCards, i)
                self.player.mana = self.player.mana + card.cost
                Sfx.playWithVariation("cardSelect", 0.85, 0.10)
                break
            end
        end
    elseif card.frozen then
        local I18n = require("src.i18n.I18n")
        self:addMessage(I18n.t("enemy_kit.msg.card_frozen", nil, "*"), "error")
        if card.juice_up then card:juice_up(0.1, 0.08) end
    else
        if self.player:spendMana(card.cost) then
            table.insert(self.selectedCards, card)

            self:playCardSelectSound()

            if card.juice_up then card:juice_up(0.15, 0.05) end
            if _G.jiggleScreen then _G.jiggleScreen(0.25) end
        else
            self:addMessage(msg("no_mana"), "error")
        end
    end
end

function Game:classPassiveTier()
    local run = self.runManager and self.runManager.currentRun
    local act = (run and run.actNumber) or 1
    return 1 + math.floor((math.max(1, act) - 1) / 2)
end

function Game:applyClassBattleStartPassive()
    if self.player then self.player.frost = 0 end
    self._toxinAppliedThisTurn = false
    self._toxinBonus = 0
    self._jokerThornFiredThisTurn = {}
    self._echoFiredThisTurn = false
    if self.selectedClass == "mage" and self.player and self.player.addOrb then
        self.player:addOrb({ type = "lightning", value = 4 })
        if self.player.addBuff then
            local f0 = self:classPassiveTier() + Game.MAGE_FOCUS_OFFSET
            if f0 > 0 then self.player:addBuff("focus", 99, f0) end
        end
        if love.timer then self._passiveFlashT = love.timer.getTime() end
    end
end

Game.TOXIN_GROWTH = 0

Game.MAGE_FOCUS_OFFSET = -1
Game.ROGUE_POISON_OFFSET = 1

Game.IMPETUS_ATTACKS = 2

function Game:toxinStacks(bonus)
    return math.max(1, self:classPassiveTier() + Game.ROGUE_POISON_OFFSET
        + (bonus or self._toxinBonus or 0))
end

function Game:applyClassTurnPassives(turnContext)
    local cls = self.selectedClass
    if cls ~= "warrior" and cls ~= "rogue" then return end
    local attacks = self._attacksThisTurn or 0
    for _, c in ipairs(turnContext.allSelectedCards or {}) do
        if (c.attack or 0) > 0 then attacks = attacks + 1 end
    end
    self._attacksThisTurn = attacks
    if cls == "rogue" then
        if Game.TOXIN_GROWTH > 0 and attacks >= 2 and not self._toxinGrowFiredThisTurn then
            self._toxinGrowFiredThisTurn = true
            self._toxinBonus = (self._toxinBonus or 0) + Game.TOXIN_GROWTH
            self:addMessage(msg("passive_toxins_grow",
                { n = self:classPassiveTier() + self._toxinBonus }), "success")
            if love.timer then self._passiveFlashT = love.timer.getTime() end
            Sfx.play("comboTrigger", { pitch = 1.1, volume = 0.6 })
        end
        return
    end
    if attacks >= Game.IMPETUS_ATTACKS and not self._impetusFiredThisTurn then
        self._impetusFiredThisTurn = true
        self.player:gainStrength(1)
        if love.timer then self._passiveFlashT = love.timer.getTime() end
        Sfx.play("comboTrigger", { pitch = 1.1, volume = 0.6 })
    end
end

function Game:playSelectedCards()
    if self.combatAnimationSystem and self.combatAnimationSystem.isBlocking
        and self.combatAnimationSystem:isBlocking() then
        return
    end
    if #self.selectedCards == 0 then
        self:addMessage(msg("select_cards"), "info")
        return
    end

    local snapshot = {}
    for _, c in ipairs(self.selectedCards) do table.insert(snapshot, c) end

    local turnContext = {
        allSelectedCards = snapshot,
        tagCounts = TagSystem.countAllTags(snapshot),
        cardsProcessed = {},
        turnNumber = self.turnCount or 0,
        activeCombos = {},
        game = self,
    }
    ComboSystem.detect(turnContext)
    self.scoreSystem:recordTurnCombos(turnContext.activeCombos)
    AchievementSystem.onCardsPlayed(self, turnContext)
    self:applyClassTurnPassives(turnContext)
    ComboSystem.announce(self, turnContext)
    self._currentTurnContext = turnContext

    local EM = _G.EventManager
    local Ev = _G.Event
    for idx, card in ipairs(self.selectedCards) do
        for i, handCard in ipairs(self.hand) do
            if handCard == card then
                table.remove(self.hand, i)
                break
            end
        end
        if EM and Ev and card.juice_up then
            EM.add(Ev:new({
                trigger = "after",
                delay = (idx - 1) * 0.06,
                blocking = false,
                func = function() card:juice_up(0.35, 0.12); return true end,
            }))
        end
    end

    self.combatAnimationSystem:startCombat(
        self.selectedCards,
        function()
            self:onCombatAnimationComplete()
        end,
        function(card, beatSink)
            return self:processCardInCombat(card, turnContext, { beats = beatSink })
        end
    )
end

function Game:getShopServiceCount(id)
    if self.isRunMode and self.runManager and self.runManager.getServiceCount then
        return self.runManager:getServiceCount(id)
    end
    return 0
end

function Game:recomputeMaxJokerSlots()
    self.maxJokerSlots = (Config.Game.MAX_JOKER_SLOTS or 3)
        + self:getShopServiceCount("joker_slot")
    if self.isRunMode and self.runManager and self.runManager.currentRun then
        self.runManager.currentRun.maxJokerSlots = self.maxJokerSlots
        self:rebuildJokerSlots()
    end
end

function Game:processCardInCombat(card, turnContext, opts)
    local sink = opts and opts.beats or nil
    local prevSink = self._beatSink
    self._beatSink = sink
    local result = self:_resolveCardInCombat(card, turnContext, sink)
    self._beatSink = prevSink
    return result
end

function Game:_resolveCardInCombat(card, turnContext, sink)
    local result = {}
    result.beats = sink
    turnContext = turnContext or self._currentTurnContext

    local function computeCardValue()
        local v, steps, entries, echoUsed = DamagePreview.cardValue(self, card,
            turnContext, DamagePreview.liveState(self))
        if echoUsed then self._echoFiredThisTurn = true end
        for _, s in ipairs(steps) do
            if s.kind == "combo" then ComboSystem.raiseBanner(turnContext) break end
        end
        local procs = {}
        for _, e in ipairs(entries) do
            self.effectSystem:notifyJokerProc(self, e.joker, e.label, e.kind, procs)
        end
        result.jokerProcs = procs
        return v
    end

    local function applySealSideEffects()
        if not card.seal then return end
        CombatBeats.step(sink, "seal." .. tostring(card.seal), function()
        if card.seal == "Gold" then
            if self.economySystem and self.economySystem.earnGold then
                self.economySystem:earnGold(3, "seal_gold")
                self:addMessage(msg("gold_seal", { value = 3 }), "gold")
            end
        elseif card.seal == "Purple" then
            if self.player and self.player.addOrb then
                self.player:addOrb({ type = "lightning", value = 1 })
                self:addMessage(msg("purple_seal"), "arcane")
            end
        elseif card.seal == "Blue" then
            self._sealDrawBonus = (self._sealDrawBonus or 0) + 1
        end
        end, "SIDE_EFFECT")
    end

    local function processAdditionalEffects()
        if not card.effects then return end
        for _, effect in ipairs(card.effects) do
            local t = effect.type
            if t ~= "strength_scaling" and t ~= "dexterity_scaling"
                and t ~= "multi_hit" and t ~= "damage_bonus_self" then
                self.effectSystem:processEffectCardStepped(self, effect, false, card)
            end
        end
    end

    if card.type == "attack" then
        if self.enemy.health <= 0 then
            if turnContext then table.insert(turnContext.cardsProcessed, card) end
            if card.exhaust and card.id then
                table.insert(self._exhaustedThisBattle, card.id)
                Sfx.play("cardExhaust")
            end
            if card.type ~= "joker" and not card.exhaust then
                table.insert(self.discard, card)
            end
            return result
        end

        local damage = computeCardValue()

        local landed, resistLvl = self.enemy:takeDamage(damage,
            require("src.systems.Resistances").ofCard(card))
        damage = landed or damage
        result.resist = resistLvl
        AchievementSystem.onCardDamage(self, card, damage)
        do
            local melt = BossMechanics.onPlayerAttack(self, card)
            if melt then
                CombatBeats.step(sink, "player.frost_melt", function()
                    self:_mechanicFx(melt)
                end, "MICRO")
            end
        end

        if self.selectedClass == "rogue" and not self._toxinAppliedThisTurn
            and self.enemy:isAlive() then
            self._toxinAppliedThisTurn = true
            CombatBeats.step(sink, "passive.toxins", function()
                local stacks = self:toxinStacks()
                self.enemy:addStatusEffect({ name = "poison", stacks = stacks, duration = 2 })
                local okCF, CF = pcall(require, "src.systems.CardFeel")
                if okCF then CF.burstAtEnemy("poison", 0.8) end
                if love.timer then self._passiveFlashT = love.timer.getTime() end
            end, "STATUS")
        end

        if resistLvl ~= "immune" then
            local FloatingText = require("src.ui.FloatingText")
            FloatingText.atCard(card, "-" .. tostring(damage), { kind = "damage" })
        end

        self:settleEnemyDamage(sink)

        self.effectSystem:applyTriggerEffects(self, "attack", {
            target = self.enemy, turnContext = turnContext, sourceCard = card,
            procSink = result.jokerProcs, beatSink = sink,
        })
        processAdditionalEffects()
        applySealSideEffects()

        result.damage = damage
    elseif card.type == "defense" then
        local defense = computeCardValue()

        local armorBefore = self.player.armor
        self.player:addArmor(defense)
        local wasted = (armorBefore + defense) - self.player.armor
        if wasted > 0 then
            local I18n = require("src.i18n.I18n")
            self:addMessage(I18n.t("messages.armor_capped",
                { max = self.player.maxArmor, wasted = wasted },
                "Bloqueio no maximo (" .. self.player.maxArmor .. ")! "
                    .. wasted .. " desperdicado"), "warning")
        end
        if self.player.armor >= self.player.maxArmor then
            AchievementSystem.onArmorCapped(self)
        end

        local FloatingText = require("src.ui.FloatingText")
        FloatingText.atCard(card, "+" .. tostring(defense), { kind = "armor" })

        self.effectSystem:applyTriggerEffects(self, "defend", {
            target = self.enemy, turnContext = turnContext, sourceCard = card,
            procSink = result.jokerProcs, beatSink = sink,
        })
        processAdditionalEffects()
        applySealSideEffects()

        result.defense = defense
    elseif card.type == "joker" then
        Debug.warn("[Game] Joker chegou via hand (leak arquitetural): " .. tostring(card.id))
        if self.isRunMode and card.id then
            self:addJokerToRun(card.id, { edition = card.edition, seal = card.seal })
        end
        result.joker = true

    elseif card.type == "effect" then
        if sink and card.effects then
            for _, effect in ipairs(card.effects) do
                self.effectSystem:processEffectCardStepped(self, effect, true, card)
            end
        else
            self._effectSourceCard = card
            card.passive(self)
            self._effectSourceCard = nil
        end
        result.effect = true
    end

    if turnContext then
        table.insert(turnContext.cardsProcessed, card)
    end

    if card.exhaust and card.id then
        table.insert(self._exhaustedThisBattle, card.id)
        Sfx.play("cardExhaust")
    end

    if card.type ~= "joker" and not card.exhaust then
        table.insert(self.discard, card)
    end

    return result
end

function Game:onCombatAnimationComplete()
    local ctx = self._currentTurnContext
    if ctx then
        CombatBeats.push("combo.once_effects", function()
            ComboSystem.applyOnceEffects(self, ctx)
        end, "SIDE_EFFECT")
    end
    self._currentTurnContext = nil

    self.selectedCards = {}

end

function Game:endTurn()
    if self.turn ~= "player" then return end
    if self.combatAnimationSystem and self.combatAnimationSystem.isBlocking
        and self.combatAnimationSystem:isBlocking() then
        self._endTurnQueued = true
        return
    end
    self._endTurnQueued = false
    for i = #self.selectedCards, 1, -1 do
        self:selectCard(self.selectedCards[i])
    end
    self:discardHandEndOfTurn()
    if self.effectSystem and self.effectSystem.orbPassiveTick then
        local pulses = {}
        self.effectSystem:orbPassiveTick(self, pulses)
        if #pulses > 0 then
            CombatBeats.push("turn.orb_pulse_start", nil, "MICRO")
            CombatBeats.pushAll(pulses)
        end
    end
    self._enemyActing = false
    self.turn = "enemy"
end

function Game:discardHandEndOfTurn()
    BossMechanics.thaw(self)
    local kept = {}
    for _, card in ipairs(self.hand) do
        if card.retain then
            table.insert(kept, card)
        else
            table.insert(self.discard, card)
        end
    end
    self.hand = kept
end

function Game:_announceEnrageIfPending(sink)
    local e = self.enemy
    if not e or not e._pendingEnrage then return false end
    e._pendingEnrage = false
    if not e:isAlive() then return false end

    local enemyRef = e
    local body = function()
        if self.enemy ~= enemyRef then return end
        local I18n = require("src.i18n.I18n")
        Sfx.playWithVariation("enemyBuffRoar", 0.88, 0.05)
        if enemyRef.juice_up then enemyRef:juice_up(0.45, 0.12) end
        local okER, ER = pcall(require, "src.ui.EnemyRenderer")
        if okER and ER.triggerBuff then ER.triggerBuff() end
        local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
        if okCF then CardFeel.burstAtEnemy("buff", 1.2) end
        if _G.triggerShake then _G.triggerShake(7, 0.2) end
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        if okFT and okER and ER.getLastPos then
            local ex, ey = ER.getLastPos()
            if ex and ey then
                FloatingText.spawn(I18n.t("status.enraged.name", nil, "Enfurecido"),
                    ex, ey - 30, { kind = "movename", hold = 0.5, lift = 24 })
            end
        end
    end

    if sink then
        sink[#sink + 1] = { label = "enemy.enraged", fn = body, hold = "STATUS" }
    elseif CombatBeats.extendCurrent("STATUS") then
        CombatBeats.mark("enemy.enraged")
        body()
    else
        CombatBeats.push("enemy.enraged", body, "STATUS")
    end
    return true
end

function Game:announceDeathIfPending(sink)
    local e = self.enemy
    if not e then return false end
    if self._deathStaged or self._deathHandled then return false end
    if not (e._pendingDeath or not e:isAlive()) then return false end
    e._pendingDeath = false
    self._deathStaged = true

    local enemyRef = e
    local body = function()
        if self.enemy ~= enemyRef then
            self._deathStaged = false
            return
        end
        self:_onEnemyDeath()
    end

    if sink then
        sink[#sink + 1] = { label = "enemy.death", fn = body, hold = Game.DEATH_HOLD }
    elseif CombatBeats.extendCurrent(Game.DEATH_HOLD) then
        CombatBeats.mark("enemy.death")
        body()
    else
        CombatBeats.push("enemy.death", body, Game.DEATH_HOLD)
    end
    return true
end

function Game:_intentAppliesDot()
    local it = self.enemy and self.enemy.getIntent and self.enemy:getIntent()
    for _, d in ipairs((it and it.debuffs) or {}) do
        if d.name == "poison" or d.name == "burn" then return true end
    end
    return false
end

function Game:_announcePhaseIfPending(sink)
    local e = self.enemy
    if not e or not e._pendingPhase then return false end
    local ph = e._pendingPhase
    e._pendingPhase = nil
    if not e:isAlive() then return false end
    local enemyRef = e
    local body = function()
        if self.enemy ~= enemyRef then return end
        local I18n = require("src.i18n.I18n")
        local key = "enemy_kit.phases." .. tostring(ph.id)
        local name = I18n.t(key .. ".name", nil, tostring(ph.id))
        self:addMessage(I18n.t(key .. ".msg", nil, name), "warning")
        Sfx.playWithVariation("enemyBuffRoar", 0.75, 0.04)
        if enemyRef.juice_up then enemyRef:juice_up(0.6, 0.15) end
        local okER, ER = pcall(require, "src.ui.EnemyRenderer")
        if okER and ER.triggerBuff then ER.triggerBuff() end
        local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
        if okCF then CardFeel.burstAtEnemy("dark", 1.4) end
        if _G.triggerShake then _G.triggerShake(10, 0.35) end
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        if okFT and okER and ER.getLastPos then
            local ex, ey = ER.getLastPos()
            if ex and ey then
                FloatingText.spawn(name, ex, ey - 30, { kind = "movename", hold = 0.7, lift = 26 })
            end
        end
    end
    if sink then
        sink[#sink + 1] = { label = "enemy.phase", fn = body, hold = "STATUS" }
    elseif CombatBeats.extendCurrent("STATUS") then
        CombatBeats.mark("enemy.phase")
        body()
    else
        CombatBeats.push("enemy.phase", body, "STATUS")
    end
    return true
end

function Game:_mechanicFx(res)
    if not res then return end
    local ok, BossTokens = pcall(require, "src.ui.BossTokens")
    if ok and BossTokens.react then BossTokens.react(self, res) end
end

function Game:_announceMechanicIfPending(sink)
    local e = self.enemy
    if not e or not BossMechanics.hasPending(e) then return false end
    local any = false
    while BossMechanics.hasPending(e) do
        local ev = BossMechanics.popEvent(e)
        local enemyRef = e
        local body = function()
            if self.enemy ~= enemyRef then return end
            self:_mechanicFx(BossMechanics.applyEvent(enemyRef, ev))
        end
        if sink then
            sink[#sink + 1] = { label = "boss." .. tostring(ev.kind), fn = body, hold = "STATUS" }
        else
            CombatBeats.push("boss." .. tostring(ev.kind), body, "STATUS")
        end
        any = true
    end
    return any
end

function Game:settleEnemyDamage(sink)
    local died = self:announceDeathIfPending(sink)
    local raged = self:_announceEnrageIfPending(sink)
    local phased = self:_announcePhaseIfPending(sink)
    local mech = self:_announceMechanicIfPending(sink)
    return died or raged or phased or mech
end

function Game:announceEnrageIfPending(sink)
    return self:settleEnemyDamage(sink)
end

function Game:isDeathSettled()
    return not self._deathPauseTimer or self._deathPauseTimer <= 0
end

function Game:isReadyForEndScreen()
    local cs = self.combatAnimationSystem
    if cs and cs.isBlocking and cs:isBlocking() then return false end
    return self:isDeathSettled()
end

function Game:enemyTurn()
    if not self.enemy:isAlive() then
        self.turn = "player"
        return
    end

    if self._enemyActing then return end
    self._enemyActing = true

    self._enemyTurnSeq = (self._enemyTurnSeq or 0) + 1
    local seq = self._enemyTurnSeq
    local enemyRef = self.enemy
    local function beat(fn)
        return function()
            if self._enemyTurnSeq ~= seq or self.enemy ~= enemyRef then return end
            fn()
        end
    end

    local intent = self.enemy.nextIntent or "attack"

    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
    if not okER then ER = nil end
    local function float(text, opts)
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        local ex, ey
        if ER and ER.getLastPos then ex, ey = ER.getLastPos() end
        if okFT and ex and ey then FloatingText.spawn(text, ex, ey, opts) end
    end

    CombatBeats.push("enemy.enrage_check", beat(function()
        self:announceEnrageIfPending(nil)
    end), "MICRO")

    if (self.enemy.armor or 0) > 0 then
        CombatBeats.push("enemy.armor_expire", beat(function()
            self.enemy.armor = 0
        end), "MICRO")
    end

    self.battleTurn = (self.battleTurn or 0) + 1
    if self.isRunMode and self.runManager and self.runManager.currentRun then
        local r = self.runManager.currentRun
        r.turnsTotal = (r.turnsTotal or 0) + 1
    end
    if self.battleTurn >= 8 and self.battleTurn < 13 then
        CombatBeats.push("enemy.fury", beat(function()
            self.enemy.baseDamage = self.enemy.baseDamage + 2
            self.enemy.damage = self.enemy.damage + 2
            self.enemy:addStatusEffect({ name = "fury", stacks = 2, duration = 99 })
            self:addMessage(msg("enemy_fury", { value = 2 }), "warning")
            Sfx.playWithVariation("enemyBuffRoar", 1.05, 0.06)
            if self.enemy.juice_up then self.enemy:juice_up(0.35, 0.1) end
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then CardFeel.burstAtEnemy("buff", 1.0) end
            float("+2", { kind = "damage", fontSize = 18 })
        end), "STATUS")
    end

    CombatBeats.push("enemy.telegraph", beat(function()
        local okEH, EnemyHud = pcall(require, "src.ui.EnemyHud")
        if okEH and EnemyHud.flashIntent then EnemyHud.flashIntent() end
        local I18n = require("src.i18n.I18n")
        local cur = self.enemy:getIntent()
        local moveName = I18n.t("enemy_kit.moves." .. tostring(cur.id) .. ".name", nil,
            I18n.t("enemy_moves." .. intent, nil, ""))
        if moveName ~= "" then
            float(moveName, { kind = "movename", hold = 0.55, lift = 26 })
        end
    end), "TELEGRAPH")

    local it = self.enemy:getIntent()
    local I18n = require("src.i18n.I18n")
    local struck = false
    local function playerFloat(text, opts)
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        if okFT and love.graphics then
            FloatingText.spawn(text, 120, love.graphics.getHeight() - 150, opts)
        end
    end

    if (it.armor or 0) > 0 then
        CombatBeats.push("enemy.defend", beat(function()
            local armorGain = it.armor
            self.enemy:addArmor(armorGain)
            Sfx.play("armorSound")
            if ER and ER.triggerDefend then ER.triggerDefend() end
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then CardFeel.burstAtEnemy("armor", 0.9) end
            float("+" .. armorGain, { kind = "armor", fontSize = 20 })
        end), "ENEMY_ACT")
    end

    if (it.hits or 0) > 0 and (it.perHit or 0) > 0 then
        local function applyHit(damage, pierce)
            local atkPitch = math.max(0.7, math.min(1.05, 1.1 - damage * 0.012))
            Sfx.playWithVariation("enemyAttack", atkPitch, 0.08)
            BossMechanics.onHitLanded(self.enemy, it)
            local hpBefore = self.player.health
            self.player:takeDamage(damage, pierce)
            local effective = hpBefore - self.player.health
            self.scoreSystem:recordDamageTaken(effective)
            if pierce then
                self:addMessage(I18n.t("enemy_kit.msg.pierce", { value = damage },
                    "Golpe atravessa o Bloqueio: {value}!"), "warning")
            end
            if _G.triggerShake then
                local intensity = math.min(14, 4 + damage * 0.25)
                _G.triggerShake(intensity, 0.22)
            end
            local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
            if okFT and love.graphics then
                if effective > 0 then
                    FloatingText.spawn("-" .. effective, 120,
                        love.graphics.getHeight() - 120,
                        { kind = "damage", fontSize = 22 })
                else
                    FloatingText.spawn("BLOQUEADO!", 120,
                        love.graphics.getHeight() - 120,
                        { kind = "armor", fontSize = 18 })
                end
            end
        end

        local hits = it.hits
        local animKind = (it.kind == "strong") and "strong" or "attack"
        for h = 1, hits do
            local landed = false
            CombatBeats.pushUntil("enemy.attack", beat(function()
                if not self.player:isAlive() then landed = true return end
                local damage = self.enemy:intentHitDamage(self.player)
                if damage <= 0 then
                    landed = true
                    return
                end
                struck = true
                if it.swarm and self.enemy:getStatusStacks("swarm") > 0 then
                    require("src.systems.CrowSfx").attack(h, hits)
                end
                if ER and ER.triggerAttack then
                    ER.triggerAttack(animKind, function()
                        applyHit(damage, it.pierce)
                        landed = true
                    end, { swarm = it.swarm,
                        strike = BossMechanics.strikeFor(self.enemy, it) })
                else
                    applyHit(damage, it.pierce)
                    landed = true
                end
            end), function() return landed end, 2.5,
                (h == hits) and "HIT_SETTLE" or "JOKER_PROC")
        end

        if EffectSystem.thornStacks(self) > 0 then
            CombatBeats.push("player.thorn_reflect", beat(function()
                if not struck then return end
                self.effectSystem:fireThornReflect(self)
                self:announceEnrageIfPending(nil)
            end), "REFLECT")
        end
    end

    for _, step in ipairs(BossMechanics.intentSteps(self.enemy, it)) do
        CombatBeats.push("boss." .. step.kind, beat(function()
            if not self.player:isAlive() then return end
            self:_mechanicFx(BossMechanics.applyIntentStep(self, step))
        end), "STATUS")
    end

    for _, d in ipairs(it.debuffs or {}) do
        CombatBeats.push("enemy.debuff." .. d.name, beat(function()
            if not self.player:isAlive() then return end
            self.player:addDebuff(d.name, d.duration, d.stacks)
            local statusName = I18n.t("status." .. d.name .. ".name", nil,
                I18n.t("enemy_kit.status." .. d.name .. ".name", nil, d.name))
            Sfx.playWithVariation("enemyBuffRoar", 0.8, 0.05)
            if _G.triggerShake then _G.triggerShake(3, 0.12) end
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then
                local theme = ({ weak = "weak", frail = "weak", vulnerable = "vulnerable",
                    poison = "poison", burn = "fire" })[d.name] or "weak"
                CardFeel.burstAtPlayer(theme, 0.9)
            end
            playerFloat(statusName, { kind = "movename", hold = 0.5, lift = 22 })
        end), "STATUS")
    end

    if (it.strength or 0) > 0 then
        CombatBeats.push("enemy.buff", beat(function()
            self.enemy:gainStrength(it.strength)
            Sfx.playWithVariation("enemyBuffRoar", 1.0, 0.06)
            if self.enemy.juice_up then self.enemy:juice_up(0.4, 0.1) end
            if ER and ER.triggerBuff then ER.triggerBuff() end
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then CardFeel.burstAtEnemy("buff", 1.1) end
            float(I18n.t("enemy_kit.msg.strength_float", { value = it.strength },
                "+" .. it.strength), { kind = "damage", fontSize = 18 })
        end), "STATUS")
    end

    if (it.heal or 0) > 0 then
        CombatBeats.push("enemy.heal", beat(function()
            local healed = self.enemy:healSelf(it.heal)
            if healed <= 0 then return end
            Sfx.playWithVariation("enemyBuffRoar", 1.15, 0.05)
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then CardFeel.burstAtEnemy("heal", 1.0) end
            float("+" .. healed, { color = { 0.45, 0.9, 0.5, 1 }, fontSize = 20 })
        end), "STATUS")
    end

    if (it.summon or 0) > 0 then
        CombatBeats.push("enemy.summon", beat(function()
            self.enemy:addStatusEffect({ name = "swarm", stacks = it.summon, duration = 999 })
            require("src.systems.CrowSfx").play("crowAppear")
            self:addMessage(I18n.t("enemy_kit.msg.summoned", { value = it.summon },
                "A revoada cresce: +{value}"), "warning")
            if ER and ER.triggerBuff then ER.triggerBuff() end
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then CardFeel.burstAtEnemy("dark", 1.1) end
            float("+" .. it.summon, { kind = "damage", fontSize = 18 })
        end), "STATUS")
    end

    if it.charge then
        CombatBeats.push("enemy.charge", beat(function()
            Sfx.playWithVariation("enemyBuffRoar", 0.7, 0.04)
            if self.enemy.juice_up then self.enemy:juice_up(0.5, 0.12) end
            if ER and ER.triggerBuff then ER.triggerBuff() end
            if _G.triggerShake then _G.triggerShake(5, 0.3) end
        end), "STATUS")
    end

    self:_pushEnemyTurnTail(beat)
end

function Game:_pushEnemyTurnTail(beat)
    local hasDot = false
    for _, st in ipairs(self.enemy.statusEffects or {}) do
        if (st.name == "poison" or st.name == "burn") and (st.stacks or 0) > 0 then
            hasDot = true
            break
        end
    end

    CombatBeats.push("enemy.dot", beat(function()
        local poisonDmg, burnDmg = self.enemy:onTurnEnd()
        local dotInfo = self.enemy.lastDot
        local ResistFx = require("src.ui.ResistFx")
        if dotInfo and ResistFx.dotTick(self.enemy, "poison", dotInfo.poison) then
            poisonDmg = 0
        end
        if dotInfo and ResistFx.dotTick(self.enemy, "burn", dotInfo.burn) then
            burnDmg = 0
        end
        if poisonDmg and poisonDmg > 0 then
            Sfx.playWithVariation("poisonTick", 1.0, 0.2)
            local okER, ER = pcall(require, "src.ui.EnemyRenderer")
            if okER and ER.triggerPoison then
                ER.triggerPoison()
                local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
                local ex, ey
                if ER.getLastPos then ex, ey = ER.getLastPos() end
                if okFT and ex and ey then
                    FloatingText.spawn("-" .. poisonDmg, ex, ey,
                        { color = { 0.45, 0.9, 0.35, 1 }, fontSize = 18 })
                end
            end
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then CardFeel.burstAtEnemy("poison", 0.8) end
        end
        if burnDmg and burnDmg > 0 then
            self.effectSystem.announceBurnTick(self, burnDmg)
            if poisonDmg and poisonDmg > 0 then
                CombatBeats.extendCurrent("DOT")
            end
        end
        self:announceDeathIfPending(nil)
    end), hasDot and "DOT" or "MICRO")

    if self.enemy:hasStatus("regen") or BossMechanics.regenBonus(self.enemy) > 0 then
        CombatBeats.push("enemy.regen", beat(function()
            local rooted = BossMechanics.regenBonus(self.enemy) > 0
            local healed = self.enemy:tickRegen()
            if rooted and healed and healed > 0 then
                self:_mechanicFx({ kind = "roots_regen", n = healed })
            end
            if healed and healed > 0 then
                local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
                if okCF then CardFeel.burstAtEnemy("heal", 0.8) end
                local okER, ER = pcall(require, "src.ui.EnemyRenderer")
                local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
                if okER and okFT and ER.getLastPos then
                    local ex, ey = ER.getLastPos()
                    if ex and ey then
                        FloatingText.spawn("+" .. healed, ex, ey,
                            { color = { 0.45, 0.9, 0.5, 1 }, fontSize = 18 })
                    end
                end
            end
        end), "DOT")
    end

    for _, step in ipairs(BossMechanics.turnEndSteps(self.enemy)) do
        CombatBeats.push("boss." .. step.kind, beat(function()
            local res = BossMechanics.applyStep(self.enemy, step)
            if res then
                CombatBeats.extendCurrent("STATUS")
                self:_mechanicFx(res)
            end
        end), "MICRO")
    end

    CombatBeats.push("player.debuff_decay", beat(function()
        if self.player.decayDebuffs then self.player:decayDebuffs() end
    end), "MICRO")

    CombatBeats.push("enemy.next_intent", beat(function()
        if not self.enemy:isAlive() then return end
        self.enemy:rollIntent(self.player)
        local moon = BossMechanics.afterRoll(self.enemy)
        if moon then
            CombatBeats.extendCurrent("STATUS")
            self:_mechanicFx(moon)
        end
    end), "DECAY")

    CombatBeats.push("player.upkeep", beat(function()
        if not self.enemy:isAlive() or not self.player:isAlive() then return end
        BossMechanics.onPlayerTurnStart(self)
        if self.player.onTurnStart then self.player:onTurnStart() end
        self.player:restoreMana()

        if self.player.retainArmor and (self.player.armor or 0) > 0 then
            for _, joker in ipairs(self.jokerSlots or {}) do
                for _, e in ipairs(joker.effects or {}) do
                    if e.type == "retain_armor" then
                        self.effectSystem:notifyJokerProc(self, joker,
                            "Escudo mantido", "armor")
                        break
                    end
                end
            end
        end
    end), "HANDOFF")

    local playerDot = self.player.getDebuffStacks
        and (self.player:getDebuffStacks("poison") + self.player:getDebuffStacks("burn") > 0
            or self:_intentAppliesDot())
    CombatBeats.push("player.dot", beat(function()
        if not self.enemy:isAlive() or not self.player:isAlive() then return end
        if not self.player.tickDebuffDots then return end
        local poison, burn = self.player:tickDebuffDots()
        local total = (poison or 0) + (burn or 0)
        if total <= 0 then return end
        self.scoreSystem:recordDamageTaken(total)
        Sfx.playWithVariation("poisonTick", 0.85, 0.15)
        local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
        if okCF then
            CardFeel.burstAtPlayer(((burn or 0) > (poison or 0)) and "fire" or "poison", 0.8)
        end
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        if okFT and love.graphics then
            FloatingText.spawn("-" .. total, 120, love.graphics.getHeight() - 120,
                { color = { 0.45, 0.9, 0.35, 1 }, fontSize = 20 })
        end
    end), playerDot and "DOT" or "MICRO")

    CombatBeats.push("player.draw", beat(function()
        if not self.enemy:isAlive() or not self.player:isAlive() then return end
        self:drawForTurn()
        local frozen = BossMechanics.onPlayerDraw(self)
        if frozen then
            CombatBeats.extendCurrent("STATUS")
            self:_mechanicFx(frozen)
        end
    end), "HANDOFF")

    do
        local steps = {}
        self.effectSystem:applyTriggerEffects(self, "turn_start", { beatSink = steps })
        for _, st in ipairs(steps) do
            local fn = st.fn
            CombatBeats.push(st.label, beat(function()
                if not self.enemy:isAlive() or not self.player:isAlive() then return end
                fn()
            end), st.hold)
        end
    end

    CombatBeats.push("turn.player_ready", beat(function()
        self._enemyActing = false
        self.turn = "player"
        self:announceDeathIfPending(nil)
    end), "MICRO")
end

function Game:usePotion()
    local run = self.isRunMode and self.runManager and self.runManager.currentRun
    if not (run and Config.Game.POTIONS and (run.potions or 0) > 0) then return false end
    if self.turn ~= "player" or not self.player or not self.player:isAlive() then return false end
    if self.player.health >= self.player.maxHealth then return false end
    run.potions = run.potions - 1
    local amt = math.floor(self.player.maxHealth * (Config.Game.POTION_HEAL_PCT or 0.2))
    self.player:heal(amt)
    return true, amt
end

function Game:_onEnemyDeath()
    if self._deathHandled then return end
    self._deathHandled = true
    self:noteBestiary("defeated")

    local okER, EnemyRenderer = pcall(require, "src.ui.EnemyRenderer")
    if okER and EnemyRenderer.triggerDeath then
        EnemyRenderer.triggerDeath(self.enemy.spriteId)
    end
    if _G.triggerShake then _G.triggerShake(18, 0.4) end
    if _G.jiggleScreen then _G.jiggleScreen(1.5) end
    Sfx.play("enemyDeath")
    self._deathPauseTimer = Game.DEATH_HOLD

    self.scoreSystem:finishBattle(self)
    self.score = self.scoreSystem.runScore
    local ProfileStats = require("engine.ProfileStats")
    local best = ProfileStats.get().bestScore or 0
    if best > 0 and self.score > best and not self.scoreSystem.recordBroken then
        self.scoreSystem.recordBroken = true
        self:addMessage(msg("new_record"), "gold")
        Sfx.play("comboTrigger")
    end

    AchievementSystem.onBattleWon(self)

    do
        local run = self.isRunMode and self.runManager and self.runManager.currentRun
        if run and run.currentNode and run.currentNode.type == "boss" then
            UnlockSystem.onBossDefeated(run.actNumber, self)
        end
        if run and Config.Game.POTIONS and run.currentNode and run.currentNode.type == "elite" then
            local slots = Config.Game.POTION_SLOTS or 1
            if (run.potions or 0) < slots then
                run.potions = (run.potions or 0) + 1
            end
        end
    end

    local EM = _G.EventManager
    if EM and _G.triggerShake then
        EM.after(0.22, function() _G.triggerShake(8, 0.18) end)
        EM.after(0.42, function() _G.triggerShake(4, 0.12) end)
    end

    if EM and self.jokerSlots then
        for i, joker in ipairs(self.jokerSlots) do
            if joker and joker.juice_up then
                EM.after((i - 1) * 0.08, function()
                    joker:juice_up(0.25, 0.08)
                end)
            end
        end
    end
end

function Game:isPhaseCleared()
    return self.enemy.health <= 0
end

function Game:_buildRoundEvalSources()
    local I18n = require("src.i18n.I18n")
    local sources = {}

    local act = 1
    if self.isRunMode and self.runManager and self.runManager:hasActiveRun() then
        act = self.runManager.currentRun.actNumber or 1
    end
    table.insert(sources, {
        label = I18n.t("round_eval.src_victory", nil, "Vitoria"),
        dollars = math.max(1, Config.Economy.victoryGold(act) + require(
            "src.systems.RunModifiers").victoryGoldDelta(
            self.isRunMode and self.runManager and self.runManager.currentRun)),
        color = {1, 0.85, 0.30, 1},
    })

    if self.player and self.player.health == self.player.maxHealth then
        table.insert(sources, {
            label = I18n.t("round_eval.src_full_hp", nil, "HP cheio"),
            dollars = Config.Economy.FULL_HP_BONUS,
            color = {0.4, 0.95, 0.5, 1},
        })
    end

    do
        local run = self.isRunMode and self.runManager and self.runManager.currentRun
        local nt = run and run.currentNode and run.currentNode.type
        local bonus = Config.Economy.nodeBonus(nt, act)
        if bonus > 0 then
            table.insert(sources, {
                label = I18n.t(nt == "boss" and "round_eval.src_boss" or "round_eval.src_elite",
                    nil, nt == "boss" and "Chefe" or "Elite"),
                dollars = bonus,
                color = {0.95, 0.55, 0.30, 1},
            })
        end
    end

    if self.economySystem then
        local interest = self.economySystem:calculateInterest()
        if interest > 0 then
            table.insert(sources, {
                label = I18n.t("round_eval.src_interest", nil, "Juros (1$ a cada 5$)"),
                dollars = interest,
                color = {0.95, 0.85, 0.30, 1},
            })
        end
    end

    return sources
end

function Game:resetHandAndDeck()
    CombatBeats.clear()
    self._enemyActing = false
    self.turn = "player"
    self.hand = {}
    self.selectedCards = {}
    self.discard = {}

    if self.player.resetTransientStats then
        self.player:resetTransientStats()
    end

    if self.isRunMode and self.runManager:hasActiveRun() then
        self:synchronizeRunDeck()
    end

    self:shuffleDeck()
    self:promoteInnateCardsToTop()

    for i = 1, Config.Game.INITIAL_HAND_SIZE + self:getShopServiceCount("card_draw_upgrade") do
        if #self.deck > 0 then
            self:drawCard((i - 1) * 0.08)
        end
    end
end

function Game:syncArmorCap()
    local act = 1
    if self.isRunMode and self.runManager:hasActiveRun() then
        act = self.runManager.currentRun.actNumber or 1
    end
    local base = Config.Game.PLAYER_MAX_ARMOR or 30
    local per = Config.Game.PLAYER_MAX_ARMOR_PER_ACT or 0
    self.player.maxArmor = base + per * math.max(0, act - 1)
end

function Game:syncInterestCap()
    if not self.economySystem or not self.economySystem.setBonusInterestCap then
        return
    end
    local porCompra = (Config.Offers and Config.Offers.INTEREST_CAP_PER_BUY) or 2
    self.economySystem:setBonusInterestCap(
        self:getShopServiceCount("interest_cap") * porCompra)
end

function Game:nextPhase()
    self._exhaustedThisBattle = {}
    self._deathHandled = false
    self._deathStaged = false
    self._deathPauseTimer = 0
    self._saveDeleted = false
    self.turn = "player"
    self._endTurnQueued = false
    self._enemyActing = false

    self.currentPhase = self.currentPhase + 1
    self.scoreSystem:startBattle()

    if self.isRunMode and self.runManager:hasActiveRun() then
        local st = require("src.systems.Rng").get():getState()
        st.meta = nil
        self.runManager.currentRun.battleRng = st
    end

    self.player:resetMaxMana()
    self.player:restoreMana()
    self:syncArmorCap()
    self:syncInterestCap()
    self:resetHandAndDeck()
    self:applyClassBattleStartPassive()

    if self.isRunMode and self.runManager:hasActiveRun() then
        local run = self.runManager.currentRun
        local nodeType = (run.currentNode and run.currentNode.type) or "battle"
        local stats = ActSystem.getEnemyStats(run.actNumber, run.floorInAct, nodeType,
            run.endlessMode and run.floorsInEndless or nil)
        local RunModifiers = require("src.systems.RunModifiers")
        stats = RunModifiers.enemyStats(run, stats, nodeType)
        local EnemyRoster = require("src.systems.EnemyRoster")
        local enemyId = EnemyRoster.resolveNode(run, run.currentNode, nodeType)
        run.battleEnemyRng = require("src.systems.Rng").get():getStreamState("enemy")
        self.enemy = EnemyRoster.spawn(Enemy, enemyId, stats, run.actNumber)
        RunModifiers.decorateEnemy(run, self.enemy)
        EnemyRoster.remember(run, enemyId)
        self.battleTurn = 0
        self.enemy.isBoss = (nodeType == "boss" or nodeType == "mini_boss")
        require("src.systems.Bestiary").beginFight(run)
        if nodeType ~= "boss" then self:noteBestiary("seen") end
    else
        local newHealth = Config.Game.ENEMY_BASE_HEALTH + (self.currentPhase - 1) * Config.Game.ENEMY_HEALTH_SCALING
        local newDamage = Config.Game.ENEMY_BASE_DAMAGE + (self.currentPhase - 1) * Config.Game.ENEMY_DAMAGE_SCALING
        self.enemy = Enemy:new(newHealth, newDamage)
        self.battleTurn = 0
    end

    if self.isRunMode and self.runManager:hasActiveRun() then
        local run = self.runManager.currentRun
        if run.floorInAct == 1 and run.actNumber > 1 then
            local pct = run.endlessMode and (Config.Endless.healPercent or 0)
                or ActSystem.getInterActHealPercent(run.actNumber - 1)
            pct = (pct or 0) * require("src.systems.RunModifiers").healMul(run, "act")
            if pct and pct > 0 then
                local before = self.player.health
                self.player:heal(math.floor(self.player.maxHealth * pct))
                local heal = self.player.health - before
                if heal > 0 then
                    self:addMessage(msg("act_transition_heal", { value = heal }), "success")
                end
            end
            Sfx.play("actComplete")
        end
    else
        if self.currentPhase % Config.Game.HEALTH_RESTORE_INTERVAL == 0 then
            self.player.health = math.min(self.player.health + Config.Game.PLAYER_HEALTH_RESTORE, self.player.maxHealth)
            self:addMessage(msg("health_restored", { value = Config.Game.PLAYER_HEALTH_RESTORE }), "success")
        end
    end

    if self.isRunMode and self.runManager:hasActiveRun() then
        self.runManager.currentRun.stage = "battle"
        self.runManager.currentRun.stageEventId = nil
    end
    self:checkpointRun()
end

function Game:syncRunPlayerState()
    local run = self.runManager and self.runManager.currentRun
    if not run then return end
    run.playerState = run.playerState or {}
    if self.player then
        run.playerState.maxHealth = self.player.maxHealth
        run.playerState.currentHealth = self.player.health
        run.playerState.baseMaxMana = self.player.baseMaxMana
    end
    if self.scoreSystem then
        run.playerState.runScore = self.scoreSystem.runScore or 0
        run.playerState.scoreRecordBroken = self.scoreSystem.recordBroken or nil
        run.playerState.lastBattleScore = self.scoreSystem.lastBattle
    end
    if self.economySystem then
        run.playerState.gold = self.economySystem.currentGold
        run.playerState.goldEarned = self.economySystem.totalGoldEarned
        run.playerState.goldSpent = self.economySystem.goldSpent
    end
end

function Game:checkpointRun()
    if not self.isRunMode then return end
    if not (self.runManager and self.runManager:hasActiveRun()) then return end
    if (self.player and not self.player:isAlive())
        or self.gameState == "gameOver" or self.gameState == "victory" then
        return
    end
    self:syncRunPlayerState()
    self.runManager:saveRun()
    require("engine.ProfileStats").flush()
end

function Game:resumeRun()
    local run = self.runManager and self.runManager.currentRun
    if not run then return false end
    self.isRunMode = true
    self.selectedClass = run.classId

    local Rng = require("src.systems.Rng")
    local savedRng = Rng.get():getState()
    local inBattle = (run.stage == nil or run.stage == "battle")
        and not (run.pendingNodes and #run.pendingNodes > 0)
    if inBattle and run.battleRng then
        local r = Rng.fromState(run.battleRng)
        r.meta = savedRng.meta
        Rng.setActive(r)
    end

    self._resumingRun = true
    self:startGame()
    self._resumingRun = false
    require("src.systems.Bestiary").attachRun(run)

    local ps = run.playerState
    if ps and ps.maxHealth then
        self.player.maxHealth = ps.maxHealth
        self.player.health = math.max(1,
            math.min(ps.currentHealth or ps.maxHealth, ps.maxHealth))
    end
    if ps and ps.gold then
        self.economySystem.currentGold = ps.gold
    end
    if ps and ps.baseMaxMana then
        self.player.baseMaxMana = ps.baseMaxMana
        self.player.maxMana = ps.baseMaxMana
        self.player.mana = self.player.maxMana
    end
    if ps and ps.runScore and self.scoreSystem then
        self.scoreSystem.runScore = ps.runScore
    end
    self.score = (self.scoreSystem and self.scoreSystem.runScore) or 0
    if ps and self.scoreSystem then
        self.scoreSystem.recordBroken = ps.scoreRecordBroken and true or false
        self.scoreSystem.lastBattle = ps.lastBattleScore
    end
    if ps and self.economySystem then
        self.economySystem.totalGoldEarned = ps.goldEarned or self.economySystem.totalGoldEarned
        self.economySystem.goldSpent = ps.goldSpent or self.economySystem.goldSpent
    end

    local nodeType = (run.currentNode and run.currentNode.type) or "battle"
    local stats = ActSystem.getEnemyStats(run.actNumber, run.floorInAct, nodeType,
        run.endlessMode and run.floorsInEndless or nil)
    local RunModifiers = require("src.systems.RunModifiers")
    stats = RunModifiers.enemyStats(run, stats, nodeType)
    local EnemyRoster = require("src.systems.EnemyRoster")
    local nodeEnemyId = run.currentNode and run.currentNode.enemyId
    local enemyId = EnemyRoster.resolveNode(run, run.currentNode, nodeType)
    if inBattle and run.battleEnemyRng then
        Rng.get():setStreamState("enemy", run.battleEnemyRng)
    end
    self.enemy = EnemyRoster.spawn(Enemy, enemyId, stats, run.actNumber)
    RunModifiers.decorateEnemy(run, self.enemy)
    if self.player then self.player.frost = 0 end
    self.battleTurn = 0
    self.enemy.isBoss = (nodeType == "boss" or nodeType == "mini_boss")
    if inBattle then self:noteBestiary("seen") end
    if not inBattle then
        local r = Rng.fromState(savedRng)
        Rng.setActive(r)
        if run.currentNode then run.currentNode.enemyId = nodeEnemyId end
    end
    return true
end

function Game:addMessage(text, type)
    if self.messageSystem then
        self.messageSystem:addMessage(text, type)
    end
end

function Game:checkGameOver()
    if not self.player:isAlive() then
        self.gameState = "gameOver"
        if self.isRunMode and self.runManager and not self._saveDeleted then
            self._saveDeleted = true
            self:noteBestiary("killedYou")
            self.runManager:deleteSave()
            local run = self.runManager.currentRun
            local PS = require("engine.ProfileStats")
            if run and run.campaignWon then
                self:_recordEndlessEnd()
            else
                self.unlockResult = UnlockSystem.onRunEnded(self:_unlockSummary(false))
                PS.recordDefeat(run and run.actNumber, run and run.floorInAct)
                PS.updateBestScore(self.score)
            end
        end
        return true
    end
    return false
end

function Game:abandonRun()
    if not self.runManager then return end
    if not self.isRunMode then self.runManager:deleteSave(); return end
    if self._saveDeleted or self._victoryRecorded then
        if self.runManager.deleteSave then self.runManager:deleteSave() end
        return
    end
    self._saveDeleted = true
    local run = self.runManager.currentRun
    if run and run.campaignWon then
        self:_recordEndlessEnd()
    elseif run then
        local PS = require("engine.ProfileStats")
        self.unlockResult = UnlockSystem.onRunEnded(self:_unlockSummary(false))
        PS.recordDefeat(run.actNumber, run.floorInAct)
    end
    self.runManager:deleteSave()
end

function Game:_recordEndlessEnd()
    local PS = require("engine.ProfileStats")
    self.unlockResult = UnlockSystem.onRunEnded(self:_unlockSummary(false))
    PS.updateBestScore(self.score)
end

function Game:enterEndless()
    if not (self.isRunMode and self.runManager and self.runManager:hasActiveRun()) then
        return false
    end
    local run = self.runManager.currentRun
    if not run.campaignWon or run.endlessMode then return false end
    run.endlessMode = true
    run.floorsInEndless = 0
    self.gameState = "playing"
    self._victoryRecorded = false
    self.unlockResult = nil
    return true
end

local CLOCK_IDLE = { menu = true, classSelection = true, gameOver = true,
                     victory = true }
function Game:tickRunClock(dt, state)
    if not self.isRunMode or CLOCK_IDLE[state or ""] then return end
    local run = self.runManager and self.runManager.currentRun
    if not run or self.gameState ~= "playing" then return end
    run.playSeconds = (run.playSeconds or 0) + (dt or 0)
end

function Game:_unlockSummary(victory)
    local run = self.runManager and self.runManager.currentRun or {}
    return {
        classId = run.classId or self.selectedClass,
        victory = victory and true or false,
        actNumber = run.actNumber or 1,
        floorInAct = run.floorInAct or 1,
        endlessMode = run.endlessMode or false,
        floorsInEndless = run.floorsInEndless or 0,
        score = self.score or 0,
        seal = run.seal or 0,
    }
end

function Game:checkVictory()
    if self.isRunMode and self.runManager:hasActiveRun() then
        local run = self.runManager.currentRun
        if run.endlessMode then return false end
        local totalActs = Config.TotalActs or 3
        local MapManager = require("src.systems.MapManager")
        if run.actNumber >= totalActs
            and run.floorInAct >= MapManager.FLOORS_PER_ACT
            and run.currentNode and run.currentNode.type == "boss"
            and self:isPhaseCleared() then
            self.gameState = "victory"
            if not self._victoryRecorded then
                self._victoryRecorded = true
                run.campaignWon = true
                local PS = require("engine.ProfileStats")
                self.unlockResult = UnlockSystem.onRunEnded(self:_unlockSummary(true))
                PS.recordVictory(run.actNumber, run.floorInAct, run.classId or self.selectedClass)
                PS.updateBestScore(self.score)
                if self.runManager.deleteSave then self.runManager:deleteSave() end
                AchievementSystem.onVictory(self)
            end
            return true
        end
        return false
    end
    if self.currentPhase > Config.Game.VICTORY_PHASES then
        self.gameState = "victory"
        return true
    end
    return false
end

function Game:playCardSelectSound()
    Sfx.playWithVariation("cardSelect", 1.0, 0.12)
end

function Game:toggleMenu()
    if self.onToggleSettings then
        self.onToggleSettings()
    else
        self:addMessage(msg("settings_unavailable"), "warning")
    end
end

return Game
