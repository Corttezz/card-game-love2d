# tools/achievement_text.py
# Texto-FONTE das conquistas nos 5 idiomas + gerador.
#
#   python -I tools/achievement_text.py locales   -> reescreve o bloco
#       `achievements = {...}` de src/i18n/locales/*.lua
#   python -I tools/achievement_text.py steam     -> steam/achievements/
#       achievements.json + achievements.vdf-like .txt pra cadastro
#
# POR QUE UM GERADOR: o mesmo texto vive em 3 lugares (jogo, painel da Steam,
# loja). Editar os 5 locales a mao e copiar pro painel e o caminho certo pra
# eles divergirem. Edite AQUI e rode os dois modos.
#
# Convencao do projeto (Out/2026): acento de verdade nos 5 idiomas (a fonte
# desenha o Latin-1 inteiro, maiusculas acentuadas inclusive — ver
# tools/test_locale_accents.lua). A Steam aceita UTF-8 — o export usa o
# mesmo texto do jogo.
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Ordem = ordem do catalogo src/data/achievements.lua
ORDER = ["primeiro_chefe", "capitulo_final", "primeira_pagina", "vitoria_guerreiro",
         "vitoria_mago", "vitoria_ladino", "trindade", "despertar", "coro_coringas",
         "grimorio_bolso", "enciclopedia", "voto_pobreza", "asceta", "tinta_crua",
         "sem_rascunhos", "relampago", "fio_navalha", "imaculado", "miasma", "muralha",
         "tinta_viva", "golpe_tinta", "conduite_pleno", "maos_limpas", "velas_10k",
         "escriba", "ferreiro", "veterano", "bibliotecario", "alem_da_pagina",
         "ciclo_3", "ciclo_5", "ciclo_10", "primeiro_selo", "selo_max_guerreiro",
         "selo_max_mago", "selo_max_ladino"]

T = {}
T["pt_BR"] = {
    "primeiro_chefe": ("Coroa Partida", "Derrote seu primeiro chefe."),
    "capitulo_final": ("O Terceiro Capítulo", "Derrote o chefe do Ato 3."),
    "primeira_pagina": ("Primeira Página", "Vença sua primeira corrida."),
    "vitoria_guerreiro": ("Lâmina Lendária", "Vença uma corrida com o Guerreiro."),
    "vitoria_mago": ("Arcano Supremo", "Vença uma corrida com o Mago."),
    "vitoria_ladino": ("Sombra Invicta", "Vença uma corrida com o Ladino."),
    "trindade": ("Trindade do Grimório", "Vença uma corrida com cada classe."),
    "despertar": ("Todos Despertos", "Desbloqueie todas as classes."),
    "coro_coringas": ("Coro de Coringas", "Vença uma batalha com todos os espaços de coringa ocupados."),
    "grimorio_bolso": ("Grimório de Bolso", "Vença com um deck de 6 cartas ou menos."),
    "enciclopedia": ("Enciclopédia Ambulante", "Vença com 30 ou mais cartas no deck."),
    "voto_pobreza": ("Voto de Pobreza", "Vença sem comprar nada em lojas."),
    "asceta": ("Asceta", "Vença sem possuir nenhum coringa."),
    "tinta_crua": ("Tinta Crua", "Vença usando apenas cartas comuns."),
    "sem_rascunhos": ("Sem Rascunhos", "Vença sem nunca usar a Forja."),
    "relampago": ("Relâmpago Selado", "Vença uma batalha antes de o inimigo agir."),
    "fio_navalha": ("Fio da Navalha", "Vença uma batalha com exatamente 1 HP."),
    "imaculado": ("Imaculado", "Derrote um chefe sem tomar dano."),
    "miasma": ("Miasma", "Acumule 15 de veneno em um inimigo."),
    "muralha": ("Muralha do Escriba", "Atinja o máximo de bloqueio num turno."),
    "tinta_viva": ("Tinta Viva", "Dispare 4 combos no mesmo turno."),
    "golpe_tinta": ("Golpe de Tinta", "Cause 60 de dano com uma única carta."),
    "conduite_pleno": ("Conduíte Pleno", "Tenha 3 orbes canalizados ao mesmo tempo."),
    "maos_limpas": ("Mãos Limpas", "Vença uma batalha sem jogar cartas de ataque."),
    "velas_10k": ("Dez Mil Velas", "Alcance 10.000 pontos numa corrida."),
    "escriba": ("Escriba Incansável", "Jogue 2500 cartas (somando corridas)."),
    "ferreiro": ("Ferreiro-Mor", "Forje 25 cartas (somando corridas)."),
    "veterano": ("Veterano das Páginas", "Vença 10 corridas."),
    "bibliotecario": ("Bibliotecário", "Descubra todas as cartas do grimório."),
    "alem_da_pagina": ("Além da Última Página", "Alcance o andar 10 do Sem Fim."),
    "ciclo_3": ("Três Voltas", "Feche o ciclo 3 do Sem Fim."),
    "ciclo_5": ("Cinco Voltas", "Feche o ciclo 5 do Sem Fim."),
    "ciclo_10": ("Ouroboros", "Feche o ciclo 10 do Sem Fim."),
    "primeiro_selo": ("Lacre Rompido", "Vença uma corrida com um Selo do Grimório."),
    "selo_max_guerreiro": ("Último Selo: Guerreiro", "Vença com o Guerreiro no Selo 10."),
    "selo_max_mago": ("Último Selo: Mago", "Vença com o Mago no Selo 10."),
    "selo_max_ladino": ("Último Selo: Ladino", "Vença com o Ladino no Selo 10."),
}
T["en"] = {
    "primeiro_chefe": ("Broken Crown", "Defeat your first boss."),
    "capitulo_final": ("The Third Chapter", "Defeat the Act 3 boss."),
    "primeira_pagina": ("First Page", "Win your first run."),
    "vitoria_guerreiro": ("Legendary Blade", "Win a run with the Warrior."),
    "vitoria_mago": ("Supreme Arcanist", "Win a run with the Mage."),
    "vitoria_ladino": ("Unbeaten Shadow", "Win a run with the Rogue."),
    "trindade": ("Grimoire Trinity", "Win a run with every class."),
    "despertar": ("All Awakened", "Unlock every class."),
    "coro_coringas": ("Choir of Jokers", "Win a battle with every joker slot filled."),
    "grimorio_bolso": ("Pocket Grimoire", "Win with a deck of 6 cards or fewer."),
    "enciclopedia": ("Walking Encyclopedia", "Win with 30 or more cards in your deck."),
    "voto_pobreza": ("Vow of Poverty", "Win without buying anything in shops."),
    "asceta": ("Ascetic", "Win without owning a single joker."),
    "tinta_crua": ("Raw Ink", "Win using only common cards."),
    "sem_rascunhos": ("No Drafts", "Win without ever using the Forge."),
    "relampago": ("Sealed Lightning", "Win a battle before the enemy acts."),
    "fio_navalha": ("Razor's Edge", "Win a battle with exactly 1 HP."),
    "imaculado": ("Immaculate", "Defeat a boss without taking damage."),
    "miasma": ("Miasma", "Stack 15 poison on an enemy."),
    "muralha": ("Scribe's Rampart", "Reach maximum block in a turn."),
    "tinta_viva": ("Living Ink", "Trigger 4 combos in the same turn."),
    "golpe_tinta": ("Ink Strike", "Deal 60 damage with a single card."),
    "conduite_pleno": ("Full Conduit", "Have 3 orbs channeled at once."),
    "maos_limpas": ("Clean Hands", "Win a battle without playing attack cards."),
    "velas_10k": ("Ten Thousand Candles", "Reach 10,000 points in a run."),
    "escriba": ("Tireless Scribe", "Play 2500 cards (across runs)."),
    "ferreiro": ("Master Smith", "Forge 25 cards (across runs)."),
    "veterano": ("Veteran of the Pages", "Win 10 runs."),
    "bibliotecario": ("Librarian", "Discover every card in the grimoire."),
    "alem_da_pagina": ("Beyond the Last Page", "Reach floor 10 of endless mode."),
    "ciclo_3": ("Three Turns", "Close cycle 3 of endless mode."),
    "ciclo_5": ("Five Turns", "Close cycle 5 of endless mode."),
    "ciclo_10": ("Ouroboros", "Close cycle 10 of endless mode."),
    "primeiro_selo": ("Broken Seal", "Win a run with a Grimoire Seal."),
    "selo_max_guerreiro": ("Last Seal: Warrior", "Win with the Warrior on Seal 10."),
    "selo_max_mago": ("Last Seal: Mage", "Win with the Mage on Seal 10."),
    "selo_max_ladino": ("Last Seal: Rogue", "Win with the Rogue on Seal 10."),
}
T["es"] = {
    "primeiro_chefe": ("Corona Rota", "Derrota a tu primer jefe."),
    "capitulo_final": ("El Tercer Capítulo", "Derrota al jefe del Acto 3."),
    "primeira_pagina": ("Primera Página", "Gana tu primera partida."),
    "vitoria_guerreiro": ("Hoja Legendaria", "Gana una partida con el Guerrero."),
    "vitoria_mago": ("Arcano Supremo", "Gana una partida con el Mago."),
    "vitoria_ladino": ("Sombra Invicta", "Gana una partida con el Pícaro."),
    "trindade": ("Trinidad del Grimorio", "Gana una partida con cada clase."),
    "despertar": ("Todos Despiertos", "Desbloquea todas las clases."),
    "coro_coringas": ("Coro de Comodines", "Gana una batalla con todos los espacios de comodín ocupados."),
    "grimorio_bolso": ("Grimorio de Bolsillo", "Gana con un mazo de 6 cartas o menos."),
    "enciclopedia": ("Enciclopedia Andante", "Gana con 30 o más cartas en el mazo."),
    "voto_pobreza": ("Voto de Pobreza", "Gana sin comprar nada en las tiendas."),
    "asceta": ("Asceta", "Gana sin poseer ningún comodín."),
    "tinta_crua": ("Tinta Cruda", "Gana usando solo cartas comunes."),
    "sem_rascunhos": ("Sin Borradores", "Gana sin usar nunca la Forja."),
    "relampago": ("Relámpago Sellado", "Gana una batalla antes de que el enemigo actúe."),
    "fio_navalha": ("Filo de la Navaja", "Gana una batalla con exactamente 1 PV."),
    "imaculado": ("Inmaculado", "Derrota a un jefe sin recibir daño."),
    "miasma": ("Miasma", "Acumula 15 de veneno en un enemigo."),
    "muralha": ("Muralla del Escriba", "Alcanza el bloqueo máximo en un turno."),
    "tinta_viva": ("Tinta Viva", "Activa 4 combos en el mismo turno."),
    "golpe_tinta": ("Golpe de Tinta", "Inflige 60 de daño con una sola carta."),
    "conduite_pleno": ("Conducto Pleno", "Ten 3 orbes canalizados a la vez."),
    "maos_limpas": ("Manos Limpias", "Gana una batalla sin jugar cartas de ataque."),
    "velas_10k": ("Diez Mil Velas", "Alcanza 10.000 puntos en una partida."),
    "escriba": ("Escriba Incansable", "Juega 2500 cartas (sumando partidas)."),
    "ferreiro": ("Maestro Herrero", "Forja 25 cartas (sumando partidas)."),
    "veterano": ("Veterano de las Páginas", "Gana 10 partidas."),
    "bibliotecario": ("Bibliotecario", "Descubre todas las cartas del grimorio."),
    "alem_da_pagina": ("Más Allá de la Última Página", "Alcanza el piso 10 del modo infinito."),
    "ciclo_3": ("Tres Vueltas", "Cierra el ciclo 3 del modo infinito."),
    "ciclo_5": ("Cinco Vueltas", "Cierra el ciclo 5 del modo infinito."),
    "ciclo_10": ("Uróboros", "Cierra el ciclo 10 del modo infinito."),
    "primeiro_selo": ("Lacre Roto", "Gana una partida con un Sello del Grimorio."),
    "selo_max_guerreiro": ("Último Sello: Guerrero", "Gana con el Guerrero en el Sello 10."),
    "selo_max_mago": ("Último Sello: Mago", "Gana con el Mago en el Sello 10."),
    "selo_max_ladino": ("Último Sello: Pícaro", "Gana con el Pícaro en el Sello 10."),
}
T["fr"] = {
    "primeiro_chefe": ("Couronne Brisée", "Vainquez votre premier boss."),
    "capitulo_final": ("Le Troisième Chapitre", "Vainquez le boss de l'Acte 3."),
    "primeira_pagina": ("Première Page", "Remportez votre premier périple."),
    "vitoria_guerreiro": ("Lame Légendaire", "Remportez un périple avec le Guerrier."),
    "vitoria_mago": ("Arcaniste Suprême", "Remportez un périple avec le Mage."),
    "vitoria_ladino": ("Ombre Invaincue", "Remportez un périple avec le Voleur."),
    "trindade": ("Trinité du Grimoire", "Remportez un périple avec chaque classe."),
    "despertar": ("Tous Éveillés", "Débloquez toutes les classes."),
    "coro_coringas": ("Choeur de Jokers", "Gagnez un combat avec tous les emplacements de joker occupés."),
    "grimorio_bolso": ("Grimoire de Poche", "Gagnez avec un deck de 6 cartes ou moins."),
    "enciclopedia": ("Encyclopédie Ambulante", "Gagnez avec 30 cartes ou plus dans le deck."),
    "voto_pobreza": ("Voeu de Pauvreté", "Gagnez sans rien acheter dans les boutiques."),
    "asceta": ("Ascète", "Gagnez sans posséder aucun joker."),
    "tinta_crua": ("Encre Brute", "Gagnez en n'utilisant que des cartes communes."),
    "sem_rascunhos": ("Sans Brouillon", "Gagnez sans jamais utiliser la Forge."),
    "relampago": ("Éclair Scellé", "Gagnez un combat avant que l'ennemi n'agisse."),
    "fio_navalha": ("Fil du Rasoir", "Gagnez un combat avec exactement 1 PV."),
    "imaculado": ("Immaculé", "Vainquez un boss sans subir de dégâts."),
    "miasma": ("Miasme", "Accumulez 15 de poison sur un ennemi."),
    "muralha": ("Rempart du Scribe", "Atteignez le blocage maximum en un tour."),
    "tinta_viva": ("Encre Vivante", "Déclenchez 4 combos dans le même tour."),
    "golpe_tinta": ("Coup d'Encre", "Infligez 60 dégâts avec une seule carte."),
    "conduite_pleno": ("Conduit Plein", "Ayez 3 orbes canalises en même temps."),
    "maos_limpas": ("Mains Propres", "Gagnez un combat sans jouer de carte d'attaque."),
    "velas_10k": ("Dix Mille Chandelles", "Atteignez 10 000 points en un périple."),
    "escriba": ("Scribe Infatigable", "Jouez 2500 cartes (tous périples confondus)."),
    "ferreiro": ("Maître Forgeron", "Forgez 25 cartes (tous périples confondus)."),
    "veterano": ("Vétéran des Pages", "Remportez 10 périples."),
    "bibliotecario": ("Bibliothécaire", "Découvrez toutes les cartes du grimoire."),
    "alem_da_pagina": ("Au-delà de la Dernière Page", "Atteignez l'étage 10 du mode infini."),
    "ciclo_3": ("Trois Tours", "Bouclez le cycle 3 du mode infini."),
    "ciclo_5": ("Cinq Tours", "Bouclez le cycle 5 du mode infini."),
    "ciclo_10": ("Ouroboros", "Bouclez le cycle 10 du mode infini."),
    "primeiro_selo": ("Sceau Brisé", "Gagnez une partie avec un Sceau du Grimoire."),
    "selo_max_guerreiro": ("Dernier Sceau : Guerrier", "Gagnez avec le Guerrier au Sceau 10."),
    "selo_max_mago": ("Dernier Sceau : Mage", "Gagnez avec le Mage au Sceau 10."),
    "selo_max_ladino": ("Dernier Sceau : Voleur", "Gagnez avec le Voleur au Sceau 10."),
}
T["de"] = {
    "primeiro_chefe": ("Zerbrochene Krone", "Besiege deinen ersten Boss."),
    "capitulo_final": ("Das Dritte Kapitel", "Besiege den Boss von Akt 3."),
    "primeira_pagina": ("Erste Seite", "Gewinne deinen ersten Lauf."),
    "vitoria_guerreiro": ("Legendäre Klinge", "Gewinne einen Lauf mit dem Krieger."),
    "vitoria_mago": ("Oberster Arkanist", "Gewinne einen Lauf mit dem Magier."),
    "vitoria_ladino": ("Unbesiegter Schatten", "Gewinne einen Lauf mit dem Schurken."),
    "trindade": ("Dreifaltigkeit des Grimoires", "Gewinne einen Lauf mit jeder Klasse."),
    "despertar": ("Alle Erwacht", "Schalte alle Klassen frei."),
    "coro_coringas": ("Chor der Joker", "Gewinne einen Kampf mit allen Joker-Plätzen belegt."),
    "grimorio_bolso": ("Taschen-Grimoire", "Gewinne mit einem Deck aus 6 Karten oder weniger."),
    "enciclopedia": ("Wandelnde Enzyklopädie", "Gewinne mit 30 oder mehr Karten im Deck."),
    "voto_pobreza": ("Armutsgelübde", "Gewinne, ohne in Läden etwas zu kaufen."),
    "asceta": ("Asket", "Gewinne, ohne einen einzigen Joker zu besitzen."),
    "tinta_crua": ("Rohe Tinte", "Gewinne nur mit gewöhnlichen Karten."),
    "sem_rascunhos": ("Ohne Entwurf", "Gewinne, ohne je die Schmiede zu benutzen."),
    "relampago": ("Versiegelter Blitz", "Gewinne einen Kampf, bevor der Gegner handelt."),
    "fio_navalha": ("Messers Schneide", "Gewinne einen Kampf mit genau 1 LP."),
    "imaculado": ("Makellos", "Besiege einen Boss, ohne Schaden zu nehmen."),
    "miasma": ("Miasma", "Häufe 15 Gift auf einem Gegner an."),
    "muralha": ("Wall des Schreibers", "Erreiche den maximalen Block in einem Zug."),
    "tinta_viva": ("Lebende Tinte", "Löse 4 Combos im selben Zug aus."),
    "golpe_tinta": ("Tintenschlag", "Verursache 60 Schaden mit einer einzigen Karte."),
    "conduite_pleno": ("Voller Leiter", "Habe 3 Kugeln gleichzeitig kanalisiert."),
    "maos_limpas": ("Saubere Hände", "Gewinne einen Kampf ohne Angriffskarten."),
    "velas_10k": ("Zehntausend Kerzen", "Erreiche 10.000 Punkte in einem Lauf."),
    "escriba": ("Unermüdlicher Schreiber", "Spiele 2500 Karten (über alle Läufe)."),
    "ferreiro": ("Schmiedemeister", "Schmiede 25 Karten (über alle Läufe)."),
    "veterano": ("Veteran der Seiten", "Gewinne 10 Läufe."),
    "bibliotecario": ("Bibliothekar", "Entdecke alle Karten des Grimoires."),
    "alem_da_pagina": ("Jenseits der Letzten Seite", "Erreiche Etage 10 im Endlosmodus."),
    "ciclo_3": ("Drei Runden", "Schließe Zyklus 3 des Endlosmodus ab."),
    "ciclo_5": ("Fünf Runden", "Schließe Zyklus 5 des Endlosmodus ab."),
    "ciclo_10": ("Ouroboros", "Schließe Zyklus 10 des Endlosmodus ab."),
    "primeiro_selo": ("Gebrochenes Siegel", "Gewinne einen Lauf mit einem Grimoire-Siegel."),
    "selo_max_guerreiro": ("Letztes Siegel: Krieger", "Gewinne mit dem Krieger auf Siegel 10."),
    "selo_max_mago": ("Letztes Siegel: Magier", "Gewinne mit dem Magier auf Siegel 10."),
    "selo_max_ladino": ("Letztes Siegel: Schurke", "Gewinne mit dem Schurken auf Siegel 10."),
}

# Rotulos da galeria/toast (mesmas chaves nos 5 locales).
UI = {
    "pt_BR": dict(hint="ESC fecha | setas ou clique escolhem", secret_name="???",
                  secret_desc="Conquista secreta. Continue jogando para revelá-la.",
                  toast_label="CONQUISTA DESBLOQUEADA", tier_natural="Jornada",
                  tier_build="Restrição", tier_skill="Maestria", tier_collection="Legado",
                  unlocked_on="Desbloqueada em {date}", unlocked="Desbloqueada",
                  locked="Bloqueada", secret_tag="SECRETA",
                  progress="Progresso: {cur} / {target}", total="{n} de {total}",
                  date_format="%d/%m/%Y"),
    "en": dict(hint="ESC closes | arrows or click select", secret_name="???",
               secret_desc="Secret achievement. Keep playing to reveal it.",
               toast_label="ACHIEVEMENT UNLOCKED", tier_natural="Journey",
               tier_build="Restraint", tier_skill="Mastery", tier_collection="Legacy",
               unlocked_on="Unlocked on {date}", unlocked="Unlocked", locked="Locked",
               secret_tag="SECRET", progress="Progress: {cur} / {target}",
               total="{n} of {total}", date_format="%Y-%m-%d"),
    "es": dict(hint="ESC cierra | flechas o clic eligen", secret_name="???",
               secret_desc="Logro secreto. Sigue jugando para revelarlo.",
               toast_label="LOGRO DESBLOQUEADO", tier_natural="Travesía",
               tier_build="Restricción", tier_skill="Maestría", tier_collection="Legado",
               unlocked_on="Desbloqueado el {date}", unlocked="Desbloqueado",
               locked="Bloqueado", secret_tag="SECRETO",
               progress="Progreso: {cur} / {target}", total="{n} de {total}",
               date_format="%d/%m/%Y"),
    "fr": dict(hint="ÉCHAP ferme | flèches ou clic choisissent", secret_name="???",
               secret_desc="Succès secret. Continuez à jouer pour le révéler.",
               toast_label="SUCCÈS DÉBLOQUÉ", tier_natural="Voyage",
               tier_build="Contrainte", tier_skill="Maîtrise", tier_collection="Héritage",
               unlocked_on="Débloqué le {date}", unlocked="Débloqué", locked="Verrouillé",
               secret_tag="SECRET", progress="Progression : {cur} / {target}",
               total="{n} sur {total}", date_format="%d/%m/%Y"),
    "de": dict(hint="ESC schließt | Pfeile oder Klick wählen", secret_name="???",
               secret_desc="Geheime Errungenschaft. Spiel weiter, um sie zu enthüllen.",
               toast_label="ERRUNGENSCHAFT FREIGESCHALTET", tier_natural="Reise",
               tier_build="Verzicht", tier_skill="Meisterschaft",
               tier_collection="Vermächtnis", unlocked_on="Freigeschaltet am {date}",
               unlocked="Freigeschaltet", locked="Gesperrt", secret_tag="GEHEIM",
               progress="Fortschritt: {cur} / {target}", total="{n} von {total}",
               date_format="%d.%m.%Y"),
}

LOCALES = ["pt_BR", "en", "es", "fr", "de"]
# Codigo de idioma da Steam (painel "Localization" do Steamworks)
STEAM_LANG = {"pt_BR": "brazilian", "en": "english", "es": "spanish",
              "fr": "french", "de": "german"}


def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def patch_locales():
    for loc in LOCALES:
        p = os.path.join(ROOT, "src", "i18n", "locales", loc + ".lua")
        s = open(p, encoding="utf-8").read()
        start = s.index("\n    achievements = {\n") + 1
        end = s.index("\n    },\n", start) + len("\n    },\n")
        lines = ["    achievements = {",
                 "        -- GERADO por tools/achievement_text.py (texto-fonte dos 5",
                 "        -- idiomas e do painel da Steam). Edite la, nao aqui.",
                 "        list = {"]
        for k in ORDER:
            n, d = T[loc][k]
            lines.append("            %s = { name = %s, desc = %s }," % (k, q(n), q(d)))
        lines.append("        },")
        for k, v in UI[loc].items():
            lines.append("        %s = %s," % (k, q(v)))
        lines.append("    },")
        s = s[:start] + "\n".join(lines) + "\n" + s[end:]
        open(p, "w", encoding="utf-8", newline="").write(s)
        print("locale", loc, "ok")


def read_catalog():
    """Le id/steam/hidden/tier de src/data/achievements.lua (parse simples)."""
    import re
    src = open(os.path.join(ROOT, "src", "data", "achievements.lua"), encoding="utf-8").read()
    out = []
    for m in re.finditer(r'\{\s*id\s*=\s*"([a-z0-9_]+)",\s*steam\s*=\s*"([A-Z0-9_]+)",'
                         r'\s*tier\s*=\s*"([a-z]+)"(,\s*hidden\s*=\s*true)?', src):
        out.append({"id": m.group(1), "steam": m.group(2), "tier": m.group(3),
                    "hidden": bool(m.group(4))})
    return out


def export_steam():
    cat = read_catalog()
    ids = [c["id"] for c in cat]
    assert ids == ORDER, "ORDER diverge do catalogo: %s" % (set(ids) ^ set(ORDER))
    outdir = os.path.join(ROOT, "steam", "achievements")
    os.makedirs(outdir, exist_ok=True)
    data = []
    for c in cat:
        e = {"apiName": c["steam"], "id": c["id"], "tier": c["tier"],
             "hidden": c["hidden"],
             "iconAchieved": "icons/%s.png" % c["steam"],
             "iconUnachieved": "icons/%s_locked.png" % c["steam"],
             "name": {}, "desc": {}}
        for loc in LOCALES:
            n, d = T[loc][c["id"]]
            e["name"][STEAM_LANG[loc]] = n
            e["desc"][STEAM_LANG[loc]] = d
        data.append(e)
    with open(os.path.join(outdir, "achievements.json"), "w", encoding="utf-8",
              newline="\n") as f:
        json.dump({"count": len(data), "achievements": data}, f,
                  ensure_ascii=False, indent=2)
        f.write("\n")
    # Tabela legivel pra colar no painel, campo por campo.
    with open(os.path.join(outdir, "CADASTRO.txt"), "w", encoding="utf-8",
              newline="\n") as f:
        f.write("# Gerado por tools/achievement_text.py steam — NAO editar a mao.\n")
        f.write("# Uma conquista por bloco, na ordem do catalogo. Campos do painel\n")
        f.write("# Steamworks > Stats & Achievements > Achievements.\n\n")
        for e in data:
            f.write("API Name ......: %s\n" % e["apiName"])
            f.write("Hidden ........: %s\n" % ("yes" if e["hidden"] else "no"))
            f.write("Set by ........: Client\n")
            f.write("Achieved icon .: %s\n" % e["iconAchieved"])
            f.write("Unachieved icon: %s\n" % e["iconUnachieved"])
            for loc in LOCALES:
                lang = STEAM_LANG[loc]
                f.write("  [%s] %s — %s\n" % (lang, e["name"][lang], e["desc"][lang]))
            f.write("\n")
    print("steam: %d conquistas exportadas em %s" % (len(data), outdir))


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "locales":
        patch_locales()
    elif mode == "steam":
        export_steam()
    else:
        print("uso: python -I tools/achievement_text.py locales|steam")
        sys.exit(2)
