return {
    narrator = { name = "Feder" },
    footer = {
        ["continue"] = "Weiter",
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
            seal = "Spiel mehrere Karten ZUSAMMEN: Jeder Angriff nach dem ersten macht mehr Schaden (*Salve*), jede Verteidigung nach der ersten gibt mehr Block (*Bollwerk*), und gleiche Karten zählen mehr (*Paar*).",
            guide = "Das Siegel über einer Karte zeigt den Bonus, den sie jetzt bekäme. Die ganze Liste steht im *Leitfaden*, im Pausenmenü.",
        },
        conduit = {
            passive = "Du bist ein *Magier*. Deine Passive, *{passive}*, beginnt jeden Kampf mit einem *Blitz-Orb*, der schon in der Reihe liegt. Ein Orb ist ein Zauber, der gespannt bleibt und von selbst wirkt.",
            row = "Das ist deine *Orb-Reihe*: {slots} Plätze. Ein leerer Platz ist ein erloschener Ring. Ein neuer Orb kommt von rechts herein.",
            number = "Die Zahl unter dem Orb sagt, was er am Ende jedes deiner Züge von selbst tut: sein *Puls*. Dieser Blitz pulsiert *{pulse}* Schaden.",
        },
        channel = {
            card = "Diese Karte *kanalisiert*: Neben dem geschriebenen Effekt erschafft sie einen neuen Orb in der Reihe. Fahr mit der Maus darüber, und der Platz, der ihn aufnimmt, blinkt.",
            made = "Du hast *kanalisiert*: Die Karte hat ihren Effekt getan UND einen neuen Orb erschaffen, der rechts in die Reihe kam.",
            oldest = "Der linke, mit dem hellen Rahmen, ist der *älteste*. Der Pfeil auf der Schiene zeigt den Ausgang: Wenn ein Orb geht, ist es immer zuerst dieser.",
            hover = "Fahr mit der Maus über einen Orb, um die genauen Zahlen zu sehen: wie viel er pro Zug pulsiert und wie viel er beim *Auslösen* bringt. Dazu komme ich gleich.",
        },
        pulse = {
            happened = "Hast du das Ende deines Zugs gesehen? Die Orbs haben *pulsiert*: Jeder tat, was seine Zahl sagte, ohne Karte und ohne Mana. So geht es jeden Zug, solange sie in der Reihe liegen.",
            kinds = "Jedes Element pulsiert anders: *Blitz* und *Feuer* verletzen den Gegner, *Eis* gibt Block, *Heilig* heilt. *Schatten* pulsiert nicht: Er wächst jeden Zug und löst doppelt aus.",
            reveal = "Und der *Blitz* hat einen Bonus: Wenn die Absicht des Gegners im Nebel verborgen ist, enthüllt sein Puls die nächste Ankündigung.",
        },
        evoke_card = {
            card = "Diese Karte *löst aus*: Der älteste Orb, der mit dem Rahmen, verlässt die Reihe und entlädt auf einmal seinen *vollen* Effekt. Stärker als der Puls, aber der Orb ist weg.",
            preview = "Fahr mit der Maus über die Karte: Der Orb, der gehen wird, leuchtet *cyan* auf, und seine Zahl wird zum Auslöse-Wert.",
            all = "*Alle auslösen* leert die ganze Reihe, einen Orb nach dem anderen, vom ältesten zum neuesten.",
        },
        overflow = {
            full = "Volle Reihe, und du hast noch einen kanalisiert: Der *älteste* Orb wurde verdrängt und hat sich beim Hinausgehen mit vollem Wert *ausgelöst*. Nichts geht verloren.",
            plan = "Das heißt: Sind alle {slots} Plätze voll, ist jedes neue Kanalisieren auch ein Auslösen. Füll die Reihe, und jede Karte wird zum Schuss.",
        },
        focus = {
            what = "Du hast *Fokus*: Jeder Punkt zählt zum Wert all deiner Orbs dazu, im Puls wie beim Auslösen. Die Zahlen auf den Orbs rechnen den Fokus schon mit.",
            conduit = "Von jetzt an gibt *{passive}* auch {f} Fokus zu Beginn jedes Kampfs. Je tiefer die Reise, desto mehr Fokus.",
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
            offers = "Der *Laden*! Karten auf Ständern, Relikte und eine Packung auf dem Tresen, alles gegen Gold.",
            price = "Jedes Stück trägt seinen *Preis*: ein Messingschild unter der Karte, ein Anhänger vorn am Tresen für den Rest. Rot heißt: noch nicht bezahlbar.",
            buy = "Klicke ein Stück an, um es auf der *Schriftrolle* zu lesen; gekauft wird über das Band *KAUFEN*. Fahre darüber und die Gegenstände erklären sich.",
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
        class_select = {
            welcome = "Krah! Bevor die Reise beginnt, wähle, wer das Grimoire führt. Für den Anfang gibt es nichts Besseres als den *Krieger*.",
            warrior = "Der Krieger schlägt hart zu und steckt viel ein. Seine Passive heißt *{passive}*: {rule}",
            start = "Fang hier an. Wenn du bereit bist, öffnest du die Reise mit diesem Band.",
            locked = "Die anderen Klassen liegen in Ketten und werden durchs Spielen befreit. {list}",
            details = "Und dieses Lesezeichen öffnet die *Details* der Klasse: Startkarten und Zahlen.",
        },
        fog = {
            veil = "Der *Nebel* hat sich geschlossen. Du siehst noch die ART seines Zugs, aber nicht die Zahl. Der Zug steht schon fest, nur das Lesen fehlt.",
            counter = "Wenn der Schneesturm aufreißt, kommt die Zahl zurück. *Enthüllen*-Karten und der Puls des Blitz-Orbs vertreiben den Nebel ebenfalls für eine Runde.",
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
        intro = "Combos gelten für Karten, die ZUSAMMEN gespielt werden. Das Siegel über einer Karte auf der Hand zeigt, wie viel Combo-Bonus sie bekäme.",
        close_hint = "Esc / B schließt · < > Reiter",
        pause_shortcut = "Leitfaden [G]",
    },
    status = {
        mana = { name = "Mana",
            desc = "{stacks} von {duration} verfügbar. Jede Karte kostet die Zahl in ihrer Ecke. Füllt sich zu Beginn deiner Runde auf; Rest verfällt." },
    },
}
