# Steam store trailer (30–45 s) and 12 short clips: PLAN (nothing rendered)

Daniel Cortez, 13/11/2026. This is a shot list taken from real gameplay. Rendering and encoding count as bulk media, so they run **only from 02:00 to 06:00 BRT** (rule 23).
Nothing gets uploaded to Steamworks or published, and nothing is generated with paid credits.

## Sources (all real gameplay already recorded)

- **Takes:** headless, identity `card-game-trailer-v9`, folder `%APPDATA%\LOVE\card-game-trailer-v9\trailer_gameplay\`. Each take comes with `audio.jsonl`, so the game's sounds can be rebuilt.

  | Take | Duration | What it shows |
  |---|---|---|
  | `zero_carrion_c10c` | 56.4 s | The Carrion King lands in the hall (crows, name card) |
  | `gp_class` | 12.3 s | Class selection, from mage to warrior |
  | `gp_first` | 49.6 s | A full first turn: hover, play, damage, End Turn, intent, YOUR TURN |
  | `gp_spoils` | 17.8 s | The loot: pick 1 of 3 cards, then YOUR DECK |
  | `gp_fork` | 9.5 s | The labeled crossroads and the click on Battle |
  | `gp_mid2_ram_cultist` | 47.0 s | Act 2, a 10-card deck with 3 jokers: a 2-attack combo takes the enemy from 108 to 58 |
  | `gp_mage_a3` | 30.9 s | The Mage in act 3 |
  | `gp_rogue_a5` | 35.3 s | The Rogue in act 5, with a creature arriving |
  | `gp_tyrant` | 29.9 s | The Tyrant loses a chain ("Chain snapped!") |
  | `gp_monarch` | 58.7 s | The Winter Monarch freezes the hand, the ice rain, the lethal blow, the "Winter Aegis" trophy |
  | `gp_mid2_moon_gargoyle` | 48.1 s | Recorded, not used yet (another act 2 fight) |

- **Recorder:** `tools/trailer_record.lua` (`SHOTS.gp_*`), branch `trailer-gameplay`. A new take: headless, 1 `lovec` at a time, never the real save, never a window.
- **Music:** `boss-abyss_tyrant.mp3`, the main track of the approved cuts.
- **On-screen text:** only the texts approved on 01/11 16:39: 145 LIVING CARDS. · 6 ACTS. · 42 CREATURES. · EVERY BOSS / BREAKS THE RULES. · CHAINS. · FROST. · BREAK THEM BACK. · A ROGUELIKE DECKBUILDER (on the logo). "WISHLIST ON STEAM" appears on the logo, as in the approved cuts.
- **Note:** the 69 s gameplay cut, on branch `trailer-gameplay`, is waiting for Daniel's decision on the old commits. This plan only reuses its takes, which are files outside git.

## A. Store trailer, 40 s (allowed window 30–45 s)

The rule: gameplay in the first 5 s, and no logo before the gameplay.

| # | In the film | Take | Moment | Text on screen |
|---|---|---|---|---|
| 1 | 0.0–3.5 | `gp_mid2_ram_cultist` | The 2-attack combo, enemy HP from 108 to 58 (hook with numbers) | — |
| 2 | 3.5–5.0 | `gp_class` | Class selection (mage → warrior), fast | — |
| 3 | 5.0–12.0 | `gp_first` | A slice of the full turn: hover on Strike, play, damage, intent | — |
| 4 | 12.0–15.0 | `gp_spoils` | Pick 1 of 3 cards; the deck grows | 145 LIVING CARDS. |
| 5 | 15.0–17.0 | `gp_fork` | The crossroads, click on Battle | 6 ACTS. |
| 6 | 17.0–19.0 | `gp_mage_a3` | The Mage in act 3, the arrival | — |
| 7 | 19.0–21.0 | `gp_rogue_a5` | The Rogue in act 5, the creature arrives | 42 CREATURES. |
| 8 | 21.0–22.5 | `gp_tyrant` | The Tyrant's name card | EVERY BOSS / BREAKS THE RULES. |
| 9 | 22.5–25.5 | `gp_tyrant` | The chain snaps | CHAINS. |
| 10 | 25.5–29.5 | `gp_monarch` | The hand freezes; the ice rain, 55 → 44 | FROST. |
| 11 | 29.5–34.5 | `gp_monarch` | The lethal blow, hero at 9 HP, the trophy | BREAK THEM BACK. |
| 12 | 34.5–40.0 | logo | RUNEMOIRE + A ROGUELIKE DECKBUILDER + WISHLIST ON STEAM | (approved) |

- **Delivery:** 1920×1080 H.264 (Steam accepts it), plus a 1280×720 version for the site and social. Loudness at −14 LUFS, true peak ≤ −1 dBTP, as in the approved cuts.
- **Review:** an independent review must score ≥ 9 before Daniel sees it (the bar from `trailer-do-zero.md`).

## B. 12 short clips (6–15 s each, real gameplay, no voice-over)

Each clip ships in 16:9 (1920×1080) and 9:16 (1080×1920). The 9:16 crop is centered on the hand and the target, with the game's CRT frame kept.
For the Steam GIF: C05 and C03, cut to 3–6 s, at most 3 MB.

| Clip | Duration | Take | What it shows | Text |
|---|---|---|---|---|
| C01 | 12 s | `gp_first` | A full turn in one shot: read the card, play, damage, intent, YOUR TURN | — |
| C02 | 8 s | `gp_class` | Three classes, one book: the selection | — |
| C03 | 6 s | `gp_mid2_ram_cultist` | The combo, 108 → 58 | — |
| C04 | 10 s | `gp_spoils` | Pick 1 of 3; the deck grows | 145 LIVING CARDS. |
| C05 | 8 s | `gp_mid2_ram_cultist` | The jokers in the top panel during the combo (the GIF for the long description) | — |
| C06 | 9 s | `gp_fork` | Choosing the path: Rest, Battle, Event | 6 ACTS. |
| C07 | 10 s | `gp_mage_a3` | The Mage in act 3 | — |
| C08 | 10 s | `gp_rogue_a5` | The Rogue in act 5 | 42 CREATURES. |
| C09 | 12 s | `gp_tyrant` | The chain boss: the chain snaps | CHAINS. |
| C10 | 12 s | `gp_monarch` | The frost boss: the hand freezes | FROST. |
| C11 | 12 s | `gp_monarch` | The lethal blow at 9 HP and the trophy | BREAK THEM BACK. |
| C12 | 12 s | `zero_carrion_c10c` | The Carrion King arrives in the hall (the hook of the approved cuts) | — |

Every clip ends on a 1.5 s logo card (RUNEMOIRE). There is no Steam link until the Coming Soon page exists; the CTA is runemoire.com.

## C. How to render (02:00–06:00 only)

1. Edit from the takes above with the cut pipeline in `docs/handoff/trailer-do-zero/corte/` (`edl.py`, `build_video.py`, `mix.py`, `mux.py`), with a new EDL for "store_40s" and one per clip.
2. Output goes to `E:\dev\projects\card-game-trailer\build\trailer\` with new names (`runemoire_store_40s_*`, `runemoire_clip_C01..C12_*`). Never overwrite the old masters.
3. A missing take (none is missing today) is recorded headless with the same identity, 1 `lovec` at a time.
4. Nothing goes to Steamworks or social media. Daniel chooses and publishes.
