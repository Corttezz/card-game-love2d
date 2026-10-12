-- Onboarding v2 (src/systems/Tutorial + src/ui/Narrator + components/GuideScreen):
-- roteiro do corvo narrador (script.<conversa>.<fala>, *ênfase* em sangue),
-- rodapé do balão, Guia de combos/glossário, tooltip da mana. Arquivo próprio
-- por locale; plugado no principal como `tutorial = require(...)`.
return {
    narrator = { name = "Feder" },
    footer = {
        click = "Klicken zum Weitermachen",
        ["continue"] = "weiter",
        skip = "überspringen",
        disable = "Ich kenne das Spiel: Tutorial aus",
    },
    act = {
        select = "Wähle eine Karte",
        play = "Drücke Karten spielen",
        end_turn = "Drücke Zug Beenden",
    },
    settings_tips = "Raben-Tutorial",
    settings_reset = "Tutorial neu starten",
    settings_reset_value = "{n} Gespräche gesehen",
    settings_reset_done = "Von vorn",
    script = {
        intro = {
            hello = "Krah! Ich bin *Feder*, der Rabe, der dieses Grimoire hütet. Ich zeige dir, wie man kämpft. Versprochen, ganz kurz.",
            enemy = "Das ist dein Gegner. Der Balken unter ihm ist sein *Leben*: Bring es auf null, und der Kampf ist vorbei.",
            intent = "Dieses Symbol ist seine *Absicht*: was er tut, wenn dein Zug endet. Die Zahl ist der Schaden, der auf dich zukommt.",
            hero = "Hier sind DEIN *Leben* und dein *Block*. Fällt dein Leben auf null, endet die Reise.",
            hand = "Das sind deine Karten. Das Grimoire beginnt mit nur zwei. *Wähle eine* aus, um sie bereitzulegen.",
            mana = "Jede Karte kostet *Mana*: die Zahl in ihrer Ecke. Das Mana füllt sich jede Runde wieder auf, also gib es ruhig aus.",
            preview = "Das ist die *Vorschau*: wie viel Schaden und Block deine Auswahl bringt, mit allen Boni.",
            play = "Bereit? Los geht's: Drücke *Karten spielen*!",
        },
        end_turn = {
            ["end"] = "Guter Treffer! Wenn Mana oder Ideen ausgehen, drücke *Zug Beenden*. Dann handelt der Gegner, genau wie seine Absicht angekündigt hat.",
        },
        second_turn = {
            kept = "Siehst du? Er hat getan, was er angekündigt hat. Lies jede Runde die *Absicht* und schütze dich, wenn ein großer Schlag kommt.",
            loop = "Jede Runde eine neue Hand und volles Mana. Jetzt bist du dran. Ich melde mich, wenn es Neues gibt. Krah!",
        },
        boss = {
            arrive = "Das ist der *Boss* dieses Akts. Besiege ihn, und der Weg führt ins nächste Land.",
            signature = "Jeder Boss hat einen eigenen Schlag: Beschwörung, Aufladen, Schläge, die Block durchbrechen... Lies jede Runde die *Absicht*.",
        },
        elite = {
            warn = "Vorsicht: ein *Elite*. Stärker als ein gewöhnlicher Gegner, aber auch die Belohnung ist besser.",
        },
        block = {
            reset = "Du hast *Block* bekommen: Er fängt den nächsten Schlag ab. Aber Achtung: Block *verfällt zu Beginn deines Zugs*. Aufsparen geht nicht.",
        },
        combo = {
            seal = "Sieh mal: Karten auf deiner Hand *kombinieren*! ZUSAMMEN im selben Zug gespielt, bringen sie mehr. Die Vorschau zeigt das Siegel *+COMBO*.",
            guide = "Die vollständige Combo-Liste steht im *Leitfaden*, im Pausenmenü.",
        },
        orbs = {
            pulse = "Deine *Orbs*! Jeder pulsiert am Ende deines Zugs, und die Zahl darauf ist der Effekt.",
            evoke = "Kanalisierst du bei voller Reihe, wird der älteste *ausgelöst*. Das ist der mit dem Pfeil, und sein Effekt ist stärker.",
        },
        jokers = {
            passive = "Ein *Joker*! Er wirkt den ganzen Lauf von selbst, ganz ohne Mana.",
            bench = "Nur die *aktiven* in diesem Rahmen wirken; der Rest wartet auf der Bank. Öffne den Rahmen, um zu tauschen.",
        },
        rewards = {
            pick = "Sieg! Wähle *eine* Karte für dein Grimoire.",
            skip = "Oder überspring sie: Ein schlankes Grimoire zieht seine besten Karten öfter. Manchmal ist weniger mehr.",
        },
        dice_help = {
            what = "Die *Würfel des Schreibers* sind eine freiwillige Wette: Du tippst auf die Summe zweier Würfel und setzt Gold darauf.",
            bets = "*Niedrig* (Summe 2 bis 6) und *Hoch* (8 bis 12) treffen in 42 % der Fälle und zahlen 2,5× den Einsatz. Die *Sieben* trifft zu 17 % und zahlt 6×.",
            stakes = "Der *Einsatz* ist, was du riskierst, und seine Werte steigen mit jedem Akt. Liegst du daneben, behält das Haus ihn.",
            once = "Ein Wurf pro Ladenbesuch, und das Ergebnis gilt sofort, auch wenn du gehst und zurückkommst. Im Schnitt ist der Tisch ausgeglichen: nutze ihn, wenn dir für einen Kauf nur wenig fehlt.",
        },
        dice = {
            odds = "Zwei Würfel, eine Wette. *Niedrig* (2 bis 6) und *Hoch* (8 bis 12) zahlen 2,5×; die *Sieben* zahlt 6×.",
            bet = "Wähle Wette und Einsatz, dann würfle. Jede Wette zeigt ihre Chance direkt an.",
        },
        shop = {
            offers = "Der *Laden*! Karten, Relikte und Packungen gegen Gold.",
            refresh = "Nichts dabei? *Erneuern* tauscht die Auslage, kostet aber jedes Mal mehr.",
            dice = "Und dort die *Würfel des Schreibers*: Setze Gold auf einen Wurf mit zwei Würfeln. Ein Wurf pro Laden.",
            interest = "Ach ja: Gespartes Gold bringt *Zinsen*. Je 5 $ in der Tasche gibt es +1 $ bei einem Sieg, bis +5 $.",
        },
        forge = {
            pick = "In der *Schmiede* wählst du eine Karte zum Verbessern. Jede Kopie entwickelt sich einzeln.",
        },
        rest = {
            choose = "Ein *Lagerfeuer*. Ruh dich aus, um Leben zurückzugewinnen, oder nutz die Zeit, um eine Karte zu *schmieden*.",
        },
        event = {
            read = "Ein *Ereignis*! Lies in Ruhe: Jede Wahl zeigt, was sie kostet [-] und was sie bringt [+].",
        },
        fork = {
            paths = "Eine *Weggabelung*. Jede Marke ist ein Weg: Kampf, *Elite*, Rast, Laden oder Ereignis. Wähle deinen.",
        },
        endless = {
            cycle = "Hinter dem letzten Boss liegt *Endlos*. In jedem Zyklus aus acht Etagen wählst du einen *Fluch*.",
            grow = "Die Gegner wachsen mit jedem Zyklus, ohne Grenze. Wie weit trägt dich dein Grimoire?",
        },
        seals = {
            unlocked = "Gewonnen! Jetzt kannst du die *Grimoire-Siegel* brechen: Jedes Siegel ist eine härtere Regel, und sie stapeln sich.",
            score = "Mehr Siegel, mehr Punkte. Gewinne mit einem Siegel, um das nächste freizuschalten, mit derselben Klasse.",
        },
    },
    guide = {
        title = "GRIMOIRE-LEITFADEN",
        tab_combos = "Combos",
        tab_glossary = "Glossar",
        examples = "Z. B.: {cards}",
        intro = "Combos gelten für Karten, die ZUSAMMEN gespielt werden. Das Siegel +COMBO auf der Hand zeigt, wenn einer bereit ist.",
        close_hint = "Esc / B schließt · < > Reiter",
        pause_shortcut = "Leitfaden [G]",
    },
    status = {
        mana = { name = "Mana",
            desc = "{stacks} von {duration} verfügbar. Jede Karte kostet die Zahl in ihrer Ecke. Füllt sich zu Beginn deiner Runde auf; Rest verfällt." },
    },
}
