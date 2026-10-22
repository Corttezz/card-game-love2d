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
| obsidian_sentinel | ver tabela do ato 3 | plinto | 1a leva: 16 cubos isometricos minusculos (o modelo ignorou a vista), reescrito "wide low front-facing slab" |

## Resultado por criatura

### Ato 1 (commit do ato)
| criatura | clipe | veredito | tentativas | nota |
|---|---|---|---|---|
| cursed_scarecrow | awaken | ok, sutil | 1 | arranca-se com um pulo pequeno (quadro 5), palha voando; a amplitude e modesta, o motor soma o deslocamento |
| hollow_farmer | walk | ok | 1 | forcado baixa e arrasta no meio do clipe, volta a ficar em pe no fim |
| plague_rats | form | ok | 2 | 1a: rato brotava NO AR acima da pilha (quadros 1-2); 2a com "every rat touches the ground or another rat" |
| harvest_reaper | form | ok | 2 | 1a: ficava solido no quadro 2 e VOLTAVA a silhueta nos 6-7 (floreio da foice virou arco preto); 2a "brightens a little more in EVERY frame, body still" |
| blight_bull | charge | ok | 1 | galope com cabeca baixa; a derrapada e do motor (poeira) |
| wicker_effigy | awaken | ok | 2 | 1a: o corpo INTEIRO virou ouro brilhante nos quadros 2-7; 2a "the wicker stays dark brown wood, only the three fires and the eyes give light" |

# Atos 4 a 6 (frente entradas-arte-b, 22/Out/2026)

Fabrica propria: `python tools/pixellab_entradas_b.py run|run2|run3|poll|strip|install <id>/<clipe> <tentativa>|anchors|anchor_sheet|install_anchor <id> <tentativa> <idx>|status` (mesma estrutura; o lead funde depois). Jobs em `tools/preview_out/entradas_arte/jobs_b.json`, tentativas cruas em `raw_b/` (nao versionado), tiras 4x em `atoN/<id>_<clipe>.png` com UMA linha por tentativa (idle na primeira coluna, metricas no rotulo). Diferenca de contrato: aqui instala-se `retornados[1:N]` + idle 0 real = 8 quadros nos clipes de 8 e 6 nos curtos (`howl`, `land`); o quadro de entrada nao e instalado.

- `brotar`: quadro inicial = idle deslocado para baixo e cortado na borda (`start="down:0.9"`, fracao da altura do conteudo), ultimo pinado no idle. Funcionou de primeira nos 6 (troll 0.55, serpe 0.8, carnical 0.9, sanguessuga 0.9, mae dos esporos 0.6, servo da cova 0.9).
- `form`, `swoop`, `descend`, `howl`, `land`: inicio = idle, fim pinado. Funcionam.
- **Ciclos (`walk`, `trot`, `crawl`) nao aceitam o pino**: com o ultimo quadro pinado no idle o modelo quase nao mexe as pernas (`motion` 17 a 30 no xama, cavaleiro, bruxa, dullahan). Sem pino e com "exaggerated, high steps, body bobbing" os passos aparecem; o ultimo quadro instalado continua sendo o idle forcado, entao a parada e um passo para o idle em um quadro.
- Particula pedida no prompt vira borrao: a neve do espectro do gelo virou mancha branca e o bafo do uivo do lobo virou balao (tentativa 1). Regerado com "no cloud, no vapor, no particles"; particula e do motor.
- Ancoras: `create_image_pro` com referencia de estilo = props do bioma + a criatura lado a lado numa imagem so, luz do bioma (frost e marsh pela direita, dusk pela esquerda baixa), "no creature"; instaladas recortadas com alfa duro.

| criatura | clipe | veredito | tentativas | nota |
|---|---|---|---|---|
| frost_wight | form | ok, sutil | 2 | balanco e cintilar discretos; a opacidade e do motor |
| frost_wolf | trot | ok | 1 | trote em diagonal, cabeca baixa |
| frost_wolf | howl | ok | 2 | boca escancarada, cabeca pouco erguida |
| rime_shaman | walk | ok | 2 | sem pino |
| glacier_knight | walk | ok | 2 | sem pino, espada balanca com o passo |
| frost_troll | emerge | ok | 1 | sobe agachado da neve |
| ice_wyrm | emerge | ok | 1 | cabeca primeiro, lascas de gelo |
| bog_ghoul | emerge | ok | 1 | mao com torrao de lama antes do corpo |
| plague_toad | hop | fraco | 3 | agacha e estica pouco, nunca sai do chao: o arco do salto tem de vir do motor |
| leech_horror | emerge | ok | 1 | |
| mire_hag | walk | ok | 2 | sem pino, capa balanca |
| croc_warrior | crawl | ok | 2 | espreita agachado, cauda varre |
| spore_mother | emerge | ok | 1 | chapeu abre ao subir |
| dusk_shade | form | ok | 1 | chamas esticam e encolhem |
| dusk_bat | swoop | ok | 1 | batida alta das asas |
| grave_thrall | emerge | ok | 1 | terra caindo |
| blood_duke | form | ok | 1 | floreio da capa, braco no rosto |
| dullahan | walk | ok | 3 | sem pino |
| fallen_angel | descend | ok | 1 | asas dobram e abrem |
| fallen_angel | land | ok, sutil | 2 | asas sobem, joelhos dobram pouco |

Ancoras (`assets/sprites/world/anchors/`): frost_troll 110x59 monte de neve com pedras; ice_wyrm 104x34 lombada de neve rachada; bog_ghoul 82x29 lama com bolhas e osso; leech_horror 102x33 poca com pedras; spore_mother 102x67 moita de cogumelos; grave_thrall 87x40 terra revolvida com lapide; dusk_shade 71x28 poca de sombra com fios roxos.
