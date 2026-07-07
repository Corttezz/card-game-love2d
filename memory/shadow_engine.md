---
name: shadow_engine
description: ShadowEngine v1 — sombras projetadas de silhueta (substitui as elipses "círculo nos pés"); direção pelo sol do bioma, comprimento pelo horário, fila pós-grama
type: project
---

# ShadowEngine v1 — sombras projetadas (Jul/2026)

**Pedido:** "sombra projetada pra frente do monstro, na silhueta da forma
dele... árvores com sombra diferente por distância e iluminação. NÃO mexer
nas sombras das cartas."

## Técnica
Silhueta do PRÓPRIO sprite virada de cabeça pra baixo a partir dos pés
(`sy` negativo, pivô `oy=ih`), achatada e cisalhada — o sol dos biomas vive
no horizonte, então a sombra projeta pro PRIMEIRO PLANO:
- **comprimento** `len = 0.34 + 0.30·tod` (sol rasante no anoitecer = longa)
- **direção** ponta foge do sol POR COLUNA: `tipShift = (px−sunX)/(w/2)`
- **opacidade** `alpha = 0.15 + 0.15·luma` (luz difusa/escura = suave)
- **tamanho** ∝ escala do dono (perspectiva de graça)
Zero stencil/shader — só transform + tint. `engine/ShadowEngine.lua`.

## Sinais do cisalhamento (pegadinha!)
- `.sprite` (draw args, oy nos pés): ponta desloca `−kx·ih·s` → `kx = −shd·0.55`.
- `.begin` (emissão translate→shear→scale ⇒ no ponto o scale aplica ANTES):
  y já flipado → `kx = +shd·0.55`. Sinais OPOSTOS entre os dois caminhos.

## Fila pós-grama (interação com a REGRA DE PROFUNDIDADE)
Sombra imediata no slot do prop era COBERTA pelo tapete mais próximo
(campo 100% coberto = sombra invisível). Props usam `ShadowEngine.queue`;
`drawProps` chama `ShadowEngine.flush()` DEPOIS de props+grama — a sombra
escurece a grama em que cai (e o pé de quem estiver dentro dela, como
sombra real). Inimigo/encounter/landmarks desenham após o campo →
imediato (`.sprite`/`.begin`).

## Integrações
- `EnemyRenderer.draw`: silhueta do FRAME ATUAL da animação via
  `begin/finish` (a sombra respira/ataca junto). `SpriteAnimation:draw`
  ignora setColor → passar o tint devolvido pelo `begin`. Interiores
  (sem frame do WorldRoad, staleness 0.1s) → fallback elipse legada.
- WorldRoad: `setFrame(sunX, w, tod, luma)` no draw; props/companheiras/
  cercas (queue), landmark/fork marks/encounter (sprite imediato).
- Castelo mantém elipse direcional (projetar o sprite gigante da fachada
  cobriria o campo — backlog se pedirem).
- **Cartas: intocadas** (linguagem própria, aprovada).

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

## v8.3 (feedback: "silhueta ainda segue o corpo perfeito — arredonda")
SMEAR de 3 passadas deslocadas (raio ∝ largura na tela, `iw·s·0.035`)
com alpha por passada `1−(1−A)^(1/3)` — o centro sobreposto recompõe o
alpha alvo e a borda vira penumbra; dedos/palhas/detalhes se FUNDEM em
massas arredondadas. `begin/finish` virou `silhouette(feetX, feetY,
opts, drawFn)` — o motor chama o drawFn 1× por passada (anim do
inimigo idem). Custo: 3× draws de sombra (~300 draws/frame, trivial).

## Custo
Bench 13.48ms/frame total da cena (luz+sombra+tapete somados; orçamento
16.6 — margem ok mas ficar de olho ao adicionar camadas novas).
