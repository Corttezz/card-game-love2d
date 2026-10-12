-- src/data/run_modifiers.lua
-- DADOS dos modificadores de corrida (Out/2026): os SELOS DO GRIMÓRIO
-- (dificuldade escolhida na seleção de classe, estilo Ascensão) e as
-- MALDIÇÕES do endless (mutadores que o jogador escolhe 1-de-2 a cada ciclo).
-- O COMPORTAMENTO mora em src/systems/RunModifiers.lua; o desenho e a
-- pesquisa (Balatro/StS/Monster Train/Hades) em memory/endless_and_seals.md.
--
-- Cada regra é um par (campo, valor) que RunModifiers soma ou multiplica:
--   eliteWeight  ×  peso de elite no mapa
--   restHeal     ×  cura da fogueira
--   actHeal      ×  cura entre atos / entre ciclos do endless
--   price        ×  todo preço da loja (cartas, relíquias, pacotes, reroll)
--   hpNormal     ×  vida de inimigo comum e elite
--   hpBoss       ×  vida de chefe e mini-chefe
--   dmgElite     ×  dano de elite
--   dmgAll       ×  dano de todo inimigo
--   hpAll        ×  vida de todo inimigo
--   startGold    =  ouro inicial (substitui os $10)
--   victoryGold  +  ouro da vitória por batalha (negativo = menos)
--   rewardCards  +  cartas na recompensa pós-batalha (negativo = menos)
--   enemyBlock   +  Bloqueio inicial do inimigo, em fração da vida máxima
-- Textos: i18n `seals.<id>.name/desc` e `endless_curses.<id>.name/desc`.

local M = {}

-- SELOS: CUMULATIVOS (o selo 5 traz as regras de 1 a 5). Um por nível, na
-- ordem em que entram. Cada um mexe num sistema diferente de propósito: o
-- jogador sente cada degrau, em vez de "+5% de vida" dez vezes.
M.SEALS = {
    { id = "cerco",            rules = { eliteWeight = 1.5 } },
    { id = "cura_escassa",     rules = { restHeal = 0.75 } },
    { id = "mercado_caro",     rules = { price = 1.15 } },
    { id = "hordas",           rules = { hpNormal = 1.10 } },
    { id = "chefes_couracados", rules = { hpBoss = 1.15 } },
    { id = "feridas_abertas",  rules = { actHeal = 0.5 } },
    { id = "bolsa_leve",       rules = { startGold = 0, victoryGold = -1 } },
    { id = "elites_ferozes",   rules = { dmgElite = 1.15 } },
    { id = "escolha_curta",    rules = { rewardCards = -1 } },
    { id = "ultimo_selo",      rules = { dmgAll = 1.10 } },
}

-- MALDIÇÕES do endless: EMPILHÁVEIS (a mesma pode ser escolhida de novo e
-- conta por acúmulo). `score` = bônus de pontuação por acúmulo — é o que paga
-- o risco (Balatro paga a aposta maior com a própria pontuação). `max` =
-- teto de acúmulos (some do sorteio ao bater).
M.CURSES = {
    { id = "vigor_profano",   score = 0.20, max = 6, rules = { hpAll = 1.15 } },
    { id = "laminas",         score = 0.25, max = 6, rules = { dmgAll = 1.10 } },
    { id = "couraca_abissal", score = 0.20, max = 4, rules = { enemyBlock = 0.08 } },
    { id = "cacada",          score = 0.15, max = 3, rules = { eliteWeight = 2.0 } },
    { id = "dizimo",          score = 0.15, max = 4, rules = { price = 1.25 } },
    { id = "fome",            score = 0.20, max = 3, rules = { restHeal = 0.70, actHeal = 0.70 } },
}

-- Bônus de pontuação por nível de selo (+10% por selo).
M.SEAL_SCORE = 0.10

return M
