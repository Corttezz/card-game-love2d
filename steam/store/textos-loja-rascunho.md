# Steam store texts: DRAFT (not uploaded)

Daniel Cortez, 13/11/2026. Source: the SEO & Growth research brief (`C:\Users\corte\OpenBot\Shared\seo-growth\pesquisa\runemoire.md`, section 1), checked against the game on this date.
**Draft only.** Nothing here has been entered in Steamworks. The store page, its publication and every Steamworks field belong to Daniel.

## Facts checked in the code (13/11/2026)

| Fact | Value | Where |
|---|---|---|
| Classes | 3: Warrior, Mage, Rogue | `src/i18n/locales/en.lua` |
| Acts | 6 | `Config.TotalActs = 6` (`src/core/Config.lua:141`) |
| Creatures | 42 | `enemies.lua` `ROSTER` (checked for the trailer on 07/11) |
| Cards | 145 (35 common, 60 uncommon, 38 rare, 12 legendary) | `src/data/cards/*.lua`; the site's export `cardCounts.total = 145` |
| Achievements | 37 | `steam/achievements/achievements.json` |
| Languages | 5: English, Brazilian Portuguese, Spanish, French, German | `src/i18n/locales/` |
| Platform | Windows | `tools/build_release.py` |
| Post-game | Endless mode and Seals 1 to 10 per class | `memory/endless_and_seals.md` |

The research brief left the card total as "[CHECK]" (128/128 in screenshot 07). The code has **145**, the same number as the approved trailer text "145 LIVING CARDS".

## 1. Short description (Steam limit: 300 characters)

**en** (266 characters):
> Open a cursed grimoire and walk its road of six acts. Play as the Warrior, Mage or Rogue, build your deck card by card, stack passive jokers into chain combos and break each boss's signature curse. A pixel-art roguelike deckbuilder where every run writes a new page.

**pt-BR** (289 characters):
> Abra um grimório amaldiçoado e percorra sua estrada de seis atos. Jogue de Guerreiro, Mago ou Ladino, monte o deck carta a carta, empilhe coringas passivos em combos em cadeia e quebre a maldição de cada chefe. Um roguelike deckbuilder em pixel art em que cada run escreve uma página nova.

**es, fr, de:** pending. Localize from the English text with the game's own vocabulary (`src/i18n/locales/*.lua`) and a native review.

## 2. Tags, in weight order (only the first 20 count)

1. Roguelike Deckbuilder
2. Deckbuilding
3. Card Battler
4. Pixel Graphics
5. Dark Fantasy
6. Card Game
7. Roguelike
8. Turn-Based Combat
9. Strategy
10. Roguelite
11. Singleplayer
12. Replay Value
13. Fantasy
14. Procedural Generation
15. Retro
16. Magic
17. Medieval
18. 2D
19. Perma Death
20. Indie

Do not use: Difficult (the balance is still being measured), Class-Based (on Steam it leans toward shooters), Casual (it contradicts Dark Fantasy).
The tag IDs and the reason for each tag are in the research brief, section 1.2.

## 3. Capsule text

- **On the capsule images: only the RUNEMOIRE logo.** No tagline, quotes, awards or "Wishlist now". The current capsules already follow this rule (`README.md` in this folder).
- **Tagline, for text fields and social posts only:** "Open the grimoire. Survive the page." / pt-BR: "Abra o grimório. Sobreviva à página." (the same line as the site).
- **For Daniel to decide:** the research suggests adding 2 or 3 cards in the foreground of the main capsule, so the genre reads at small size. That would change approved art, so it stays a suggestion.

## 4. Long description: the first 3 lines

**en**
> **Open the grimoire. Survive the page.**
> Runemoire is a pixel-art roguelike deckbuilder. Pick the Warrior, Mage or Rogue, walk a cursed road through six acts and fight with a deck you build along the way.
> Stack passive jokers into chain combos, read each enemy's intent before it strikes, and break the signature curse of every boss, then push into Endless and climb the Seals.

**pt-BR**
> **Abra o grimório. Sobreviva à página.**
> Runemoire é um roguelike deckbuilder em pixel art. Escolha Guerreiro, Mago ou Ladino, percorra uma estrada amaldiçoada de seis atos e lute com o deck que você monta pelo caminho.
> Empilhe coringas passivos em combos em cadeia, leia a intenção de cada inimigo antes do golpe e quebre a maldição de cada chefe. Depois, siga no Endless e suba os Selos.

Change from the brief: line 3 said "jokers that fire on every play". The jokers are passive, with different triggers, so the draft reuses the wording of the short description ("passive jokers into chain combos").

**Under the 3 lines (en):**
- A 3–6 s GIF of a joker combo: clip C05 in `trailer-loja-e-clipes-plano.md`.
- Facts list:
  - 3 classes, each with its own deck and passive
  - 6 acts and 6 biomes, each ending with a boss that breaks a rule
  - 42 creatures
  - 145 cards, plus passive jokers, every one animated
  - Endless mode and Seals 1–10 per class
  - 37 achievements
  - Play in English, Brazilian Portuguese, Spanish, French or German

## 5. Screenshot order

Order: 03_road_battle, 04_boss_room, 05_shop, 06_road_fork, 02_class_select, 07_collection, 08_victory, then 01_menu last (or drop it).
The files are in `screenshots/en` and `screenshots/pt_BR`. es, fr and de come once the page has those languages.

## 6. AI disclosure: draft for the Steam Content Survey (Daniel reviews and submits)

> Runemoire's pixel art was made with AI-assisted tools (PixelLab) and then edited by hand. The sound effects and music were generated with AI audio tools (ElevenLabs and a local ACE-Step model) and mixed for the game. All game design, code, card balance and writing are by the developer.

The audio is licensed (Daniel, 10/11/2026). This text only discloses the AI tools; it is not a license statement.
