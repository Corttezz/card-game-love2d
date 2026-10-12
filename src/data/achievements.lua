-- src/data/achievements.lua
-- Catalogo das conquistas. DADOS puros — a logica de unlock vive em
-- src/systems/AchievementSystem.lua; a ponte com a Steam em
-- src/systems/SteamBridge.lua.
--
-- Calibracao herdada de Balatro/StS/Monster Train: ~1/3 cai jogando
-- normalmente (JORNADA), ~1/3 exige run dedicada (RESTRICAO + MAESTRIA),
-- poucas sao horizonte de dezenas de horas (LEGADO).
--
-- CAMPOS
--   id       chave do perfil (ProfileStats.achievements[id]) — NUNCA renomear:
--            renomear apaga a conquista de quem ja tinha.
--   steam    API name do Steamworks — CONGELADO (tools/test_achievements
--            guarda a lista). Steam nao deixa renomear depois de publicado.
--   tier     natural | build | skill | collection  (categoria da galeria)
--   hidden   true = secreta: "???" ate liberar (na galeria E na Steam)
--   progress { stat = <nome>, target = N } — conquista com contador; o
--            valor atual vem de AchievementSystem.progressOf (fonte unica).
--   name/desc FALLBACK DE DEV sem acento (o texto exibido vem do i18n,
--            achievements.list.<id>.name/desc nos 5 locales).
--
-- Emblema: assets/sprites/achievements/<id>.png (+ <id>_locked.png). Os dois
-- sao gerados/derivados por tools/achievement_icons.py; o teste exige ambos.

return {
    -- ===== JORNADA (progresso natural) =====
    { id = "primeiro_chefe",   steam = "ACH_PRIMEIRO_CHEFE",   tier = "natural",
      name = "Coroa Partida", desc = "Derrote seu primeiro chefe." },
    { id = "capitulo_final",   steam = "ACH_CAPITULO_FINAL",   tier = "natural",
      name = "O Terceiro Capitulo", desc = "Derrote o chefe do Ato 3." },
    { id = "primeira_pagina",  steam = "ACH_PRIMEIRA_PAGINA",  tier = "natural",
      name = "Primeira Pagina", desc = "Venca sua primeira corrida." },
    { id = "vitoria_guerreiro", steam = "ACH_VITORIA_GUERREIRO", tier = "natural",
      name = "Lamina Lendaria", desc = "Venca uma corrida com o Guerreiro." },
    { id = "vitoria_mago",     steam = "ACH_VITORIA_MAGO",     tier = "natural",
      name = "Arcano Supremo", desc = "Venca uma corrida com o Mago." },
    { id = "vitoria_ladino",   steam = "ACH_VITORIA_LADINO",   tier = "natural",
      name = "Sombra Invicta", desc = "Venca uma corrida com o Ladino." },
    { id = "trindade",         steam = "ACH_TRINDADE",         tier = "natural",
      name = "Trindade do Grimorio", desc = "Venca uma corrida com cada classe.",
      progress = { stat = "classesWon", target = 3 } },
    { id = "despertar",        steam = "ACH_DESPERTAR",        tier = "natural",
      name = "Todos Despertos", desc = "Desbloqueie todas as classes.",
      progress = { stat = "classesUnlocked", target = 3 } },
    { id = "coro_coringas",    steam = "ACH_CORO_CORINGAS",    tier = "natural",
      name = "Coro de Coringas", desc = "Venca uma batalha com todos os espacos de coringa ocupados." },

    -- ===== RESTRICAO (run dedicada) =====
    { id = "grimorio_bolso",   steam = "ACH_GRIMORIO_BOLSO",   tier = "build",
      name = "Grimorio de Bolso", desc = "Venca com um deck de 6 cartas ou menos." },
    { id = "enciclopedia",     steam = "ACH_ENCICLOPEDIA",     tier = "build",
      name = "Enciclopedia Ambulante", desc = "Venca com 30 ou mais cartas no deck." },
    { id = "voto_pobreza",     steam = "ACH_VOTO_POBREZA",     tier = "build",
      name = "Voto de Pobreza", desc = "Venca sem comprar nada em lojas." },
    { id = "asceta",           steam = "ACH_ASCETA",           tier = "build",
      name = "Asceta", desc = "Venca sem possuir nenhum coringa." },
    { id = "tinta_crua",       steam = "ACH_TINTA_CRUA",       tier = "build",
      name = "Tinta Crua", desc = "Venca usando apenas cartas comuns." },
    { id = "sem_rascunhos",    steam = "ACH_SEM_RASCUNHOS",    tier = "build",
      name = "Sem Rascunhos", desc = "Venca sem nunca usar a Forja." },

    -- ===== MAESTRIA (skill) =====
    { id = "relampago",        steam = "ACH_RELAMPAGO",        tier = "skill",
      name = "Relampago Selado", desc = "Venca uma batalha antes de o inimigo agir." },
    { id = "fio_navalha",      steam = "ACH_FIO_NAVALHA",      tier = "skill", hidden = true,
      name = "Fio da Navalha", desc = "Venca uma batalha com exatamente 1 de vida." },
    { id = "imaculado",        steam = "ACH_IMACULADO",        tier = "skill",
      name = "Imaculado", desc = "Derrote um chefe sem tomar dano." },
    { id = "miasma",           steam = "ACH_MIASMA",           tier = "skill",
      name = "Miasma", desc = "Acumule 15 de veneno em um inimigo." },
    { id = "muralha",          steam = "ACH_MURALHA",          tier = "skill",
      name = "Muralha do Escriba", desc = "Atinja o maximo de bloqueio num turno." },
    { id = "tinta_viva",       steam = "ACH_TINTA_VIVA",       tier = "skill",
      name = "Tinta Viva", desc = "Dispare 4 combos no mesmo turno." },
    { id = "golpe_tinta",      steam = "ACH_GOLPE_TINTA",      tier = "skill",
      name = "Golpe de Tinta", desc = "Cause 60 de dano com uma unica carta." },
    { id = "conduite_pleno",   steam = "ACH_CONDUITE_PLENO",   tier = "skill",
      name = "Conduite Pleno", desc = "Tenha 3 orbes canalizados ao mesmo tempo." },
    { id = "maos_limpas",      steam = "ACH_MAOS_LIMPAS",      tier = "skill", hidden = true,
      name = "Maos Limpas", desc = "Venca uma batalha sem jogar cartas de ataque." },
    { id = "velas_10k",        steam = "ACH_VELAS_10K",        tier = "skill",
      name = "Dez Mil Velas", desc = "Alcance 10.000 pontos numa corrida." },

    -- ===== LEGADO (longo prazo) =====
    { id = "escriba",          steam = "ACH_ESCRIBA",          tier = "collection",
      name = "Escriba Incansavel", desc = "Jogue 2500 cartas (somando corridas).",
      progress = { stat = "cardsPlayed", target = 2500 } },
    { id = "ferreiro",         steam = "ACH_FERREIRO",         tier = "collection",
      name = "Ferreiro-Mor", desc = "Forje 25 cartas (somando corridas).",
      progress = { stat = "forges", target = 25 } },
    { id = "veterano",         steam = "ACH_VETERANO",         tier = "collection",
      name = "Veterano das Paginas", desc = "Venca 10 corridas.",
      progress = { stat = "wins", target = 10 } },
    { id = "bibliotecario",    steam = "ACH_BIBLIOTECARIO",    tier = "collection",
      name = "Bibliotecario", desc = "Descubra todas as cartas do grimorio.",
      progress = { stat = "cardsSeen", target = "all_cards" } },
    { id = "alem_da_pagina",   steam = "ACH_ALEM_DA_PAGINA",   tier = "collection", hidden = true,
      name = "Alem da Ultima Pagina", desc = "Alcance o andar 10 do modo infinito.",
      progress = { stat = "bestEndlessFloor", target = 10 } },

    -- ===== POS-JOGO (Out/2026): endless em ciclos + Selos do Grimorio =====
    -- Marcos do endless contam ANDARES (8 por ciclo): o ciclo 3 fecha no 24.
    { id = "ciclo_3",          steam = "ACH_CICLO_3",          tier = "collection",
      name = "Tres Voltas", desc = "Feche o ciclo 3 do modo infinito.",
      progress = { stat = "bestEndlessFloor", target = 24 } },
    { id = "ciclo_5",          steam = "ACH_CICLO_5",          tier = "collection",
      name = "Cinco Voltas", desc = "Feche o ciclo 5 do modo infinito.",
      progress = { stat = "bestEndlessFloor", target = 40 } },
    { id = "ciclo_10",         steam = "ACH_CICLO_10",         tier = "collection", hidden = true,
      name = "Ouroboros", desc = "Feche o ciclo 10 do modo infinito.",
      progress = { stat = "bestEndlessFloor", target = 80 } },
    { id = "primeiro_selo",    steam = "ACH_PRIMEIRO_SELO",    tier = "skill",
      name = "Lacre Rompido", desc = "Venca uma corrida com um Selo do Grimorio." },
    { id = "selo_max_guerreiro", steam = "ACH_SELO_MAX_GUERREIRO", tier = "skill",
      name = "Ultimo Selo: Guerreiro", desc = "Venca com o Guerreiro no Selo 10." },
    { id = "selo_max_mago",    steam = "ACH_SELO_MAX_MAGO",    tier = "skill",
      name = "Ultimo Selo: Mago", desc = "Venca com o Mago no Selo 10." },
    { id = "selo_max_ladino",  steam = "ACH_SELO_MAX_LADINO",  tier = "skill",
      name = "Ultimo Selo: Ladino", desc = "Venca com o Ladino no Selo 10." },
}
