-- Kit dos inimigos (src/data/enemies.lua): nomes de golpe, linhas do tooltip
-- do intent, status novos e mensagens. Arquivo próprio por locale para não
-- disputar o locale principal; entra nele como `enemy_kit = require(...)`.
return {
    moves = {
        attack = { name = "Investida" }, strong = { name = "Golpe Brutal" },
        defend = { name = "Postura Defensiva" }, buff = { name = "Fúria Crescente" },
        -- Ato 1
        rusty_scythe = { name = "Foice Enferrujada" }, crow_pecks = { name = "Bicadas de Corvo" },
        dread_stare = { name = "Olhar de Pavor" }, straw_wall = { name = "Muralha de Palha" },
        slime_crush = { name = "Esmagar" }, acid_spit = { name = "Cuspe Ácido" },
        swell = { name = "Inchar" }, ooze_split = { name = "Gotas Ferventes" },
        reap = { name = "Ceifar" }, harvest = { name = "Colheita" },
        reaper_mark = { name = "Marca do Ceifador" }, whetstone = { name = "Afiar a Lâmina" },
        rotten_claw = { name = "Garra Podre" }, infected_bite = { name = "Mordida Infecta" },
        gorge = { name = "Devorar" }, frenzy = { name = "Frenesi" },
        call_of_crows = { name = "Chamado da Revoada" }, murder_of_crows = { name = "Revoada" },
        royal_peck = { name = "Bicada Real" }, carrion_feast = { name = "Banquete de Carniça" },
        -- Ato 2
        stone_talons = { name = "Garras de Pedra" }, dive = { name = "Mergulho" },
        stone_skin = { name = "Pele de Pedra" }, lunar_shriek = { name = "Grito Lunar" },
        stone_fist = { name = "Punho de Pedra" }, stone_wall = { name = "Muralha" },
        gather_mass = { name = "Acumular Massa" }, crushing_blow = { name = "Esmagamento" },
        tremor = { name = "Tremor" },
        rune_ward = { name = "Runa de Proteção" }, rune_bolt = { name = "Raio Rúnico" },
        overcharge = { name = "Sobrecarga" }, slam = { name = "Pancada" },
        chill_touch = { name = "Toque Gélido" }, wail = { name = "Lamento" },
        life_drain = { name = "Drenar Vida" }, phantom_slash = { name = "Corte Fantasma" },
        frost_shield = { name = "Escudo de Gelo" }, essence_drain = { name = "Drenar Essência" },
        necrotic_ray = { name = "Raio Necrótico" }, bone_volley = { name = "Rajada de Ossos" },
        -- Ato 3
        fireball = { name = "Bola de Fogo" }, scratch = { name = "Arranhões" },
        cackle = { name = "Gargalhada" }, ember_jab = { name = "Estocada de Brasa" },
        shadow_blade = { name = "Lâmina Sombria" }, fade = { name = "Esvanecer" },
        umbral_cut = { name = "Corte Umbral" }, whisper = { name = "Sussurro" },
        obsidian_strike = { name = "Golpe de Obsidiana" }, bulwark = { name = "Bastião" },
        shard_burst = { name = "Estilhaços" }, glare = { name = "Olhar Petrificante" },
        blood_drain = { name = "Dreno Sanguíneo" }, hemorrhage = { name = "Hemorragia" },
        blood_feast = { name = "Banquete de Sangue" }, noble_thrust = { name = "Estocada Nobre" },
        gather_flames = { name = "Reunir Chamas" }, hellfire = { name = "Fogo Infernal" },
        abyssal_claws = { name = "Garras do Abismo" }, cinder_spray = { name = "Chuva de Cinzas" },
        -- Ato 4
        freezing_touch = { name = "Toque Congelante" }, wight_claw = { name = "Garra Espectral" },
        blizzard = { name = "Nevasca" },
        ice_lance = { name = "Lança de Gelo" }, glacial_aegis = { name = "Égide Glacial" },
        charge = { name = "Investida Glacial" }, rime = { name = "Geada" },
        eternal_winter = { name = "Inverno Eterno" }, winter_blade = { name = "Lâmina do Inverno" },
        royal_blizzard = { name = "Nevasca Real" }, frozen_crown = { name = "Coroa Gélida" },
        -- Ato 5
        hex = { name = "Maldição" }, toxic_cauldron = { name = "Caldeirão Tóxico" },
        crooked_cane = { name = "Bengala Torta" }, bog_brew = { name = "Poção do Lodo" },
        plague_cloud = { name = "Nuvem Pestilenta" }, colossal_slam = { name = "Pancada Colossal" },
        putrid_blow = { name = "Golpe Pútrido" }, regrow = { name = "Regenerar" },
        -- Ato 6
        waning_light = { name = "Luz Minguante" }, lunar_blades = { name = "Lâminas Lunares" },
        veil = { name = "Véu" }, total_eclipse = { name = "Eclipse Total" },
        black_corona = { name = "Coroa Negra" }, star_rain = { name = "Chuva de Estrelas" },
        void_embrace = { name = "Abraço do Vazio" },
    },

    -- Linhas do tooltip do intent, montadas dos números CONGELADOS.
    intent = {
        hit      = "Ataca causando {value} de dano.",
        multi    = "Ataca {hits} vezes: {value} de dano cada ({total} no total).",
        pierce   = "ATRAVESSA o seu Bloqueio.",
        armor    = "Ganha {value} de Bloqueio.",
        strength = "Ganha +{value} de dano permanente.",
        heal     = "Recupera {value} de vida.",
        summon   = "Invoca +{value} corvos: a Revoada bate uma vez a mais por corvo.",
        charge   = "Carregando: o próximo golpe será devastador.",
        debuff   = "Aplica {name} por {duration} turno(s).",
        dot      = "Aplica {name}: {stacks} de dano por turno, por {duration} turno(s).",
    },

    status = {
        frail      = { name = "Frágil",
            desc = "Suas defesas rendem 25% menos Bloqueio. Dura {duration} turno(s)." },
        poison_self = { name = "Veneno",
            desc = "Você perde {stacks} de vida no início do seu turno (ignora o Bloqueio), por {duration} turno(s)." },
        burn_self  = { name = "Queimadura",
            desc = "Você perde {stacks} de vida no início do seu turno (ignora o Bloqueio), por {duration} turno(s)." },
        weak_self  = { name = "Fraco",
            desc = "Seus ataques causam 25% menos dano. Dura {duration} turno(s)." },
        vulnerable_self = { name = "Vulnerável",
            desc = "Você recebe 50% mais dano dos golpes inimigos. Dura {duration} turno(s)." },
        swarm      = { name = "Revoada",
            desc = "{stacks} corvo(s) invocado(s): cada um soma um golpe à Revoada." },
        eclipse    = { name = "Eclipse",
            desc = "Segunda fase: golpes novos e 30% mais dano." },
    },

    phases = {
        eclipse = { name = "ECLIPSE TOTAL", msg = "O eclipse se fecha: a Rainha muda de forma e bate mais forte!" },
    },

    msg = {
        pierce         = "Golpe atravessa o Bloqueio: {value} de dano!",
        debuffed       = "Você está {name}!",
        strength_float = "+{value} DANO",
        healed         = "O inimigo recupera {value} de vida",
        summoned       = "A revoada cresce: +{value} corvo(s)",
        charging       = "O inimigo está carregando um golpe devastador!",
        player_dot     = "Você perde {value} de vida (veneno/queimadura)",
    },

    -- Espólio do chefe: 1 de 3 coringas raros depois da carta (CardRewardScreen)
    boss_reward = {
        title    = "ESPÓLIO DO CHEFE",
        subtitle = "Escolha 1 coringa raro para levar pela jornada",
        skip     = "Seguir sem coringa",
    },
}
