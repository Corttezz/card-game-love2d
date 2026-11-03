# Cut 11g (edit/mix only, from `revisao-grimoire-corte11f.md`, ae13205d)

_Director, 03/11/2026. Tirano stays the main version, Rei the alternative. No new capture. Everything else from 11f2 is unchanged: card play 55 → 7/55 → kill, halls at ~1,1 s, CRT takes, Higgsfield halls, text cards, the logo_sting ending, and no zoom._

> **NOT PUBLISHABLE UNTIL THE SFX ARE REPLACED OR LICENSED.**

## Files
- `E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_c11g.mp4` (1080p) and `grimoire_trailer_c11g_720p.mp4` (Tirano)
- `E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_c11g_rei.mp4` (1080p) and `grimoire_trailer_c11g_rei_720p.mp4` (Rei)
- Delivered, identical byte for byte: `C:\Users\corte\grokbot_entrega\corte11g_720p.mp4` and `corte11g_rei_720p.mp4`.
- Cut script: `tools/trailer_c11g_cut.py` (trailer worktree). Measurement script: `corte/medir11g.py`, which reads the 720p mix itself (band below 150 Hz, onset per 20 ms, ratio to the median, rank within ±1 s; hit = 100 ms RMS peak minus the median of the 1 s before).

## Changes
1. **Tirano halls:** a low impact on every hall switch. `boss_land_impact` at −3 dB plus `boot-impact` at −7 dB on each of the six cuts, with a −5 dB music duck for 250 ms. Every cut now carries a bass hit of **8,4× to 20,9×** in the mix (the bar was ≥ 4×). The halls stay at ~1,15 s.
2. **Crows:** the shot runs at **1,8×**, so the 8 dives still take the hero from 41 to 9 in one continuous piece of the take, ending on the tick (King 30 → 21). Tirano goes from 5,4 to 2,8 s; Rei from 5,0 to 3,2 s.
3. **Lethal blow (both versions):**
   - On screen: a 5-frame hit-stop on the blow (the frame repeated), a flash during the stop, then a 10 px shake that fades over 0,35 s. No zoom.
   - In the mix: the music ducks −13 dB from 0,45 s before the blow until 0,7 s after it, and `boss_land_impact` (+4 dB) and `boot-impact` (+2 dB) land on the blow.
   - Hit over the bed 1 s before: **Tirano +19,6 dB, Rei +17,9 dB** (11f Tirano was −3,0).
4. **Card-play kill:** the cut to the Collection now comes 0,25 s after the −30 hit and flash, so the two cards no longer sit in front of the dying enemy for 1,2 s.

## Checks
- **Ending:** 390/390 logo frames in both, 1,56/255 from the source (same as v8).
- **Loudness:** Tirano −14,0 LUFS / −1,3 dBTP / LRA 10,6; Rei −14,0 / −0,9 / 9,2.
- **Bitrate:** 720p 14,0 / 14,1 Mb/s; 1080p 34,3 / 34,3 Mb/s.
- **Duration:** 67,3 s (Tirano) and 68,3 s (Rei).
- **Scale:** gameplay stays at 1,00. The only flags are the TV power-on and the game's door-to-swoop transition.
- **Proofs** in `corte11g_provas\`: `golpes_e_grave.md`, plus for each version `p_corvos_6qps.png`, `p_golpe_letal_20qps.png` and `p_cartas_morte_8qps.png`.
- **"SIX BOSSES." over five halls:** unchanged, pending with Daniel.

## Revision 2 (after `revisao-corte11g.md`, f1fb98a1, PASS 9,3 / 9,4, with sound risks)
- **Lethal blow:** the music now drops −7 dB when the lethal turn starts, then −9 dB, and ducks to −16 dB 0,3 s before the blow. The blow's peak already sits at the −1 dBTP limit, so the margin has to come from the bed under it. Impacts on the blow are +4 dB.

  | lethal blow, peak over… | Tirano | Rei |
  |---|---|---|
  | the bed 1 s before | +22,3 dB | +19,5 dB |
  | the music 2,2 to 1,2 s before | +18,5 dB | +14,6 dB |
  | the crows' climax 3,5 to 2,5 s before | +5,4 dB | +9,0 dB |

- **Card-play kill:** `boss_land_impact` added on the −30. It is now +10,0 dB (Tirano) and +9,3 dB (Rei) over the bed (was −5,3 / −2,5).
- **Loudness:** Tirano −14,1 LUFS / −1,0 dBTP / LRA 10,5; Rei −14,0 / −0,8 / 9,2.
- **Bitrate:** 720p 14,0 / 14,1 Mb/s.
- **Delivery:** the files in `grokbot_entrega` were replaced with this revision (`cmp` identical).
