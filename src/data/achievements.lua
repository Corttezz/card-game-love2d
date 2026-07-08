-- src/data/achievements.lua
-- Catálogo das 20 conquistas (F4 do gameplay-overhaul-v1), adaptadas do
-- dossiê Balatro/StS/Monster Train. DADOS puros — a lógica de unlock vive
-- em src/systems/AchievementSystem.lua.
--
-- Calibração herdada dos 3 jogos: ~1/3 cai jogando normalmente, ~1/3 exige
-- run dedicada, 2-3 são horizonte de dezenas de horas.
--
-- icon: nome resolvível pelo IconLoader (assets/sprites/icons/*.png).

return {
    -- ===== Progresso natural =====
    { id = "primeira_pagina",  name = "Primeira Pagina",
      desc = "Venca sua primeira corrida.",
      icon = "scroll", tier = "natural" },
    { id = "trindade",         name = "Trindade do Grimorio",
      desc = "Venca uma corrida com cada classe.",
      icon = "star", tier = "natural" },
    { id = "capitulo_final",   name = "O Capitulo Final",
      desc = "Derrote o chefe do Ato 3.",
      icon = "skull_crowned", tier = "natural" },
    { id = "alem_da_pagina",   name = "Alem da Ultima Pagina",
      desc = "Alcance o andar 10 do modo infinito.",
      icon = "moon", tier = "natural" },
    { id = "escriba",          name = "Escriba Incansavel",
      desc = "Jogue 2500 cartas (entre corridas).",
      icon = "scroll", tier = "natural" },

    -- ===== Restrição de build =====
    { id = "grimorio_bolso",   name = "Grimorio de Bolso",
      desc = "Venca com um deck de 6 cartas ou menos.",
      icon = "gem", tier = "build" },
    { id = "enciclopedia",     name = "Enciclopedia Ambulante",
      desc = "Venca com 30 ou mais cartas no deck.",
      icon = "scroll", tier = "build" },
    { id = "voto_pobreza",     name = "Voto de Pobreza",
      desc = "Venca sem comprar nada em lojas.",
      icon = "coin", tier = "build" },
    { id = "asceta",           name = "Asceta",
      desc = "Venca sem nenhum joker equipado.",
      icon = "mask", tier = "build" },
    { id = "tinta_crua",       name = "Tinta Crua",
      desc = "Venca usando apenas cartas comuns.",
      icon = "rune", tier = "build" },
    { id = "sem_rascunhos",    name = "Sem Rascunhos",
      desc = "Venca sem nunca usar a Forja.",
      icon = "axe", tier = "build" },

    -- ===== Skill / score =====
    { id = "relampago",        name = "Relampago Selado",
      desc = "Venca uma batalha no primeiro turno.",
      icon = "bolt", tier = "skill" },
    { id = "fio_navalha",      name = "Fio da Navalha",
      desc = "Venca uma batalha com exatamente 1 HP.",
      icon = "dagger", tier = "skill" },
    { id = "imaculado",        name = "Imaculado",
      desc = "Derrote um chefe sem tomar dano.",
      icon = "shield_kite", tier = "skill" },
    { id = "miasma",           name = "Miasma",
      desc = "Acumule 15+ de veneno em um inimigo.",
      icon = "potion_red", tier = "skill" },
    { id = "muralha",          name = "Muralha do Escriba",
      desc = "Atinja o maximo de armadura num turno.",
      icon = "shield_round", tier = "skill" },
    { id = "tinta_viva",       name = "Tinta Viva",
      desc = "Dispare 4 combos no mesmo turno.",
      icon = "flame", tier = "skill" },
    { id = "velas_10k",        name = "Dez Mil Velas",
      desc = "Alcance 10.000 pontos numa corrida.",
      icon = "star", tier = "skill" },

    -- ===== Coleção / longo prazo =====
    { id = "bibliotecario",    name = "Bibliotecario",
      desc = "Descubra todas as cartas do grimorio.",
      icon = "eye", tier = "collection" },
    { id = "ferreiro",         name = "Ferreiro-Mor",
      desc = "Forje 25 cartas (entre corridas).",
      icon = "helm", tier = "collection" },
}
