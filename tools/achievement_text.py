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
# Convencao do projeto: acento SO no pt_BR; es/fr/de em ASCII (ver
# tools/test_achievements_i18n.lua). A Steam aceita UTF-8 — o export usa o
# mesmo texto do jogo (consistencia > enfeite).
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
         "escriba", "ferreiro", "veterano", "bibliotecario", "alem_da_pagina"]

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
    "alem_da_pagina": ("Além da Última Página", "Alcance o andar 10 do modo infinito."),
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
}
T["es"] = {
    "primeiro_chefe": ("Corona Rota", "Derrota a tu primer jefe."),
    "capitulo_final": ("El Tercer Capitulo", "Derrota al jefe del Acto 3."),
    "primeira_pagina": ("Primera Pagina", "Gana tu primera partida."),
    "vitoria_guerreiro": ("Hoja Legendaria", "Gana una partida con el Guerrero."),
    "vitoria_mago": ("Arcano Supremo", "Gana una partida con el Mago."),
    "vitoria_ladino": ("Sombra Invicta", "Gana una partida con el Picaro."),
    "trindade": ("Trinidad del Grimorio", "Gana una partida con cada clase."),
    "despertar": ("Todos Despiertos", "Desbloquea todas las clases."),
    "coro_coringas": ("Coro de Comodines", "Gana una batalla con todos los espacios de comodin ocupados."),
    "grimorio_bolso": ("Grimorio de Bolsillo", "Gana con un mazo de 6 cartas o menos."),
    "enciclopedia": ("Enciclopedia Andante", "Gana con 30 o mas cartas en el mazo."),
    "voto_pobreza": ("Voto de Pobreza", "Gana sin comprar nada en las tiendas."),
    "asceta": ("Asceta", "Gana sin poseer ningun comodin."),
    "tinta_crua": ("Tinta Cruda", "Gana usando solo cartas comunes."),
    "sem_rascunhos": ("Sin Borradores", "Gana sin usar nunca la Forja."),
    "relampago": ("Relampago Sellado", "Gana una batalla antes de que el enemigo actue."),
    "fio_navalha": ("Filo de la Navaja", "Gana una batalla con exactamente 1 PV."),
    "imaculado": ("Inmaculado", "Derrota a un jefe sin recibir dano."),
    "miasma": ("Miasma", "Acumula 15 de veneno en un enemigo."),
    "muralha": ("Muralla del Escriba", "Alcanza el bloqueo maximo en un turno."),
    "tinta_viva": ("Tinta Viva", "Activa 4 combos en el mismo turno."),
    "golpe_tinta": ("Golpe de Tinta", "Inflige 60 de dano con una sola carta."),
    "conduite_pleno": ("Conducto Pleno", "Ten 3 orbes canalizados a la vez."),
    "maos_limpas": ("Manos Limpias", "Gana una batalla sin jugar cartas de ataque."),
    "velas_10k": ("Diez Mil Velas", "Alcanza 10.000 puntos en una partida."),
    "escriba": ("Escriba Incansable", "Juega 2500 cartas (sumando partidas)."),
    "ferreiro": ("Maestro Herrero", "Forja 25 cartas (sumando partidas)."),
    "veterano": ("Veterano de las Paginas", "Gana 10 partidas."),
    "bibliotecario": ("Bibliotecario", "Descubre todas las cartas del grimorio."),
    "alem_da_pagina": ("Mas Alla de la Ultima Pagina", "Alcanza el piso 10 del modo infinito."),
}
T["fr"] = {
    "primeiro_chefe": ("Couronne Brisee", "Vainquez votre premier boss."),
    "capitulo_final": ("Le Troisieme Chapitre", "Vainquez le boss de l'Acte 3."),
    "primeira_pagina": ("Premiere Page", "Remportez votre premier periple."),
    "vitoria_guerreiro": ("Lame Legendaire", "Remportez un periple avec le Guerrier."),
    "vitoria_mago": ("Arcaniste Supreme", "Remportez un periple avec le Mage."),
    "vitoria_ladino": ("Ombre Invaincue", "Remportez un periple avec le Voleur."),
    "trindade": ("Trinite du Grimoire", "Remportez un periple avec chaque classe."),
    "despertar": ("Tous Eveilles", "Debloquez toutes les classes."),
    "coro_coringas": ("Choeur de Jokers", "Gagnez un combat avec tous les emplacements de joker occupes."),
    "grimorio_bolso": ("Grimoire de Poche", "Gagnez avec un deck de 6 cartes ou moins."),
    "enciclopedia": ("Encyclopedie Ambulante", "Gagnez avec 30 cartes ou plus dans le deck."),
    "voto_pobreza": ("Voeu de Pauvrete", "Gagnez sans rien acheter dans les boutiques."),
    "asceta": ("Ascete", "Gagnez sans posseder aucun joker."),
    "tinta_crua": ("Encre Brute", "Gagnez en n'utilisant que des cartes communes."),
    "sem_rascunhos": ("Sans Brouillon", "Gagnez sans jamais utiliser la Forge."),
    "relampago": ("Eclair Scelle", "Gagnez un combat avant que l'ennemi n'agisse."),
    "fio_navalha": ("Fil du Rasoir", "Gagnez un combat avec exactement 1 PV."),
    "imaculado": ("Immacule", "Vainquez un boss sans subir de degats."),
    "miasma": ("Miasme", "Accumulez 15 de poison sur un ennemi."),
    "muralha": ("Rempart du Scribe", "Atteignez le blocage maximum en un tour."),
    "tinta_viva": ("Encre Vivante", "Declenchez 4 combos dans le meme tour."),
    "golpe_tinta": ("Coup d'Encre", "Infligez 60 degats avec une seule carte."),
    "conduite_pleno": ("Conduit Plein", "Ayez 3 orbes canalises en meme temps."),
    "maos_limpas": ("Mains Propres", "Gagnez un combat sans jouer de carte d'attaque."),
    "velas_10k": ("Dix Mille Chandelles", "Atteignez 10 000 points en un periple."),
    "escriba": ("Scribe Infatigable", "Jouez 2500 cartes (tous periples confondus)."),
    "ferreiro": ("Maitre Forgeron", "Forgez 25 cartes (tous periples confondus)."),
    "veterano": ("Veteran des Pages", "Remportez 10 periples."),
    "bibliotecario": ("Bibliothecaire", "Decouvrez toutes les cartes du grimoire."),
    "alem_da_pagina": ("Au-dela de la Derniere Page", "Atteignez l'etage 10 du mode infini."),
}
T["de"] = {
    "primeiro_chefe": ("Zerbrochene Krone", "Besiege deinen ersten Boss."),
    "capitulo_final": ("Das Dritte Kapitel", "Besiege den Boss von Akt 3."),
    "primeira_pagina": ("Erste Seite", "Gewinne deinen ersten Lauf."),
    "vitoria_guerreiro": ("Legendaere Klinge", "Gewinne einen Lauf mit dem Krieger."),
    "vitoria_mago": ("Oberster Arkanist", "Gewinne einen Lauf mit dem Magier."),
    "vitoria_ladino": ("Unbesiegter Schatten", "Gewinne einen Lauf mit dem Schurken."),
    "trindade": ("Dreifaltigkeit des Grimoires", "Gewinne einen Lauf mit jeder Klasse."),
    "despertar": ("Alle Erwacht", "Schalte alle Klassen frei."),
    "coro_coringas": ("Chor der Joker", "Gewinne einen Kampf mit allen Joker-Plaetzen belegt."),
    "grimorio_bolso": ("Taschen-Grimoire", "Gewinne mit einem Deck aus 6 Karten oder weniger."),
    "enciclopedia": ("Wandelnde Enzyklopaedie", "Gewinne mit 30 oder mehr Karten im Deck."),
    "voto_pobreza": ("Armutsgeluebde", "Gewinne, ohne in Laeden etwas zu kaufen."),
    "asceta": ("Asket", "Gewinne, ohne einen einzigen Joker zu besitzen."),
    "tinta_crua": ("Rohe Tinte", "Gewinne nur mit gewoehnlichen Karten."),
    "sem_rascunhos": ("Ohne Entwurf", "Gewinne, ohne je die Schmiede zu benutzen."),
    "relampago": ("Versiegelter Blitz", "Gewinne einen Kampf, bevor der Gegner handelt."),
    "fio_navalha": ("Messers Schneide", "Gewinne einen Kampf mit genau 1 LP."),
    "imaculado": ("Makellos", "Besiege einen Boss, ohne Schaden zu nehmen."),
    "miasma": ("Miasma", "Haeufe 15 Gift auf einem Gegner an."),
    "muralha": ("Wall des Schreibers", "Erreiche den maximalen Block in einem Zug."),
    "tinta_viva": ("Lebende Tinte", "Loese 4 Combos im selben Zug aus."),
    "golpe_tinta": ("Tintenschlag", "Verursache 60 Schaden mit einer einzigen Karte."),
    "conduite_pleno": ("Voller Leiter", "Habe 3 Kugeln gleichzeitig kanalisiert."),
    "maos_limpas": ("Saubere Haende", "Gewinne einen Kampf ohne Angriffskarten."),
    "velas_10k": ("Zehntausend Kerzen", "Erreiche 10.000 Punkte in einem Lauf."),
    "escriba": ("Unermuedlicher Schreiber", "Spiele 2500 Karten (ueber alle Laeufe)."),
    "ferreiro": ("Schmiedemeister", "Schmiede 25 Karten (ueber alle Laeufe)."),
    "veterano": ("Veteran der Seiten", "Gewinne 10 Laeufe."),
    "bibliotecario": ("Bibliothekar", "Entdecke alle Karten des Grimoires."),
    "alem_da_pagina": ("Jenseits der Letzten Seite", "Erreiche Etage 10 im Endlosmodus."),
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
               toast_label="LOGRO DESBLOQUEADO", tier_natural="Travesia",
               tier_build="Restriccion", tier_skill="Maestria", tier_collection="Legado",
               unlocked_on="Desbloqueado el {date}", unlocked="Desbloqueado",
               locked="Bloqueado", secret_tag="SECRETO",
               progress="Progreso: {cur} / {target}", total="{n} de {total}",
               date_format="%d/%m/%Y"),
    "fr": dict(hint="ECHAP ferme | fleches ou clic choisissent", secret_name="???",
               secret_desc="Succes secret. Continuez a jouer pour le reveler.",
               toast_label="SUCCES DEBLOQUE", tier_natural="Voyage",
               tier_build="Contrainte", tier_skill="Maitrise", tier_collection="Heritage",
               unlocked_on="Debloque le {date}", unlocked="Debloque", locked="Verrouille",
               secret_tag="SECRET", progress="Progression : {cur} / {target}",
               total="{n} sur {total}", date_format="%d/%m/%Y"),
    "de": dict(hint="ESC schliesst | Pfeile oder Klick waehlen", secret_name="???",
               secret_desc="Geheime Errungenschaft. Spiel weiter, um sie zu enthuellen.",
               toast_label="ERRUNGENSCHAFT FREIGESCHALTET", tier_natural="Reise",
               tier_build="Verzicht", tier_skill="Meisterschaft",
               tier_collection="Vermaechtnis", unlocked_on="Freigeschaltet am {date}",
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
