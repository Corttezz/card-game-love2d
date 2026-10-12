-- Kit de los enemigos (src/data/enemies.lua): nombres de golpes, líneas del
-- tooltip de intención, estados nuevos y mensajes. Archivo propio por locale;
-- entra en el principal como `enemy_kit = require(...)`.
return {
    moves = {
        attack = { name = "Embestida" }, strong = { name = "Golpe Brutal" },
        defend = { name = "Postura Defensiva" }, buff = { name = "Furia Creciente" },
        -- Acto 1
        rusty_scythe = { name = "Hoz Oxidada" }, crow_pecks = { name = "Picotazos de Cuervo" },
        dread_stare = { name = "Mirada de Pavor" }, straw_wall = { name = "Muro de Paja" },
        slime_crush = { name = "Aplastar" }, acid_spit = { name = "Escupitajo Ácido" },
        swell = { name = "Hincharse" }, ooze_split = { name = "Gotas Hirvientes" },
        reap = { name = "Segar" }, harvest = { name = "Cosecha" },
        reaper_mark = { name = "Marca del Segador" }, whetstone = { name = "Afilar la Hoja" },
        rotten_claw = { name = "Garra Podrida" }, infected_bite = { name = "Mordida Infecta" },
        gorge = { name = "Devorar" }, frenzy = { name = "Frenesí" },
        call_of_crows = { name = "Llamada de la Bandada" }, murder_of_crows = { name = "Bandada" },
        royal_peck = { name = "Picotazo Real" }, carrion_feast = { name = "Festín de Carroña" },
        -- Acto 2
        stone_talons = { name = "Garras de Piedra" }, dive = { name = "Picado" },
        stone_skin = { name = "Piel de Piedra" }, lunar_shriek = { name = "Chillido Lunar" },
        stone_fist = { name = "Puño de Piedra" }, stone_wall = { name = "Muralla" },
        gather_mass = { name = "Acumular Masa" }, crushing_blow = { name = "Aplastamiento" },
        tremor = { name = "Temblor" },
        rune_ward = { name = "Runa de Protección" }, rune_bolt = { name = "Rayo Rúnico" },
        overcharge = { name = "Sobrecarga" }, slam = { name = "Porrazo" },
        chill_touch = { name = "Toque Gélido" }, wail = { name = "Lamento" },
        life_drain = { name = "Drenar Vida" }, phantom_slash = { name = "Tajo Fantasma" },
        frost_shield = { name = "Escudo de Hielo" }, essence_drain = { name = "Drenar Esencia" },
        necrotic_ray = { name = "Rayo Necrótico" }, bone_volley = { name = "Ráfaga de Huesos" },
        -- Acto 3
        fireball = { name = "Bola de Fuego" }, scratch = { name = "Arañazos" },
        cackle = { name = "Carcajada" }, ember_jab = { name = "Estocada de Brasa" },
        shadow_blade = { name = "Hoja Sombría" }, fade = { name = "Desvanecerse" },
        umbral_cut = { name = "Corte Umbrío" }, whisper = { name = "Susurro" },
        obsidian_strike = { name = "Golpe de Obsidiana" }, bulwark = { name = "Bastión" },
        shard_burst = { name = "Esquirlas" }, glare = { name = "Mirada Petrificante" },
        blood_drain = { name = "Drenaje Sanguíneo" }, hemorrhage = { name = "Hemorragia" },
        blood_feast = { name = "Festín de Sangre" }, noble_thrust = { name = "Estocada Noble" },
        gather_flames = { name = "Reunir Llamas" }, hellfire = { name = "Fuego Infernal" },
        abyssal_claws = { name = "Garras del Abismo" }, cinder_spray = { name = "Lluvia de Cenizas" },
        -- Acto 4
        freezing_touch = { name = "Toque Congelante" }, wight_claw = { name = "Garra Espectral" },
        blizzard = { name = "Ventisca" },
        ice_lance = { name = "Lanza de Hielo" }, glacial_aegis = { name = "Égida Glacial" },
        charge = { name = "Carga Glacial" }, rime = { name = "Escarcha" },
        eternal_winter = { name = "Invierno Eterno" }, winter_blade = { name = "Hoja del Invierno" },
        royal_blizzard = { name = "Ventisca Real" }, frozen_crown = { name = "Corona Gélida" },
        -- Acto 5
        hex = { name = "Maleficio" }, toxic_cauldron = { name = "Caldero Tóxico" },
        crooked_cane = { name = "Bastón Torcido" }, bog_brew = { name = "Brebaje del Fango" },
        plague_cloud = { name = "Nube Pestilente" }, colossal_slam = { name = "Porrazo Colosal" },
        putrid_blow = { name = "Golpe Pútrido" }, regrow = { name = "Regenerar" },
        -- Acto 6
        waning_light = { name = "Luz Menguante" }, lunar_blades = { name = "Hojas Lunares" },
        veil = { name = "Velo" }, total_eclipse = { name = "Eclipse Total" },
        black_corona = { name = "Corona Negra" }, star_rain = { name = "Lluvia de Estrellas" },
        void_embrace = { name = "Abrazo del Vacío" },
    },

    intent = {
        hit      = "Ataca causando {value} de daño.",
        multi    = "Ataca {hits} veces: {value} de daño cada una ({total} en total).",
        pierce   = "ATRAVIESA tu Bloqueo.",
        armor    = "Gana {value} de Bloqueo.",
        strength = "Gana +{value} de daño permanente.",
        heal     = "Recupera {value} de vida.",
        summon   = "Invoca +{value} cuervos: la Bandada golpea una vez más por cuervo.",
        charge   = "Cargando: el próximo golpe será devastador.",
        debuff   = "Aplica {name} durante {duration} turno(s).",
        dot      = "Aplica {name}: {stacks} de daño por turno durante {duration} turno(s).",
    },

    status = {
        frail      = { name = "Frágil",
            desc = "Tus defensas otorgan un 25% menos de Bloqueo. Dura {duration} turno(s)." },
        poison_self = { name = "Veneno",
            desc = "Pierdes {stacks} de vida al inicio de tu turno (ignora el Bloqueo) durante {duration} turno(s)." },
        burn_self  = { name = "Quemadura",
            desc = "Pierdes {stacks} de vida al inicio de tu turno (ignora el Bloqueo) durante {duration} turno(s)." },
        weak_self  = { name = "Débil",
            desc = "Tus ataques causan un 25% menos de daño. Dura {duration} turno(s)." },
        vulnerable_self = { name = "Vulnerable",
            desc = "Recibes un 50% más de daño de los golpes enemigos. Dura {duration} turno(s)." },
        swarm      = { name = "Bandada",
            desc = "{stacks} cuervo(s) invocado(s): cada uno suma un golpe a la Bandada." },
        eclipse    = { name = "Eclipse",
            desc = "Segunda fase: golpes nuevos y un 30% más de daño." },
    },

    phases = {
        eclipse = { name = "ECLIPSE TOTAL", msg = "El eclipse se cierra: ¡la Reina cambia de forma y golpea más fuerte!" },
    },

    msg = {
        pierce         = "¡El golpe atraviesa tu Bloqueo: {value} de daño!",
        debuffed       = "¡Estás {name}!",
        strength_float = "+{value} DAÑO",
        healed         = "El enemigo recupera {value} de vida",
        summoned       = "La bandada crece: +{value} cuervo(s)",
        charging       = "¡El enemigo está cargando un golpe devastador!",
        player_dot     = "Pierdes {value} de vida (veneno/quemadura)",
    },

    -- Espólio do chefe: 1 de 3 coringas raros depois da carta (CardRewardScreen)
    boss_reward = {
        title    = "BOTÍN DEL JEFE",
        subtitle = "Elige 1 comodín raro para tu viaje",
        skip     = "Seguir sin comodín",
    },
}
