# Cut 11f (only items 1 to 3 of `revisao-grimoire-corte11e.md`)

_Director, 03/11/2026. Base: cut 11 rev 5 (11e), approved by the team (5616373d) but held back by the lead (Tirano 8,7, Rei 9,0; 13a503b3). Everything else from 11e is unchanged:_
- _the calm six-act opening_
- _the collection_
- _the entrances with the Scarecrow_
- _the boss montage on the beat_
- _the logo_sting ending_
- _no zoom_
- _720p at high bitrate_
- _life numbers that only change on a hit_

> **NOT PUBLISHABLE UNTIL THE SFX ARE REPLACED OR LICENSED.** Music: ACE-Step local. Halls: Higgsfield.

## Files
- `E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_c11f.mp4` (1080p) and `grimoire_trailer_c11f_720p.mp4` (Tirano, main)
- `E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_c11f_rei.mp4` (1080p) and `grimoire_trailer_c11f_rei_720p.mp4` (Rei)
- Cut: `tools/trailer_c11f_cut.py` (trailer worktree). New card take: `SHOTS.cards_c11f` in `card-game-trailer-zero/tools/trailer_record.lua`.

## What changed
1. **Tirano hall montage on strong accents.** The Tirano track only has its strong bass hits once per bar (~2,29 s at 105 BPM); the half-bar is a medium accent. Each hall now lasts one bar, and every cut is the **top-ranked onset within ±1 s** (strength × bass rise). The ice wyrm entrance ends on the first strong hit, so the montage starts on it. The Rei version keeps its ~1,25 s pace; its first hall moved onto the strongest hit (it was 3rd of 7). Tables: `corte11f_provas\acentos_saloes_tirano.md` and `acentos_saloes_rei.md`.

   | Tirano (cut, t) | onset | bass | rank ±1 s |
   |---|---|---|---|
   | Carrion King 39,572 | 7,3× | +4,2 dB | 1 of 9 |
   | Tower Lich 41,848 | 9,6× | +10,7 dB | 1 of 8 |
   | Abyss Tyrant 44,135 | 7,2× | +4,2 dB | 1 of 8 |
   | Winter Monarch 46,422 | 10,5× | +6,5 dB | 1 of 8 |
   | Rot Colossus 48,709 | 6,9× | +4,1 dB | 1 of 8 |
   | → gate 50,997 | 8,0× | +5,3 dB | 1 of 8 |

   For comparison, 11e Tirano was 38,713 / 39,851 / 40,989 / 41,848 / 42,997, ranked 1 to 6 of 9.

   | Rei (cut, t) | onset | bass | rank ±1 s |
   |---|---|---|---|
   | Carrion King 39,398 | 28,6× | +33,7 dB | 1 of 7 |
   | Tower Lich 40,664 | 21,9× | +30,6 dB | 2 of 7 |
   | Abyss Tyrant 41,604 | 23,0× | +32,5 dB | 1 of 7 |
   | Winter Monarch 43,160 | 26,4× | +30,5 dB | 1 of 7 |
   | Rot Colossus 44,414 | 31,5× | +30,9 dB | 1 of 8 |
   | → gate 45,679 | 25,2× | +32,4 dB | 1 of 7 |

   Note: the Tirano track is dense and its bass never jumps like the Rei's. Its strongest local accent is about +4 to +11 dB, against +30 dB in the Rei.
2. **Acts:** the dissolve between acts drops from 0,45 s to **0,20 s**, and each act lasts 2,3 s (was 2,0). The opening still walks forward with calm ambient sound.
3. **Card play:** new take `cards_c11f` (same headless recorder, in-game CRT, identity `card-game-trailer-v9`, one lovec). The rogue faces a pit brute with **55/55**.
   - The Volley +15 combo takes it to **7/55**; the bar drops by 87% on screen, with the game's hits, flash and shake.
   - The next turn shows **7 LETHAL** and kills it.
   - The cut between the two turns shows enemy 7/55 and hero 60/60 on both sides (`corte11f_provas\<version>\p_cartas_corte_antes_depois.png`, `p_cartas_folha_4qps.png`).
   - The enemy HP was set at the start of the fight, before any frame that goes into the film.

## Checks
- **Ending:** 390 of 390 frames from `logo_sting.mp4`, 1,56/255 in both versions (same as v8).
- **Fight:** no number changes across a cut (`p_cortes_da_luta_antes_depois.png`).
- **Scale:** gameplay stays at 1,00. The only flags are the TV turning on, the door-to-swoop transition, and in the Rei the card-to-Scarecrow cut (a cut, not a zoom).
- **Dark frames:** only the TV turning on and the logo background.
- **Loudness:** Tirano −14,1 LUFS / −1,1 dBTP / LRA 10,2; Rei −14,1 / −1,1 / 9,2.
- **Bitrate:** 720p 13,7 / 14,1 Mb/s; 1080p 33,0 / 34,4 Mb/s.
- **Duration:** 76,5 s (Tirano) and 69,6 s (Rei).
- **"SIX BOSSES." over five halls** is unchanged (pending with Daniel).
