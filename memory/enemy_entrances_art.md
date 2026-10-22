---
name: enemy_entrances_art
description: Arte das ENTRADAS dos inimigos (clipes walk/charge/emerge/awaken/swoop/land/form/assemble + ancoras de cenario) gerada no PixelLab por tools/pixellab_entradas.py; contrato de quadros (ultimo = idle 0), quadros derivados do idle, tripwires e o que ficou fraco
type: project
---

# Arte das entradas (atos 1 a 3, Out/2026)

Roteiro: `docs/superpowers/specs/2026-10-22-entradas-inimigos-design.md`. Motor: `src/ui/EnemyEntrance.lua` (frente entradas-motor). Esta nota cobre so a ARTE.

## Ferramenta

`python tools/pixellab_entradas.py run [ato|id ...]` (fabrica com ate 4 jobs em paralelo; a conta aceita 10 jobs simultaneos SOMADOS entre todos os agentes, "rate limit exceeded (10/10 jobs)" = outro agente segurando vaga, o scheduler so tenta de novo). `strips` grava a tira 4x de cada clipe (idle 0 de referencia depois da linha vermelha) em `tools/preview_out/entradas_arte/atoN/<id>_<clip>.png`; `anchors queue|poll|sheet|install <id>=<lote>_<idx>` cuida das ancoras; `status` resume. Jobs em `tools/preview_out/entradas_arte/jobs.json`, cada tentativa guardada em `atoN/tries/`.

- Uma ferramenta por familia: clipe = `animate_image` (v3), ancora = `create_image_pro` (4 candidatas por chamada a 86-170 px, PNG da criatura como `style_image` + referencia de escala, marco de elite do bioma como referencia de paleta).
- `frame_count` tem de ser PAR; `get_image` devolve N+1 quadros (0 = o quadro de entrada). Instalados: 9 quadros nos clipes de 8 e 7 nos curtos (`land`).
- **Ultimo quadro = idle/south/0.png byte a byte.** Pinado por `last_frame_base64`; se o modelo desviou (`end_drift`, fracao de pixels do conteudo que diferem > 48 num canal) ate 30 %, o tool SOBRESCREVE o ultimo quadro com o idle 0 (`pinned`); acima disso regera com outra semente (ate 3) e fica com a de menor desvio (`best_of_3`).
- **Quadro 0 derivado do idle** (`derive`): `sunk:N` (criatura deslocada para baixo, so N px do topo visiveis no fundo do canvas: ember_imp, pit_brute; desenhar com a base do canvas na linha do chao ja le como enterrado), `mist` (silhueta quase preta: harvest_reaper, spectral_knight), `dark` (corpo escurecido e olhos apagados: abyss_watcher), `unlit` (pixels quentes viram carvao: wicker_effigy, obsidian_sentinel), `statue` (cinza pedra, roxo apagado: moon_gargoyle), `rubble` (o idle fatiado em blocos de 14 px girados e empilhados baixo: rune_golem), `rats_bottom` (so a camada de baixo da pilha, `tools/preview_out/new_enemies/plague_rats/death_end.png`). O estado inerte da viagem e o quadro 0 do clipe, nunca um PNG a parte.
- `wicker_effigy_anchor.png` e o proprio idle apagado (`derive unlit`), nao gerado.
- Tripwires: anim morta (md5), quadro vazio/minusculo, desvio do fim. A metrica nao julga identidade no meio do clipe: isso e olhando a tira 4x.

## Ancoras instaladas (`assets/sprites/world/anchors/<id>_anchor.png`, recortadas no conteudo, escala de pixel da criatura, base do PNG = contato com o chao)

| ancora | tamanho | o que e | nota |
|---|---|---|---|
| cursed_scarecrow | 56x113 | poste de madeira com travessa e palha | mais alto que o espantalho (86 px): ele pende da travessa |
| harvest_reaper | 117x45 | banco de nevoa escura rasteira com palhas | o motor engrossa por alpha |
| wicker_effigy | 128x126 | a efigie apagada (idle com os pixels quentes em carvao) | = quadro 0 do `awaken` |
| moon_gargoyle | 114x51 | pedra achatada de perche | a estatua e o quadro 0 do `awaken` |
| ram_cultist | 123x43 | circulo runico SO linhas violeta, sem disco de terra | 1a leva vinha com disco escuro de terra (ficava mancha na estrada), regerado "lines only" |
| abyss_acolyte | 100x41 | sigilo de brasa SO linhas | 1a leva virou LAJE de pedra elevada, regerado "lines only" |
| ember_imp | 133x47 | fenda de lava | |
| pit_brute | 140x55 | fosso com borda de rocha e brasas | |
| abyss_watcher | 84x109 | borrao de fumaca negra com tentaculos de fumaca | flutua |
| obsidian_sentinel | 125x32 | plinto largo de obsidiana com veios de lava | 1a leva: cubos isometricos minusculos (o modelo ignorou a vista), reescrito "ONE wide low front-facing slab filling the canvas width" |

## Resultado por criatura

### Ato 1 (commit do ato)
| criatura | clipe | veredito | tentativas | nota |
|---|---|---|---|---|
| cursed_scarecrow | awaken | ok | 3 | v1/v2 (quadro 0 = idle) liam como idle com palha; o lead pediu o despertar de verdade. O v3 NAO ergue os bracos a partir do idle (`pose cursed_scarecrow/limp` so baixou a cabeca), entao a pose pendurada veio de `create_image_pro` com o idle como "character base" (4 candidatas, identidade intacta: `ato1/cursed_scarecrow_limp_stills.png`), gravada em `derived/cursed_scarecrow_limp.png` e usada como quadro 0 (`first="file:..."`): 3 quadros inerte de olhos apagados, cabeca sobe no 3, convulsao com palha nos 5-6, assenta no idle. Na cena (`screenshot_entradas ato1`) ele pende na frente do poste a esquerda da estrada e pula para o centro no assentamento |
| hollow_farmer | walk | ok | 1 | forcado baixa e arrasta no meio do clipe, volta a ficar em pe no fim |
| plague_rats | form | ok | 2 | 1a: rato brotava NO AR acima da pilha (quadros 1-2); 2a com "every rat touches the ground or another rat" |
| harvest_reaper | form | ok | 2 | 1a: ficava solido no quadro 2 e VOLTAVA a silhueta nos 6-7 (floreio da foice virou arco preto); 2a "brightens a little more in EVERY frame, body still" |
| blight_bull | charge | ok | 1 | galope com cabeca baixa; a derrapada e do motor (poeira) |
| wicker_effigy | awaken | ok | 2 | 1a: o corpo INTEIRO virou ouro brilhante nos quadros 2-7; 2a "the wicker stays dark brown wood, only the three fires and the eyes give light" |

### Ato 2
| criatura | clipe | veredito | tentativas | nota |
|---|---|---|---|---|
| moon_gargoyle | awaken | ok | 2 | 1a: "a cor volta" virou CICLO de cor (flash branco, roxo, gargula VERMELHA); 2a com "only from grey toward lavender and purple, never red, never cyan": cinza 4 quadros, roxo um pouco saturado nos 5-7, assenta no idle |
| ram_cultist | walk | fraco, usavel | 3 | a tunica esconde as pernas e o modelo quase nao mexe o corpo; a 3a ("EXAGGERATED... hem swinging wide, lifting to show a boot") vende o passo pela barra e pela faixa; o deslocamento e do motor |
| storm_harpy | swoop | ok | 1 | ciclo de asas limpo, pernas recolhidas, fecha no idle |
| storm_harpy | land | ok | 1 | 7 quadros: asas abrem alto, agacha, assenta |
| rune_golem | assemble | ok | 2 | 1a: entulho virava golem em UM quadro e as runas ficavam magenta no meio; 2a por etapas (pernas, torso, punhos, cabeca; runas so no fim) |
| spectral_knight | form | ok | 1 | solidifica em 0-4; depois ergue a espada que CLAREIA (branca) por 3 quadros: le como lampejo espectral, nao regerado |
| storm_griffin | swoop | ok | 1 | ciclo de asas com raios |
| storm_griffin | land | ok | 1 | as asas viram RAIO por 3 quadros no pouso (o "pousa com um trovao" do roteiro) e dobram de volta |

### Ato 3
| criatura | clipe | veredito | tentativas | nota |
|---|---|---|---|---|
| ember_imp | emerge | ok | 1 | so juba e ponta da cauda no fundo do canvas, salta, pausa no apice de garras abertas, pousa no idle |
| hellhound | charge | ok | 1 | ciclo de galope, cabecas baixas |
| abyss_acolyte | walk | ok | 1 | deslize: tunica e correntes balancam, grimorio sobe e flameja |
| obsidian_sentinel | awaken | ok | 2 | 1a: veios AMARELOS com estrela de desenho animado no elmo (quadros 2-4); 2a "black to dull red to orange, never yellow, no burst, no star" |
| pit_brute | emerge | ok | 1 | sobe dos chifres, ica-se, puxa o martelo e finca; o martelo entra pequeno no quadro 5 |
| abyss_watcher | form | ok | 1 | silhueta clareia, olhos abrem (piscam um pouco nos quadros 2-4), tentaculos ganham cor |

## Gasto e licoes (atos 1 a 3)
- 27 jobs de animacao (19 clipes + 8 retentativas) e 10 chamadas de `create_image_pro` (9 ancoras + 2 regeracoes "lines only" + 1 do plinto, menos a efigie derivada): ~55 geracoes das 450 da frente.
- O v3 respeita o pino do ultimo quadro: drift maximo 0,04 (gargula), nenhum clipe precisou de `best_of_3`.
- O que o modelo erra sozinho e previsivel: "cor voltando" vira ciclo de cor; "acende" vira corpo inteiro brilhando; "ergue a arma" vira flash branco; "monta" monta em um quadro; "entra" faz coisa brotar no ar. O prompt que funciona proibe pelo nome (never yellow, nothing floats, a little more in EVERY frame) e descreve etapas.
- Pose de partida que o idle nao alcanca (bracos erguidos, pendurado): o animador nao a inventa; gere a pose como still em `create_image_pro` com o idle de "character base" e anime still -> idle pinado.
- Tunica longa esconde o passo: walk de figura de tunica (cultista, acolito) sai como deslize; aceitar e deixar o deslocamento com o motor.
- Vista de ancora: "flat on the ground" sem "seen straight from the front" vira cubo isometrico; "burned into the ground" vira LAJE. Pedir "ONLY glowing lines, no ground, no slab" da a marca pronta para sobrepor na estrada.
- Dois processos gravando o mesmo `anchor_jobs.json` perdem job (corrida): enfileirar ancoras de UM processo por vez.

## Rodada 2: naturalidade dos que andam (dono: "os que vem andando tem que ficar mais naturais... abusar do pixel art")
Os seis clipes de movimento foram REGERADOS a 12 quadros (13 instalados, ultimo = idle 0) com prompt de "duas passadas completas" + movimento secundario nomeado (pe sobe e planta, peso muda de lado, barra/corrente/palha/chama/vapor), ainda `animate_image` (o esqueleto nao foi preciso: com 12 quadros e passada descrita o v3 mexe as pernas). v1 de 8 quadros guardado em `atoN/tries/<id>_<clip>_v1/`.
| clipe | antes (8q) | depois (12q) |
|---|---|---|
| hollow_farmer/walk | forcado baixa e sobe, pernas quase paradas | joelho sobe e pe planta alternando, corpo afunda na perna manca, forcado arrasta no chao (4-7) e finca, avental e mangas balancam |
| ram_cultist/walk | arrastado | procissao: barra da tunica abre e levanta mostrando a bota (4-7), faixa chicoteia, peso de um lado pro outro, turibulo em arco |
| abyss_acolyte/walk | deslize | barra abre mostrando o pe (3-6), correntes balancam, grimorio sobe e flameja no fim; o mais quieto dos tres (a arte nao tem perna) |
| blight_bull/charge | galope curto | duas passadas: dianteiras alcancam e batem, traseiras empurram, ombros sobem e descem, espigas e costelas chacoalham; freada no fim e sutil |
| hellhound/charge | ciclo curto | passada de salto completa (estica e junta), jubas esticadas com brasas brancas, veios pulsam |
| plague_rats/form | 3 ratos chegando | de 2 ratos no chao a pilha cheia, um rato novo sobe por quadro, tudo encostado, nada no ar |

Espantalho awaken v4 = DUAS ETAPAS (`stages cursed_scarecrow/awaken`): pendurado -> agachado (still `derived/cursed_scarecrow_crouch.png`, `create_image_pro` com o idle de character base, `ato1/cursed_scarecrow_crouch_stills.png`) em 6 quadros, agachado -> idle em 6; 13 quadros, drift 0,010: olhos acendem no 2, cai e crava as garras no chao (4-6), palha voando, levanta (7-11).
Gasto da rodada: 6 clipes x 2 geracoes (12q a ~100 px) + still do agachamento + 2 etapas = ~16; frente ~90 das 450.


# Atos 4 a 6 (frente entradas-arte-b, 22/Out/2026)

Fabrica propria: `python tools/pixellab_entradas_b.py run|run2|run3|poll|strip|install <id>/<clipe> <tentativa>|anchors|anchor_sheet|install_anchor <id> <tentativa> <idx>|status` (mesma estrutura; o lead funde depois). Jobs em `tools/preview_out/entradas_arte/jobs_b.json`, tentativas cruas em `raw_b/` (nao versionado), tiras 4x em `atoN/<id>_<clipe>.png` com UMA linha por tentativa (idle na primeira coluna, metricas no rotulo). Diferenca de contrato: aqui instala-se `retornados[1:N]` + idle 0 real = 8 quadros nos clipes de 8 e 6 nos curtos (`howl`, `land`); o quadro de entrada nao e instalado. **Revisao do dono (22/Out, 'os que vem andando tem que ficar mais naturais'):** os 8 clipes de movimento (walk x4, trot, crawl, hop, swoop) foram regerados a 12 quadros (`V4`, `run4`; `frame_count=12` funciona ate ~133 px de canvas) com duas passadas completas e movimento secundario (capa, pelo, cauda, chama); 7 instalados a 12q, o sapo ficou a 8q.

- `brotar`: quadro inicial = idle deslocado para baixo e cortado na borda (`start="down:0.9"`, fracao da altura do conteudo), ultimo pinado no idle. Funcionou de primeira nos 6 (troll 0.55, serpe 0.8, carnical 0.9, sanguessuga 0.9, mae dos esporos 0.6, servo da cova 0.9).
- `form`, `swoop`, `descend`, `howl`, `land`: inicio = idle, fim pinado. Funcionam.
- **Ciclos (`walk`, `trot`, `crawl`) nao aceitam o pino**: com o ultimo quadro pinado no idle o modelo quase nao mexe as pernas (`motion` 17 a 30 no xama, cavaleiro, bruxa, dullahan). Sem pino e com "exaggerated, high steps, body bobbing" os passos aparecem; o ultimo quadro instalado continua sendo o idle forcado, entao a parada e um passo para o idle em um quadro.
- Particula pedida no prompt vira borrao: a neve do espectro do gelo virou mancha branca e o bafo do uivo do lobo virou balao (tentativa 1). Regerado com "no cloud, no vapor, no particles"; particula e do motor.
- Ancoras: `create_image_pro` com referencia de estilo = props do bioma + a criatura lado a lado numa imagem so, luz do bioma (frost e marsh pela direita, dusk pela esquerda baixa), "no creature"; instaladas recortadas com alfa duro.

| criatura | clipe | veredito | tentativas | nota |
|---|---|---|---|---|
| frost_wight | form | ok, sutil | 2 | balanco e cintilar discretos; a opacidade e do motor |
| frost_wolf | trot | ok | 2 | 12q sem pino: duas passadas, patas alternam, pelo ondula, bafo em ritmo |
| frost_wolf | howl | ok | 2 | boca escancarada, cabeca pouco erguida |
| rime_shaman | walk | ok | 4 | 12q sem pino: passos com joelho, agacha e sobe, capa de pele atrasa |
| glacier_knight | walk | ok | 3 | 12q sem pino: pernas alternam de verdade, corpo cai no pisao, espada balanca |
| frost_troll | emerge | ok | 1 | sobe agachado da neve |
| ice_wyrm | emerge | ok | 1 | cabeca primeiro, lascas de gelo |
| bog_ghoul | emerge | ok | 1 | mao com torrao de lama antes do corpo |
| plague_toad | hop | fraco | 4 | 8q (2a tentativa): agacha e estica pouco, nunca sai do chao; a 4a (12q) virou lingua de gosma amarela e foi descartada. O canvas do idle tem 3 px acima da cabeca, nao ha espaco para salto dentro do quadro: o arco vertical tem de vir do motor (o EnemyRenderer desenha pelo canto superior com a escala do idle, quadro mais alto desalinha) |
| leech_horror | emerge | ok | 1 | |
| mire_hag | walk | ok | 3 | 12q sem pino: botas levantam, capa e aba do chapeu balancam; maos vazias (lampiao no prompt faria aparecer objeto que o idle nao tem) |
| croc_warrior | crawl | ok | 4 | 12q sem pino: espreita agachado com passos, cauda arrasta; 'water dripping' virou 3 pixels brancos soltos perto da cauda nos quadros 7 a 10 |
| spore_mother | emerge | ok | 1 | chapeu abre ao subir |
| dusk_shade | form | ok | 1 | chamas esticam e encolhem |
| dusk_bat | swoop | ok | 2 | 12q pinado: tres batidas, dobra as asas num mergulho inclinado e abre para frear |
| grave_thrall | emerge | ok | 1 | terra caindo |
| blood_duke | form | ok | 1 | floreio da capa, braco no rosto |
| dullahan | walk | ok | 4 | 12q sem pino: capa abre larga, passos visiveis, cabeca na mao sobe pouco |
| fallen_angel | descend | ok | 1 | asas dobram e abrem |
| fallen_angel | land | ok, sutil | 2 | asas sobem, joelhos dobram pouco |

Ancoras (`assets/sprites/world/anchors/`): frost_troll 110x59 monte de neve com pedras; ice_wyrm 104x34 lombada de neve rachada; bog_ghoul 82x29 lama com bolhas e osso; leech_horror 102x33 poca com pedras; spore_mother 102x67 moita de cogumelos; grave_thrall 87x40 terra revolvida com lapide; dusk_shade 71x28 poca de sombra com fios roxos.
