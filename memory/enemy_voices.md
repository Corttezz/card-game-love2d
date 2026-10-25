---
name: Vozes dos inimigos (hurt/death por criatura)
description: Som próprio de cada uma das 42 criaturas ao levar golpe e ao morrer: arquivos por scan em audio/sfx/enemies/<id>/, runtime EnemySfx (cooldown, sem repetir, imune calado, morte troca o genérico), como foram feitos (DSP + 2 fontes ElevenLabs) e o que regerar.
type: project
---

# Vozes dos inimigos (25/Out/2026)

Pedido do dono: "os mobs, quando tomam dano, emitam um som específico deles assim que tomam o golpe".

## Runtime

- `src/systems/EnemySfx.lua` + dados em `src/data/enemy_sfx.lua`.
- **Registro por SCAN**: `audio/sfx/enemies/<id>/<evento>_N.mp3`, eventos `hurt`, `death`, `attack` e `roar`. Arquivo novo
  toca sem código e sem `main.lua`. Carga preguiçosa POR CRIATURA (5 mp3 no 1º golpe dela, nunca as 210 de uma vez).
  Código do som: `enemyVoice_<id>_<evento><N>`. `id` = `enemy.spriteId` (o id do roster), e `kitId` é o reserva.
  `EnemySfxData.ALIAS[id] = outro` faz uma criatura usar a pasta de outra.
- **Ganchos (uma linha cada)**:
  - `Enemy:takeDamage` chama `EnemySfx.hurt(self, vidaPerdida, nivel)`, no MESMO quadro do impacto do tema da carta
    (`CombatSequence` toca o impacto e logo em seguida resolve a carta).
  - `Game:_onEnemyDeath` chama `EnemySfx.death` no lugar do `Sfx.play("enemyDeath")`.
  - `applyHit` do turno do inimigo chama `EnemySfx.attack`, uma voz por cima do `enemyAttack`.
  - O buff de Força usa `EnemySfx.roar(...) or enemyBuffRoar`.
  - Entrada não ganhou gancho, porque o `EnemyEntrance` já tem som por criatura (`memory/enemy_entrances.md`).
- **Regras**:
  - Escolhe a variante sem repetir a anterior, com pitch ±4% (`pitchVar`).
  - Cooldown de `hurt` de 0,18 s: num multigolpe a voz sai só no 1º golpe e os seguintes ficam só com o impacto (`play` devolve `false`).
  - Relógio que volta (stub de teste) reabre o cooldown.
  - **Não toca** quando:
    - o tick é imune (o `ResistFx` já toca o "shrug");
    - o golpe não tira vida (Bloqueio absorve);
    - o golpe mata (quem fala é o `death`).
  - DoT (veneno/queimadura) não passa por `takeDamage` e fica mudo de propósito.
  - Criatura sem arquivos:
    - `hurt` fica só com o impacto;
    - `death` cai no `enemyDeath`;
    - `Debug.warn` sai UMA vez por criatura e evento, e só com `_G.audioSystem` presente.
  - `attack`/`roar` sem arquivo ficam calados e sem aviso, porque são opcionais.
- **Mix**:
  - Arquivos de hurt a -17 LUFS e de death a -16 LUFS (medidos na parte ativa), com pico ≤ -2 dBFS.
  - Volumes no registro:
    - hurt 0,42, uns 5 dB sob o impacto (-14 LUFS a 0,55);
    - death 0,62, para empatar com o `enemyDeath` (-13 LUFS a 0,48).
- Trava: `love . test_one test_enemy_sfx`, que cobre:
  - as 42 resolvem 3 hurt + 2 death próprios;
  - as durações;
  - o cooldown, a não-repetição e o pitch;
  - a imunidade via `Enemy:takeDamage` real (fogo no imp);
  - o `_onEnemyDeath` real sem `enemyDeath`;
  - o fallback, o warn único, o ALIAS e o scan com sonda gravada no save dir.

## Como os arquivos foram feitos

- **Cota ElevenLabs**: restavam 209 créditos (reset ~12/Nov). O lead deu 50 à frente, e a prioridade ficou com AUDIO-FLOW.
  Foram gastas 2 gerações de 2,5 s (`tools/preview_out/vozes_inimigos/raw/el_beast_pain.mp3` = rosnado de besta grande,
  `el_undead_pain.mp3` = gemido de morto-vivo). Elas são as fontes COMPARTILHADAS, com pitch por criatura.
- Todo o resto é DSP offline: `python tools/enemy_voices/build.py [id ...]` (numpy/scipy + ffmpeg). Cada som soma:
  1. **voz**: recorte do pico do som de ENTRADA da própria criatura (`audio/sfx/entrances/`), e/ou a fonte EL com pitch, e/ou
     voz sintetizada (`ghost` lamento, `shriek` guincho, `squeak` chiado, `croak` coaxo, `hiss`);
  2. **material** procedural (`tools/enemy_voices/synth.py`): osso, molhado, pedra, metal, gelo, fogo, madeira, palha,
     penas, corrente, baque, zumbido escuro, brilho.
  - Variantes: hurt = 3 picos diferentes da fonte × pitch 1,00/0,94/1,07 + semente do material.
  - Death: a região mais longa da fonte, pitch 1,00/0,93.
  - Corte de silêncio, cauda com fade, normalização LUFS + limitador.
- Prova: `python tools/enemy_voices/report.py` gera:
  - `tools/preview_out/vozes_inimigos/tabela.md`: duração, LUFS ativo, LUFS ebur128 com loop 4x, pico e ataque de cada um dos 210;
  - `ato1..6.png`: onda + espectrograma, onde vermelho na onda = clip.
  - Faixas: hurt 0,2 a 0,62 s com ataque ≤ 0,06 s; death 0,6 a 1,55 s.
  - Nenhuma fonte tem música nem fala. Sem escuta real: o veredito é por medida e espectrograma.

## Tabela por criatura (voz + material | morte)

| ato | criatura | tipo | hurt: voz | hurt: material | death |
|---|---|---|---|---|---|
| 1 | cursed_scarecrow | comum | corda/palha da entrada (wake) + chiado | palha + madeira | queda + corvos da entrada + palha |
| 1 | hollow_farmer | comum | EL morto-vivo ×1,05 | madeira + baque | EL morto-vivo + baque |
| 1 | plague_rats | comum | chiados + ratos da entrada ×1,10 | palha (patinhas) | ratos da entrada + chiados |
| 1 | harvest_reaper | elite | lamento + foice da entrada ×1,10 | metal | foice + lamento caindo |
| 1 | blight_bull | elite | EL besta ×0,85 | baque + molhado | EL besta + baque grave |
| 1 | wicker_effigy | mini-chefe | vime em chamas da entrada + rangido | fogo + palha | vime + fogo + palha |
| 1 | carrion_king | chefe | corvo `appear_2` ×0,8 + EL morto-vivo ×0,8 | penas | corvo `cine_2` + EL morto-vivo + penas |
| 2 | moon_gargoyle | comum | guincho + pedra da entrada + EL besta ×1,6 | pedra | pedra rachando + pedra |
| 2 | ram_cultist | comum | EL besta ×1,45 (balido) | zumbido | EL besta + runa da entrada |
| 2 | storm_harpy | comum | guincho + EL besta ×1,9 | penas | guincho + trovão da entrada + penas |
| 2 | rune_golem | elite | pedras da entrada ×1,1 + zumbido | pedra | pedras + pedra |
| 2 | spectral_knight | elite | lamento + armadura oca da entrada | metal oco | lamento + armadura + metal |
| 2 | storm_griffin | mini-chefe | guincho + EL besta ×1,3 | penas | pouso da entrada + guincho |
| 2 | tower_lich | chefe | lamento grave + EL morto-vivo ×0,8 | osso | EL morto-vivo + ossos + lamento |
| 3 | ember_imp | comum | guincho + EL besta ×1,7 | fogo | guincho + fenda de fogo + fogo |
| 3 | hellhound | comum | rosnado da entrada + EL besta ×1,15 | fogo | EL besta + rosnado + fogo |
| 3 | abyss_acolyte | comum | EL morto-vivo ×1,2 | zumbido escuro | EL morto-vivo + sigilo + zumbido |
| 3 | obsidian_sentinel | elite | pedra da entrada ×1,1 | pedra + metal | pedra + pedra |
| 3 | pit_brute | elite | EL besta ×0,75 + grunhido da entrada | baque | EL besta + queda + baque |
| 3 | abyss_watcher | mini-chefe | lamento de ar + drone da entrada ×1,2 | molhado | drone + molhado |
| 3 | abyss_tyrant | chefe | EL besta ×0,6 | corrente + fogo | EL besta + `tyrant_chain_snap` + baque |
| 4 | frost_wight | comum | lamento + vento gelado da entrada | gelo | lamento + vento + gelo |
| 4 | frost_wolf | comum | EL besta ×1,3 (ganido) + uivo da entrada | palha (neve) | uivo + EL besta |
| 4 | rime_shaman | comum | EL morto-vivo ×1,15 | gelo + madeira | EL morto-vivo + cajado + gelo |
| 4 | glacier_knight | elite | EL morto-vivo ×0,95 (baixo) | metal + gelo | armadura da entrada + metal + gelo |
| 4 | frost_troll | elite | EL besta ×0,8 + grunhido da entrada | gelo + baque | EL besta + neve explodindo + baque |
| 4 | ice_wyrm | mini-chefe | EL besta ×0,9 + sibilo | gelo | EL besta + gelo rompendo + gelo |
| 4 | winter_monarch | chefe | lamento + EL morto-vivo ×0,85 | gelo | `boss_frost_shatter` + lamento + EL |
| 5 | bog_ghoul | comum | EL morto-vivo | molhado | EL + lama da entrada + molhado |
| 5 | plague_toad | comum | coaxo | molhado | coaxo + splash da entrada + molhado |
| 5 | leech_horror | comum | sibilo + gosma da entrada ×1,15 | molhado | gosma + molhado |
| 5 | mire_hag | elite | EL morto-vivo ×1,35 (bruxa) | molhado + madeira | EL + lanterna/lama da entrada |
| 5 | croc_warrior | elite | sibilo/rosnado da entrada + EL besta ×0,95 | molhado | EL besta + splash da entrada |
| 5 | spore_mother | mini-chefe | sibilo de esporo + cogumelo da entrada | molhado | cogumelo + `boss_spore_collapse` + molhado |
| 5 | rot_colossus | chefe | EL besta ×0,6 + `colossus_crack` | molhado + madeira | `colossus_crumble` + EL besta |
| 6 | dusk_shade | comum | lamento + sombra da entrada | sibilo | lamento + sombra |
| 6 | dusk_bat | comum | chiados + asas da entrada ×1,15 | penas (asas) | asas + chiados + penas |
| 6 | grave_thrall | comum | EL morto-vivo ×0,95 | osso | ossos + EL + terra da entrada |
| 6 | blood_duke | elite | EL morto-vivo ×1,1 + sibilo | asas | morcegos da entrada + EL + sibilo |
| 6 | dullahan | elite | lamento grave + armadura da entrada | metal | armadura + metal + lamento |
| 6 | fallen_angel | mini-chefe | EL morto-vivo ×1,05 + brilho | penas | luz da entrada + penas + lamento |
| 6 | eclipse_queen | chefe | lamento agudo + EL morto-vivo ×1,2 | brilho | `boss_eclipse_break` + lamento + brilho |

Vozes COMPARTILHADAS:
- **EL besta**: blight_bull, ram_cultist, storm_harpy, storm_griffin, moon_gargoyle, ember_imp, hellhound, pit_brute,
  abyss_tyrant, frost_wolf, frost_troll, ice_wyrm, croc_warrior e rot_colossus.
- **EL morto-vivo**: hollow_farmer, carrion_king, tower_lich, abyss_acolyte, rime_shaman, glacier_knight, winter_monarch,
  bog_ghoul, mire_hag, grave_thrall, blood_duke, fallen_angel e eclipse_queen.

Os chefes mantêm corvos/CrowSfx e os sons de mecânica/cinemática; só ganharam hurt/death.

## Pendente / regerar quando houver cota (~12/Nov) ou plano pago

- TUDO aqui é ElevenLabs FREE (as 2 fontes EL e os recortes das entradas) e não tem uso comercial: está listado em `known_gaps.md` 0b.
- Prioridade de regeração com voz própria de verdade (hoje é síntese, e é a mais "eletrônica"):
  1. storm_harpy, storm_griffin e ember_imp (guincho FM);
  2. plague_rats e dusk_bat (chiado sintético);
  3. plague_toad (coaxo em trem de pulsos);
  4. frost_wight, dusk_shade, spectral_knight, eclipse_queen e harvest_reaper (lamento sintético).
- Depois disso, as famílias que dividem a mesma fonte EL com pitch (14 bestas e 13 mortos-vivos) merecem voz própria
  cada uma: o 3-cabeças, o lobo, o touro e o croc soam parentes.
- `attack` (vocal de preparo) e `roar` (buff): o runtime e os ganchos existem, mas NENHUM arquivo foi feito. Soltar
  `attack_1.mp3`/`roar_1.mp3` na pasta já toca.

Ligações: [[sfx_generation]] · [[audio_system]] · [[enemy_entrances]] · [[boss_mechanics]]
