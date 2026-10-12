-- Gegner-Kit (src/data/enemies.lua): Angriffsnamen, Zeilen des
-- Absichts-Tooltips, neue Zustände und Meldungen. Eigene Datei pro Locale;
-- im Haupt-Locale eingebunden als `enemy_kit = require(...)`.
return {
    moves = {
        attack = { name = "Ansturm" }, strong = { name = "Brutaler Hieb" },
        defend = { name = "Abwehrhaltung" }, buff = { name = "Wachsende Wut" },
        -- Akt 1
        rusty_scythe = { name = "Rostige Sense" }, crow_pecks = { name = "Krähenhiebe" },
        dread_stare = { name = "Grauenblick" }, straw_wall = { name = "Strohwall" },
        slime_crush = { name = "Zerquetschen" }, acid_spit = { name = "Säurespucke" },
        swell = { name = "Anschwellen" }, ooze_split = { name = "Kochende Tropfen" },
        reap = { name = "Ernten" }, harvest = { name = "Erntezeit" },
        reaper_mark = { name = "Mal des Schnitters" }, whetstone = { name = "Klinge Wetzen" },
        rotten_claw = { name = "Faulige Klaue" }, infected_bite = { name = "Infizierter Biss" },
        gorge = { name = "Verschlingen" }, frenzy = { name = "Raserei" },
        call_of_crows = { name = "Ruf der Krähen" }, murder_of_crows = { name = "Krähenschwarm" },
        royal_peck = { name = "Königlicher Hieb" }, carrion_feast = { name = "Aasfestmahl" },
        -- Akt 2
        stone_talons = { name = "Steinkrallen" }, dive = { name = "Sturzflug" },
        stone_skin = { name = "Steinhaut" }, lunar_shriek = { name = "Mondschrei" },
        stone_fist = { name = "Steinfaust" }, stone_wall = { name = "Steinmauer" },
        gather_mass = { name = "Masse Sammeln" }, crushing_blow = { name = "Zermalmen" },
        tremor = { name = "Beben" },
        rune_ward = { name = "Schutzrune" }, rune_bolt = { name = "Runenblitz" },
        overcharge = { name = "Überladung" }, slam = { name = "Wuchtschlag" },
        chill_touch = { name = "Kalte Berührung" }, wail = { name = "Wehklage" },
        life_drain = { name = "Lebensentzug" }, phantom_slash = { name = "Phantomhieb" },
        frost_shield = { name = "Frostschild" }, essence_drain = { name = "Essenzentzug" },
        necrotic_ray = { name = "Nekrotischer Strahl" }, bone_volley = { name = "Knochensalve" },
        -- Akt 3
        fireball = { name = "Feuerball" }, scratch = { name = "Kratzer" },
        cackle = { name = "Gackern" }, ember_jab = { name = "Glutstoß" },
        shadow_blade = { name = "Schattenklinge" }, fade = { name = "Verblassen" },
        umbral_cut = { name = "Schattenschnitt" }, whisper = { name = "Flüstern" },
        obsidian_strike = { name = "Obsidianschlag" }, bulwark = { name = "Bollwerk" },
        shard_burst = { name = "Splitterhagel" }, glare = { name = "Versteinernder Blick" },
        blood_drain = { name = "Blutentzug" }, hemorrhage = { name = "Blutsturz" },
        blood_feast = { name = "Blutfestmahl" }, noble_thrust = { name = "Edler Stoß" },
        gather_flames = { name = "Flammen Sammeln" }, hellfire = { name = "Höllenfeuer" },
        abyssal_claws = { name = "Abgrundklauen" }, cinder_spray = { name = "Ascheregen" },
        -- Akt 4
        freezing_touch = { name = "Eisige Berührung" }, wight_claw = { name = "Geisterklaue" },
        blizzard = { name = "Schneesturm" },
        ice_lance = { name = "Eislanze" }, glacial_aegis = { name = "Gletscherägide" },
        charge = { name = "Gletscheransturm" }, rime = { name = "Raureif" },
        eternal_winter = { name = "Ewiger Winter" }, winter_blade = { name = "Winterklinge" },
        royal_blizzard = { name = "Königlicher Schneesturm" }, frozen_crown = { name = "Eiskrone" },
        -- Akt 5
        hex = { name = "Fluch" }, toxic_cauldron = { name = "Giftkessel" },
        crooked_cane = { name = "Krummer Stock" }, bog_brew = { name = "Sumpfgebräu" },
        plague_cloud = { name = "Pestwolke" }, colossal_slam = { name = "Kolossaler Schlag" },
        putrid_blow = { name = "Fauliger Hieb" }, regrow = { name = "Nachwachsen" },
        -- Akt 6
        waning_light = { name = "Schwindendes Licht" }, lunar_blades = { name = "Mondklingen" },
        veil = { name = "Schleier" }, total_eclipse = { name = "Totale Finsternis" },
        black_corona = { name = "Schwarze Korona" }, star_rain = { name = "Sternenregen" },
        void_embrace = { name = "Umarmung der Leere" },
    },

    intent = {
        hit      = "Greift an und verursacht {value} Schaden.",
        multi    = "Greift {hits}-mal an: je {value} Schaden ({total} insgesamt).",
        pierce   = "DURCHBRICHT deinen Block.",
        armor    = "Erhält {value} Block.",
        strength = "Erhält dauerhaft +{value} Schaden.",
        heal     = "Heilt {value} LP.",
        summon   = "Beschwört +{value} Krähen: der Krähenschwarm trifft pro Krähe einmal mehr.",
        charge   = "Lädt auf: der nächste Angriff wird verheerend.",
        debuff   = "Verursacht {name} für {duration} Runde(n).",
        dot      = "Verursacht {name}: {stacks} Schaden pro Runde für {duration} Runde(n).",
    },

    status = {
        frail      = { name = "Zerbrechlich",
            desc = "Deine Verteidigungen geben 25 % weniger Block. Hält {duration} Runde(n)." },
        poison_self = { name = "Gift",
            desc = "Du verlierst zu Beginn deiner Runde {stacks} LP (ignoriert Block), für {duration} Runde(n)." },
        burn_self  = { name = "Verbrennung",
            desc = "Du verlierst zu Beginn deiner Runde {stacks} LP (ignoriert Block), für {duration} Runde(n)." },
        weak_self  = { name = "Geschwächt",
            desc = "Deine Angriffe verursachen 25 % weniger Schaden. Hält {duration} Runde(n)." },
        vulnerable_self = { name = "Verwundbar",
            desc = "Du erleidest 50 % mehr Schaden durch gegnerische Angriffe. Hält {duration} Runde(n)." },
        swarm      = { name = "Schwarm",
            desc = "{stacks} Krähe(n) beschworen: jede fügt dem Krähenschwarm einen Treffer hinzu." },
        eclipse    = { name = "Finsternis",
            desc = "Zweite Phase: neue Angriffe und 30 % mehr Schaden." },
    },

    phases = {
        eclipse = { name = "TOTALE FINSTERNIS", msg = "Die Finsternis schließt sich: die Königin wandelt sich und schlägt härter zu!" },
    },

    msg = {
        pierce         = "Der Hieb durchbricht deinen Block: {value} Schaden!",
        debuffed       = "Du bist {name}!",
        strength_float = "+{value} SCHADEN",
        healed         = "Der Gegner heilt {value} LP",
        summoned       = "Der Schwarm wächst: +{value} Krähe(n)",
        charging       = "Der Gegner lädt einen verheerenden Angriff auf!",
        player_dot     = "Du verlierst {value} LP (Gift/Verbrennung)",
    },

    -- Espólio do chefe: 1 de 3 coringas raros depois da carta (CardRewardScreen)
    boss_reward = {
        title    = "BEUTE DES BOSSES",
        subtitle = "Wähle 1 seltenen Joker für deine Reise",
        skip     = "Ohne Joker weiter",
    },
}
