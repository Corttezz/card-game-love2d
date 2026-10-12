---
name: Navegação por teclado e gamepad (NavCursor)
description: Out/2026 — cursor de foco em todas as telas (meta Steam Deck): alvos registrados no draw, foco = hover, clique sintético, ações de contexto com glifo no botão; telas com navegação própria; fluxo de run inteiro só por pad (love . nav_flow); armadilhas.
type: project
---

# Navegação por teclado e gamepad (Out/2026)

`src/ui/NavCursor.lua`. Em vez de ensinar cada tela a navegar, o cursor se
apoia no que elas já fazem: hover por POLLING e clique por
mousepressed/released.

## Como funciona
- **Alvos**: quem desenha algo clicável chama `NavCursor.target(key, x,y,w,h)`
  no draw. `Button:draw` (inclusive o invisível) e `Card:draw` já registram.
  O retângulo vira PIXELS DA TELA na hora (transformPoint + scissor ×k), e
  leva a camada corrente do InputFocus: só valem os da camada com foco.
  Chave estável: o próprio objeto ou uma string ("deck:3", "fork:2").
- **Foco = hover**: no modo teclado/pad, `InputFocus.setPositionOverride`
  faz o "mouse" morar no centro do foco (Card mira o terço de baixo — a
  carta sobe no hover e o ponto continua na caixa de repouso).
- **Entrada**: setas/D-pad/analógico = vizinho espacial (desvio lateral
  pesa 2x; nada na direção → rola a tela via wheelmoved); Enter/Espaço/A =
  clique sintético no foco (o MESMO love.mousepressed/released, sem a lente
  do CRT: `NavCursor.synthesizing`); gatilho/I = clique direito
  (inspecionar); B/Esc = Esc; X/Q, Y/E, LB/Z, RB/C = ações de contexto que
  a tela publica com `NavCursor.action(botão, fn, rect)` — glifo no canto do
  botão (A/B/X/Y no pad, tecla no teclado). Sem rodapé. LB/RB sem ação
  percorrem o GRUPO do foco (a mão: `card.navGroup = "hand"`).
- **Convivência**: mexer o mouse desliga o modo; a 1ª tecla só mostra o
  anel (partindo do que estava sob o mouse). Foco automático evita a barra
  do topo (camada chrome); Enter nela só depois de andar até lá.
- **Telas que navegam sozinhas** (`ownsNavigation` no objeto/classe, ou
  `NavCursor.STATE_OWNS`): pausa, configurações, confirmação, dados do
  escriba, fim de jogo, conquistas, zoom da coleção. Recebem as teclas como
  antes; no pad o main traduz botão → tecla pra elas.

## Tela nova
Algo clicável que não é Button/Card → `NavCursor.target` no draw com o
MESMO retângulo do hit-test. Tooltip por hover → também (foco = hover).
Ação principal da tela → `NavCursor.action("x"/"y", ...)` com o rect do
botão. Navegação própria → `ownsNavigation = true`.

## Testes
`test_navcursor` (test_all) e `love . nav_flow` — o jogo de verdade, run
inteira sem mouse: menu → classe → batalha (RB/A/Y) → cash out → espólio →
encruzilhada → loja (compra) → descanso → evento → pausa → configurações,
conferindo que o foco nunca sai da tela. `NAV_W/NAV_H` (um setMode no
início) e `NAV_SHOTS=1` geram `nav_<cena>_<W>x<H>.png`. O fluxo espera
TEMPO (`sleep`), não quadros: sem vsync o tool roda a centenas de fps.

## Armadilhas achadas
- Função ADOTADA pelo UiScale chamada dentro de `UiScale.outside` reabria o
  contexto (o mundo da encruzilhada desenhava ×k em 1080p+ e o clique não
  acertava os marcos — nem com mouse). `outside` agora suspende a adoção.
- Botão que surge depois de uma animação (Resgatar do cash out): o foco
  automático caía na TopBar e o Enter abria o deck. Regra: foco automático
  na chrome cede ao conteúdo quando ele aparece.

**Why:** Steam Deck Verified exige jogar tudo sem mouse; reescrever 20
telas teria 20 jeitos de errar. **How to apply:** ver "Tela nova".
