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
-- Cada ato: 3 comuns, 2 elites, mini-chefe DISTINTO dos elites, 1 chefe.
-- Sorteio pelo stream "enemy", sem repetir o último inimigo enfrentado.
-- REGRA (dono, Out/2026): só criatura DO BIOMA do ato — nada de emprestar
-- sprite de outro ato ("monstros sem relação com o bioma"). A fonte da
-- pertença é HOME_BIOME abaixo; test_enemies cruza as duas tabelas.
Enemies.ROSTER = {
    [1] = { battle = { "cursed_scarecrow", "hollow_farmer", "plague_rats" },
            elite = { "harvest_reaper", "blight_bull" },
            mini_boss = { "wicker_effigy" },
            boss = { "carrion_king" } },
    [2] = { battle = { "moon_gargoyle", "ram_cultist", "storm_harpy" },
            elite = { "rune_golem", "spectral_knight" },
            mini_boss = { "storm_griffin" },
            boss = { "tower_lich" } },
    [3] = { battle = { "ember_imp", "hellhound", "abyss_acolyte" },
            elite = { "obsidian_sentinel", "pit_brute" },
            mini_boss = { "abyss_watcher" },
            boss = { "abyss_tyrant" } },
    [4] = { battle = { "frost_wight", "frost_wolf", "rime_shaman" },
            elite = { "glacier_knight", "frost_troll" },
            mini_boss = { "ice_wyrm" },
            boss = { "winter_monarch" } },
    [5] = { battle = { "bog_ghoul", "plague_toad", "leech_horror" },
            elite = { "mire_hag", "croc_warrior" },
            mini_boss = { "spore_mother" },
            boss = { "rot_colossus" } },
    [6] = { battle = { "dusk_shade", "dusk_bat", "grave_thrall" },
            elite = { "blood_duke", "dullahan" },
            mini_boss = { "fallen_angel" },
            boss = { "eclipse_queen" } },
}

-- Bioma de ORIGEM de cada criatura (o ato cuja arte/cenário ela habita).
-- Declarado à parte do ROSTER de propósito: é o que impede o "empréstimo".
Enemies.HOME_BIOME = {
    cursed_scarecrow = 1, hollow_farmer = 1, plague_rats = 1, harvest_reaper = 1,
    blight_bull = 1, wicker_effigy = 1, carrion_king = 1,
    moon_gargoyle = 2, ram_cultist = 2, storm_harpy = 2, rune_golem = 2,
    spectral_knight = 2, storm_griffin = 2, tower_lich = 2,
    ember_imp = 3, hellhound = 3, abyss_acolyte = 3, obsidian_sentinel = 3,
    pit_brute = 3, abyss_watcher = 3, abyss_tyrant = 3,
    frost_wight = 4, frost_wolf = 4, rime_shaman = 4, glacier_knight = 4,
    frost_troll = 4, ice_wyrm = 4, winter_monarch = 4,
    bog_ghoul = 5, plague_toad = 5, leech_horror = 5, mire_hag = 5,
    croc_warrior = 5, spore_mother = 5, rot_colossus = 5,
    dusk_shade = 6, dusk_bat = 6, grave_thrall = 6, blood_duke = 6,
    dullahan = 6, fallen_angel = 6, eclipse_queen = 6,
}

-- ── ESCALA DE DANO POR ATO (calibrada pela bateria do piloto, Out/2026) ─────
-- As curvas de dano do Config.Acts foram afinadas para o kit ANTIGO, cujo
-- golpe médio valia ~0,76× o dano base (50% ataque, 16% forte ×1,6, resto
-- sem dano). Os kits batem em média ~1,0–1,1× e ainda debuffam — sem esta
-- escala o guerreiro do piloto caiu de 60% para 15% de vitória (morrendo nos
-- chefes dos atos 3-4). O começo SOBE um pouco de propósito: a auditoria
-- mediu 0,0–0,2 de dano sofrido por turno nos atos 1-2 (zero tensão).
Enemies.DAMAGE_SCALE_BY_ACT = { 1.15, 1.10, 0.92, 0.88, 0.84, 0.84 }

-- Chefes por cima da escala do ato: a mecânica-assinatura (carga, perfurante,
-- revoada, peste, eclipse) já é o perigo — com o dano cheio, os chefes dos
-- atos 4-6 respondiam por ~2/3 das mortes do piloto (bateria v4, Out/2026).
Enemies.BOSS_DAMAGE_SCALE = 0.90

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
    -- CHEFE A2 — escudo de gelo a cada 3º turno (a janela de burst é o turno
    -- SEGUINTE, quando o escudo cai) e drena: Fragilidade + cura.
    tower_lich = {
        opener = "essence_drain",
        moves = {
            { id = "frost_shield",  kind = "defend", weight = 0, armor = 1.8,
              debuff = { name = F, duration = 2 }, every = 3 },
            { id = "essence_drain", kind = "attack", weight = 35, mult = 0.8,
              heal = 0.06, debuff = { name = F, duration = 2 } },
            { id = "necrotic_ray",  kind = "strong", weight = 35, mult = 1.3 },
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
              next = "hellfire", every = 4 },
            { id = "hellfire",      kind = "strong", weight = 0, mult = 1.7,
              debuff = { name = "burn", stacks = 2, duration = 2 } },
            { id = "abyssal_claws", kind = "attack", weight = 50, mult = 1.1 },
            { id = "cinder_spray",  kind = "multi",  weight = 50, mult = 0.4, hits = 3,
              debuff = { name = "burn", stacks = 2, duration = 1 } },
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
            { id = "winter_blade",   kind = "strong", weight = 40, mult = 0.7, pierce = true },
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
        passive = { regenPct = 0.015 },
        opener = "plague_cloud",
        moves = {
            { id = "plague_cloud", kind = "debuff", weight = 25,
              debuff = { name = "poison", stacks = 4, duration = 3 }, maxRow = 1 },
            { id = "colossal_slam", kind = "strong", weight = 30, mult = 1.35 },
            { id = "putrid_blow",  kind = "attack", weight = 30, mult = 1.0,
              debuff = { name = "poison", stacks = 3, duration = 2 } },
            { id = "regrow",       kind = "heal",   weight = 15, heal = 0.05,
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
            { at = 0.5, id = "eclipse", dmgMul = 1.15, opener = "total_eclipse",
              moves = {
                  { id = "total_eclipse", kind = "debuff", weight = 0,
                    debuff = { { name = W, duration = 2 }, { name = F, duration = 2 },
                               { name = V, duration = 1 } } },
                  { id = "black_corona",  kind = "strong", weight = 35, mult = 0.7,
                    pierce = true },
                  { id = "star_rain",     kind = "multi",  weight = 35, mult = 0.4, hits = 3 },
                  { id = "void_embrace",  kind = "attack", weight = 30, mult = 1.3,
                    heal = 0.05 },
              } },
        },
    },

    -- ===================== CRIATURAS NOVAS (Out/2026, frente inimigos-arte) =====================
    -- A silhueta já anuncia o golpe: o kit segue o conceito que veio com a arte.

    -- ATO 1 — CAMPOS
    hollow_farmer = {   -- camponês oco: ergue o forcado um turno e crava no seguinte
        moves = {
            { id = "pitchfork_jab",    kind = "attack", weight = 40, mult = 1.1 },
            { id = "wind_up",          kind = "charge", weight = 25, armor = 0.5,
              next = "pitchfork_skewer", maxRow = 1, minTurn = 2 },
            { id = "pitchfork_skewer", kind = "strong", weight = 0, mult = 2.0 },
            { id = "hunker",           kind = "defend", weight = 15, armor = 1.0, maxRow = 1 },
            { id = "dread_stare",      kind = "attack", weight = 20, mult = 0.6,
              debuff = { name = W, duration = 2 }, maxRow = 1 },
        },
    },
    plague_rats = {     -- ninhada: muitas mordidas fracas + peste
        hpMul = 0.9,
        opener = "infected_bite",
        moves = {
            { id = "gnaw",          kind = "multi",  weight = 40, mult = 0.35, hits = 3 },
            { id = "infected_bite", kind = "attack", weight = 30, mult = 0.6,
              debuff = { name = "poison", stacks = 3, duration = 2 }, maxRow = 1 },
            { id = "swarm_over",    kind = "multi",  weight = 15, mult = 0.25, hits = 5 },
            { id = "scatter",       kind = "defend", weight = 15, armor = 0.8, maxRow = 1 },
        },
    },
    blight_bull = {     -- touro podre: couro grosso e investida
        hpMul = 1.15,
        opener = "bellow",
        moves = {
            { id = "gore",        kind = "strong", weight = 30, mult = 1.6 },
            { id = "rotten_hide", kind = "attack", weight = 25, mult = 0.7, armor = 1.3, maxRow = 1 },
            { id = "trample",     kind = "multi",  weight = 25, mult = 0.5, hits = 2 },
            { id = "bellow",      kind = "buff",   weight = 20, strength = 0.2, maxRow = 1 },
        },
    },
    wicker_effigy = {   -- gigante de vime em brasa: queima e se atiça
        opener = "kindle",
        moves = {
            { id = "ember_lash",   kind = "attack", weight = 35, mult = 0.8,
              debuff = { name = "burn", stacks = 3, duration = 2 } },
            { id = "kindle",       kind = "buff",   weight = 20, strength = 0.25, maxRow = 1 },
            { id = "wicker_crush", kind = "strong", weight = 25, mult = 1.5 },
            { id = "smoke_screen", kind = "defend", weight = 20, armor = 1.2, maxRow = 1 },
        },
    },

    -- ATO 2 — PLANALTOS
    ram_cultist = {     -- cultista do incensário: enfraquece e expõe
        opener = "dark_hymn",
        moves = {
            { id = "dark_hymn",    kind = "debuff", weight = 25,
              debuff = { { name = W, duration = 2 }, { name = V, duration = 1 } }, maxRow = 1 },
            { id = "censer_swing", kind = "attack", weight = 40, mult = 1.1 },
            { id = "brand",        kind = "attack", weight = 20, mult = 0.6,
              debuff = { name = V, duration = 2 }, maxRow = 1 },
            { id = "prayer",       kind = "heal",   weight = 15, heal = 0.08, armor = 0.6,
              maxRow = 1, minTurn = 2 },
        },
    },
    storm_harpy = {     -- garras à frente: duas, três garradas
        hpMul = 0.9,
        moves = {
            { id = "talon_flurry", kind = "multi",  weight = 45, mult = 0.4, hits = 3 },
            { id = "dive",         kind = "strong", weight = 25, mult = 1.6 },
            { id = "screech",      kind = "debuff", weight = 15,
              debuff = { name = W, duration = 2 }, maxRow = 1 },
            { id = "gust",         kind = "defend", weight = 15, armor = 0.9, maxRow = 1 },
        },
    },
    spectral_knight = { -- escudo-torre: bloqueio alto e contra-golpe
        hpMul = 1.1,
        opener = "tower_shield",
        moves = {
            { id = "tower_shield",   kind = "defend", weight = 25, armor = 1.8, maxRow = 1 },
            { id = "riposte",        kind = "attack", weight = 30, mult = 0.8, armor = 1.0 },
            { id = "spectral_lance", kind = "strong", weight = 25, mult = 0.9, pierce = true },
            { id = "ghost_charge",   kind = "strong", weight = 20, mult = 1.5 },
        },
    },
    storm_griffin = {   -- grifo da tempestade: rajada de garras e trovão
        opener = "thunder_roar",
        moves = {
            { id = "lightning_talons", kind = "multi",  weight = 35, mult = 0.45, hits = 3 },
            { id = "thunder_roar",     kind = "buff",   weight = 20, strength = 0.25,
              armor = 0.6, maxRow = 1 },
            { id = "storm_dive",       kind = "strong", weight = 30, mult = 1.6 },
            { id = "static_shock",     kind = "attack", weight = 15, mult = 0.6,
              debuff = { name = W, duration = 1 } },
        },
    },

    -- ATO 3 — ABISMO
    hellhound = {       -- duas cabeças: duas mordidas e bafo de brasa
        hpMul = 0.95,
        moves = {
            { id = "twin_bite",       kind = "multi",  weight = 45, mult = 0.55, hits = 2 },
            { id = "hellfire_breath", kind = "attack", weight = 30, mult = 0.7,
              debuff = { name = "burn", stacks = 3, duration = 2 }, maxRow = 1 },
            { id = "howl",            kind = "buff",   weight = 15, strength = 0.2, maxRow = 1 },
            { id = "pounce",          kind = "strong", weight = 10, mult = 1.4 },
        },
    },
    abyss_acolyte = {   -- acólito do tomo: amaldiçoa e se fortalece
        opener = "curse",
        moves = {
            { id = "curse",     kind = "debuff", weight = 25,
              debuff = { { name = W, duration = 2 }, { name = F, duration = 2 } }, maxRow = 1 },
            { id = "void_bolt", kind = "attack", weight = 35, mult = 1.1 },
            { id = "dark_pact", kind = "buff",   weight = 20, strength = 0.25, heal = 0.05,
              maxRow = 1 },
            { id = "tome_slam", kind = "attack", weight = 20, mult = 0.8, armor = 0.8 },
        },
    },
    pit_brute = {       -- marreta: ergue um turno, desaba no outro
        hpMul = 1.15,
        moves = {
            { id = "raise_hammer", kind = "charge", weight = 25, armor = 0.8,
              next = "hammer_fall", maxRow = 1 },
            { id = "hammer_fall",  kind = "strong", weight = 0, mult = 2.2 },
            { id = "chain_lash",   kind = "multi",  weight = 40, mult = 0.4, hits = 3 },
            { id = "brute_punch",  kind = "attack", weight = 35, mult = 1.1 },
        },
    },
    abyss_watcher = {   -- massa de sete olhos: loucura e raio
        opener = "gaze_of_madness",
        moves = {
            { id = "gaze_of_madness", kind = "debuff", weight = 25,
              debuff = { { name = W, duration = 2 }, { name = V, duration = 1 },
                         { name = F, duration = 1 } }, maxRow = 1 },
            { id = "eye_ray",         kind = "strong", weight = 30, mult = 1.0, pierce = true },
            { id = "tentacle_lash",   kind = "multi",  weight = 30, mult = 0.35, hits = 4 },
            { id = "blink",           kind = "defend", weight = 15, armor = 1.2, maxRow = 1 },
        },
    },

    -- ATO 4 — CIDADELA GELADA
    frost_wolf = {      -- matilha: mordidas rápidas
        hpMul = 0.9,
        moves = {
            { id = "frost_fangs", kind = "multi",  weight = 45, mult = 0.4, hits = 3 },
            { id = "lunge",       kind = "attack", weight = 35, mult = 1.2 },
            { id = "pack_howl",   kind = "buff",   weight = 20, strength = 0.2, maxRow = 1 },
        },
    },
    rime_shaman = {     -- xamã do totem: enfraquece e se protege
        opener = "chill_hex",
        moves = {
            { id = "chill_hex", kind = "attack", weight = 30, mult = 0.6,
              debuff = { name = W, duration = 2 }, maxRow = 1 },
            { id = "ice_totem", kind = "defend", weight = 25, armor = 1.3, maxRow = 1 },
            { id = "frost_bolt", kind = "attack", weight = 35, mult = 1.1 },
            { id = "blizzard",  kind = "multi",  weight = 10, mult = 0.35, hits = 3 },
        },
    },
    frost_troll = {     -- troll das neves: aguenta e regenera
        hpMul = 1.2,
        passive = { regenPct = 0.02 },
        moves = {
            { id = "club_smash", kind = "strong", weight = 35, mult = 1.5 },
            { id = "troll_hide", kind = "attack", weight = 25, mult = 0.6, armor = 1.4, maxRow = 1 },
            { id = "maul",       kind = "multi",  weight = 25, mult = 0.5, hits = 2 },
            { id = "regenerate", kind = "heal",   weight = 15, heal = 0.08, maxRow = 1, minTurn = 2 },
        },
    },
    ice_wyrm = {        -- serpe: puxa o ar e sopra gelo
        moves = {
            { id = "deep_breath",  kind = "charge", weight = 20, armor = 0.8,
              next = "frost_breath", maxRow = 1, minTurn = 2 },
            { id = "frost_breath", kind = "strong", weight = 25, mult = 1.4,
              debuff = { name = F, duration = 2 } },
            { id = "scale_armor",  kind = "defend", weight = 20, armor = 1.6, maxRow = 1 },
            { id = "tail_sweep",   kind = "multi",  weight = 35, mult = 0.4, hits = 3 },
        },
    },

    -- ATO 5 — CORAÇÃO PÚTRIDO
    plague_toad = {     -- sapo inchado: cospe veneno
        hpMul = 1.05,
        opener = "toxic_spit",
        moves = {
            { id = "toxic_spit",    kind = "attack", weight = 40, mult = 0.6,
              debuff = { name = "poison", stacks = 3, duration = 2 }, maxRow = 1 },
            { id = "tongue_lash",   kind = "attack", weight = 35, mult = 1.1 },
            { id = "bloat",         kind = "defend", weight = 15, armor = 1.0, maxRow = 1 },
            { id = "noxious_croak", kind = "debuff", weight = 10,
              debuff = { { name = "poison", stacks = 3, duration = 2 }, { name = W, duration = 1 } },
              maxRow = 1 },
        },
    },
    leech_horror = {    -- massa de sanguessugas: drena
        moves = {
            { id = "life_drain",  kind = "attack", weight = 45, mult = 0.9, heal = 0.08 },
            { id = "leech_swarm", kind = "multi",  weight = 30, mult = 0.35, hits = 3, heal = 0.04 },
            { id = "engorge",     kind = "buff",   weight = 15, strength = 0.2, heal = 0.05, maxRow = 1 },
            { id = "latch",       kind = "attack", weight = 10, mult = 0.6,
              debuff = { name = W, duration = 1 } },
        },
    },
    croc_warrior = {    -- homem-crocodilo: casco e mordida
        hpMul = 1.1,
        moves = {
            { id = "shell_guard",   kind = "attack", weight = 30, mult = 0.6, armor = 1.5, maxRow = 1 },
            { id = "death_roll",    kind = "strong", weight = 30, mult = 1.6 },
            { id = "spear_thrust",  kind = "attack", weight = 30, mult = 1.1 },
            { id = "crushing_jaws", kind = "strong", weight = 10, mult = 0.9, pierce = true },
        },
    },
    spore_mother = {    -- matriarca-fungo: esporos e rebrota
        passive = { regenPct = 0.02 },
        opener = "spore_cloud",
        moves = {
            { id = "spore_cloud", kind = "debuff", weight = 25,
              debuff = { name = "poison", stacks = 4, duration = 3 }, maxRow = 1 },
            { id = "fungal_lash", kind = "multi",  weight = 30, mult = 0.4, hits = 3 },
            { id = "spore_burst", kind = "attack", weight = 30, mult = 0.7,
              debuff = { name = "poison", stacks = 2, duration = 2 } },
            { id = "mycelium",    kind = "heal",   weight = 15, heal = 0.08, armor = 0.6,
              maxRow = 1, minTurn = 2 },
        },
    },

    -- ATO 6 — CORTE DO ECLIPSE
    dusk_bat = {        -- morcego gigante: rajada que suga
        hpMul = 0.9,
        moves = {
            { id = "wing_flurry", kind = "multi",  weight = 45, mult = 0.35, hits = 3, heal = 0.04 },
            { id = "blood_bite",  kind = "attack", weight = 30, mult = 0.9, heal = 0.06 },
            { id = "screech",     kind = "debuff", weight = 15,
              debuff = { name = W, duration = 2 }, maxRow = 1 },
            { id = "flutter",     kind = "defend", weight = 10, armor = 1.0, maxRow = 1 },
        },
    },
    grave_thrall = {    -- esqueleto blindado: parede de escudo
        hpMul = 1.15,
        opener = "shield_wall",
        moves = {
            { id = "shield_wall", kind = "defend", weight = 25, armor = 1.6, maxRow = 1 },
            { id = "bone_bash",   kind = "attack", weight = 35, mult = 1.1 },
            { id = "shield_bash", kind = "attack", weight = 30, mult = 0.7, armor = 1.0 },
            { id = "rattle",      kind = "debuff", weight = 10,
              debuff = { name = F, duration = 2 }, maxRow = 1 },
        },
    },
    dullahan = {        -- cavaleiro sem cabeça: golpes pesados e pavor
        hpMul = 1.05,
        opener = "dread_stare",
        moves = {
            { id = "headless_cleave", kind = "strong", weight = 30, mult = 1.6 },
            { id = "dread_stare",     kind = "attack", weight = 25, mult = 0.6,
              debuff = { name = W, duration = 2 }, maxRow = 1 },
            { id = "ghost_charge",    kind = "strong", weight = 20, mult = 1.4 },
            { id = "spine_whip",      kind = "multi",  weight = 25, mult = 0.45, hits = 3 },
        },
    },
    fallen_angel = {    -- anjo caído: lâmina alta e asas profanas
        opener = "unholy_wings",
        moves = {
            { id = "fallen_blade",  kind = "strong", weight = 30, mult = 1.35 },
            { id = "unholy_wings",  kind = "buff",   weight = 20, strength = 0.2, armor = 0.8,
              maxRow = 1 },
            { id = "judgment",      kind = "strong", weight = 25, mult = 0.7, pierce = true },
            { id = "feather_storm", kind = "multi",  weight = 25, mult = 0.4, hits = 3 },
        },
    },
}

-- Status que o inimigo põe no JOGADOR (fonte única do contrato com Player/HUD).
Enemies.PLAYER_DEBUFFS = { weak = true, frail = true, vulnerable = true,
    poison = true, burn = true }

return Enemies
