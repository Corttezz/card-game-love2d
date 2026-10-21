return {
    ui = {
        tab_cards        = "Karten",
        tab              = "Kreaturen",
        count            = "{n} von {total} Kreaturen",
        act_header       = "Akt {n} · {biome}",
        tier = {
            common   = "Gewöhnlich",
            elite    = "Elite",
            miniboss = "Zwischenboss",
            boss     = "Boss",
        },
        unknown          = "???",
        undiscovered     = "Noch nicht begegnet",
        moves            = "Bekannte Angriffe",
        moves_hidden     = "Besiege sie, um ihre Angriffe kennenzulernen.",
        signature        = "Kennzeichen",
        lore             = "Aufzeichnung",
        stat_seen        = "Begegnet",
        stat_defeated    = "Besiegt",
        stat_killed_you  = "Hat dich besiegt",
        new_creatures    = "Neue Kreaturen: {n}",
        end_label        = "NEUE KREATUREN",
        habitat          = "Lebensraum: {biome}",
        biome = {
            fields    = "Verwüstete Felder",
            highlands = "Turmhügel",
            abyss     = "Abgrundstraße",
            frost     = "Geisterhafter Gletscher",
            marsh     = "Fäulnissumpf",
            dusk      = "Dämmerfelder",
        },
    },

    creature = {
        cursed_scarecrow = {
            epithet = "Wächter der toten Felder",
            lore = "Aus dem Stroh einer Ernte genäht, die nie reifte, bewacht sie das Kornfeld noch über das Ende hinaus. Krähen nisten in ihrer Brust und picken für sie. Ihr Kürbisblick raubt jedem den Mut, der über den Zaun steigt.",
        },
        hollow_farmer = {
            epithet = "Was die Erde erntete",
            lore = "Er pflügte die Erde, bis die Erde ihn pflügte. Noch immer trägt er Mistgabel und Hut, doch innen sind nur feuchtes Stroh und Wurzeln geblieben. Hebt er die Gabel langsam, ist es Zeit, sich zu schützen.",
        },
        plague_rats = {
            epithet = "die hungrige Brut",
            lore = "Sie ziehen nie allein umher. Sie nagten sich durch die leeren Scheunen und dann durch die Toten, die niemand begrub. Jeder Biss hinterlässt das Pestfieber im Blut.",
        },
        harvest_reaper = {
            epithet = "Schnitter der letzten Ernte",
            lore = "Er kam für das Korn und blieb für die Schnitter. Er zeichnet seine Beute vor dem Schnitt und wetzt die Klinge zwischen den Hieben. Man sagt, die Glut zu seinen Füßen seien die Seelen der letzten Ernte.",
        },
        blight_bull = {
            epithet = "Zorn der fauligen Weide",
            lore = "Vor der Seuche weidete er auf diesen Feldern; heute weidet er nur noch am Fleisch der Reisenden. Sein Fell faulte, bis es hart wie Rinde wurde. Wenn er brüllt, bebt die Erde, und die Hörner folgen sofort.",
        },
        wicker_effigy = {
            epithet = "das Opfer, das verbrannte",
            lore = "Die Dorfbewohner flochten sie aus Weiden, um Regen zu erbitten, und verbrannten sie beim letzten Erntefest. Das Feuer in ihr erlosch nie. Sie schürt ihre eigene Glut und verschwindet im Rauch, bevor sie zuschlägt.",
        },
        carrion_king = {
            epithet = "Herr des Krähenschwarms",
            lore = "Gekrönt von den Krähen, die sich auf den verwüsteten Feldern satt fraßen, herrscht er über alles, was unter freiem Himmel verfault. Er ruft den Schwarm, und jeder weitere Vogel ist ein weiterer Hieb. Verwundet steigt er zu seinem Aasmahl hinab und heilt sich.",
            signature = "Alle vier Züge ruft er zwei weitere Krähen; der Krähenschwarm trifft für jede Krähe um ihn einmal mehr und macht dich Schwach.",
        },

        moon_gargoyle = {
            epithet = "Hüterin der Zinnen",
            lore = "Gemeißelt, um über den Turm zu wachen, erwachte sie beim ersten Vollmond ohne Herrn. Am Tag ist sie Stein; bei Nacht stürzt sie sich mit Granitkrallen von den Zinnen. Ihr Mondschrei lässt die Hände aller zittern, die ihn hören.",
        },
        ram_cultist = {
            epithet = "Diener des gehörnten Schädels",
            lore = "Er trägt den Schädel eines Widders als Maske und singt die Hymnen, die der Turm ihn lehrte. Er schwingt sein Weihrauchfass als Waffe und brandmarkt die Haut der Ketzer. Zwischen den Hieben betet er, und er wird erhört.",
        },
        storm_harpy = {
            epithet = "Tochter des Donners",
            lore = "Sie wird aus den Blitzen geboren, die in die Hügel einschlagen, und fliegt mit dem Wind im Rücken. Sie greift mit Krallenwirbeln an und stürzt aus der Höhe herab. Ihr Kreischen übertönt den Donner.",
        },
        rune_golem = {
            epithet = "Wächter aus beschriebenem Stein",
            lore = "Der Lich ritzte Runen in Steinblöcke und gab ihnen einen einzigen Befehl: die Treppe bewachen. Die Runen leuchten, wenn er sich schützt, und brennen durch deinen Block, wenn er zuschlägt. Überladen trifft er wie ein Rammbock.",
        },
        spectral_knight = {
            epithet = "der Eid, der nicht starb",
            lore = "Er schwor, den Turm zu verteidigen, und starb auf der Treppe, doch der Eid starb nicht mit ihm. Hinter seinem Turmschild erwidert er jeden Hieb. Seine Geisterlanze durchbohrt jede Rüstung.",
        },
        storm_griffin = {
            epithet = "Herr der Gipfel",
            lore = "Er nistet auf dem höchsten Punkt der Hügel, wo die Blitze zuerst einschlagen. Er brüllt, und der Donner antwortet. Er stürzt aus dem Sturm herab, die Krallen voller Blitze.",
        },
        tower_lich = {
            epithet = "Meister des Runenrituals",
            lore = "Er stieg in den Turm, um den Tod zu studieren, und kam nie wieder herab. Er saugt den Lebenden die Essenz aus, um ein Ritual aus vier Runen zu nähren. Wenn die letzte Rune aufflammt, stürzt der ganze Turm auf dich herab.",
            signature = "Er erhält eine Rune pro Zug; bei vier entfesselt er den Runenkataklysmus, einen Treffer pro Rune. Füge in einem einzigen Zug viel Schaden zu, um eine Rune zu brechen.",
        },

        ember_imp = {
            epithet = "das Lachen der Glut",
            lore = "Klein, flink und immer lachend. Er schleudert Feuerbälle, die die Haut über Züge hinweg brennen lassen. Jedes Kichern verspricht, dass der nächste Hieb mehr schmerzt.",
        },
        hellhound = {
            epithet = "der zweiköpfige Hund",
            lore = "Zwei Köpfe und ein einziger Hunger. Er wittert die Lebenden entlang der Abgrundstraße und beißt mit beiden Mäulern zugleich. Sein Atem hinterlässt Brandwunden, die sich nicht schließen.",
        },
        abyss_acolyte = {
            epithet = "Leser des brennenden Folianten",
            lore = "Er dient dem Tyrannen und liest laut aus einem Folianten, der brennt, ohne zu verglühen. Jede Seite ist ein Fluch, der den Körper schwächt. Besiegelt er den dunklen Pakt, schließen sich seine Wunden und er kehrt stärker zurück.",
        },
        obsidian_sentinel = {
            epithet = "die Mauer aus schwarzem Glas",
            lore = "Im Schlund des Vulkans aus Obsidian geschmiedet, bewacht er die Tore des Abgrunds. Vor jedem Ansturm errichtet er ein Bollwerk. Wenn er springt, verstreut er Splitter, scharf wie Rasiermesser.",
        },
        pit_brute = {
            epithet = "Henker der Grube",
            lore = "Am Grund der Grube aufgewachsen, lernte er nur, den Hammer zu heben und fallen zu lassen. Hebt er ihn, hast du einen Zug, um dich vorzubereiten. Die Kettenpeitsche erledigt den Rest.",
        },
        abyss_watcher = {
            epithet = "das Auge, das nie blinzelt",
            lore = "Es schwebt über der Straße und sieht alles mit drei Augen. Sein Blick macht wahnsinnig und schwach zugleich. Der Augenstrahl durchdringt die Rüstung, und die Tentakel erledigen den Rest.",
        },
        abyss_tyrant = {
            epithet = "der Gefesselte des Abgrunds",
            lore = "Die Alten ketteten ihn am Grund des Abgrunds an und versiegelten jedes Glied mit Feuer. Die Glieder geben nach. Mit jeder Kette, die reißt, taumelt er und kehrt wütender zurück, während er Flammen für das Höllenfeuer sammelt.",
            signature = "Drei Ketten reißen bei 75 %, 50 % und 25 % seines Lebens: Reißt eine, wird sein angekündigter Hieb halbiert, doch danach schlägt er härter zu.",
        },

        frost_wight = {
            epithet = "der Tote des Schneesturms",
            lore = "Er erfror auf dem Weg zur Zitadelle und wandert ihn noch immer. Er verbirgt sich im Schneesturm: Nie weißt du, wie hart der nächste Hieb wird. Seine Berührung lässt das Blut gefrieren und bricht die Deckung.",
        },
        frost_wolf = {
            epithet = "das Heulen des Gletschers",
            lore = "Er jagte im Rudel, doch das Rudel starb im Eis, und nur er blieb übrig. Noch immer heult er, um es zu rufen, und das Heulen macht ihn stärker. Er beißt dreimal, bevor du blinzeln kannst.",
        },
        rime_shaman = {
            epithet = "der Alte der Eistotems",
            lore = "Er spricht mit der Kälte, und die Kälte antwortet. Er errichtet Eistotems zu seinem Schutz und schleudert Frostbolzen. Sein Fluch lässt deine Hände taub werden.",
        },
        glacier_knight = {
            epithet = "die Rüstung, die das Eis bewahrte",
            lore = "Er diente dem Monarchen, bis der Winter ihn ganz bedeckte. Nun ist das Eis seine Rüstung und seine Lanze. Die Eislanze durchbohrt deinen Block, und die Gletscherägide schützt ihn.",
        },
        frost_troll = {
            epithet = "Riese des ewigen Schnees",
            lore = "Wild und langsam, doch seine Wunden schließen sich jeden Zug von selbst. Sein dickes Fell dämpft die Schläge. Töte ihn schnell, sonst musst du ihn zweimal töten.",
        },
        ice_wyrm = {
            epithet = "Schlange des gefrorenen Sees",
            lore = "Sie schläft zusammengerollt unter dem Eis des Sees, bis sie Schritte hört. Vor ihrem Frostatem holt sie tief Luft, und das ist die einzige Warnung. Ihre Schuppen sind hart wie der Winter.",
        },
        winter_monarch = {
            epithet = "König des endlosen Winters",
            lore = "Er krönte sich an dem Tag, an dem die Sonne nicht zurückkehrte, und schwor, dass sie nie zurückkehren würde. Jeder seiner Hiebe hinterlässt Frost auf deinen Händen, und der Frost lässt deine teuersten Karten gefrieren. Alle drei Züge ruft er den Ewigen Winter.",
            signature = "Frost sammelt sich auf dir; ab 4 gefrieren die zwei teuersten Karten deiner Hand beim Ziehen. Angriffe schmelzen den Frost, Feuerkarten schmelzen doppelt so viel.",
        },

        bog_ghoul = {
            epithet = "der Hungrige aus dem Schlamm",
            lore = "Er kroch hungrig aus dem Sumpf und hat diesen Hunger nie gestillt. Sein Biss vergiftet das Blut. Wenn er frisst, fügt sich sein fauliges Fleisch wieder zusammen.",
        },
        plague_toad = {
            epithet = "der quakende Herold",
            lore = "Aufgebläht vor Gift, speit sie die Pest über mehrere Schritte. Wenn sie quakt, wird die Luft schwer und krank. Sie bläht ihren Körper auf, um die Hiebe auszuhalten.",
        },
        leech_horror = {
            epithet = "Hunger der tausend Mäuler",
            lore = "Tausend Egel, die gelernt haben, gemeinsam zu gehen. Jedes Maul trinkt ein wenig, und das Ganze heilt sich mit dem, was es trinkt. Wenn es sich festsaugt, weicht die Kraft aus deinem Arm.",
        },
        mire_hag = {
            epithet = "Hexe des Kessels",
            lore = "Sie kennt jedes Kraut des Sumpfes und weiß, welches tötet. Sie wirkt Flüche, die schwächen und zerbrechlich machen, und schöpft Gift aus ihrem Kessel. Blutet sie, trinkt sie ihr eigenes Sumpfgebräu.",
        },
        croc_warrior = {
            epithet = "Krieger der Ufer",
            lore = "Er bewacht die Ufer mit Speer und Panzer. Wenn er zubeißt, wirbelt er seine Beute in der Todesrolle herum. Seine Kiefer durchdringen jeden Block.",
        },
        spore_mother = {
            epithet = "der Garten der Toten",
            lore = "Sie keimte aus einer Leiche und wuchs, bis sie den ganzen Sumpf beherbergte. Sie verbreitet Sporenwolken, die die Luft vergiften. Ihre Myzelwurzeln heilen sie jeden Zug.",
        },
        rot_colossus = {
            epithet = "das faulige Herz des Sumpfes",
            lore = "Aus Stämmen, Knochen und Schlamm gemacht, ist der Koloss der Sumpf selbst, aufgerichtet. Seine Wurzeln trinken aus der Erde und heilen ihn langsam. Schneide sie durch, sonst endet der Kampf nie.",
            signature = "Wurzeln im Boden heilen ihn jeden Zug ein wenig und wachsen alle zwei Züge nach, bis zu drei. Ein einziger harter Hieb kappt eine Wurzel.",
        },

        dusk_shade = {
            epithet = "Flüstern der Dämmerung",
            lore = "Er entsteht aus dem letzten Schatten vor der Nacht. Er flüstert, und der Wille wankt; seine Schattenklinge gleitet durch deinen Block. Die Dämmerung verhüllt ihn, und seine Absicht ist schwer zu lesen.",
        },
        dusk_bat = {
            epithet = "die Blutschwinge",
            lore = "Sie fliegt in Wirbeln und trinkt bei jedem Biss. Ihr Kreischen macht den Körper schwach. Je mehr du blutest, desto länger lebt sie.",
        },
        grave_thrall = {
            epithet = "die Knochenmauer",
            lore = "Aus einem flachen Grab erhoben, um dem Hof als Mauer zu dienen. Er trägt einen Schild, größer als er selbst, und führt ihn als Waffe. Das Klappern seiner Knochen macht deine Deckung zerbrechlich.",
        },
        blood_duke = {
            epithet = "Herr des purpurnen Festmahls",
            lore = "Ein Adliger des Finsternis-Hofes, der nie ein Festmahl ausschlug. Er saugt denen, die er verwundet, das Leben aus und wird mit jedem Schluck stärker. Die Blutung, die er verursacht, macht das Fleisch verwundbar.",
        },
        dullahan = {
            epithet = "der kopflose Ritter",
            lore = "Er verlor seinen Kopf in einer Schlacht, an die sich niemand mehr erinnert. Wo er sein sollte, trägt er eine violette Flamme. Sein augenloser Blick verbreitet noch immer Grauen.",
        },
        fallen_angel = {
            epithet = "das gefallene Licht",
            lore = "Sie fiel vom Himmel, als die Finsternis begann, und wollte nicht wieder aufsteigen. Ihre unheiligen Schwingen schützen und stärken sie. Ihr Urteil durchdringt jeden Block.",
        },
        eclipse_queen = {
            epithet = "Herrin des schwarzen Mondes",
            lore = "Sie herrscht über den Hof der Dämmerung, seit der Mond die Sonne verschlang. Ihre Kraft wächst und schwindet mit den Phasen des Mondes. Bis zur Hälfte verwundet, wird sie selbst zur Finsternis.",
            signature = "Der Mond durchläuft vier Phasen: Bei Vollmond zählt ihr Hieb 50 % mehr; bei Neumond wirst du Verwundbar. Unter der Hälfte ihres Lebens tritt sie in die Finsternis ein.",
        },
    },
}
