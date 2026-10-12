-- src/data/enemies.lua
-- ============================================================================
-- INIMIGOS — roster por ato + kit de golpes por criatura (Out/2026)
-- ============================================================================
-- Auditoria de conteúdo (Out/2026): TODO inimigo jogava igual. Havia uma
-- tabela de intents só (atacar / golpe forte ×1.6 / defender / +2 de dano)
-- dividida pelas 21 criaturas, e a identidade de cada uma morava apenas no
-- sprite. Ninguém debuffava o jogador, ninguém batia várias vezes, nenhum
-- golpe tinha nome, e o chefe era um saco de vida maior.
--
-- Este arquivo é DADO PURO (sem lógica). Quem lê: src/systems/EnemyRoster.lua
-- (sorteio do roster) e src/entities/Enemy.lua (rolagem e execução do golpe).
--
-- ── KIT (chave = id do sprite, a mesma do EnemyRenderer) ───────────────────
--   hpMul / dmgMul   escala sobre a curva do ato (ActSystem). Gosma = parruda
--                    e fraca; diabrete = frágil e venenoso.
--   opener           golpe do PRIMEIRO turno (o cartão de visita da criatura).
--   moves            golpes sorteáveis (ver abaixo).
--   phases           { { at = 0.5, id, dmgMul, moves, opener } } — troca de
--                    kit ao cruzar a fração de vida (Rainha do Eclipse).
--   passive          { regenPct } — estado permanente desde o 1º turno.
--
-- ── GOLPE ───────────────────────────────────────────────────────────────────
--   id        chave i18n `enemy_kit.moves.<id>` (nome + descrição no tooltip).
--   kind      categoria de LEITURA (ícone do HUD): attack | strong | multi |
--             defend | buff | debuff | heal | charge | summon.
--             A execução lê os CAMPOS, não o kind — um golpe pode ter dano,
--             bloqueio e debuff juntos ("bloqueia e golpeia").
--   weight    peso no sorteio (stream "enemy" do Rng).
--   mult      dano POR GOLPE = floor(dano do inimigo × mult).
--   hits      quantos golpes (multi). Bloqueio absorve cada um, mas o teto de
--             Bloqueio por ato faz a soma vazar.
--   swarm     hits += pilhas do status `swarm` do inimigo (revoada).
--   pierce    ignora o Bloqueio do jogador.
--   armor     bloqueio ganho = getDefendAmount() × armor.
--   strength  +dano PERMANENTE = max(2, floor(dano base × strength)).
--   heal      cura = floor(vida máxima × heal).
--   debuff    { name, duration, stacks } NO JOGADOR: weak (−25% no dano dos
--             seus ataques), frail (−25% no Bloqueio das suas defesas),
--             vulnerable (+50% de dano recebido), poison / burn (dano por
--             turno que ignora Bloqueio). Pode ser lista (vários debuffs).
--   summon    pilhas de `swarm` somadas ao inimigo.
--   next      id do golpe FORÇADO no turno seguinte (carga → golpe).
--   every     forçado a cada N turnos (turno % every == 0).
--   minTurn   não sai antes deste turno.
--   maxRow    máximo de usos seguidos (padrão 2; o 3º igual é proibido).
--
-- INVARIANTE (CLAUDE.md §6): o intent é CONGELADO no anúncio. O número que o
-- jogador vê no HUD é o teto do que acontece — Fúria/buff entre o anúncio e a
-- execução só valem no próximo intent.
-- ============================================================================

local Enemies = {}

-- ── ROSTER POR ATO ──────────────────────────────────────────────────────────
-- Cada ato: 2+ comuns, 1+ elite, mini-chefe DISTINTO do elite, 1 chefe.
-- Sorteio pelo stream "enemy", sem repetir o último inimigo enfrentado.
-- Sprites emprestados de outros atos só onde o tema casa, até chegarem os
-- novos (frente "inimigos-arte"): a gosma e o carniçal nas catacumbas, o
-- golem de pedra e o espectro na torre, a sombra no abismo.
Enemies.ROSTER = {
    [1] = { battle = { "cursed_scarecrow", "grave_slime" },
            elite = { "harvest_reaper" },
            mini_boss = { "bog_ghoul" },
            boss = { "carrion_king" } },
    [2] = { battle = { "moon_gargoyle", "stone_golem" },
            elite = { "rune_golem" },
            mini_boss = { "abyss_wraith" },
            boss = { "tower_lich" } },
    [3] = { battle = { "ember_imp", "dusk_shade" },
            elite = { "obsidian_sentinel" },
            mini_boss = { "blood_duke" },
            boss = { "abyss_tyrant" } },
    [4] = { battle = { "frost_wight", "stone_golem" },
            elite = { "glacier_knight" },
            mini_boss = { "moon_gargoyle" },
            boss = { "winter_monarch" } },
    [5] = { battle = { "bog_ghoul", "grave_slime" },
            elite = { "mire_hag" },
            mini_boss = { "harvest_reaper" },
            boss = { "rot_colossus" } },
    [6] = { battle = { "dusk_shade", "abyss_wraith" },
            elite = { "blood_duke" },
            mini_boss = { "obsidian_sentinel" },
            boss = { "eclipse_queen" } },
}

-- ── KITS ────────────────────────────────────────────────────────────────────
local W, F, V = "weak", "frail", "vulnerable"

Enemies.KITS = {
    -- Kit legado: os quatro intents de antes, para Enemy:new sem kit (testes,
    -- modo clássico). Mesmos pesos e mesma regra de pressão.
    generic = {
        moves = {
            { id = "attack", kind = "attack", weight = 50, mult = 1.0 },
            { id = "strong", kind = "strong", weight = 16, mult = 1.6 },
            { id = "defend", kind = "defend", weight = 18, armor = 1.0 },
            { id = "buff",   kind = "buff",   weight = 16, strengthFlat = 2 },
        },
    },

    -- ===================== ATO 1 — CATACUMBAS =====================
    cursed_scarecrow = {
        opener = "dread_stare",
        moves = {
            { id = "rusty_scythe", kind = "attack", weight = 40, mult = 1.1 },
            { id = "crow_pecks",   kind = "multi",  weight = 30, mult = 0.45, hits = 3 },
            { id = "dread_stare",  kind = "attack", weight = 15, mult = 0.6,
              debuff = { name = W, duration = 2 }, maxRow = 1 },
            { id = "straw_wall",   kind = "defend", weight = 15, armor = 1.0, maxRow = 1 },
        },
    },
    grave_slime = {
        hpMul = 1.3, dmgMul = 0.85,
        opener = "acid_spit",
        moves = {
            { id = "slime_crush", kind = "attack", weight = 40, mult = 1.1 },
            { id = "acid_spit",   kind = "attack", weight = 30, mult = 0.7,
              debuff = { name = F, duration = 2 }, maxRow = 1 },
            { id = "swell",       kind = "buff",   weight = 15, strength = 0.25,
              armor = 0.6, maxRow = 1 },
            { id = "ooze_split",  kind = "multi",  weight = 15, mult = 0.4, hits = 3 },
        },
    },
    harvest_reaper = {
        hpMul = 1.0, dmgMul = 1.0,
        opener = "reaper_mark",
        moves = {
            { id = "reap",        kind = "strong", weight = 30, mult = 1.6 },
            { id = "harvest",     kind = "multi",  weight = 30, mult = 0.5, hits = 3 },
            { id = "reaper_mark", kind = "debuff", weight = 15,
              debuff = { name = V, duration = 2 }, maxRow = 1, minTurn = 1 },
            { id = "whetstone",   kind = "buff",   weight = 25, strength = 0.2,
              armor = 0.8, maxRow = 1 },
        },
    },
    bog_ghoul = {
        hpMul = 1.1,
        opener = "infected_bite",
        moves = {
            { id = "rotten_claw",   kind = "attack", weight = 40, mult = 1.1 },
            { id = "infected_bite", kind = "attack", weight = 30, mult = 0.6,
              debuff = { name = "poison", stacks = 3, duration = 2 }, maxRow = 1 },
            { id = "gorge",         kind = "attack", weight = 15, mult = 0.8,
              heal = 0.08, maxRow = 1 },
            { id = "frenzy",        kind = "multi",  weight = 15, mult = 0.4, hits = 4 },
        },
    },
    -- CHEFE A1 — invoca a revoada: cada Chamado soma corvos, e a Revoada bate
    -- uma vez por corvo. Quanto mais a luta demora, mais golpes por turno.
    carrion_king = {
        opener = "call_of_crows",
        moves = {
            { id = "call_of_crows", kind = "summon", weight = 0, summon = 2,
              armor = 0.8, every = 4 },
            { id = "murder_of_crows", kind = "multi", weight = 45, mult = 0.35,
              hits = 2, swarm = true, debuff = { name = W, duration = 1 } },
            { id = "royal_peck",   kind = "attack", weight = 35, mult = 1.2 },
            { id = "carrion_feast", kind = "heal",  weight = 20, heal = 0.08,
              armor = 0.6, maxRow = 1, minTurn = 3 },
        },
    },

    -- ===================== ATO 2 — TORRE DE PEDRA =====================
    moon_gargoyle = {
        opener = "lunar_shriek",
        moves = {
            { id = "stone_talons", kind = "attack", weight = 35, mult = 1.1 },
            { id = "dive",         kind = "strong", weight = 25, mult = 1.6 },
            { id = "stone_skin",   kind = "attack", weight = 20, mult = 0.6,
              armor = 0.9, maxRow = 1 },
            { id = "lunar_shriek", kind = "debuff", weight = 20,
              debuff = { name = W, duration = 2 }, maxRow = 1 },
        },
    },
    stone_golem = {
        hpMul = 1.35, dmgMul = 0.9,
        moves = {
            { id = "stone_fist",  kind = "attack", weight = 40, mult = 1.1 },
            { id = "stone_wall",  kind = "defend", weight = 20, armor = 1.4, maxRow = 1 },
            { id = "gather_mass", kind = "charge", weight = 25, armor = 0.6,
              next = "crushing_blow", maxRow = 1, minTurn = 2 },
            { id = "crushing_blow", kind = "strong", weight = 0, mult = 2.2 },
            { id = "tremor",      kind = "multi",  weight = 15, mult = 0.35, hits = 3,
              debuff = { name = F, duration = 1 } },
        },
    },
    rune_golem = {
        hpMul = 1.1,
        opener = "rune_ward",
        moves = {
            { id = "rune_ward",  kind = "attack", weight = 25, mult = 0.7,
              armor = 1.2, maxRow = 1 },
            { id = "rune_bolt",  kind = "strong", weight = 30, mult = 0.9, pierce = true },
            { id = "overcharge", kind = "buff",   weight = 15, strength = 0.25, maxRow = 1 },
            { id = "slam",       kind = "attack", weight = 30, mult = 1.2 },
        },
    },
    abyss_wraith = {
        hpMul = 0.95, dmgMul = 1.05,
        opener = "wail",
        moves = {
            { id = "chill_touch", kind = "attack", weight = 35, mult = 0.9,
              debuff = { name = F, duration = 2 } },
            { id = "wail",        kind = "debuff", weight = 20,
              debuff = { { name = W, duration = 2 }, { name = V, duration = 1 } },
              maxRow = 1 },
            { id = "life_drain",  kind = "attack", weight = 25, mult = 1.0, heal = 0.08 },
            { id = "phantom_slash", kind = "multi", weight = 20, mult = 0.4, hits = 3 },
        },
    },
    -- CHEFE A2 — escudo de gelo a cada 3º turno (a janela de burst é o turno
    -- SEGUINTE, quando o escudo cai) e drena: Fragilidade + cura.
    tower_lich = {
        opener = "essence_drain",
        moves = {
            { id = "frost_shield",  kind = "defend", weight = 0, armor = 1.8,
              debuff = { name = F, duration = 2 }, every = 3 },
            { id = "essence_drain", kind = "attack", weight = 35, mult = 0.8,
              heal = 0.06, debuff = { name = F, duration = 2 } },
            { id = "necrotic_ray",  kind = "strong", weight = 35, mult = 1.4 },
            { id = "bone_volley",   kind = "multi",  weight = 30, mult = 0.4, hits = 4 },
        },
    },

    -- ===================== ATO 3 — ABISMO =====================
    ember_imp = {
        hpMul = 0.85, dmgMul = 1.0,
        opener = "fireball",
        moves = {
            { id = "fireball", kind = "attack", weight = 35, mult = 0.8,
              debuff = { name = "burn", stacks = 3, duration = 2 } },
            { id = "scratch",  kind = "multi",  weight = 30, mult = 0.4, hits = 3 },
            { id = "cackle",   kind = "buff",   weight = 15, strength = 0.2, maxRow = 1 },
            { id = "ember_jab", kind = "attack", weight = 20, mult = 1.2 },
        },
    },
    dusk_shade = {
        opener = "whisper",
        moves = {
            { id = "shadow_blade", kind = "attack", weight = 35, mult = 1.1 },
            { id = "fade",         kind = "defend", weight = 15, armor = 1.2, maxRow = 1 },
            { id = "umbral_cut",   kind = "strong", weight = 30, mult = 0.8, pierce = true },
            { id = "whisper",      kind = "attack", weight = 20, mult = 0.5,
              debuff = { name = W, duration = 2 }, maxRow = 1 },
        },
    },
    obsidian_sentinel = {
        hpMul = 1.15,
        opener = "bulwark",
        moves = {
            { id = "obsidian_strike", kind = "strong", weight = 30, mult = 1.5 },
            { id = "bulwark",         kind = "attack", weight = 25, mult = 0.6,
              armor = 1.5, maxRow = 1 },
            { id = "shard_burst",     kind = "multi",  weight = 30, mult = 0.35, hits = 4 },
            { id = "glare",           kind = "debuff", weight = 15,
              debuff = { name = F, duration = 2 }, maxRow = 1 },
        },
    },
    blood_duke = {
        hpMul = 1.0, dmgMul = 1.05,
        opener = "blood_feast",
        moves = {
            { id = "blood_drain",    kind = "attack", weight = 35, mult = 1.0, heal = 0.08 },
            { id = "hemorrhage",     kind = "multi",  weight = 30, mult = 0.45, hits = 3,
              debuff = { name = V, duration = 1 } },
            { id = "blood_feast",    kind = "buff",   weight = 15, strength = 0.25,
              heal = 0.05, maxRow = 1 },
            { id = "noble_thrust",   kind = "strong", weight = 20, mult = 1.5 },
        },
    },
    -- CHEFE A3 — carrega o Fogo Infernal: um turno inteiro telegrafando, o
    -- golpe seguinte é o maior da luta e queima.
    abyss_tyrant = {
        opener = "abyssal_claws",
        moves = {
            { id = "gather_flames", kind = "charge", weight = 0, armor = 1.0,
              next = "hellfire", every = 3 },
            { id = "hellfire",      kind = "strong", weight = 0, mult = 2.4,
              debuff = { name = "burn", stacks = 4, duration = 3 } },
            { id = "abyssal_claws", kind = "attack", weight = 50, mult = 1.1 },
            { id = "cinder_spray",  kind = "multi",  weight = 50, mult = 0.4, hits = 3,
              debuff = { name = "burn", stacks = 2, duration = 2 } },
        },
    },

    -- ===================== ATO 4 — CIDADELA GELADA =====================
    frost_wight = {
        opener = "freezing_touch",
        moves = {
            { id = "freezing_touch", kind = "attack", weight = 30, mult = 0.8,
              debuff = { name = F, duration = 2 }, maxRow = 1 },
            { id = "wight_claw",     kind = "attack", weight = 40, mult = 1.15 },
            { id = "blizzard",       kind = "multi",  weight = 30, mult = 0.4, hits = 3 },
        },
    },
    glacier_knight = {
        hpMul = 1.1,
        moves = {
            { id = "ice_lance",     kind = "strong", weight = 35, mult = 0.9, pierce = true },
            { id = "glacial_aegis", kind = "attack", weight = 25, mult = 0.7,
              armor = 1.5, maxRow = 1 },
            { id = "charge",        kind = "strong", weight = 25, mult = 1.6 },
            { id = "rime",          kind = "debuff", weight = 15,
              debuff = { name = F, duration = 2 }, maxRow = 1 },
        },
    },
    -- CHEFE A4 — lâminas que atravessam o Bloqueio e um inverno que fragiliza
    -- tudo a cada 3º turno.
    winter_monarch = {
        opener = "winter_blade",
        moves = {
            { id = "eternal_winter", kind = "debuff", weight = 0, armor = 1.2,
              debuff = { { name = F, duration = 2 }, { name = W, duration = 2 } },
              every = 3 },
            { id = "winter_blade",   kind = "strong", weight = 40, mult = 0.85, pierce = true },
            { id = "royal_blizzard", kind = "multi",  weight = 35, mult = 0.4, hits = 4 },
            { id = "frozen_crown",   kind = "attack", weight = 25, mult = 1.2 },
        },
    },

    -- ===================== ATO 5 — CORAÇÃO PÚTRIDO =====================
    mire_hag = {
        hpMul = 1.05,
        opener = "hex",
        moves = {
            { id = "hex",           kind = "debuff", weight = 20,
              debuff = { { name = W, duration = 2 }, { name = F, duration = 2 } },
              maxRow = 1 },
            { id = "toxic_cauldron", kind = "attack", weight = 30, mult = 0.6,
              debuff = { name = "poison", stacks = 4, duration = 3 } },
            { id = "crooked_cane",  kind = "attack", weight = 35, mult = 1.2 },
            { id = "bog_brew",      kind = "heal",   weight = 15, heal = 0.12,
              maxRow = 1, minTurn = 2 },
        },
    },
    -- CHEFE A5 — nuvens de peste no jogador e regeneração própria: a luta
    -- longa é dele.
    rot_colossus = {
        hpMul = 1.0,
        passive = { regenPct = 0.03 },
        opener = "plague_cloud",
        moves = {
            { id = "plague_cloud", kind = "debuff", weight = 25,
              debuff = { name = "poison", stacks = 5, duration = 3 }, maxRow = 1 },
            { id = "colossal_slam", kind = "strong", weight = 30, mult = 1.5 },
            { id = "putrid_blow",  kind = "attack", weight = 30, mult = 1.0,
              debuff = { name = "poison", stacks = 3, duration = 2 } },
            { id = "regrow",       kind = "heal",   weight = 15, heal = 0.07,
              armor = 0.8, maxRow = 1, minTurn = 2 },
        },
    },

    -- ===================== ATO 6 — CORTE DO ECLIPSE =====================
    -- CHEFE A6 — duas lutas numa: abaixo de 50% de vida o ECLIPSE fecha, o
    -- kit troca e o dano sobe.
    eclipse_queen = {
        opener = "waning_light",
        moves = {
            { id = "waning_light", kind = "attack", weight = 35, mult = 1.0,
              debuff = { name = W, duration = 1 } },
            { id = "lunar_blades", kind = "multi",  weight = 35, mult = 0.4, hits = 3 },
            { id = "veil",         kind = "defend", weight = 30, armor = 1.3, maxRow = 1 },
        },
        phases = {
            { at = 0.5, id = "eclipse", dmgMul = 1.3, opener = "total_eclipse",
              moves = {
                  { id = "total_eclipse", kind = "debuff", weight = 0,
                    debuff = { { name = W, duration = 2 }, { name = F, duration = 2 },
                               { name = V, duration = 1 } } },
                  { id = "black_corona",  kind = "strong", weight = 35, mult = 1.0,
                    pierce = true },
                  { id = "star_rain",     kind = "multi",  weight = 35, mult = 0.45, hits = 4 },
                  { id = "void_embrace",  kind = "attack", weight = 30, mult = 1.3,
                    heal = 0.05 },
              } },
        },
    },
}

-- Status que o inimigo põe no JOGADOR (fonte única do contrato com Player/HUD).
Enemies.PLAYER_DEBUFFS = { weak = true, frail = true, vulnerable = true,
    poison = true, burn = true }

return Enemies
