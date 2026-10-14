---
name: shadow_engine
description: ShadowEngine — sombras projetadas de silhueta (direção pelo sol, comprimento pelo horário, fila pós-grama) e, desde a v9, PEGADA — objeto baixo e largo (fogueira, baú, pedra, cadáver) projeta só o que sobe da pegada, nunca uma cópia inteira no chão
type: project
---

# ShadowEngine — sombras projetadas (Jul/2026) + pegada (v9, Out/2026)

**Pedido original:** "sombra projetada pra frente do monstro, na silhueta da
forma dele... árvores com sombra diferente por distância e iluminação. NÃO
mexer nas sombras das cartas."

## Técnica
Silhueta do PRÓPRIO sprite virada de cabeça pra baixo a partir dos pés
(`sy` negativo, pivô `oy=ih`), achatada e cisalhada — o sol dos biomas vive
no horizonte, então a sombra projeta pro PRIMEIRO PLANO:
- **comprimento** `len = 0.55 + 0.45·tod` (sol rasante no anoitecer = longa)
- **direção** ponta foge do sol POR COLUNA: `tipShift = (px−sunX)/(w/2)`
- **opacidade** `alpha = 0.15 + 0.15·luma` (luz difusa/escura = suave)
- **tamanho** ∝ escala do dono (perspectiva de graça)
Zero stencil/shader — só transform + tint. `engine/ShadowEngine.lua`.

## Sinais do cisalhamento (pegadinha!)
- `.sprite` (draw args, oy nos pés): ponta desloca `−kx·ih·s` → `kx = −shd·0.78`.
- `.silhouette` (emissão translate→shear→scale ⇒ no ponto o scale aplica
  ANTES): y já flipado → `kx = +shd·0.78`. Sinais OPOSTOS entre os caminhos.

## Fila pós-grama (interação com a REGRA DE PROFUNDIDADE)
Sombra imediata no slot do prop era COBERTA pelo tapete mais próximo
(campo 100% coberto = sombra invisível). Props usam `ShadowEngine.queue`;
`drawProps` chama `ShadowEngine.flush()` DEPOIS de props+grama — a sombra
escurece a grama em que cai (e o pé de quem estiver dentro dela, como
sombra real). Inimigo/encounter/landmarks desenham após o campo →
imediato (`.sprite`/`.silhouette`).

## v9 — PEGADA (Out/2026)

**Pedido do dono (com captura da fogueira do descanso):** "A fogueira é um
círculo, e a sombra é o círculo inteiro depois dela. Isso acontece com várias
coisas, inimigos vivos ou mortos, estruturas. Revisar TODAS as sombras e
empurrar um pouquinho mais pra dentro. As BANDEIRAS e as LOJAS estão
perfeitas: não mexa nelas."

**Causa (confirmada no motor):** `.sprite`/`.silhouette` viravam a silhueta
INTEIRA a partir do pé, tratando toda linha do sprite como ALTURA. Num
objeto baixo e largo a faixa de baixo do sprite é a PROFUNDIDADE da pegada
no chão (o anel de pedras visto de cima, a tampa do baú, a barriga do
cadáver), não altura — e a chama da fogueira (metade do sprite) nem corpo
é. Resultado: cópia inteira do objeto deitada à frente dele.

**Regra nova (no motor, por metadata — nunca if-por-nome):** `opts` ganha
um perfil de pegada, frações da ALTURA DO CONTEÚDO (`ih − footPad`):
- `baseK` — faixa de baixo que é pegada. A sombra nasce no CENTRO dela
  (`ay = feetY − baseK·H·s/2`), o pivô da virada sobe pro topo da pegada e
  a faixa da pegada NÃO projeta (recorte por `setScissor` no scratch ⅓,
  nada de quad por sprite). O que sobra cai em boa parte DENTRO da
  pegada; só uma orla sai pro lado oposto ao sol.
- `riseK` — fração acima da pegada que projeta. Fogueira: só as pedras.
  `0` = nada projeta (fissura de lava é decalque; `sprite` devolve `true`
  pra não cair na elipse de fallback).
- `lenK` — encurta (atarracado).
Sem perfil o caminho é o v8.4 **pixel a pixel** (trava no teste): árvore,
pinheiro, poste, placa, cerca, pilar, estandarte, loja, tenda, obelisco,
totem e criatura bípede em pé não mudam.

**Quem declara o quê:**
- Props e marcos: `WorldRoad.SHADOW_PROFILE` (campo de módulo — o arquivo
  está no teto de 200 locais), chave = tipo do prop (`rock`, `stump`,
  `bush`, `flowers`, `tuft`, `mushroom`, `crystal`, `fissure`) ou chave de
  marco (`landmark_chest`, `landmark_rest` + as 5 fogueiras por bioma,
  via `lmCfg`). Frações medidas no PNG (perfil de opacidade por linha).
  Vai por `shadowOpts(alphaK, flip, footPad, prof)`, pool por frame.
- Criaturas: `shadowBaseK` em `src/data/enemy_poses.lua` (ratos, touro,
  lobo, cão, grifo, sapo, wyrm, lodo, gárgula, imp, croc) e
  `EnemyRenderer.shadowProfile(pose, clip, alturaDoQuadro, alturaDoIdle)`
  (puro): `lenK = 1 − 1.2·baseK`; na **death** a altura do quadro cai e a
  pegada cresce junto — `lying = (1 − h/hIdle)/0.35` (o touro deitado ainda
  mede 70% do touro em pé), `baseK = max(pose, 0.55·lying)`,
  `lenK = min(., 1 − 0.35·lying)`. `clipMetrics.frameHeights[i]` (topo→chão
  por quadro, do mesmo scan dos `framePads`). O billboard da viagem leva
  `shadowBaseK/contentH` em `getEncounterBillboard`.
- Castelo mantém elipse direcional. Cartas: intocadas.

**Trava:** `love . test_one test_world_shadows` (registrado no `test_all`):
alto-fino/estandarte/loja/tenda idênticos a uma reimplementação do v8.4
byte a byte; baixo/largo nasce dentro da pegada, ≥ 70% dos pixels dentro
dela, orla abaixo do contato limitada; cadáver dos 3 tipos ≥ 70% dentro;
flutuante idêntico; fila = solo; decalque = 0 px. Capturas antes/depois
por caso: `love . test_one screenshot_sombras_mundo antes|depois` (+ par
`_ns` com o motor mudo, relógio constante → byte a byte comparável) e
pranchas em `tools/preview_out/sombras_mundo/`.

## Sombra de CONTATO × sombra de ALTURA (v1.1, Set/2026)

`silhouette` aceita `widthK` (estreita a silhueta), `lenK` e `alphaK`
(**só em chamada solo** — numa fila a cor é única por construção, que é o
que impede sombras cruzadas de escurecerem em dobro). `tipShiftAt(px)`
expõe a direção "pra longe do sol" pra quem precisa deslocar a própria
sombra.

Quem usa: criatura FLUTUANTE (`src/data/enemy_poses.lua`). A sombra dela
**não sobe com o corpo** — fica no chão, menor, mais fraca, mais borrada e
escorregada pro lado oposto à luz. É o vão entre corpo e sombra que diz
"isto está no ar"; elipse de contato colada embaixo de quem paira foi o
defeito reportado em Set/2026. Ver
[`memory/enemy_pose_and_scene_anchor.md`](enemy_pose_and_scene_anchor.md).

## Integrações
- `EnemyRenderer.draw`: silhueta do FRAME ATUAL da animação via
  `silhouette` (a sombra respira/ataca junto). `SpriteAnimation:draw`
  ignora setColor → passar o tint recebido. Interiores (sem frame do
  WorldRoad, staleness 0.1s) → fallback elipse legada.
- WorldRoad: `setFrame(sunX, w, tod, luma)` no draw; props/companheiras/
  cercas (queue), landmark/fork marks/encounter (sprite imediato).
- Quirk conhecido: `alphaK` em `.sprite` solo é ignorado (só `silhouette`
  seta `soloAlphaK`) — o fade dos marcos do fork não esmaece a sombra. Não
  é da v9; fica registrado.

## v8.1 (feedback)
- "Sem distorção, fiel demais; pode ser maior" → len 0.34-0.64 →
  **0.55-1.00** e shear 0.55 → **0.78** — a sombra estica de verdade.
- "Monstros muito à esquerda" (obsidian_sentinel, glacier_knight):
  NÃO era sombra — o crop de instalação usa a UNIÃO dos bboxes de todas
  as anims e a death caindo pro lado descentra o idle no canvas (medido:
  −19/−20/−10px). Fix: `contentOffsetX(id)` no EnemyRenderer — offset do
  centro do conteúdo do 1º frame idle (ImageData 1x, cache por id),
  aplicado no cx (sombra/HUD/emissivos seguem juntos). Checar SEMPRE
  centralização por CONTEÚDO ao instalar monstro novo.

## v8.3 / v8.4 (silhueta arredondada, cor única)
SMEAR de 3 passadas deslocadas (raio ∝ largura na tela, `iw·s·0.035`)
desenhadas OPACAS num canvas scratch ⅓-res com blend "lighten" (união
chapada) e compostas UMA vez em preto com o alpha do frame: borda
quantizada no pixel lógico, sombras cruzadas não escurecem em dobro.
`silhouette(feetX, feetY, opts, drawFn)` chama o drawFn 1× por passada.

## Custo
Bench 13.48ms/frame total da cena (luz+sombra+tapete somados; orçamento
16.6). `flush` ~0.4 ms. A fila REUSA as entradas entre frames
(`squeueN`) e o WorldRoad passa `opts` de um pool por frame — o motor lê
`opts` só no `flush` do MESMO frame; não guarde referência além dele.
v9: `test_perf_budget` inalterado (427 draw calls, 31 KB/quadro).
