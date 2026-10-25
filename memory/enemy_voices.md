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

## v1 REJEITADA pelo dono (25/Out/2026)

"Muito infantis: parecem brinquedo que apita, barulhinho de palhaço fofo. A ideia é certa, mas tem que ser mais sério e
mais ligado a cada inimigo." Os culpados mais prováveis da v1:
- os sintéticos tonais `shriek` (FM), `squeak` (senoide), `croak` (trem de pulsos) e `shimmer`;
- o pitch PARA CIMA (fonte EL ×1,3 a ×1,9);
- o lamento de senoide.

Tudo isso saiu (`tools/enemy_voices/synth.py` foi apagado). **Regra: voz de inimigo é dark fantasy séria (pesada,
grave, gutural, com material e respiração); nunca pitch acima de 1,0, nunca contorno que sobe, nunca síntese tonal.**

## Como os arquivos foram feitos (v2)

**Modelo local: inviável hoje.** RTX 2060 SUPER 8 GB serve, mas:
- **Stable Audio Open 1.0** (e small) é GATED no Hugging Face (HTTP 401 sem token): exige conta do dono, aceitar a
  licença e um token, e não há token nesta máquina. A licença (Stability AI Community License, versão de 05/Jul/2024)
  PERMITE uso comercial gratuito para quem fatura menos de US$ 1 mi/ano, e o usuário é dono das saídas. Acima disso é
  preciso a licença Enterprise.
- **AudioLDM2**: CC-BY-NC-SA 4.0, sem uso comercial, então está descartado.
- **AudioGen/AudioCraft**: os pesos são CC-BY-NC, também descartados.
- Caminho futuro: o dono loga no HF, aceita a licença do SAO 1.0, e a geração roda num venv isolado no scratchpad.

**Feito por DSP sobre material GRAVADO do repo**:
- `python tools/enemy_voices/build.py [id ...]`, reprodutível (sementes por arquivo); são uns 2,5 min para as 42.
- Fontes:
  - as 2 EL (`raw/el_beast_pain.mp3` e `raw/el_undead_pain.mp3`);
  - o som de entrada da criatura;
  - `audio/sfx/boss/*` (colossus_crack/crumble, death_thud, land_impact, lava_implosion, eyes_rumble, tyrant_chain_snap,
    frost_shatter, ice_crackle, spore_collapse, wing_pass, feather_burst, eclipse_*);
  - `impact-*`, `scene-stone-thud`/`wood-knock`/`rustle` e `event-enter-wind`;
  - `audio/sword-sound` e `audio/punching-light-armour`;
  - os trovões de `weather/`.
- Cadeia por camada:
  - recorte do pico (hurt: 3 picos diferentes) ou da região mais longa (death);
  - pitch SEMPRE ≤ 1,0 (`assert`);
  - **queda de pitch embutida**: reamostragem com taxa caindo de p a 0,9p (hurt) ou 0,82p (death), então o contorno só cai;
  - variantes ×1,00/0,95/0,90 (hurt) e ×1,00/0,93 (death).
- "Corpo" por família (`FX`): low-shelf +4 a 6 dB em 170 Hz, saturação tanh, passa-baixa 3,6 a 6 kHz, respiração (ruído
  180 a 1000 Hz seguindo o envelope da voz), sala curta (IR 0,32 s, molhado 10 a 42%, o máximo nos fantasmas) e passa-alta
  75 Hz (sem sub-ronco que gasta a loudness).
- Teto de centroide por família (`CENTROID_CAP`, com `cap` opcional por criatura): se passar, aperta o passa-baixa.
- Se a subida de pitch medida passar de 1,05, o arquivo é refeito com queda maior (até 5 tentativas).
- Loudness (-17/-16 LUFS), pico ≤ -2 dBFS, duração, cooldown, não-repetição e runtime ficam iguais à v1.
- Prova: rode `ENEMY_VOICES_OLD=<pasta da v1> python tools/enemy_voices/report.py`. Ele grava em
  `tools/preview_out/vozes_inimigos/v2/`:
  - `tabela.md`: por arquivo, duração, LUFS, pico, ataque, centroide v1/v2 e subida de pitch; por criatura e por família, a
    média do centroide;
  - `ato1..6_ab.png`: onda + espectrograma, com a v1 em cima e a v2 embaixo.
- Critérios:
  - hurt de 0,2 a 0,62 s, com ataque ≤ 0,06 s;
  - death de 0,6 a 1,55 s, com ataque ≤ 0,15 s;
  - pico ≤ -0,5 dBFS;
  - subida de pitch ≤ 1,06 (rastreador por autocorrelação em `dsp.max_rise`, resistente a salto de oitava);
  - centroide médio da criatura abaixo do da v1.
- A v1 (rejeitada) fica em `tools/preview_out/vozes_inimigos/ato*.png` e `tabela.md`, para comparação.

| familia | centroide medio v1 (Hz) | centroide medio v2 (Hz) | veredito |
|---|---|---|---|---|
| cursed_scarecrow | undead | 3029 | 639 | ok |
| hollow_farmer | undead | 593 | 584 | ok |
| plague_rats | vermin | 4804 | 741 | ok |
| harvest_reaper | ghost | 1077 | 602 | ok |
| blight_bull | beast | 338 | 326 | ok |
| wicker_effigy | fire | 5804 | 488 | ok |
| carrion_king | undead | 1416 | 633 | ok |
| moon_gargoyle | stone | 1697 | 439 | ok |
| ram_cultist | undead | 553 | 508 | ok |
| storm_harpy | vermin | 2872 | 424 | ok |
| rune_golem | stone | 438 | 424 | ok |
| spectral_knight | ghost | 866 | 567 | ok |
| storm_griffin | beast | 1628 | 333 | ok |
| tower_lich | ghost | 860 | 481 | ok |
| ember_imp | fire | 3113 | 424 | ok |
| hellhound | beast | 519 | 316 | ok |
| abyss_acolyte | undead | 461 | 454 | ok |
| obsidian_sentinel | stone | 748 | 361 | ok |
| pit_brute | beast | 299 | 280 | ok |
| abyss_watcher | wet | 517 | 295 | ok |
| abyss_tyrant | beast | 570 | 257 | ok |
| frost_wight | ghost | 1371 | 607 | ok |
| frost_wolf | beast | 612 | 371 | ok |
| rime_shaman | undead | 2343 | 626 | ok |
| glacier_knight | metal | 1695 | 519 | ok |
| frost_troll | beast | 451 | 304 | ok |
| ice_wyrm | beast | 1604 | 331 | ok |
| winter_monarch | ghost | 1350 | 537 | ok |
| bog_ghoul | wet | 910 | 552 | ok |
| plague_toad | wet | 660 | 308 | ok |
| leech_horror | wet | 1159 | 544 | ok |
| mire_hag | undead | 1222 | 670 | ok |
| croc_warrior | beast | 534 | 348 | ok |
| spore_mother | wet | 1488 | 509 | ok |
| rot_colossus | beast | 354 | 247 | ok |
| dusk_shade | ghost | 861 | 467 | ok |
| dusk_bat | vermin | 3129 | 346 | ok |
| grave_thrall | undead | 1872 | 551 | ok |
| blood_duke | undead | 2868 | 619 | ok |
| dullahan | metal | 604 | 354 | ok |
| fallen_angel | ghost | 1274 | 482 | ok |
| eclipse_queen | ghost | 916 | 572 | ok |

| familia | centroide medio v1 (Hz) | centroide medio v2 (Hz) | arquivos |
|---|---|---|---|
| beast | 691 | 311 | 50 |
| fire | 4458 | 456 | 10 |
| ghost | 1072 | 539 | 40 |
| metal | 1150 | 437 | 10 |
| stone | 961 | 408 | 15 |
| undead | 1595 | 587 | 45 |
| vermin | 3602 | 504 | 15 |
| wet | 947 | 442 | 25 |
| TODAS | 1416 | 463 | 210 |

## Tabela por criatura (v2)

| ato | criatura | tipo | família | hurt: voz | hurt: material | death |
|---|---|---|---|---|---|---|
| 1 | cursed_scarecrow | comum | undead | EL morto-vivo x0.70 + entrada wake x0.80 | scene-rustle x0.80 + scene-wood-knock x0.70 | entrada stop x0.85 + EL morto-vivo x0.60 |
| 1 | hollow_farmer | comum | undead | EL morto-vivo x0.72 | scene-stone-thud x0.75 + scene-wood-knock x0.65 | EL morto-vivo x0.62 + entrada stop x0.75 |
| 1 | plague_rats | comum | vermin | entrada stop x0.70 + EL besta x0.95 | scene-rustle x0.80 | entrada start x0.75 + entrada stop x0.70 + EL besta x0.85 |
| 1 | harvest_reaper | elite | ghost | EL morto-vivo x0.65 + entrada stop x0.80 | sword-sound x0.70 | EL morto-vivo x0.55 + entrada stop x0.70 + event-enter-wind x0.80 |
| 1 | blight_bull | elite | beast | EL besta x0.70 + entrada stop x0.75 | scene-stone-thud x0.75 | EL besta x0.65 + boss_land_impact x0.80 |
| 1 | wicker_effigy | mini-chefe | fire | entrada wake x0.80 + EL morto-vivo x0.60 | impact-fire x0.80 + scene-wood-knock x0.70 | entrada wake x0.70 + boss_hellfire_wall x0.80 + EL morto-vivo x0.55 |
| 1 | carrion_king | chefe | undead | EL morto-vivo x0.70 + appear_2 x0.70 | boss_wing_pass x0.80 | EL morto-vivo x0.60 + cine_2 x0.75 + boss_death_thud x0.90 |
| 2 | moon_gargoyle | comum | stone | entrada wake x0.80 + EL besta x0.80 | colossus_crack x0.85 + scene-stone-thud x0.80 | colossus_crumble x0.85 + EL besta x0.70 |
| 2 | ram_cultist | comum | undead | EL morto-vivo x0.80 + EL besta x0.95 | impact-dark x0.80 | EL morto-vivo x0.70 + entrada stop x0.80 |
| 2 | storm_harpy | comum | vermin | EL besta x0.95 + entrada stop x0.85 | boss_wing_pass x0.85 | EL besta x0.80 + thunder-near x0.90 + boss_feather_burst x0.80 |
| 2 | rune_golem | elite | stone | entrada stop x0.80 + boss_eyes_rumble x0.85 | colossus_crack x0.80 | colossus_crumble x0.80 + entrada stop x0.70 |
| 2 | spectral_knight | elite | ghost | EL morto-vivo x0.60 + entrada stop x0.85 | punching-light-armour x0.80 | EL morto-vivo x0.50 + entrada stop x0.70 + event-enter-wind x0.80 |
| 2 | storm_griffin | mini-chefe | beast | EL besta x0.85 + entrada stop x0.85 | boss_wing_pass x0.80 | EL besta x0.70 + entrada stop x0.80 + thunder-mid x0.90 |
| 2 | tower_lich | chefe | ghost | EL morto-vivo x0.60 + boss_rune_ignite x0.80 | scene-wood-knock x0.60 | EL morto-vivo x0.50 + boss_death_thud x0.85 + boss_ice_crackle x0.80 |
| 3 | ember_imp | comum | fire | EL besta x1.00 + entrada rise x0.85 | impact-fire x0.85 | EL besta x0.85 + boss_lava_implosion x0.90 |
| 3 | hellhound | comum | beast | entrada stop x0.85 + EL besta x0.85 | impact-fire x0.80 | EL besta x0.70 + entrada stop x0.75 + impact-fire x0.70 |
| 3 | abyss_acolyte | comum | undead | EL morto-vivo x0.60 | scene-stone-thud x0.70 | EL morto-vivo x0.65 + entrada stop x0.75 + boss_eyes_rumble x0.85 |
| 3 | obsidian_sentinel | elite | stone | entrada wake x0.80 + boss_eyes_rumble x0.80 | punching-light-armour x0.75 + colossus_crack x0.85 | colossus_crumble x0.80 + entrada stop x0.80 |
| 3 | pit_brute | elite | beast | EL besta x0.65 + entrada stop x0.85 | scene-stone-thud x0.75 | EL besta x0.55 + entrada rise x0.80 + boss_land_impact x0.80 |
| 3 | abyss_watcher | mini-chefe | wet | entrada stop x0.80 + EL morto-vivo x0.55 | impact-poison x0.75 | boss_death_thud x0.85 + entrada stop x0.70 + boss_spore_collapse x0.80 + EL morto-vivo x0.50 |
| 3 | abyss_tyrant | chefe | beast | EL besta x0.55 + tyrant_unchained x0.80 | tyrant_chain_snap x0.80 | EL besta x0.50 + tyrant_chain_snap x0.80 + boss_lava_implosion x0.85 |
| 4 | frost_wight | comum | ghost | EL morto-vivo x0.60 + entrada stop x0.80 | boss_ice_crackle x0.80 | impact-ice x0.70 + EL morto-vivo x0.50 + entrada stop x0.70 + boss_frost_shatter x0.80 |
| 4 | frost_wolf | comum | beast | EL besta x0.95 + entrada stop x0.80 | scene-rustle x0.75 | entrada stop x0.85 + EL besta x0.80 |
| 4 | rime_shaman | comum | undead | EL morto-vivo x0.80 | boss_ice_crackle x0.80 + scene-wood-knock x0.70 | EL morto-vivo x0.70 + entrada stop x0.80 + impact-ice x0.75 |
| 4 | glacier_knight | elite | metal | EL morto-vivo x0.65 + entrada stop x0.80 | punching-light-armour x0.75 + impact-ice x0.80 | punching-light-armour x0.75 + entrada stop x0.70 + EL morto-vivo x0.55 + boss_frost_shatter x0.80 |
| 4 | frost_troll | elite | beast | EL besta x0.70 + entrada stop x0.85 | scene-stone-thud x0.75 + impact-ice x0.75 | EL besta x0.60 + entrada start x0.80 + boss_land_impact x0.80 |
| 4 | ice_wyrm | mini-chefe | beast | EL besta x0.75 + entrada rise x0.80 | boss_ice_crackle x0.75 | EL besta x0.60 + entrada rise x0.75 + boss_frost_shatter x0.80 |
| 4 | winter_monarch | chefe | ghost | EL morto-vivo x0.60 + monarch_strike x0.80 | boss_ice_crackle x0.75 | EL morto-vivo x0.50 + boss_frost_shatter x0.75 + boss_blizzard_whiteout x0.85 |
| 5 | bog_ghoul | comum | wet | EL morto-vivo x0.72 + entrada rise x0.70 | impact-poison x0.75 | EL morto-vivo x0.65 + entrada rise x0.75 |
| 5 | plague_toad | comum | wet | EL besta x0.65 + entrada stop x0.80 | entrada hop x0.75 | EL besta x0.55 + entrada stop x0.70 + boss_spore_collapse x0.80 |
| 5 | leech_horror | comum | wet | entrada rise x0.75 + EL morto-vivo x0.60 | impact-poison x0.70 | entrada rise x0.65 + boss_spore_collapse x0.75 + EL morto-vivo x0.50 |
| 5 | mire_hag | elite | undead | EL morto-vivo x0.90 | entrada stop x0.80 | boss_death_thud x0.85 + entrada stop x0.75 + EL morto-vivo x0.80 + impact-poison x0.75 |
| 5 | croc_warrior | elite | beast | entrada stop x0.80 + EL besta x0.75 | entrada start x0.80 | EL besta x0.60 + entrada start x0.75 |
| 5 | spore_mother | mini-chefe | wet | entrada rise x0.75 + EL morto-vivo x0.55 | boss_spore_collapse x0.80 | entrada rise x0.65 + boss_spore_collapse x0.75 + EL morto-vivo x0.50 |
| 5 | rot_colossus | chefe | beast | EL besta x0.55 + colossus_crack x0.80 | boss_roots_crawl x0.80 | colossus_crumble x0.80 + EL besta x0.50 |
| 6 | dusk_shade | comum | ghost | EL morto-vivo x0.55 + entrada stop x0.80 | event-enter-wind x0.80 | boss_death_thud x0.85 + EL morto-vivo x0.45 + entrada stop x0.70 + boss_eclipse_fade x0.80 |
| 6 | dusk_bat | comum | vermin | entrada stop x0.70 + EL besta x0.90 | boss_wing_pass x0.85 | entrada stop x0.65 + EL besta x0.75 + boss_feather_burst x0.80 |
| 6 | grave_thrall | comum | undead | EL morto-vivo x0.70 + entrada rise x0.80 | scene-wood-knock x0.65 + punching-light-armour x0.80 | EL morto-vivo x0.60 + entrada rise x0.75 + boss_death_thud x0.85 |
| 6 | blood_duke | elite | undead | EL morto-vivo x0.75 + entrada stop x0.80 | impact-dark x0.80 | EL morto-vivo x0.60 + entrada stop x0.75 + boss_wing_pass x0.80 |
| 6 | dullahan | elite | metal | EL morto-vivo x0.55 + entrada stop x0.80 | punching-light-armour x0.75 | entrada stop x0.70 + EL morto-vivo x0.45 + tyrant_chain_snap x0.80 |
| 6 | fallen_angel | mini-chefe | ghost | EL morto-vivo x0.70 + entrada stop x0.80 | boss_feather_burst x0.80 | EL morto-vivo x0.60 + entrada start x0.75 + boss_feathers_settle x0.85 |
| 6 | eclipse_queen | chefe | ghost | EL morto-vivo x0.75 + boss_eclipse_hum x0.80 | impact-arcane x0.75 | boss_death_thud x0.85 + EL morto-vivo x0.60 + boss_eclipse_break x0.80 + boss_eclipse_fade x0.80 |

Vozes COMPARTILHADAS (mesma fonte EL com pitch e material diferentes):
- **EL besta**: touro, ratos, harpia, grifo, gárgula, diabrete, cão infernal, bruto, tirano, lobo, troll, wyrm, sapo,
  croc, colosso, morcego e cultista.
- **EL morto-vivo**: os demais humanoides, fantasmas e chefes que não são besta.

## Pendente

- TUDO ainda nasce de ElevenLabs FREE (as 2 fontes, as entradas e os sons de chefe): `known_gaps.md` 0d.
- **Ouvir primeiro**:
  - plague_rats, dusk_bat e storm_harpy: eram os mais "brinquedo" e agora são guincho grave com rosnado;
  - plague_toad: era o trem de pulsos;
  - um morto-vivo bem grave (abyss_acolyte, hollow_farmer, rime_shaman hurt_1, mire_hag), para checar se não virou só
    ronco abafado em caixa de som pequena.
- Voz própria por criatura, em vez de 2 fontes divididas por 42 criaturas: gerar com Stable Audio Open (depois do login
  do dono) ou ElevenLabs pago, com prompts sérios por criatura.
- `attack`/`roar`: runtime e ganchos prontos, sem arquivos.

Ligações: [[sfx_generation]] · [[audio_system]] · [[enemy_entrances]] · [[boss_mechanics]]
