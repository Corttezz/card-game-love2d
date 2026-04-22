-- src/data/events.lua
-- Pool de eventos narrativos. Cada evento tem:
--   id (unique), act (1-3 ou "any"), title, body (texto),
--   options = { { label, apply = function(game) ... end } }
--
-- apply pode retornar string com feedback textual para toast.

local Events = {}

Events.POOL = {
    -- ========== ATO 1 — Catacumbas ==========
    {
        id = "altar_proibido",
        act = "any",
        title = "Altar Proibido",
        body  = "Um altar de pedra pulsa com energia sombria. Uma voz sussurra: 'entregue seu sangue...'",
        options = {
            { label = "Sacrificar 8 HP → carta rara",
              apply = function(game)
                  game.player:takeDamage(8)
                  local rewards = game.runManager.cardRegistry:generateCardRewards(
                      game.selectedClass, 1, { minRarity = "rare" })
                  if rewards[1] then
                      game:addCardToRun(rewards[1].cardId)
                      return "Voce adquiriu uma carta rara."
                  end
                  return "O altar silencia."
              end },
            { label = "Ir embora",
              apply = function() return "Voce segue em frente, intacto." end },
        },
    },
    {
        id = "bigorna_antiga",
        act = "any",
        title = "Bigorna Antiga",
        body  = "Uma bigorna enferrujada aguarda. Parece que ainda tem uma forja no peito dela.",
        options = {
            { label = "Forjar carta aleatoria",
              apply = function(game)
                  local deck = game.runManager.currentRun.currentDeck
                  if #deck == 0 then return "Voce nao tem cartas no deck." end
                  local picked = deck[love.math.random(#deck)]
                  -- marca a carta com upgrade (flag persistente na run)
                  game.runManager.currentRun.upgraded = game.runManager.currentRun.upgraded or {}
                  game.runManager.currentRun.upgraded[picked] =
                      (game.runManager.currentRun.upgraded[picked] or 0) + 1
                  return "Carta '" .. picked .. "' forjada!"
              end },
            { label = "Ignorar",
              apply = function() return "A bigorna apaga." end },
        },
    },
    {
        id = "aposta_ouro",
        act = "any",
        title = "Aposta do Estranho",
        body  = "Um estranho encapuzado sorri. 'Cara ou coroa. 50 ouros em jogo.'",
        options = {
            { label = "Apostar 20 ouro (50% ganha +50)",
              apply = function(game)
                  if game.economySystem.currentGold < 20 then
                      return "Voce nao tem 20 ouros."
                  end
                  game.economySystem.currentGold = game.economySystem.currentGold - 20
                  if love.math.random() < 0.5 then
                      game.economySystem.currentGold = game.economySystem.currentGold + 70
                      return "Voce ganhou! +50 ouro liquido."
                  end
                  return "Voce perdeu 20 ouros."
              end },
            { label = "Recusar",
              apply = function() return "O estranho some." end },
        },
    },
    {
        id = "cristais_maximos",
        act = "any",
        title = "Cristais Maximos",
        body  = "Cristais flutuam em ar denso. Tocar um pode mudar sua essencia.",
        options = {
            { label = "+5 HP maximo",
              apply = function(game)
                  game.player.maxHealth = game.player.maxHealth + 5
                  game.player.health = game.player.health + 5
                  return "Vida maxima +5."
              end },
            { label = "+1 Mana maxima",
              apply = function(game)
                  game.player.maxMana = game.player.maxMana + 1
                  game.player.baseMaxMana = game.player.baseMaxMana + 1
                  return "Mana maxima +1."
              end },
            { label = "Ir embora",
              apply = function() return "Voce ignora o brilho." end },
        },
    },
    {
        id = "biblioteca_esquecida",
        act = "any",
        title = "Biblioteca Esquecida",
        body  = "Pilhas de pergaminhos antigos. Um livro especifico chama sua atencao.",
        options = {
            { label = "Estudar (ganha 2 cartas aleatorias)",
              apply = function(game)
                  local rewards = game.runManager.cardRegistry:generateCardRewards(
                      game.selectedClass, 2)
                  local names = {}
                  for _, r in ipairs(rewards) do
                      game:addCardToRun(r.cardId)
                      table.insert(names, r.cardId)
                  end
                  return "Voce aprendeu: " .. table.concat(names, ", ")
              end },
            { label = "Queimar livros (ganha 30 ouro)",
              apply = function(game)
                  game.economySystem.currentGold = game.economySystem.currentGold + 30
                  return "+30 ouro, mas algo se perdeu."
              end },
        },
    },
    {
        id = "fonte_vida",
        act = "any",
        title = "Fonte da Vida",
        body  = "Agua cristalina brota de uma pedra antiga. O cheiro e reconfortante.",
        options = {
            { label = "Beber (cura 40% maxHP)",
              apply = function(game)
                  local amt = math.floor(game.player.maxHealth * 0.40)
                  game.player:heal(amt)
                  return "Curou " .. amt .. " HP."
              end },
            { label = "Engarrafar (ganha carta 'Healing Potion')",
              apply = function(game)
                  game:addCardToRun("effect_healing_potion")
                  return "Voce agora possui Pocao de Cura."
              end },
            { label = "Ir embora", apply = function() return "Fonte intocada." end },
        },
    },
    {
        id = "comerciante_misterioso",
        act = "any",
        title = "Comerciante Misterioso",
        body  = "Um homem com cicatrizes oferece uma carta lendaria por um preco alto.",
        options = {
            { label = "Comprar (-150 ouro, +carta lendaria)",
              apply = function(game)
                  if game.economySystem.currentGold < 150 then
                      return "Precisa de 150 ouro."
                  end
                  game.economySystem.currentGold = game.economySystem.currentGold - 150
                  local rewards = game.runManager.cardRegistry:generateCardRewards(
                      game.selectedClass, 1, { minRarity = "legendary" })
                  if rewards[1] then
                      game:addCardToRun(rewards[1].cardId)
                      return "Voce adquiriu " .. rewards[1].cardId
                  end
                  return "O comerciante nao encontrou nada adequado."
              end },
            { label = "Recusar", apply = function() return "Ele suspira e parte." end },
        },
    },
    {
        id = "espelho_quebrado",
        act = "any",
        title = "Espelho Quebrado",
        body  = "Um espelho rachado mostra seu reflexo deformado. Quer remover uma parte de si?",
        options = {
            { label = "Remover 1 carta aleatoria do deck",
              apply = function(game)
                  local deck = game.runManager.currentRun.currentDeck
                  if #deck <= 2 then return "Deck muito pequeno para remover." end
                  local idx = love.math.random(#deck)
                  local id = deck[idx]
                  game.runManager:removeCardFromDeck(id)
                  game:synchronizeRunDeck()
                  return "Removido: " .. id
              end },
            { label = "Virar as costas", apply = function() return "Voce ignora o reflexo." end },
        },
    },
    {
        id = "mochila_abandonada",
        act = "any",
        title = "Mochila Abandonada",
        body  = "Uma mochila no chao. Algo se mexe dentro.",
        options = {
            { label = "Abrir",
              apply = function(game)
                  local roll = love.math.random()
                  if roll < 0.4 then
                      game.economySystem.currentGold = game.economySystem.currentGold + 25
                      return "Ouro dentro! +25."
                  elseif roll < 0.8 then
                      game:addCardToRun("effect_healing_potion")
                      return "Pocao de cura!"
                  else
                      game.player:takeDamage(6)
                      return "Armadilha! -6 HP."
                  end
              end },
            { label = "Deixar quieta", apply = function() return "Voce prossegue." end },
        },
    },
    {
        id = "mistery_node",
        act = "any",
        title = "Nevoa Estranha",
        body  = "Uma nevoa estranha te envolve. Voce desperta diferente...",
        options = {
            { label = "Aceitar (efeito aleatorio)",
              apply = function(game)
                  -- Usa o mystery do EffectSystem
                  local effect = { type = "mystery" }
                  game.effectSystem:processEffectCard(game, effect)
                  return "Algo mudou em voce."
              end },
            { label = "Resistir", apply = function() return "A nevoa dissipa." end },
        },
    },
}

-- Sorteia um evento do pool para um ato especifico (ou "any").
function Events.roll(actNumber)
    local valid = {}
    for _, e in ipairs(Events.POOL) do
        if e.act == "any" or e.act == actNumber then
            table.insert(valid, e)
        end
    end
    if #valid == 0 then return nil end
    return valid[love.math.random(#valid)]
end

return Events
