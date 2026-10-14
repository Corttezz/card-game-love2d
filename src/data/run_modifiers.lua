local M = {}

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

M.CURSES = {
    { id = "vigor_profano",   score = 0.20, max = 6, rules = { hpAll = 1.15 } },
    { id = "laminas",         score = 0.25, max = 6, rules = { dmgAll = 1.10 } },
    { id = "couraca_abissal", score = 0.20, max = 4, rules = { enemyBlock = 0.08 } },
    { id = "cacada",          score = 0.15, max = 3, rules = { eliteWeight = 2.0 } },
    { id = "dizimo",          score = 0.15, max = 4, rules = { price = 1.25 } },
    { id = "fome",            score = 0.20, max = 3, rules = { restHeal = 0.70, actHeal = 0.70 } },
}

M.SEAL_SCORE = 0.10

return M
