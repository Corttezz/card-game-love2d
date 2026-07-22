---
name: EventManager — regra das filas (base é do COMBATE)
description: Lição do bug "cartas invisíveis até o hover" (Jul/2026) — parallel/parallelEase são blockable e ficam presos atrás do rabo bloqueante do combate na fila base. TODA tela/overlay que anima via EventManager DEVE usar fila própria.
type: project
---

# EventManager: filas, blocking e a REGRA DE OURO

## Semântica (engine/EventManager.lua + Event.lua)
- Filas nomeadas; `"base"` é a default de `add/after/ease/parallel/parallelEase`.
- `Event.blocking` default **true** (`EM.after`/`EM.ease` BLOQUEIAM a fila).
- `Event.blockable` default **true** — vale TAMBÉM pros helpers `parallel*`
  (eles só setam `blocking=false`). Ou seja: um "parallel" NÃO roda enquanto
  houver um evento bloqueante NA FRENTE dele na mesma fila.

## O bug que fixou a regra (Jul/2026)
"Cartas invisíveis na tela de espólios até passar o mouse": o `show()` da
CardRewardScreen agendava entrada/materialize com `parallel*` na fila **base**
— a MESMA onde Game/CombatSequence agendam o rabo da batalha (morte do
inimigo, shakes, transições) com `EM.after` (bloqueante). As animações da
tela ficavam PRESAS atrás disso e só rodavam quando a base destravava,
segundos depois (o jogador percebia "no hover"). Piloto do fix definitivo:
**fila dedicada `reward_fx`**, limpa a cada `show()`.

## REGRA DE OURO
- A fila `"base"` pertence ao FLUXO DE COMBATE/jogo. Nenhuma tela/overlay
  deve agendar animação nela.
- Toda tela que anima via EventManager usa FILA PRÓPRIA (`"boot"`,
  `"menu_intro"`, `"reward_fx"`, `"shop_select"`, `"shop_hover"`,
  `"shop_fly"`...) e dá `EventManager.clear(fila)` no show/abertura.
- Eventos zumbis de aberturas anteriores: além do clear no show, callbacks
  com efeito de fluxo (fechar tela, avançar estado) DEVEM guardar
  (`if self.visible then ...`).

## Lição irmã: Card:draw MUTA self.x/y — layout precisa de âncora imutável
O bug REAL das "cartas invisíveis até o hover" (diagnosticado por log em jogo
real, Jul/2026) nem era fila: `Card:draw(x, y)` GRAVA `self.x/self.y = x/y`.
A CardRewardScreen desenhava `draw(inst.x, inst.y + _entryOy)` → **feedback
loop**: `y += entryOy` a cada FRAME (−70/frame) até as cartas estabilizarem em
y≈−1900 (fora da tela). Hover "consertava" porque caminhos de draw do hover
reancoravam. **Regra**: em telas que aplicam offset de animação por cima da
posição, a base do draw é uma ÂNCORA IMUTÁVEL (`inst.homeX/homeY`), nunca
`inst.x/y`. E o simulador de validação DEVE chamar `screen:draw()` por frame
— draw muta estado; só update não reproduz feedback loops de draw (foi assim
que o bug passou batido 2×).

## Pegadinha remanescente (conhecida, aceitável)
`Card:start_materialize/start_dissolve` agendam o ease do `dissolve` como
evento BLOQUEANTE na base (dentro de Card.lua, via `em.add(ev:new{...})` sem
blocking=false e sem fila). Logo após combate eles podem atrasar. Nos
espólios não dependemos mais deles (entrada = queda `_entryOy` na `reward_fx`
com dissolve=0); se outra tela precisar, passar a fila/blocking no Card ou
aceitar o atraso.
