return {
    ui = {
        tab_cards        = "Cards",
        tab              = "Creatures",
        count            = "{n} of {total} creatures",
        act_header       = "Act {n} · {biome}",
        tier = {
            common   = "Common",
            elite    = "Elite",
            miniboss = "Mini-boss",
            boss     = "Boss",
        },
        unknown          = "???",
        undiscovered     = "Not yet encountered",
        moves            = "Known moves",
        moves_hidden     = "Defeat it to learn its moves.",
        signature        = "Signature",
        lore             = "Record",
        stat_seen        = "Faced",
        stat_defeated    = "Defeated",
        stat_killed_you  = "Defeated you",
        new_creatures    = "New creatures: {n}",
        end_label        = "NEW CREATURES",
        habitat          = "Habitat: {biome}",
        biome = {
            fields    = "Ruined Fields",
            highlands = "Tower Hills",
            abyss     = "Abyss Road",
            frost     = "Spectral Glacier",
            marsh     = "Rotting Marsh",
            dusk      = "Dusk Fields",
        },
    },

    creature = {
        cursed_scarecrow = {
            epithet = "Warden of the Dead Fields",
            lore = "Stitched from the straw of a harvest that never ripened, it guards the wheat long after the end. Crows nest in its chest and peck for it. Its pumpkin stare drains the courage of anyone who climbs the fence.",
        },
        hollow_farmer = {
            epithet = "What the Soil Reaped",
            lore = "He tilled the soil until the soil tilled him. He still carries the pitchfork and the hat, but inside there is only damp straw and root. When he raises the pitchfork slowly, it is time to brace.",
        },
        plague_rats = {
            epithet = "the Hungry Brood",
            lore = "They never travel alone. They gnawed through the empty barns, then through the dead no one buried. Every bite leaves plague fever in the blood.",
        },
        harvest_reaper = {
            epithet = "Reaper of the Last Harvest",
            lore = "It came for the wheat and stayed for the reapers. It marks its prey before the cut and hones its blade between strokes. They say the embers at its feet are the souls of the last harvest.",
        },
        blight_bull = {
            epithet = "Fury of the Rotten Pasture",
            lore = "It grazed these fields before the blight; now it grazes only on travelers. Its hide rotted until it hardened like bark. When it bellows, the earth shakes and the horns come right behind.",
        },
        wicker_effigy = {
            epithet = "the Offering That Burned",
            lore = "The villagers wove it from wicker to beg for rain and burned it at the last harvest feast. The fire never went out inside it. It stokes its own embers and vanishes into smoke before it crushes.",
        },
        carrion_king = {
            epithet = "Lord of the Murder",
            lore = "Crowned by the crows that gorged on the ruined fields, it rules over all that rots beneath the open sky. It calls the murder, and every extra bird is one more blow. When wounded, it descends to its carrion feast and mends.",
            signature = "Every four turns he calls two more crows; the Murder of Crows strikes once more for each crow around him and leaves you Weak.",
        },

        moon_gargoyle = {
            epithet = "Keeper of the Battlements",
            lore = "Carved to watch over the tower, it woke on the first full moon without a master. By day it is stone; by night it dives from the battlements with granite talons. Its lunar shriek makes the hands of all who hear it tremble.",
        },
        ram_cultist = {
            epithet = "Devotee of the Horned Skull",
            lore = "He wears a ram's skull as a mask and sings the hymns the tower taught him. He swings his censer as a weapon and brands the skin of heretics. Between blows he prays, and he is heard.",
        },
        storm_harpy = {
            epithet = "Daughter of Thunder",
            lore = "She is born from the lightning that strikes the hills and flies with the wind at her back. She attacks in flurries of talons and dives from on high. Her screech cuts through the thunder.",
        },
        rune_golem = {
            epithet = "Guardian of Inscribed Stone",
            lore = "The lich carved runes into blocks of stone and gave them a single order: guard the stairs. The runes glow when it shields itself and burn through your block when it strikes. Overcharged, it hits like a battering ram.",
        },
        spectral_knight = {
            epithet = "the Oath That Did Not Die",
            lore = "He swore to defend the tower and died on its stairs, but the oath did not die with him. Behind his tower shield, he answers every blow. His spectral lance pierces any armor.",
        },
        storm_griffin = {
            epithet = "Lord of the Peaks",
            lore = "It nests on the highest point of the hills, where lightning strikes first. It roars, and the thunder answers. It dives from the storm with talons crackling with lightning.",
        },
        tower_lich = {
            epithet = "Master of the Runic Rite",
            lore = "He climbed the tower to study death and never came down. He drains the essence of the living to feed a rite of four runes. When the last rune ignites, the whole tower comes crashing down on you.",
            signature = "He gains one rune per turn; at four, he unleashes the Runic Cataclysm, one hit per rune. Deal heavy damage in a single turn to break a rune.",
        },

        ember_imp = {
            epithet = "the Laughing Ember",
            lore = "Small, quick and always laughing. It hurls fireballs that leave your skin burning for turns. Every cackle promises that the next blow will hurt more.",
        },
        hellhound = {
            epithet = "the Two-Headed Hound",
            lore = "Two heads and a single hunger. It sniffs out the living along the abyss road and bites with both mouths at once. Its breath leaves burns that do not close.",
        },
        abyss_acolyte = {
            epithet = "Reader of the Burning Tome",
            lore = "He serves the tyrant by reading aloud from a tome that burns without being consumed. Every page is a curse that weakens the body. When he seals the dark pact, his wounds close and he returns stronger.",
        },
        obsidian_sentinel = {
            epithet = "the Black Glass Wall",
            lore = "Forged from obsidian at the mouth of the volcano, it guards the gates of the abyss. It raises a bulwark before every charge. When it cracks, it scatters shards as sharp as razors.",
        },
        pit_brute = {
            epithet = "Executioner of the Pit",
            lore = "Raised at the bottom of the pit, he only ever learned to lift the hammer and let it fall. When it rises, you have one turn to prepare. The chain lash takes care of the rest.",
        },
        abyss_watcher = {
            epithet = "the Eye That Never Blinks",
            lore = "It floats above the road and sees everything with three eyes. Its gaze maddens and weakens all at once. The eye ray pierces armor, and the tentacles do the rest.",
        },
        abyss_tyrant = {
            epithet = "the Chained One of the Abyss",
            lore = "The ancients bound him at the bottom of the abyss and sealed every link with fire. The links are giving way. With each chain that breaks, he staggers and returns more furious, gathering flames for Hellfire.",
            signature = "Three chains break at 75%, 50% and 25% of his health: when one breaks, his announced blow is halved, but he hits harder from then on.",
        },

        frost_wight = {
            epithet = "the Blizzard's Dead",
            lore = "It froze to death on the road to the citadel and still walks it. It hides in the blizzard: you never know how hard the next blow will be. Its touch chills the blood and breaks your guard.",
        },
        frost_wolf = {
            epithet = "Howl of the Glacier",
            lore = "It hunted in a pack, but the pack died in the ice and only it remained. It still howls to call them, and the howl makes it stronger. It bites three times before you can blink.",
        },
        rime_shaman = {
            epithet = "Elder of the Ice Totems",
            lore = "He speaks to the cold, and the cold answers. He raises ice totems to shield himself and hurls bolts of frost. His curse leaves your hands numb.",
        },
        glacier_knight = {
            epithet = "the Armor the Ice Kept",
            lore = "He served the Monarch until winter covered him whole. Now the ice is his armor and his lance. The ice lance pierces your block, and the glacial aegis shields him.",
        },
        frost_troll = {
            epithet = "Giant of the Endless Snow",
            lore = "Fierce and slow, but its wounds close on their own every turn. Its thick hide softens every blow. Kill it quickly, or you will have to kill it twice.",
        },
        ice_wyrm = {
            epithet = "Serpent of the Frozen Lake",
            lore = "It sleeps coiled beneath the ice of the lake until it hears footsteps. It draws a deep breath before its frost breath, and that is the only warning. Its scales are as hard as winter.",
        },
        winter_monarch = {
            epithet = "King of the Endless Winter",
            lore = "He crowned himself on the day the sun did not return and swore it never would. Each of his blows leaves frost on your hands, and the frost freezes your costliest cards. Every three turns, he calls the Eternal Winter.",
            signature = "Frost builds up on you; at 4 or more, the two costliest cards in your hand freeze when drawn. Attacks melt the frost, and fire cards melt twice as much.",
        },

        bog_ghoul = {
            epithet = "the Starving of the Mire",
            lore = "It crawled out of the swamp hungry and has never sated that hunger. Its bite infects the blood with poison. When it devours, its rotten flesh knits back together.",
        },
        plague_toad = {
            epithet = "the Croaking Herald",
            lore = "Swollen with venom, it spits plague from several paces away. When it croaks, the air grows heavy and sick. It puffs up its body to endure the blows.",
        },
        leech_horror = {
            epithet = "Hunger of a Thousand Mouths",
            lore = "A thousand leeches that learned to walk together. Each mouth drinks a little, and the whole heals with what it drinks. When it latches on, the strength drains from your arm.",
        },
        mire_hag = {
            epithet = "Witch of the Cauldron",
            lore = "She knows every herb in the swamp and which of them kills. She casts curses that weaken and make frail, and serves poison from her cauldron. When she bleeds, she drinks her own bog brew.",
        },
        croc_warrior = {
            epithet = "Warrior of the Banks",
            lore = "He guards the riverbanks with spear and shell. When he bites, he spins his prey in a death roll. His jaws pierce any block.",
        },
        spore_mother = {
            epithet = "the Garden of the Dead",
            lore = "She sprouted from a corpse and grew until she sheltered the whole swamp. She spreads clouds of spores that poison the air. Her mycelium roots heal her every turn.",
        },
        rot_colossus = {
            epithet = "Rotten Heart of the Swamp",
            lore = "Made of trunks, bones and mud, the Colossus is the swamp itself standing tall. Its roots drink from the earth and slowly heal it. Cut them, or the fight will never end.",
            signature = "Roots sunk into the ground heal him a little each turn and grow every two turns, up to three. A single heavy blow cuts a root.",
        },

        dusk_shade = {
            epithet = "Whisper of the Dusk",
            lore = "It is born from the last shadow before nightfall. It whispers, and your will falters; its umbral blade slips past your block. The twilight cloaks it, and its intent is hard to read.",
        },
        dusk_bat = {
            epithet = "the Blood Wing",
            lore = "It flies in flurries and drinks with every bite. Its screech leaves the body weak. The more you bleed, the longer it lives.",
        },
        grave_thrall = {
            epithet = "the Wall of Bones",
            lore = "Raised from a shallow grave to serve as a wall for the court. It carries a shield larger than itself and wields it as a weapon. The rattle of its bones makes your guard frail.",
        },
        blood_duke = {
            epithet = "Lord of the Crimson Feast",
            lore = "A noble of the eclipse court, he has never refused a feast. He drains the life of those he wounds and grows stronger with every sip. The hemorrhage he causes leaves the flesh vulnerable.",
        },
        dullahan = {
            epithet = "the Headless Knight",
            lore = "He lost his head in a battle no one remembers anymore. He bears a violet flame where it should be. His eyeless gaze still strikes dread.",
        },
        fallen_angel = {
            epithet = "the Light That Fell",
            lore = "She fell from the sky when the eclipse began and chose not to rise again. Her unholy wings shield and strengthen her. Her judgment pierces any block.",
        },
        eclipse_queen = {
            epithet = "Lady of the Black Moon",
            lore = "She has ruled the twilight court since the moon swallowed the sun. Her strength waxes and wanes with the phases of the moon. Wounded to half, she becomes the eclipse herself.",
            signature = "The moon turns through four phases: at Full Moon her blow is worth 50% more; at New Moon you become Vulnerable. Below half health, she enters the Eclipse.",
        },
    },
}
