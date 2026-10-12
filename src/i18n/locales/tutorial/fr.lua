-- Onboarding v2 (src/systems/Tutorial + src/ui/Narrator + components/GuideScreen):
-- roteiro do corvo narrador (script.<conversa>.<fala>, *ênfase* em sangue),
-- rodapé do balão, Guia de combos/glossário, tooltip da mana. Arquivo próprio
-- por locale; plugado no principal como `tutorial = require(...)`.
return {
    narrator = { name = "Plume" },
    footer = {
        ["continue"] = "Continuer",
        skip = "passer",
        disable = "Je sais jouer : couper le tutoriel",
    },
    act = {
        select = "Sélectionnez une carte",
        play = "Appuyez sur Jouer Cartes",
        end_turn = "Appuyez sur Fin du Tour",
    },
    settings_tips = "Tutoriel du corbeau",
    settings_reset = "Relancer le tutoriel",
    settings_reset_value = "{n} échanges vus",
    settings_reset_done = "Depuis le début",
    script = {
        intro = {
            hello = "Croâ ! Je suis *Plume*, le corbeau gardien de ce grimoire. Je vais vous apprendre à combattre. Promis, ce sera bref.",
            enemy = "Voici votre adversaire. La barre sous lui, c'est sa *vie* : videz-la et le combat est fini.",
            intent = "Cette icône, c'est son *intention* : ce qu'il fera à la fin de votre tour. Le chiffre indique les dégâts à venir.",
            hero = "Ici, VOTRE *vie* et votre *Blocage*. Si votre vie tombe à zéro, le voyage s'arrête.",
            hand = "Voici vos cartes. Le grimoire commence avec deux seulement. *Sélectionnez-en une* pour la préparer.",
            mana = "Chaque carte coûte du *mana* : le chiffre dans son coin. Le mana se remplit à chaque tour, alors dépensez-le sans compter.",
            preview = "Voici l'*aperçu* : les dégâts et le Blocage que votre sélection va produire, bonus compris.",
            play = "Prêt ? Allez-y : appuyez sur *Jouer Cartes* !",
        },
        end_turn = {
            ["end"] = "Joli coup ! Quand le mana ou les idées manquent, appuyez sur *Fin du Tour*. L'ennemi agit alors, exactement comme son intention l'annonçait.",
        },
        second_turn = {
            kept = "Vous voyez ? Il a fait ce qu'il avait annoncé. Lisez l'*intention* à chaque tour et protégez-vous quand un gros coup arrive.",
            loop = "Nouvelle main à chaque tour, mana au plein. À vous de jouer. Je reviendrai s'il y a du nouveau. Croâ !",
        },
        boss = {
            arrive = "Voici le *boss* de l'acte. Battez-le et la route mène à la contrée suivante.",
            signature = "Chaque boss a un coup signature : invocation, charge, coups qui percent le Blocage... Lisez l'*intention* à chaque tour.",
        },
        elite = {
            warn = "Attention : un *Élite*. Plus coriace qu'un ennemi ordinaire, mais la récompense est meilleure aussi.",
        },
        block = {
            reset = "Vous avez gagné du *Blocage* : il absorbe le prochain coup. Mais attention : le Blocage *repart à zéro au début de votre tour*. Impossible de le garder.",
        },
        combo = {
            seal = "Regardez : des cartes de votre main *se combinent* ! Jouées ENSEMBLE dans le même tour, elles rapportent plus. L'aperçu affiche le sceau *+COMBO*.",
            guide = "La liste complète des combos se trouve dans le *Guide*, dans le menu Pause.",
        },
        orbs = {
            pulse = "Vos *orbes* ! Chacun pulse à la fin de votre tour, et le chiffre inscrit dessus est l'effet.",
            evoke = "Canaliser avec la rangée pleine *évoque* le plus ancien, celui de la flèche, avec un effet plus fort.",
        },
        jokers = {
            passive = "Un *Joker* ! Il agit tout seul pendant toute la partie, sans coûter de mana.",
            bench = "Seuls les *actifs* de ce cadre fonctionnent ; les autres attendent sur le banc. Ouvrez le cadre pour les échanger.",
        },
        rewards = {
            pick = "Victoire ! Choisissez *une* carte pour votre grimoire.",
            skip = "Ou passez : un grimoire léger pioche plus souvent ses meilleures cartes. Parfois, moins c'est mieux.",
        },
        dice_help = {
            what = "Les *Dés du Scribe* sont un pari facultatif : vous annoncez la somme de deux dés et misez de l'or dessus.",
            bets = "*Bas* (somme 2 à 6) et *Haut* (8 à 12) gagnent 42 % du temps et paient 2,5× la mise. Le *Sept* gagne 17 % du temps et paie 6×.",
            stakes = "La *mise* est ce que vous risquez, et ses valeurs augmentent à chaque acte. Si vous perdez, la maison la garde.",
            once = "Un lancer par visite à la boutique, et le résultat est définitif tout de suite, même si vous partez et revenez. En moyenne la table est à l'équilibre : elle sert à tenter sa chance quand il manque peu pour un achat.",
        },
        dice = {
            odds = "Deux dés, un pari. *Bas* (2 à 6) et *Haut* (8 à 12) paient 2,5× ; le *Sept* paie 6×.",
            bet = "Choisissez le pari et la mise, puis lancez. Chaque pari affiche sa probabilité.",
        },
        shop = {
            offers = "La *boutique* ! Cartes, reliques et paquets, contre de l'or.",
            refresh = "Rien ne vous plaît ? *Actualiser* change la vitrine, mais coûte plus cher à chaque fois.",
            dice = "Et là-bas, les *Dés du Scribe* : pariez de l'or sur un lancer de deux dés. Un lancer par boutique.",
            interest = "Ah, et l'or gardé rapporte des *intérêts* : chaque tranche de 5 $ vaut +1 $ quand vous gagnez un combat, jusqu'à +5 $.",
        },
        forge = {
            pick = "À la *forge*, choisissez une carte à améliorer. Chaque copie évolue séparément.",
        },
        rest = {
            choose = "Un *feu de camp*. Reposez-vous pour regagner de la vie, ou prenez le temps de *forger* une carte.",
        },
        event = {
            read = "Un *événement* ! Lisez bien : chaque choix indique ce qu'il coûte [-] et ce qu'il rapporte [+].",
        },
        fork = {
            paths = "Une *croisée des chemins*. Chaque borne est une voie : combat, *Élite*, repos, boutique ou événement. À vous de choisir.",
        },
        endless = {
            cycle = "Au-delà du dernier boss s'étend l'*Infini*. À chaque cycle de huit étages, vous choisissez une *malédiction*.",
            grow = "Les ennemis grandissent à chaque cycle, sans limite. Jusqu'où tiendra votre grimoire ?",
        },
        seals = {
            unlocked = "Victoire ! Vous pouvez maintenant briser les *Sceaux du Grimoire* : chaque sceau est une règle plus dure, et ils se cumulent.",
            score = "Plus de sceaux, plus de points. Gagnez avec un sceau pour débloquer le suivant, avec la même classe.",
        },
    },
    guide = {
        title = "GUIDE DU GRIMOIRE",
        tab_combos = "Combos",
        tab_glossary = "Glossaire",
        examples = "Ex. : {cards}",
        intro = "Les combos comptent entre cartes jouées ENSEMBLE, dans la même main. Le sceau +COMBO vous prévient quand un combo est prêt.",
        close_hint = "Échap / B ferme · < > onglets",
        pause_shortcut = "Guide [G]",
    },
    status = {
        mana = { name = "Mana",
            desc = "{stacks} sur {duration} disponible. Chaque carte coûte le chiffre de son coin. Se remplit au début de votre tour ; le surplus ne se garde pas." },
    },
}
