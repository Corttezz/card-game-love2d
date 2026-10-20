# Revisão dos monstros por ato (20/Out/2026)

Pedido do dono: "revise cada um dos atos com cada uma das opções de monstros, revisando: sombras, morte, sombras de morte, estados, ataque".

## Como foi revisado

- Ferramenta: `lovec . test_one screenshot_revisao_monstros <ato>[:id,...]` (1920x1080 virtual, tod 0,85 e 0,50 no 1º comum de cada ato, no ato 1 inteiro e no chefe). Por inimigo, na cena real (estrada para comum, elite e mini-chefe; salão para o chefe): fim da viagem, 1º quadro da batalha, parado, ataque em 6 tempos, golpe forte em 3, golpe com veneno, fraqueza, vulnerável, queimadura e força, enfurecido (beat real do `Game`), tooltip da intenção, tooltip de estado, névoa (intenção "?") e morte em 8 tempos pelo caminho real `Game:_onEnemyDeath` (no chefe, com a cinemática de morte).
- Saídas por inimigo em `atoN/`: `<id>.png` (folha 1:1), `<id>_pes.png` (pés a 2x, recorte fixo no ponto do idle) e `<id>_sombra.png` (sombra ISOLADA: cada quadro é renderizado de novo com `ShadowEngine.silhouette`, a faixa de contato e o contato do salão mudos, mesmo relógio; vermelho = onde a sombra escurece). A ferramenta imprime por quadro px de sombra, centro, extensão e pico, e o deslocamento corpo/sombra na troca viagem → batalha.
- As folhas por inimigo (448 MB) ficam fora do git; `visao_atoN.jpg` são as pranchas reduzidas (parado, ataque 0,30, forte 0,32, golpe + estados, tooltip de estado, morte 0,35 e 2,50).
- Arte: comparação lado a lado do quadro 0 de todo clip (ataque, forte, golpe, morte) contra o idle 0, por diferença média e tamanho do conteúdo.

## Defeitos achados e corrigidos (valem para todos os 42)

| Defeito | Prova | Correção | Trava |
|---|---|---|---|
| Sombra e faixa de contato paradas no lugar enquanto o corpo dava o bote (46 a 70 px), o recuo do golpe (14 px) e a deriva do flutuante | `cursed_scarecrow_pes.png` antes: mancha escura à direita dos pés com o corpo à esquerda | Sombra soma `atkDX + knockDX + driftX` e o `atkDY` para baixo; na viagem o flutuante soma a mesma deriva | `test_enemy_shadow_motion` (bote e recuo, desvio ≤ 2,5 px) |
| Cadáver de flutuante sem nenhum contato com o chão (lia como colado no ar) | `dusk_shade` morte 0,95 | `EnemyRenderer.contactK`: 0 no ar, sink² na queda, 1 pousado | idem (flutuante caído tem contato; no ar e no ataque não) |
| Contato do cadáver com a largura do pé EM PÉ do 1º quadro da morte | código | Pés medidos por quadro (`clipMetrics.frameFeet`) | idem (largura = quadro deitado) |
| Ícone de força do enfurecido/buff nascia acima do canvas, em cima da barra de vida e das pílulas | `eclipse_queen` névoa e morte 0,10, `dusk_bat` | Nasce no tronco (30% da altura do conteúdo) e sobe 10 px | idem (nunca acima do topo do canvas) |
| Três clips de ataque de outra geração de arte: o monstro virava outro desenho ao atacar | `carrion_king` (corvo atarracado, coroa maior, canvas 256), `harvest_reaper` (corpo virava silhueta amarela, canvas 184), `cursed_scarecrow` (calça verde, cabeça maior, canvas 176) | Regerados no PixelLab `animate_image` a partir do idle 0 atual (`tools/pixellab_attack_redo.py`), canvas igual ao idle | `test_enemy_clip_identity` (quadro 0 de todo clip = idle 0) |

## Tabela por ato

Legenda: ok = revisado e sem defeito; corrigido = defeito achado e consertado (o quê); regerado = arte nova; pendente = ver lista no fim.
"Sombra" = parado, chegada e batalha. "Estados" = pílulas, ícones, tooltips, enfurecido, névoa. "Sombra de morte" = sombra/contato acompanhando o corpo na queda e no cadáver.

### Ato 1 (campo, estrada) e salão 1

| Inimigo | Sombra | Ataque | Estados | Morte | Sombra de morte |
|---|---|---|---|---|---|
| cursed_scarecrow | ok (troca viagem/batalha 0,2 px) | regerado + corrigido (sombra no bote) | corrigido (ícone de força) | ok | corrigido (contato deitado) |
| hollow_farmer | ok | corrigido (sombra no bote) | corrigido (ícone) | ok | corrigido (contato deitado) |
| plague_rats | ok | corrigido | corrigido (ícone) | ok | corrigido |
| harvest_reaper | ok | regerado + corrigido | corrigido (ícone) | ok | corrigido |
| blight_bull | ok | corrigido | corrigido (ícone) | ok | corrigido |
| wicker_effigy | ok | corrigido | corrigido (ícone) | ok | corrigido |
| carrion_king (chefe, salão) | ok (contato do salão + elipse) | regerado | corrigido (ícone) | ok (cinemática, corvos, troféu) | ok |

### Ato 2 (lua, estrada) e salão 2

| Inimigo | Sombra | Ataque | Estados | Morte | Sombra de morte |
|---|---|---|---|---|---|
| moon_gargoyle | ok | corrigido (sombra no bote) | corrigido (ícone) | ok | corrigido (contato deitado) |
| ram_cultist | ok | corrigido | corrigido (ícone) | ok | corrigido |
| storm_harpy | ok | corrigido | corrigido (ícone) | ok | corrigido |
| rune_golem | ok | corrigido | corrigido (ícone) | ok | corrigido |
| spectral_knight | ok | corrigido | corrigido (ícone) | ok (lápide fica em pé, sombra dela também, coerente) | corrigido |
| storm_griffin | ok | corrigido | corrigido (ícone) | ok | corrigido |
| tower_lich (chefe flutuante, salão) | ok (sombra no chão atrás da mão: palco da mão) | ok | corrigido (ícone) | ok (cai até o chão do salão) | ok |

### Ato 3 (inferno, estrada) e salão 3

| Inimigo | Sombra | Ataque | Estados | Morte | Sombra de morte |
|---|---|---|---|---|---|
| ember_imp | ok | corrigido (sombra no bote) | corrigido (ícone) | ok | corrigido (contato deitado) |
| hellhound | ok | corrigido | corrigido (ícone) | ok | corrigido |
| abyss_acolyte | ok | corrigido | corrigido (ícone) | ok | corrigido |
| obsidian_sentinel | ok | corrigido | corrigido (ícone) | ok | corrigido |
| pit_brute | ok | corrigido | corrigido (ícone) | ok | corrigido |
| abyss_watcher (flutuante) | ok (sombra solta, coerente com a altura) | corrigido (sombra segue o bote e a deriva) | corrigido (ícone) | ok | corrigido (contato ao pousar) |
| abyss_tyrant (chefe, salão) | ok | ok | ok (correntes; ícone corrigido) | ok | ok |

### Ato 4 (gelo, estrada) e salão 4

| Inimigo | Sombra | Ataque | Estados | Morte | Sombra de morte |
|---|---|---|---|---|---|
| frost_wight | ok | corrigido (sombra no bote) | corrigido (ícone) | ok | corrigido (contato deitado) |
| frost_wolf | ok | corrigido | corrigido (ícone) | ok | corrigido |
| rime_shaman | ok | corrigido | corrigido (ícone) | ok (cajado fica em pé, sombra longa dele coerente) | corrigido |
| glacier_knight | ok | corrigido | corrigido (ícone) | ok | corrigido |
| frost_troll | ok | corrigido | corrigido (ícone) | ok | corrigido |
| ice_wyrm | ok | corrigido | corrigido (ícone) | ok | corrigido |
| winter_monarch (chefe, salão) | ok (contato do salão) | ok | corrigido (ícone) | ok | ok |

### Ato 5 (pântano, estrada) e salão 5

| Inimigo | Sombra | Ataque | Estados | Morte | Sombra de morte |
|---|---|---|---|---|---|
| bog_ghoul | ok | corrigido (sombra no bote) | corrigido (ícone) | ok | corrigido (contato deitado) |
| plague_toad | ok | corrigido | corrigido (ícone) | ok (sapo deitado ainda alto, sombra proporcional) | corrigido |
| leech_horror | ok | corrigido | corrigido (ícone) | ok | corrigido |
| mire_hag | ok | corrigido | corrigido (ícone) | ok | corrigido |
| croc_warrior | ok | corrigido | corrigido (ícone) | ok | corrigido |
| spore_mother | ok | corrigido | corrigido (ícone) | ok (chapéu largo fica, sombra dele também) | corrigido |
| rot_colossus (chefe, salão) | ok | ok | corrigido (ícone) | pendente (ver 2) | ok |

### Ato 6 (crepúsculo, estrada) e salão 6

| Inimigo | Sombra | Ataque | Estados | Morte | Sombra de morte |
|---|---|---|---|---|---|
| dusk_shade (flutuante) | ok (sombra solta) | corrigido (sombra segue bote e deriva) | corrigido (ícone) | ok | corrigido (contato ao pousar; antes nenhum) |
| dusk_bat (flutuante) | ok | corrigido | corrigido (ícone sobre a barra) | ok | corrigido (contato ao pousar) |
| grave_thrall | ok | corrigido | corrigido (ícone) | ok (escudo fica em pé, sombra dele coerente) | corrigido |
| blood_duke | ok | corrigido | corrigido (ícone) | ok | corrigido |
| dullahan | ok | corrigido | corrigido (ícone) | ok | corrigido |
| fallen_angel | ok | corrigido | corrigido (ícone) | ok | corrigido |
| eclipse_queen (chefe flutuante, salão) | ok | ok | corrigido (ícone cobria barra e pílulas) | ok | ok |

Som do ataque: `enemyAttack` toca no ápice (`applyHit`), morte `enemyDeath`, enfurecido `enemyBuffRoar`; todos registrados no `main.lua`.
Troca viagem → batalha: desvio do corpo ≤ 0,9 px em todos os 36 de estrada; sombra com a mesma área (±3%) e o mesmo centro.

## Segunda rodada (pedido do lead: zero pendência)

| Item | O que foi feito | Prova |
|---|---|---|
| Leitura no escuro (atos 3 e 5, crepúsculo do 6, ato 4) | Oclusor do inimigo focal (`SceneGrade.FOCAL_TINT.enemy = 0,30`: parte do branco com 30% do matiz da hora; cenário segue ambiente puro) + contorno de 1 px de arte na cor da névoa do bioma, só no escuro (0 com luz cheia, até 0,40), na batalha e na viagem | `luz_atoN_antes.jpg` / `luz_atoN_depois.jpg` (N = 3 a 6, colunas tod 0,65 / 0,85 / 1,0) |
| Morte do Colosso | Cadáver entra em fusão (corpo, sombra e contato) enquanto o monte de blocos some (`BossCinematic.bossAlpha`, `opts.alpha`) | `colosso_morte_antes_depois.png` (cima antes, baixo depois) |
| Círculo laranja no ataque do espantalho | Edição de pixel testada e descartada (a cor do efeito é a mesma da palha); regerado com prompt sem efeito, 4 candidatas limpas, escolhida a s101v3 (garra rasga o peito) | `ato1/cursed_scarecrow.png` (quadros de ataque) |
| Garra do Rei-Carniça | Golpe agora lê pela antecipação do golpe forte (item abaixo) e pelas linhas de corte do jogo; a arte s22 fica | `ato1/carrion_king.png` |
| Golpe forte | Igual em todo inimigo, sem arte nova: preparo de 0,40 s com pausa, recuo de 24 px, agachamento de 10% que estica no bote e escurecimento para a sombra do bioma no preparo | `golpe_forte_pit_brute.png` (parado, comum, forte 0,15 / 0,30 / 0,42) |
| Sombra no salão do chefe | Os seis salões têm a luz atrás do chefe: o ShadowEngine liga no salão (`GameplayScene.hallShadowFrame`) e o chefe projeta a silhueta do quadro atual para a frente, no lugar da elipse | `salao_sombra_antes_depois.png` |

Travas novas: `test_enemy_shadow_motion` (contorno só no escuro, golpe forte, fusão do corpo com sombra e contato, salão com silhueta), `test_scene_grade` (inimigo focal claro e com matiz).

## Pendente / leitura honesta

1. Ato 4 ficou um pouco mais claro com o oclusor focal (troll de gelo quase branco no tod 0,65); continua lendo, mas é mais "recortado" que antes.
2. Contorno de luz usa a cor da névoa do bioma: no ato 3 ele é vermelho e só reforça a borda, não muda o corpo.
3. Chefe no salão: o contato do `InteriorDepth` continua por baixo da silhueta, e no tapete vermelho do salão 1 a silhueta é bem suave (é o tom do salão).
