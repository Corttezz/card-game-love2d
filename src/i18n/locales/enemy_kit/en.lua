-- Enemy kit (src/data/enemies.lua): move names, intent tooltip lines, new
-- statuses and messages. Own file per locale; plugged into the main locale
-- as `enemy_kit = require(...)`.
return {
    moves = {
        attack = { name = "Lunge" }, strong = { name = "Brutal Blow" },
        defend = { name = "Defensive Stance" }, buff = { name = "Rising Fury" },
        -- Act 1
        rusty_scythe = { name = "Rusty Scythe" }, crow_pecks = { name = "Crow Pecks" },
        dread_stare = { name = "Dread Stare" }, straw_wall = { name = "Straw Wall" },
        slime_crush = { name = "Crush" }, acid_spit = { name = "Acid Spit" },
        swell = { name = "Swell" }, ooze_split = { name = "Boiling Droplets" },
        reap = { name = "Reap" }, harvest = { name = "Harvest" },
        reaper_mark = { name = "Reaper's Mark" }, whetstone = { name = "Whet the Blade" },
        rotten_claw = { name = "Rotten Claw" }, infected_bite = { name = "Infected Bite" },
        gorge = { name = "Gorge" }, frenzy = { name = "Frenzy" },
        call_of_crows = { name = "Call of Crows" }, murder_of_crows = { name = "Murder of Crows" },
        royal_peck = { name = "Royal Peck" }, carrion_feast = { name = "Carrion Feast" },
        -- Act 2
        stone_talons = { name = "Stone Talons" }, dive = { name = "Dive" },
        stone_skin = { name = "Stone Skin" }, lunar_shriek = { name = "Lunar Shriek" },
        stone_fist = { name = "Stone Fist" }, stone_wall = { name = "Stone Wall" },
        gather_mass = { name = "Gather Mass" }, crushing_blow = { name = "Crushing Blow" },
        tremor = { name = "Tremor" },
        rune_ward = { name = "Rune Ward" }, rune_bolt = { name = "Rune Bolt" },
        overcharge = { name = "Overcharge" }, slam = { name = "Slam" },
        chill_touch = { name = "Chill Touch" }, wail = { name = "Wail" },
        life_drain = { name = "Life Drain" }, phantom_slash = { name = "Phantom Slash" },
        frost_shield = { name = "Frost Shield" }, essence_drain = { name = "Essence Drain" },
        necrotic_ray = { name = "Necrotic Ray" }, bone_volley = { name = "Bone Volley" },
        -- Act 3
        fireball = { name = "Fireball" }, scratch = { name = "Scratches" },
        cackle = { name = "Cackle" }, ember_jab = { name = "Ember Jab" },
        shadow_blade = { name = "Shadow Blade" }, fade = { name = "Fade" },
        umbral_cut = { name = "Umbral Cut" }, whisper = { name = "Whisper" },
        obsidian_strike = { name = "Obsidian Strike" }, bulwark = { name = "Bulwark" },
        shard_burst = { name = "Shard Burst" }, glare = { name = "Petrifying Glare" },
        blood_drain = { name = "Blood Drain" }, hemorrhage = { name = "Hemorrhage" },
        blood_feast = { name = "Blood Feast" }, noble_thrust = { name = "Noble Thrust" },
        gather_flames = { name = "Gather Flames" }, hellfire = { name = "Hellfire" },
        abyssal_claws = { name = "Abyssal Claws" }, cinder_spray = { name = "Cinder Spray" },
        -- Act 4
        freezing_touch = { name = "Freezing Touch" }, wight_claw = { name = "Wight Claw" },
        blizzard = { name = "Blizzard" },
        ice_lance = { name = "Ice Lance" }, glacial_aegis = { name = "Glacial Aegis" },
        charge = { name = "Glacial Charge" }, rime = { name = "Rime" },
        eternal_winter = { name = "Eternal Winter" }, winter_blade = { name = "Winter Blade" },
        royal_blizzard = { name = "Royal Blizzard" }, frozen_crown = { name = "Frozen Crown" },
        -- Act 5
        hex = { name = "Hex" }, toxic_cauldron = { name = "Toxic Cauldron" },
        crooked_cane = { name = "Crooked Cane" }, bog_brew = { name = "Bog Brew" },
        plague_cloud = { name = "Plague Cloud" }, colossal_slam = { name = "Colossal Slam" },
        putrid_blow = { name = "Putrid Blow" }, regrow = { name = "Regrow" },
        -- Act 6
        waning_light = { name = "Waning Light" }, lunar_blades = { name = "Lunar Blades" },
        veil = { name = "Veil" }, total_eclipse = { name = "Total Eclipse" },
        black_corona = { name = "Black Corona" }, star_rain = { name = "Star Rain" },
        void_embrace = { name = "Void Embrace" },
    },

    intent = {
        hit      = "Attacks for {value} damage.",
        multi    = "Attacks {hits} times: {value} damage each ({total} total).",
        pierce   = "PIERCES your Block.",
        armor    = "Gains {value} Block.",
        strength = "Gains +{value} permanent damage.",
        heal     = "Recovers {value} HP.",
        summon   = "Summons +{value} crows: Murder of Crows hits once more per crow.",
        charge   = "Charging: the next attack will be devastating.",
        debuff   = "Applies {name} for {duration} turn(s).",
        dot      = "Applies {name}: {stacks} damage per turn for {duration} turn(s).",
    },

    status = {
        frail      = { name = "Frail",
            desc = "Your defenses grant 25% less Block. Lasts {duration} turn(s)." },
        poison_self = { name = "Poison",
            desc = "You lose {stacks} HP at the start of your turn (ignores Block) for {duration} turn(s)." },
        burn_self  = { name = "Burn",
            desc = "You lose {stacks} HP at the start of your turn (ignores Block) for {duration} turn(s)." },
        weak_self  = { name = "Weak",
            desc = "Your attacks deal 25% less damage. Lasts {duration} turn(s)." },
        vulnerable_self = { name = "Vulnerable",
            desc = "You take 50% more damage from enemy attacks. Lasts {duration} turn(s)." },
        swarm      = { name = "Murder",
            desc = "{stacks} crow(s) summoned: each adds one hit to Murder of Crows." },
        eclipse    = { name = "Eclipse",
            desc = "Second phase: new moves and 30% more damage." },
    },

    phases = {
        eclipse = { name = "TOTAL ECLIPSE", msg = "The eclipse closes: the Queen changes form and hits harder!" },
    },

    msg = {
        pierce         = "The blow pierces your Block: {value} damage!",
        debuffed       = "You are {name}!",
        strength_float = "+{value} DMG",
        healed         = "The enemy recovers {value} HP",
        summoned       = "The murder grows: +{value} crow(s)",
        charging       = "The enemy is charging a devastating attack!",
        player_dot     = "You lose {value} HP (poison/burn)",
    },

    -- Espólio do chefe: 1 de 3 coringas raros depois da carta (CardRewardScreen)
    boss_reward = {
        title    = "BOSS'S SPOILS",
        subtitle = "Choose 1 rare joker to carry on your journey",
        skip     = "Continue without a joker",
    },
}
