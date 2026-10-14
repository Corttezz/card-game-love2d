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
            seal = "Jouez plusieurs cartes ENSEMBLE : chaque attaque après la première frappe plus fort (*Salve*), chaque défense après la première donne plus de Blocage (*Rempart*), et les cartes identiques valent plus (*Paire*).",
            guide = "Le sceau au-dessus d'une carte montre le bonus qu'elle gagnerait maintenant. La liste complète est dans le *Guide*, dans le menu Pause.",
        },
        conduit = {
            passive = "Vous êtes un *Mage*. Votre passive, *{passive}*, ouvre chaque combat avec un *orbe de Foudre* déjà dans la rangée. Un orbe est un sort qui reste armé et agit tout seul.",
            row = "Voici votre *rangée d'orbes* : {slots} emplacements. Un emplacement vide est un anneau éteint. Un nouvel orbe entre par la droite.",
            number = "Le chiffre sous l'orbe dit ce qu'il fait tout seul à la fin de chacun de vos tours : sa *pulsation*. Cette Foudre pulse *{pulse}* dégâts.",
        },
        channel = {
            card = "Cette carte *canalise* : en plus de l'effet écrit, elle crée un nouvel orbe dans la rangée. Survolez-la et l'emplacement qui va le recevoir clignote.",
            made = "Vous avez *canalisé* : la carte a fait son effet écrit ET créé un nouvel orbe, entré par la droite de la rangée.",
            oldest = "Celui de gauche, avec le cadre clair, est le *plus ancien*. La flèche sur le rail marque la sortie : quand un orbe part, c'est toujours lui d'abord.",
            hover = "Survolez un orbe pour voir les chiffres exacts : combien il pulse par tour et combien il rend quand on l'*évoque*. J'y arrive.",
        },
        pulse = {
            happened = "Vous avez vu la fin de votre tour ? Les orbes ont *pulsé* : chacun a fait ce que son chiffre disait, sans carte ni mana. C'est ainsi à chaque tour, tant qu'ils sont dans la rangée.",
            kinds = "Chaque élément pulse à sa façon : *Foudre* et *Feu* blessent l'ennemi, *Glace* donne du Blocage, *Sacré* soigne. *Ombre* ne pulse pas : elle grandit chaque tour et s'évoque en double.",
            reveal = "Et l'éclair de la *Foudre* a un bonus : quand l'intention de l'ennemi est cachée par la brume, sa pulsation révèle la prochaine annonce.",
        },
        evoke_card = {
            card = "Cette carte *évoque* : l'orbe le plus ancien, celui du cadre, quitte la rangée et libère d'un coup son effet *complet*. Plus fort que la pulsation, mais l'orbe s'en va.",
            preview = "Survolez la carte : l'orbe qui va partir s'allume en *cyan* et son chiffre devient la valeur d'évocation.",
            all = "*Tout évoquer* vide la rangée entière, un orbe à la fois, du plus ancien au plus récent.",
        },
        overflow = {
            full = "Rangée pleine et vous en avez canalisé un de plus : l'orbe *le plus ancien* a été expulsé et, en sortant, il s'est *évoqué* à pleine valeur. Rien n'est perdu.",
            plan = "Autrement dit : avec les {slots} emplacements pleins, chaque nouvelle canalisation est aussi une évocation. Remplissez la rangée et chaque carte devient un tir.",
        },
        focus = {
            what = "Vous avez du *Focus* : chaque point s'ajoute à la valeur de tous vos orbes, à la pulsation comme à l'évocation. Les chiffres des orbes le comptent déjà.",
            conduit = "Désormais, *{passive}* donne aussi {f} de Focus au début de chaque combat. Plus le voyage est profond, plus il y en a.",
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
            offers = "La *boutique* ! Des cartes sur leurs chevalets, des reliques et un paquet sur le comptoir, contre de l'or.",
            price = "Chaque pièce porte son *prix* : plaque de laiton sous la carte, étiquette pendue au devant du comptoir pour le reste. En rouge, ce que vous ne pouvez pas encore payer.",
            buy = "Cliquez sur une pièce pour la lire sur le *parchemin* ; l'achat se fait sur le ruban *ACHETER*. Survolez-les et les objets disent ce qu'ils font.",
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
        class_select = {
            welcome = "Croâ ! Avant le voyage, choisissez qui portera le grimoire. Pour commencer, rien ne vaut le *Guerrier*.",
            warrior = "Le Guerrier frappe fort et encaisse les coups. Sa passive, c'est *{passive}* : {rule}",
            start = "Commencez par ici. Quand vous êtes prêt, ouvrez le voyage avec ce ruban.",
            locked = "Les autres classes sont enchaînées, et c'est en jouant qu'on les libère. {list}",
            details = "Et ce signet ouvre les *détails* de la classe : cartes de départ et chiffres.",
        },
        fog = {
            veil = "La *brume* s'est refermée. Vous voyez encore le TYPE de son coup, mais pas le nombre. Le coup est déjà décidé, seule la lecture a disparu.",
            counter = "Quand le blizzard s'ouvre, le nombre revient. Les cartes *Révéler* et la pulsation de l'orbe de Foudre dissipent aussi la brume pour un tour.",
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
        intro = "Les combos comptent entre cartes jouées ENSEMBLE, dans le même coup. Le sceau au-dessus d'une carte en main montre le bonus de combo qu'elle gagnerait.",
        close_hint = "Échap / B ferme · < > onglets",
        pause_shortcut = "Guide [G]",
    },
    status = {
        mana = { name = "Mana",
            desc = "{stacks} sur {duration} disponible. Chaque carte coûte le chiffre de son coin. Se remplit au début de votre tour ; le surplus ne se garde pas." },
    },
}
