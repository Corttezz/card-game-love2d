-- src/data/unlocks.lua
-- DADOS do sistema de desbloqueio (lógica em src/systems/UnlockSystem.lua).
-- Tabelas puras, sem lógica. Ver memory/unlocks.md.
--
-- Filosofia (StS "Unlock" por classe + marcos Balatro):
--   * Todo card que NÃO aparece aqui vem LIBERADO de fábrica. O núcleo liberado
--     de cada classe mantém ~60% do pool por raridade (8 comuns, 8-12 incomuns,
--     5-7 raras) — as ofertas continuam com variedade desde a 1ª run.
--   * Cada classe tem 5 NÍVEIS DE MAESTRIA; cada nível libera um pacote
--     temático de 3 cartas da própria classe. XP vem do quanto a run andou
--     (andares, chefes, vitória) — morrer cedo também conta, só conta menos.
--   * As 3 lendárias neutras (joker_001..003) são MARCOS (Balatro): saem de
--     feitos, não de XP, e valem pra qualquer classe.
--   * Starters (ver CardRegistry:getStarterDeckForClass) e cartas concedidas
--     por evento (effect_healing_potion) NUNCA podem entrar aqui — o teste
--     test_unlocks trava isso.

local U = {}

-- XP pra passar DO nível N pro N+1 (índice = nível atual). 5 níveis no total:
-- 100 → 250 → 450 → 700 → 1000 de XP acumulado. Uma vitória completa (6 atos)
-- rende ~870 XP; uma morte no ato 2 rende ~150.
U.LEVEL_COSTS = { 100, 150, 200, 250, 300 }

-- Composição do XP de uma run (ver UnlockSystem.computeRunXP).
U.XP = {
    PER_FLOOR    = 10,   -- por andar alcançado (ato-1)*8 + andar
    PER_ACT      = 40,   -- por ato completado (chefe do ato vencido)
    VICTORY      = 150,  -- bônus de vitória
    PER_ENDLESS  = 15,   -- por andar do endless
    MINIMUM      = 20,   -- piso: nenhuma run sai de mãos vazias
}

-- Pacotes por classe. bundles[n] = cartas liberadas ao ATINGIR o nível n.
-- `theme` é a chave i18n `unlocks.bundle.<classe>_<n>` (nome do pacote no reveal).
U.CLASS_BUNDLES = {
    warrior = {
        { theme = "warrior_1", cards = { "warrior_flame_barrier", "warrior_taunt", "warrior_juggernaut" } },
        { theme = "warrior_2", cards = { "warrior_feed", "warrior_bloodletting", "warrior_helm_of_valor" } },
        { theme = "warrior_3", cards = { "warrior_rage", "warrior_war_cry", "warrior_berserk" } },
        { theme = "warrior_4", cards = { "warrior_immolate", "warrior_ghostly_armor", "warrior_power_through" } },
        { theme = "warrior_5", cards = { "warrior_demon_form", "warrior_spot_weakness", "warrior_eternal_bulwark" } },
    },
    mage = {
        { theme = "mage_1", cards = { "mage_blizzard", "mage_frost_nova", "mage_rainbow" } },
        { theme = "mage_2", cards = { "mage_ball_lightning", "mage_overcharge", "mage_electrodynamics" } },
        { theme = "mage_3", cards = { "mage_doom_and_gloom", "mage_dark_harvest", "mage_echo_form" } },
        { theme = "mage_4", cards = { "mage_fission", "mage_arcane_torrent", "mage_flame_tongue" } },
        { theme = "mage_5", cards = { "mage_meteor_strike", "mage_healing_drop", "mage_primordial_storm" } },
    },
    rogue = {
        { theme = "rogue_1", cards = { "rogue_bouncing_flask", "rogue_catalyst", "rogue_envenom" } },
        { theme = "rogue_2", cards = { "rogue_stiletto", "rogue_accuracy", "rogue_a_thousand_cuts" } },
        { theme = "rogue_3", cards = { "rogue_shadow_dance", "rogue_moonshadow", "rogue_after_image" } },
        { theme = "rogue_4", cards = { "rogue_corpse_explosion", "rogue_executioner", "rogue_expose_weakness" } },
        { theme = "rogue_5", cards = { "rogue_rake", "rogue_calculated_gamble", "rogue_toxin_master" } },
    },
}

-- Marcos (cartas neutras). `kind`:
--   act_cleared  — vencer o chefe do ato `n` com qualquer classe
--   victory      — vencer uma run
--   reach_act    — chegar ao ato `n`
U.MILESTONES = {
    { card = "joker_001", kind = "act_cleared", n = 1 },
    { card = "joker_002", kind = "reach_act",   n = 4 },
    { card = "joker_003", kind = "victory" },
}

-- Desbloqueio de CLASSES. Guerreiro sempre liberado.
--   mage  — completar o Ato 2 (vencer o chefe do ato 2) com qualquer classe
--   rogue — completar o Ato 4 OU vencer uma run
-- reqKey/vars: chaves do bloco `unlock.class.*` dos locales (frente classes).
U.CLASSES = {
    warrior = { always = true, reqKey = "unlock.class.default" },
    mage    = { actCleared = 2, reqKey = "unlock.class.mage_req",  vars = { act = 2 } },
    rogue   = { actCleared = 4, orVictory = true,
                reqKey = "unlock.class.rogue_req", vars = { act = 4 } },
}

U.CLASS_ORDER = { "warrior", "mage", "rogue" }

return U
