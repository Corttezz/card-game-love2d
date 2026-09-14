-- src/data/events.lua
-- Pool de eventos narrativos. Cada evento tem:
--   id (unique), act (1-3 ou "any"), title, body (texto),
--   options = { { label, gains?, costs?, apply = function(game) ... end } }
--
-- gains/costs (listas de strings curtas) viram o sufixo EXPLÍCITO do botão:
--   "Beber da fonte  [+cura 40% HP]" — o jogador SEMPRE sabe a troca antes
--   de clicar (padrão StS: risco informado, nunca pegadinha). Opções neutras
--   ("ir embora") não declaram nada.
--
-- apply pode retornar string com feedback textual para toast.
-- RNG: decisões de evento usam o stream "event" do Rng da run (reprodutível
-- por seed; não contamina os rolls de carta/loja/mapa).

local Rng = require("src.systems.Rng")
local I18n = require("src.i18n.I18n")

-- Texto do evento (title/body/label) vive nos locales sob `events.<id>`; os
-- literais que sobraram aqui sao FALLBACK. Quem resolve e a EventScreen, no
-- DRAW — se resolvesse aqui, no load do modulo, trocar de idioma em runtime
-- nao mudaria nada, porque Events.POOL e construido uma vez so.
--
-- Ja os retornos de `apply` resolvem AQUI mesmo: eles rodam no clique, entao
-- o I18n.t acontece na hora certa.
local function T(id, key, vars, fb)
    return I18n.t("events." .. id .. "." .. key, vars, fb)
end

local Events = {}

-- Helper: recompensa de carta com contexto do deck (afinidade/anti-duplicata).
-- P0.5/P0.10 (rebalance Jul/2026): tambem passa actNumber (cap de afinidade
-- progressivo por ato) e runManager (dedup de oferta de joker ja possuido).
local function rewardOpts(game, extra)
    local opts = extra or {}
    if game.runManager and game.runManager.getDeckCardIds then
        opts.deckIds = game.runManager:getDeckCardIds()
    end
    local run = game.runManager and game.runManager.currentRun
    opts.actNumber = (run and run.actNumber) or 1
    opts.runManager = game.runManager
    opts.stream = "event"
    return opts
end

Events.POOL = {
    -- ========== Eventos de qualquer ato ==========
    {
        id = "altar_proibido",
        act = "any",
        title = "Altar Proibido",
        body  = "Um altar de pedra pulsa com energia sombria. Uma voz sussurra: 'entregue seu sangue...'",
        options = {
            { label = "Sacrificar sangue",
              gains = { { k = "card_rare", fb = "carta RARA" } }, costs = { { k = "hp", n = 8, fb = "8 HP" } },
              apply = function(game)
                  game.player:takeDamage(8)
                  local rewards = game.runManager.cardRegistry:generateCardRewards(
                      game.selectedClass, 1, rewardOpts(game, { minRarity = "rare" }))
                  if rewards[1] then
                      game:addCardToRun(rewards[1].cardId)
                      return T("altar_proibido", "r_got_rare", nil, "Voce adquiriu uma carta rara.")
                  end
                  return T("altar_proibido", "r_silent", nil, "O altar silencia.")
              end },
            { label = "Ir embora",
              apply = function() return T("altar_proibido", "r_leave", nil, "Voce segue em frente, intacto.") end },
        },
    },
    {
        id = "bigorna_antiga",
        act = "any",
        title = "Bigorna Antiga",
        body  = "Uma bigorna enferrujada aguarda. Parece que ainda tem uma forja no peito dela.",
        options = {
            { label = "Martelar o aco",
              gains = { { k = "forge_random", fb = "forja +1 em carta aleatoria" } },
              apply = function(game)
                  local deck = game.runManager.currentRun.currentDeck
                  if #deck == 0 then return T("bigorna_antiga", "r_no_cards", nil, "Voce nao tem cartas no deck.") end
                  -- Tenta até 5 vezes pegar uma carta que ainda não bateu o cap;
                  -- senão cancela com mensagem (com cap 0/infinito passa de primeira).
                  for _ = 1, 5 do
                      local entry = deck[Rng.get():random("event", #deck)]
                      local picked = type(entry) == "table" and entry.id or entry
                      local lvl = game.runManager:upgradeCard(picked)
                      if lvl then
                          return T("bigorna_antiga", "r_forged",
                              { name = I18n.cardName(picked), lvl = lvl },
                              "Carta forjada!")
                      end
                  end
                  return T("bigorna_antiga", "r_all_max", nil, "Todas as cartas escolhidas ja estao no maximo.")
              end },
            { label = "Ignorar",
              apply = function() return T("bigorna_antiga", "r_ignore", nil, "A bigorna apaga.") end },
        },
    },
    {
        id = "aposta_ouro",
        act = "any",
        title = "Aposta do Estranho",
        body  = "Um estranho encapuzado sorri. 'Cara ou coroa. Dobro ou nada.'",
        options = {
            { label = "Apostar",
              gains = { { k = "gamble", pct = 50, n = 50, fb = "50% de ganhar $50" } }, costs = { { k = "gold", n = 20, fb = "$20" } },
              apply = function(game)
                  if game.economySystem.currentGold < 20 then
                      return T("aposta_ouro", "r_no_gold", { n = 20 }, "Voce nao tem 20 ouros.")
                  end
                  game.economySystem.currentGold = game.economySystem.currentGold - 20
                  if Rng.get():random("event") < 0.5 then
                      game.economySystem.currentGold = game.economySystem.currentGold + 70
                      return T("aposta_ouro", "r_win", { n = 50 }, "Voce ganhou! +50 ouro liquido.")
                  end
                  return T("aposta_ouro", "r_lose", { n = 20 }, "Voce perdeu 20 ouros.")
              end },
            { label = "Recusar",
              apply = function() return T("aposta_ouro", "r_refuse", nil, "O estranho some.") end },
        },
    },
    {
        id = "cristais_maximos",
        act = "any",
        title = "Cristais Maximos",
        body  = "Cristais flutuam em ar denso. Tocar um pode mudar sua essencia.",
        options = {
            { label = "Tocar o cristal rubro",
              gains = { { k = "max_hp", n = 5, fb = "5 HP maximo" } },
              apply = function(game)
                  game.player.maxHealth = game.player.maxHealth + 5
                  game.player.health = game.player.health + 5
                  return T("cristais_maximos", "r_hp", { n = 5 }, "Vida maxima +5.")
              end },
            { label = "Tocar o cristal azul",
              gains = { { k = "max_mana", n = 1, fb = "1 mana maxima" } },
              apply = function(game)
                  game.player.maxMana = game.player.maxMana + 1
                  game.player.baseMaxMana = game.player.baseMaxMana + 1
                  return T("cristais_maximos", "r_mana", { n = 1 }, "Mana maxima +1.")
              end },
            { label = "Ir embora",
              apply = function() return T("cristais_maximos", "r_leave", nil, "Voce ignora o brilho.") end },
        },
    },
    {
        id = "biblioteca_esquecida",
        act = "any",
        title = "Biblioteca Esquecida",
        body  = "Pilhas de pergaminhos antigos. Um livro especifico chama sua atencao.",
        options = {
            { label = "Estudar",
              gains = { { k = "cards_random", n = 2, fb = "2 cartas aleatorias" } },
              apply = function(game)
                  local rewards = game.runManager.cardRegistry:generateCardRewards(
                      game.selectedClass, 2, rewardOpts(game))
                  local names = {}
                  for _, r in ipairs(rewards) do
                      game:addCardToRun(r.cardId)
                      table.insert(names, I18n.cardName(r.cardId))
                  end
                  return T("biblioteca_esquecida", "r_learned",
                      { names = table.concat(names, ", ") }, "Voce aprendeu.")
              end },
            { label = "Queimar os livros",
              gains = { { k = "gold", n = 30, fb = "$30" } },
              apply = function(game)
                  game.economySystem.currentGold = game.economySystem.currentGold + 30
                  return T("biblioteca_esquecida", "r_burn", { n = 30 }, "+30 ouro, mas algo se perdeu.")
              end },
        },
    },
    {
        id = "fonte_vida",
        act = "any",
        title = "Fonte da Vida",
        body  = "Agua cristalina brota de uma pedra antiga. O cheiro e reconfortante.",
        options = {
            { label = "Beber",
              gains = { { k = "heal_pct", n = 40, fb = "cura 40% HP" } },
              apply = function(game)
                  local amt = math.floor(game.player.maxHealth * 0.40)
                  game.player:heal(amt)
                  return T("fonte_vida", "r_drink", { n = amt }, "Curou HP.")
              end },
            { label = "Engarrafar",
              gains = { { k = "card_potion", fb = "carta Pocao de Cura" } },
              apply = function(game)
                  game:addCardToRun("effect_healing_potion")
                  return T("fonte_vida", "r_bottle", nil, "Voce agora possui Pocao de Cura.")
              end },
            { label = "Ir embora", apply = function() return T("fonte_vida", "r_leave", nil, "Fonte intocada.") end },
        },
    },
    {
        id = "comerciante_misterioso",
        act = "any",
        title = "Comerciante Misterioso",
        body  = "Um homem com cicatrizes oferece uma carta lendaria por um preco alto.",
        options = {
            { label = "Comprar",
              gains = { { k = "card_legendary", fb = "carta LENDARIA" } }, costs = { { k = "gold", n = 150, fb = "$150" } },
              apply = function(game)
                  if game.economySystem.currentGold < 150 then
                      return T("comerciante_misterioso", "r_need_gold", { n = 150 }, "Precisa de 150 ouro.")
                  end
                  game.economySystem.currentGold = game.economySystem.currentGold - 150
                  -- P0.8 (rebalance Jul/2026): com legendaries por classe no
                  -- pool, minRarity='legendary' resolve. FALLBACK: se o pool
                  -- legendary da classe estiver vazio/esgotado (ex: dedup de
                  -- jokers ja possuidos), ignora o filtro de classe — NUNCA
                  -- entregar rare por $150.
                  local registry = game.runManager.cardRegistry
                  local rewards = registry:generateCardRewards(
                      game.selectedClass, 1, rewardOpts(game, { minRarity = "legendary" }))
                  if not (rewards[1] and rewards[1].rarity == "legendary") then
                      rewards = registry:generateCardRewards(
                          nil, 1, rewardOpts(game, { minRarity = "legendary" }))
                  end
                  if rewards[1] and rewards[1].rarity == "legendary" then
                      game:addCardToRun(rewards[1].cardId)
                      return T("comerciante_misterioso", "r_bought",
                          { name = I18n.cardName(rewards[1].cardId) }, "Voce adquiriu a carta.")
                  end
                  -- Sem legendary em lugar nenhum: devolve o ouro (troca honesta).
                  game.economySystem.currentGold = game.economySystem.currentGold + 150
                  return T("comerciante_misterioso", "r_refund", nil, "O comerciante nao encontrou nada adequado. Ouro devolvido.")
              end },
            { label = "Recusar", apply = function() return T("comerciante_misterioso", "r_refuse", nil, "Ele suspira e parte.") end },
        },
    },
    {
        id = "espelho_quebrado",
        act = "any",
        title = "Espelho Quebrado",
        body  = "Um espelho rachado mostra seu reflexo deformado. Quer remover uma parte de si?",
        options = {
            { label = "Aceitar o reflexo",
              costs = { { k = "remove_random", n = 1, fb = "1 carta ALEATORIA do deck" } },
              apply = function(game)
                  local deck = game.runManager.currentRun.currentDeck
                  if #deck <= 2 then return T("espelho_quebrado", "r_too_small", nil, "Deck muito pequeno para remover.") end
                  local idx = Rng.get():random("event", #deck)
                  local id = deck[idx]
                  -- removeCardAt: tira A COPIA sorteada. Por id sairia sempre
                  -- a primeira do deck, que pode estar noutro nivel de forja.
                  game.runManager:removeCardAt(idx)
                  game:synchronizeRunDeck()
                  return T("espelho_quebrado", "r_removed",
                      { name = I18n.cardName(type(id) == "table" and id.id or id) },
                      "Carta removida.")
              end },
            { label = "Virar as costas", apply = function() return T("espelho_quebrado", "r_leave", nil, "Voce ignora o reflexo.") end },
        },
    },
    {
        id = "mochila_abandonada",
        act = "any",
        title = "Mochila Abandonada",
        body  = "Uma mochila no chao. Algo se mexe dentro.",
        options = {
            { label = "Abrir",
              gains = { { k = "chance_gold", pct = 40, n = 25, fb = "40% $25" }, { k = "chance_potion", pct = 40, fb = "40% pocao" } }, costs = { { k = "chance_trap", pct = 20, n = 6, fb = "20% armadilha 6 HP" } },
              apply = function(game)
                  local roll = Rng.get():random("event")
                  if roll < 0.4 then
                      game.economySystem.currentGold = game.economySystem.currentGold + 25
                      return T("mochila_abandonada", "r_gold", { n = 25 }, "Ouro dentro! +25.")
                  elseif roll < 0.8 then
                      game:addCardToRun("effect_healing_potion")
                      return T("mochila_abandonada", "r_potion", nil, "Pocao de cura!")
                  else
                      game.player:takeDamage(6)
                      return T("mochila_abandonada", "r_trap", { n = 6 }, "Armadilha! -6 HP.")
                  end
              end },
            { label = "Deixar quieta", apply = function() return T("mochila_abandonada", "r_leave", nil, "Voce prossegue.") end },
        },
    },
    {
        id = "mistery_node",
        act = "any",
        title = "Nevoa Estranha",
        body  = "Uma nevoa estranha te envolve. Voce desperta diferente...",
        options = {
            { label = "Aceitar",
              gains = { { k = "mystery", fb = "efeito misterioso" } },
              apply = function(game)
                  -- Usa o mystery do EffectSystem
                  local effect = { type = "mystery" }
                  game.effectSystem:processEffectCard(game, effect)
                  return T("mistery_node", "r_accept", nil, "Algo mudou em voce.")
              end },
            { label = "Resistir", apply = function() return T("mistery_node", "r_resist", nil, "A nevoa dissipa.") end },
        },
    },

    -- ========== Eventos de DECK (Jul/2026 — o evento mexe no build, padrão
    -- StS: remover/duplicar/forjar valem mais que ouro no longo prazo) ==========
    {
        id = "escriba_errante",
        act = "any",
        title = "Escriba Errante",
        body  = "Um escriba de dedos manchados oferece: 'posso riscar uma pagina do seu grimorio. Para sempre.'",
        options = {
            { label = "Riscar uma pagina",
              gains = { { k = "remove_choice", n = 1, fb = "remova 1 carta A SUA ESCOLHA" } },
              apply = function(game)
                  if _G.openCardPicker then
                      _G.openCardPicker("remove")
                      -- O picker abre POR CIMA; este texto aparece ao voltar.
                      return T("escriba_errante", "r_sealed", nil, "O acordo foi selado.")
                  end
                  return T("escriba_errante", "r_distracted", nil, "O escriba se distrai e parte.")
              end },
            { label = "Guardar o grimorio",
              apply = function() return T("escriba_errante", "r_shrug", nil, "O escriba da de ombros.") end },
        },
    },
    {
        id = "espelho_de_tinta",
        act = "any",
        title = "Espelho de Tinta",
        body  = "Uma poca de tinta espelhada reflete o seu grimorio. Uma das paginas parece... copiavel.",
        options = {
            { label = "Mergulhar uma pagina",
              gains = { { k = "dup_choice", n = 1, fb = "duplique 1 carta A SUA ESCOLHA" } },
              apply = function(game)
                  if _G.openCardPicker then
                      _G.openCardPicker("duplicate")
                      return T("espelho_de_tinta", "r_copy", nil, "A tinta guarda a sua copia.")
                  end
                  return T("espelho_de_tinta", "r_fail", nil, "A tinta escorre e o reflexo se desfaz.")
              end },
            { label = "Nao tocar",
              apply = function() return T("espelho_de_tinta", "r_leave", nil, "A tinta espelhada seca lentamente.") end },
        },
    },
    {
        id = "forja_abandonada",
        act = "any",
        title = "Forja Abandonada",
        body  = "Um ferreiro partiu as pressas: a forja ainda esta QUENTE. Da tempo de um unico trabalho.",
        options = {
            { label = "Usar a forja",
              gains = { { k = "forge_choice", fb = "forje +1 em carta A SUA ESCOLHA" } },
              apply = function(game)
                  if _G.openCardPicker then
                      _G.openCardPicker("forge")
                      return T("forja_abandonada", "r_forge", nil, "O metal ainda canta com o seu trabalho.")
                  end
                  return T("forja_abandonada", "r_fail", nil, "As brasas apagam antes de voce comecar.")
              end },
            { label = "Seguir viagem",
              apply = function() return T("forja_abandonada", "r_leave", nil, "O calor fica para tras.") end },
        },
    },
    {
        id = "mercador_sangue",
        act = "any",
        title = "Mercador de Sangue",
        body  = "Um mercador palido pesa moedas numa balanca de ossos. 'Sangue por ouro. Ouro por sangue. Escolha o prato.'",
        options = {
            { label = "Vender sangue",
              gains = { { k = "gold", n = 45, fb = "$45" } }, costs = { { k = "hp", n = 12, fb = "12 HP" } },
              apply = function(game)
                  if game.player.health <= 12 then
                      return T("mercador_sangue", "r_too_weak", nil, "Voce esta fraco demais para vender sangue.")
                  end
                  game.player:takeDamage(12)
                  game.economySystem.currentGold = game.economySystem.currentGold + 45
                  return T("mercador_sangue", "r_sold", { n = 45 }, "A balanca pende. +45 ouro.")
              end },
            { label = "Comprar vigor",
              gains = { { k = "heal_flat", n = 15, fb = "cura 15 HP" } }, costs = { { k = "gold", n = 30, fb = "$30" } },
              apply = function(game)
                  if game.economySystem.currentGold < 30 then
                      return T("mercador_sangue", "r_no_gold", { n = 30 }, "Voce nao tem 30 ouros.")
                  end
                  game.economySystem.currentGold = game.economySystem.currentGold - 30
                  game.player:heal(15)
                  return T("mercador_sangue", "r_vigor", { n = 15 }, "O vigor volta as suas veias. +15 HP.")
              end },
            { label = "Recusar o prato",
              apply = function() return T("mercador_sangue", "r_refuse", nil, "O mercador guarda a balanca, decepcionado.") end },
        },
    },
}

-- Sorteia um evento do pool para um ato especifico (ou "any").
-- history: run.eventHistory ({ [id] = actNumber }) — evento visto NO MESMO ATO
-- não repete; pool esgotada no ato libera repetição (melhor que evento nenhum).
-- Stream "event" do Rng da run (reprodutível por seed).
function Events.roll(actNumber, history)
    local valid = {}
    for _, e in ipairs(Events.POOL) do
        local actOk = (e.act == "any" or e.act == actNumber)
        local seenThisAct = history and history[e.id] == actNumber
        if actOk and not seenThisAct then
            table.insert(valid, e)
        end
    end
    if #valid == 0 then
        for _, e in ipairs(Events.POOL) do
            if e.act == "any" or e.act == actNumber then
                table.insert(valid, e)
            end
        end
    end
    if #valid == 0 then return nil end
    return Rng.get():pick("event", valid)
end

return Events
