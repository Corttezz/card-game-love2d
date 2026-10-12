-- Kit des ennemis (src/data/enemies.lua) : noms des coups, lignes de
-- l'infobulle d'intention, nouveaux états et messages. Fichier propre par
-- locale ; branché dans le principal via `enemy_kit = require(...)`.
return {
    moves = {
        attack = { name = "Charge" }, strong = { name = "Coup Brutal" },
        defend = { name = "Posture Défensive" }, buff = { name = "Fureur Montante" },
        -- Acte 1
        rusty_scythe = { name = "Faux Rouillée" }, crow_pecks = { name = "Coups de Bec" },
        dread_stare = { name = "Regard d'Effroi" }, straw_wall = { name = "Mur de Paille" },
        slime_crush = { name = "Écraser" }, acid_spit = { name = "Crachat Acide" },
        swell = { name = "Gonfler" }, ooze_split = { name = "Gouttes Bouillantes" },
        reap = { name = "Faucher" }, harvest = { name = "Moisson" },
        reaper_mark = { name = "Marque du Faucheur" }, whetstone = { name = "Affûter la Lame" },
        rotten_claw = { name = "Griffe Pourrie" }, infected_bite = { name = "Morsure Infectée" },
        gorge = { name = "Dévorer" }, frenzy = { name = "Frénésie" },
        call_of_crows = { name = "Appel des Corbeaux" }, murder_of_crows = { name = "Nuée de Corbeaux" },
        royal_peck = { name = "Bec Royal" }, carrion_feast = { name = "Festin de Charogne" },
        -- Acte 2
        stone_talons = { name = "Serres de Pierre" }, dive = { name = "Piqué" },
        stone_skin = { name = "Peau de Pierre" }, lunar_shriek = { name = "Cri Lunaire" },
        stone_fist = { name = "Poing de Pierre" }, stone_wall = { name = "Muraille" },
        gather_mass = { name = "Amasser la Masse" }, crushing_blow = { name = "Écrasement" },
        tremor = { name = "Secousse" },
        rune_ward = { name = "Rune de Garde" }, rune_bolt = { name = "Éclair Runique" },
        overcharge = { name = "Surcharge" }, slam = { name = "Fracas" },
        chill_touch = { name = "Toucher Glacial" }, wail = { name = "Lamentation" },
        life_drain = { name = "Drain de Vie" }, phantom_slash = { name = "Entaille Fantôme" },
        frost_shield = { name = "Bouclier de Givre" }, essence_drain = { name = "Drain d'Essence" },
        necrotic_ray = { name = "Rayon Nécrotique" }, bone_volley = { name = "Salve d'Os" },
        -- Acte 3
        fireball = { name = "Boule de Feu" }, scratch = { name = "Griffures" },
        cackle = { name = "Ricanement" }, ember_jab = { name = "Estoc de Braise" },
        shadow_blade = { name = "Lame d'Ombre" }, fade = { name = "S'estomper" },
        umbral_cut = { name = "Taille Ombrale" }, whisper = { name = "Murmure" },
        obsidian_strike = { name = "Frappe d'Obsidienne" }, bulwark = { name = "Bastion" },
        shard_burst = { name = "Éclats" }, glare = { name = "Regard Pétrifiant" },
        blood_drain = { name = "Saignée" }, hemorrhage = { name = "Hémorragie" },
        blood_feast = { name = "Festin de Sang" }, noble_thrust = { name = "Estoc Noble" },
        gather_flames = { name = "Rassembler les Flammes" }, hellfire = { name = "Feu Infernal" },
        abyssal_claws = { name = "Griffes Abyssales" }, cinder_spray = { name = "Pluie de Cendres" },
        -- Acte 4
        freezing_touch = { name = "Toucher Gelant" }, wight_claw = { name = "Griffe Spectrale" },
        blizzard = { name = "Blizzard" },
        ice_lance = { name = "Lance de Glace" }, glacial_aegis = { name = "Égide Glaciale" },
        charge = { name = "Charge Glaciale" }, rime = { name = "Givre" },
        eternal_winter = { name = "Hiver Éternel" }, winter_blade = { name = "Lame de l'Hiver" },
        royal_blizzard = { name = "Blizzard Royal" }, frozen_crown = { name = "Couronne Gelée" },
        -- Acte 5
        hex = { name = "Maléfice" }, toxic_cauldron = { name = "Chaudron Toxique" },
        crooked_cane = { name = "Canne Tordue" }, bog_brew = { name = "Breuvage du Marais" },
        plague_cloud = { name = "Nuage Pestilentiel" }, colossal_slam = { name = "Fracas Colossal" },
        putrid_blow = { name = "Coup Putride" }, regrow = { name = "Régénérer" },
        -- Acte 6
        waning_light = { name = "Lumière Déclinante" }, lunar_blades = { name = "Lames Lunaires" },
        veil = { name = "Voile" }, total_eclipse = { name = "Éclipse Totale" },
        black_corona = { name = "Couronne Noire" }, star_rain = { name = "Pluie d'Étoiles" },
        void_embrace = { name = "Étreinte du Néant" },
    },

    intent = {
        hit      = "Attaque et inflige {value} dégâts.",
        multi    = "Attaque {hits} fois : {value} dégâts chacune ({total} au total).",
        pierce   = "TRANSPERCE votre Blocage.",
        armor    = "Gagne {value} de Blocage.",
        strength = "Gagne +{value} dégâts permanents.",
        heal     = "Récupère {value} PV.",
        summon   = "Invoque +{value} corbeaux : la Nuée frappe une fois de plus par corbeau.",
        charge   = "En charge : le prochain coup sera dévastateur.",
        debuff   = "Applique {name} pendant {duration} tour(s).",
        dot      = "Applique {name} : {stacks} dégâts par tour pendant {duration} tour(s).",
    },

    status = {
        frail      = { name = "Fragile",
            desc = "Vos défenses accordent 25 % de Blocage en moins. Dure {duration} tour(s)." },
        poison_self = { name = "Poison",
            desc = "Vous perdez {stacks} PV au début de votre tour (ignore le Blocage) pendant {duration} tour(s)." },
        burn_self  = { name = "Brûlure",
            desc = "Vous perdez {stacks} PV au début de votre tour (ignore le Blocage) pendant {duration} tour(s)." },
        weak_self  = { name = "Affaibli",
            desc = "Vos attaques infligent 25 % de dégâts en moins. Dure {duration} tour(s)." },
        vulnerable_self = { name = "Vulnérable",
            desc = "Vous subissez 50 % de dégâts en plus des coups ennemis. Dure {duration} tour(s)." },
        swarm      = { name = "Nuée",
            desc = "{stacks} corbeau(x) invoqué(s) : chacun ajoute un coup à la Nuée." },
        eclipse    = { name = "Éclipse",
            desc = "Seconde phase : nouveaux coups et 30 % de dégâts en plus." },
    },

    phases = {
        eclipse = { name = "ÉCLIPSE TOTALE", msg = "L'éclipse se referme : la Reine change de forme et frappe plus fort !" },
    },

    msg = {
        pierce         = "Le coup transperce votre Blocage : {value} dégâts !",
        debuffed       = "Vous êtes {name} !",
        strength_float = "+{value} DÉGÂTS",
        healed         = "L'ennemi récupère {value} PV",
        summoned       = "La nuée grandit : +{value} corbeau(x)",
        charging       = "L'ennemi charge un coup dévastateur !",
        player_dot     = "Vous perdez {value} PV (poison/brûlure)",
    },

    -- Espólio do chefe: 1 de 3 coringas raros depois da carta (CardRewardScreen)
    boss_reward = {
        title    = "BUTIN DU BOSS",
        subtitle = "Choisissez 1 joker rare pour votre périple",
        skip     = "Continuer sans joker",
    },
}
