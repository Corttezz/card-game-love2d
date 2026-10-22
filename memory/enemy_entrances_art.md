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
