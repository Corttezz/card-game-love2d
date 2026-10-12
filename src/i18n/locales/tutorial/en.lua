-- Onboarding v2 (src/systems/Tutorial + src/ui/Narrator + components/GuideScreen):
-- roteiro do corvo narrador (script.<conversa>.<fala>, *ênfase* em sangue),
-- rodapé do balão, Guia de combos/glossário, tooltip da mana. Arquivo próprio
-- por locale; plugado no principal como `tutorial = require(...)`.
return {
    narrator = { name = "Quill" },
    footer = {
        click = "Click to continue",
        ["continue"] = "continue",
        skip = "skip chat",
        disable = "I know how to play: turn the tutorial off",
    },
    act = {
        select = "Select a card",
        play = "Press Play Cards",
        end_turn = "Press End Turn",
    },
    settings_tips = "Raven tutorial",
    settings_reset = "Restart the tutorial",
    settings_reset_value = "{n} chats seen",
    settings_reset_done = "From the top",
    script = {
        intro = {
            hello = "Caw! I'm *Quill*, the raven who guards this grimoire. Let me teach you how to fight. I'll keep it short.",
            enemy = "This is your foe. The bar beneath it is its *health*: bring it to zero and the fight is over.",
            intent = "This icon is its *intent*: what it will do when your turn ends. The number is the damage coming your way.",
            hero = "Here are YOUR *health* and your *Block*. If your health hits zero, the journey ends.",
            hand = "These are your cards. The grimoire starts with only two. *Select one* to ready it.",
            mana = "Every card costs *mana*: the number in its corner. Mana refills every turn, so spend it freely.",
            preview = "This is the *preview*: how much damage and Block your selection will deal, with every bonus included.",
            play = "Ready? Go on: press *Play Cards*!",
        },
        end_turn = {
            ["end"] = "Nice hit! When you're out of mana or ideas, press *End Turn*. Then the enemy acts, exactly as its intent warned.",
        },
        second_turn = {
            kept = "See? It did what it announced. Read the *intent* every turn and guard up when a big blow is coming.",
            loop = "A fresh hand every turn, full mana again. Over to you. I'll pop up when there's something new. Caw!",
        },
        boss = {
            arrive = "This is the act's *boss*. Beat it and the road leads on to the next land.",
            signature = "Every boss has a signature move: summons, charge-ups, blows that pierce Block... Read the *intent* every turn.",
        },
        elite = {
            warn = "Careful: an *Elite*. Tougher than a common foe, but the reward is better too.",
        },
        block = {
            reset = "You gained *Block*: it soaks up the next blow. But mind this: Block *resets at the start of your turn*. You can't save it.",
        },
        combo = {
            seal = "Look: cards in your hand *combine*! Played TOGETHER in the same turn, they hit harder. The preview shows the *+COMBO* seal.",
            guide = "The full list of combos lives in the *Guide*, in the Pause menu.",
        },
        orbs = {
            pulse = "Your *orbs*! Each one pulses at the end of your turn, and the number written on it is the effect.",
            evoke = "Channeling with a full row *evokes* the oldest one, under the arrow, for a bigger effect.",
        },
        jokers = {
            passive = "A *Joker*! It works on its own for the whole run, at no mana cost.",
            bench = "Only the *active* ones in this frame work; the rest wait on the bench. Open the frame to swap them.",
        },
        rewards = {
            pick = "Victory! Choose *one* card for your grimoire.",
            skip = "Or skip it: a lean grimoire draws its best cards more often. Sometimes less is more.",
        },
        dice_help = {
            what = "The *Scribe's Dice* are an optional wager: you call the sum of two dice and stake gold on it.",
            bets = "*Low* (sum 2 to 6) and *High* (8 to 12) hit 42% of the time and pay 2.5× the chip. *Seven* hits 17% and pays 6×.",
            stakes = "The *chip* is how much you risk, and its values go up each act. If you miss, the house keeps it.",
            once = "One roll per shop visit, and the result is final right away, even if you leave and come back. On average the table breaks even: use it to gamble when a purchase is just out of reach.",
        },
        dice = {
            odds = "Two dice, one bet. *Low* (2 to 6) and *High* (8 to 12) pay 2.5×; *Seven* pays 6×.",
            bet = "Pick your bet and your chip, then roll. Each bet shows its odds right on it.",
        },
        shop = {
            offers = "The *shop*! Cards, relics and packs, for gold.",
            refresh = "Nothing you like? *Refresh* swaps the shelf, but it costs more each time.",
            dice = "And over there, the *Scribe's Dice*: bet gold on a roll of two dice. One roll per shop.",
            interest = "Oh, and saved gold earns *interest*: every $5 in your pocket is worth +$1 when you win a battle, up to +$5.",
        },
        forge = {
            pick = "At the *forge*, pick a card to upgrade. Each copy improves on its own.",
        },
        rest = {
            choose = "A *campfire*. Rest to recover health, or use the time to *forge* a card.",
        },
        event = {
            read = "An *event*! Read carefully: each choice shows what it costs [-] and what it gives [+].",
        },
        fork = {
            paths = "A *crossroads*. Each marker is a path: battle, *Elite*, rest, shop or event. Pick yours.",
        },
        endless = {
            cycle = "Beyond the final boss lies the *Endless*. Every cycle of eight floors, you choose a *curse*.",
            grow = "Enemies grow every cycle, with no limit. How far can your grimoire go?",
        },
        seals = {
            unlocked = "You won! Now you can break the *Grimoire Seals*: each seal is a harsher rule, and they stack.",
            score = "More seals, more points. Win on a seal to unlock the next one, with the same class.",
        },
    },
    guide = {
        title = "GRIMOIRE GUIDE",
        tab_combos = "Combos",
        tab_glossary = "Glossary",
        examples = "E.g.: {cards}",
        intro = "Combos count between cards played TOGETHER, in the same play. The +COMBO seal in your hand tells you when one is ready.",
        close_hint = "Esc / B closes · < > tabs",
        pause_shortcut = "Guide [G]",
    },
    status = {
        mana = { name = "Mana",
            desc = "{stacks} of {duration} available. Each card costs the number in its corner. Refills at the start of your turn; leftovers do not carry over." },
    },
}
