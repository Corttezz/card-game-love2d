# Cut 11 (rebuilt from the brief, not patched)

_Director, 02/11/2026. Base: Daniel's rejection of cut 10d (22:30) and `corte11_inventario.md` (commit 32131e50). Built with the v8 engine (`E:\dev\projects\card-game-trailer\tools\trailer_v3.py`) and a new cut file `tools/trailer_c11_cut.py` on branch `steam-store-v2` of the trailer worktree. No new capture. No zoom. No 4K, no push, nothing published._

> **NOT PUBLISHABLE UNTIL THE SFX ARE REPLACED OR LICENSED** (ElevenLabs free plan). Music: ACE-Step local (`boss-abyss_tyrant.mp3` main, `boss-carrion_king.mp3` alt). Halls: Higgsfield originals (AI, non-gameplay mood shots, labelled with the boss names).

## Files
| version | file |
|---|---|
| Tirano (main) 1080p master | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_c11.mp4` |
| Tirano 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_c11_720p.mp4` |
| Rei (alt) 1080p master | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_c11_rei.mp4` |
| Rei 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_c11_rei_720p.mp4` |

How to rebuild: `TRAILER_SRC=%APPDATA%\LOVE\card-game-trailer-c11\trailer TRAILER_CUT=trailer_c11_cut C11_MUSIC=tirano|rei python tools/trailer_v3.py`. Then the 720p is made with lanczos + x264 slow crf 14 and the audio gets two-pass loudnorm at −14 LUFS. The take folder `card-game-trailer-c11` holds hard links to the v8 takes plus `collection2.mkv` of v6, and a merged `audio.jsonl`. Onset maps come from `tools/trailer_c11_beats.py`.

## Structure (59,4 s, Tirano times)
| s | block | source | Daniel's point |
|---|---|---|---|
| 0 to 3 | TV turns on (the game's own power-on) | `poweron` | |
| 3 to 13,3 | **walking forward through the 6 acts**, ~1,6 s each, calm ambient only (wind, frogs, rain). "SIX ACTS. / ONE ROAD TO THE CASTLE." | `poweron` (act 1), `night_a2..a6` | 2 |
| 12,6 | the music comes in under act 6 and rises | | |
| 13,3 to 22,4 | **card play**: hand dealt, cards picked, Volley +15 combo, hits with flash and 5 px shake on each impact. "BUILD A LIVING DECK." | `deck8` (rogue) | "satisfying card play" |
| 22,4 to 26,4 | **collection** scrolling down, unlocked cards. "EVERY CARD COMES ALIVE." | `collection2` (v6) | "show the collection, cards coming down" |
| 26,4 to 35,9 | **entrances**: Scarecrow (wakes up), Storm Griffin, Fallen Angel, Ice Wyrm. "A BESTIARY OF THE CURSED." | `entr_*` | "Scarecrow entrance is cool" |
| 35,9 to 41,6 | **boss montage on the beat**: Carrion King, Tower Lich, Abyss Tyrant, Winter Monarch, Rot Colossus, one per strong onset, name under each, whoosh + hit pulse on each cut. "SIX BOSSES." | `ai_4k\hall1..5` straight (no palette treatment) | 3, "Higgsfield quality" |
| 41,6 to 52,7 | **climax**: castle gate, eyes in the dark, the King swoops in, "CARRION KING", the fight turn with combo and hits. "ONE HAND CAN BREAK A KING." | `boss8` | "epic" |
| 52,7 to 59,4 | **Grimoire icon-fill ending restored**: compass seal, rays, joker ticks, GRIMOIRE letter by letter, "WISHLIST ON STEAM", with its original sounds | `brand\logo_sting.mp4` + v8 `logo_sfx` | "the Grimoire ending was lost" |

## Proofs (`corte11_provas\`)
- **Ending:** the last 390 frames of cut 11 (both versions) against the last 390 frames of the v8 master: mean difference **0,00**. Both are 1,37/255 from the `logo_sting.mp4` source, which is encoding only (`p_fecho_quadro_a_quadro.json`, `p_fecho_v8_x_c11.png`).
- **Cuts on beats:** in `cortes_x_onsets_tirano.txt` and `cortes_x_onsets_rei.txt`, every cut after the music enters lands on a measured onset of that version's own track (0,0 frame). The only exceptions are the first cut into the cards (music still fading in) and, in the Rei version, the griffin cut (−3,5 q, a 2,1× onset). Boss montage cuts:
  - Tirano: 35,857 / 36,995 / 38,133 / 39,282 / 40,420 s.
  - Rei: 35,637 / 36,763 / 37,854 / 39,108 / 40,362 s.
- **No zoom:** `escala_filme_inteiro.txt` measures scale between neighbouring frames over the whole film. The only flags are:
  - 1,5 s, the game's own TV power-on animation;
  - 42,8 to 43,1 s, the dark door to swoop transition (few matches);
  - two degenerate fits on a glitch and on the black.
  
  Every clip is cropped at scale 1,00, with punches off and no zoom transitions.
- **No CHAINS/FROST text.** The text cards are listed below.
- **Quality** (`p_qualidade.txt`):

  | file | resolution | video bitrate |
  |---|---|---|
  | Tirano 720p | 1280x720 60 | 13,9 Mb/s |
  | Rei 720p | 1280x720 60 | 13,9 Mb/s |
  | 1080p masters | 1920x1080 60 | 33,7 Mb/s |
  | cut 10d 720p | 1280x720 60 | 5,7 Mb/s |
  | best earlier cut (v8 master) | 1920x1080 60 | 28,9 Mb/s |

  Hall sharpness on the same crop: **236** (c11 720p), **411** (c11 1080p), **60 to 67** (10d 720p).
- **Loudness:** Tirano −14,0 LUFS / −1,5 dBTP; Rei −13,9 LUFS / −2,3 dBTP.
- **Dark frames:** the first 1,1 s (TV off, then turning on) and 52,9 to 55,6 s (the logo's dark background while the seal draws), both the same as in v8. Nothing else.
- **Contact sheets:** `folha_tirano_2qps.png`, `folha_rei_2qps.png`.

## Text cards (proposal for Daniel)
1. SIX ACTS. / ONE ROAD TO THE CASTLE.
2. BUILD A LIVING DECK.
3. EVERY CARD COMES ALIVE.
4. A BESTIARY OF THE CURSED.
5. SIX BOSSES. (with the five boss names under the halls)
6. ONE HAND CAN BREAK A KING.
7. WISHLIST ON STEAM (logo)

## Truth notes
- Gameplay is captured in-engine (recorder, 25/Oct build), with the HUD on in the card and fight shots. God mode and 5 mana were used for capture.
- The halls are AI mood shots, used only for the boss montage with names.
- The final boss (Eclipse Queen) is not shown.
