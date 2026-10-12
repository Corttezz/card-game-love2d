---
name: Escala global de UI (UiScale)
description: Out/2026 — telas de UI num espaço virtual ~1280x720 desenhado com scale(k); como adotar tela nova, armadilhas (scissor, fonte dpiscale, love.resize, tooltips/partículas), o que ainda é 1:1 (batalha) e como verificar.
type: project
---

# Escala global de UI (Out/2026)

Queixa (auditoria de UI): em 1080p pouco escalava, em 1440p nada — carta ~7%
da altura, texto ilegível, miniaturas de 60px numa estante vazia.

## Desenho

`src/ui/UiScale.lua`. Em vez de reescrever o layout de cada tela com um
fator, a tela roda num **contexto** em que:

- `love.graphics.getWidth/getHeight/getDimensions` = janela / k (virtual);
- `love.mouse.getPosition/getX/getY/setPosition` = mouse / k (o hover por
  polling de 40+ call sites funciona sem mudar nenhum);
- `setScissor/intersectScissor/getScissor` convertem pra pixels reais
  (scissor ignora transformação — a 1ª coisa que quebra em UI escalada);
- `love.graphics.push(); scale(k)` no desenho;
- `FontManager.getFont` cria a fonte com **dpiscale** = escala corrente
  (`UiScale.fontDpi`, lê o transform, degraus de 0.25): métricas lógicas
  iguais, glifo rasterizado no tamanho final → texto nítido.

`k = clamp(min(W/1280, H/720), 1, 2.5) × multiplicador`, em degraus de 1/4
(1366x768 → 1, 1080p → 1.5, 1440p → 2, 4K → 2.5). Multiplicador =
Configurações → Vídeo → "Escala da interface" (80/90/Auto/125/150%,
RELATIVO ao Auto — absoluto, 150% seria menor que o Auto em 4K),
`gameSettings.uiScale`, aplicado no boot por `SettingsMenu.applyRuntime`.

**Adoção**: `UiScale.adopt(Classe)` embrulha todo método — show/resize/
update/draw/input rodam no MESMO espaço (layout calculado no `show()`
chamado de fora do draw também). Chamada aninhada (depth>0) passa direto.
`mousepressed/released/moved` chamados de fora recebem x,y ÷ k. Lista em
`UiScale.SCREENS`/`MODULES`, adotada no começo do `love.load`
(`adoptDefaults`, antes dos tools). TopBar com predicado: escala fora de
`playing`.

## Batalha (adotada na 2ª leva, Out/2026)

`src.scenes.GameplayScene` é adotado (MODULES): mão, hover, tooltip ao
lado, HUD, prévia de dano, botões, quadro de coringas, toasts e TopBar
vivem no espaço da UI. O MUNDO (WorldRoad, salão do chefe, inimigo,
InteriorFX, SceneLayer) roda dentro de `UiScale.outside` com a janela real
— ele já escala sozinho (enemyScreenK/hallScreenK). Fronteiras:
- `syncBattleStage` mede o limite do palco na UI (mão) e passa × k pro
  `WorldRoad.battleRelFor`; o teto da mão no salão idem;
- o bbox do inimigo volta ÷ k pro `EnemyHud`/prévia;
- `EnemyRenderer.getLastPos()` devolve ÷ k (quem pergunta é texto
  flutuante/partícula, que desenham com a UI);
- `EventManager.update` roda no contexto (beats, compra, FX = lógica de UI);
  partículas/CoinBurst/FloatingText desenham no contexto em todo estado
  (menos boot). Por isso as moedas do cash-out saem do lugar certo.
`test_enemy_stage` cobre 1080p/1440p/4K com a escala ligada (régua em
pixels da tela). Captura: `love . test_one screenshot_uiscale_battle [loc]`.
**O inimigo é a estrela** (2ª rodada): com a mão a k cheio o palco
empurrava o inimigo estrada adentro (~14-17% da altura). Três alavancas:
- a MÃO cresce mais devagar que a UI: `handK = 1 + (k-1)·HAND_GROWTH(0.5)`
  (1.25 em 1080p, 1.5 em 1440p, 1.75 em 4K) — `GameplayScene.handScale()`
  devolve handK/k no espaço da UI; leque, faixa visível, lift e selecionada
  encolhem junto;
- `WorldRoad.enemyScreenK` v2: 1 até a área do 1024x768 (716px), +1.4x por
  área-base a mais, teto 2.6 (o billboard da viagem usa a mesma função);
- TETO DO HOVER: a carta levantada sobe só até o pé do inimigo (salão de
  laje baixa — lich do ato 2), mas sempre o bastante pra aparecer inteira.
Medido (bbox do sprite, inclui margem do canvas): estrada 20% (1024/1366,
inalterado) → 25.6% 1080p · 29.6% 1440p · 26.0% 4K; chefe 38-44% em todos.

## Armadilhas

- **`love.resize` de dentro de tela adotada**: o resize global recria
  canvases (CRT) e o layout da batalha com a janela REAL — use
  `UiScale.outside(love.resize, UiScale.realDimensions())` (Configurações
  fazem isso no fullscreen e na escala).
- **A lente do CRT** (`InputFocus.installMouseGate → screenToContent`) mede
  a janela: a leitura crua do mouse dentro do contexto restaura as
  dimensões reais durante a leitura.
- **Coisas desenhadas DEPOIS, fora do contexto**: `StatusTooltip` guarda o
  `k` de quem chamou `show`; partículas/CoinBurst/FloatingText desenham no
  espaço da tela quando o estado não é batalha/estrada (main.lua).
- **Canvas com `origin()`** (CardFrame, PixelCanvas) desenha 1:1 — a fonte
  sai com dpi 1 ali (o transform é a fonte da verdade).
- **Testes**: o testkit faz `UiScale.force(1)` (cliques injetados em
  coordenada de layout com janela falsa). `test_ui_scale` desliga, exercita
  o espaço escalado e restaura.
- **Erro dentro de método adotado**: o wrapper chama `reset()` e relança;
  `love.update/draw` também chamam `reset()` (higiene, como InputFocus).

## Verificar

`love . test_one test_ui_scale` · `love . test_one screenshot_uiscale
[loc[:tela]]` (5 tamanhos até 3840x2160, canvas com janela falsa, sem
setMode). Coleção "cartas por cima do cabeçalho": só aparece no
`screenshot_collection` (desenho direto no backbuffer da janela do tool,
scissor deslocado 80px); o mesmo frame em canvas no tamanho igual corta
no lugar certo.

**Why:** reescrever 20 telas com fator por tela teria 20 jeitos de errar e
deixaria a próxima tela nascer pequena. **How to apply:** tela nova de UI →
`UiScale.SCREENS`; nada de `newCanvas(getWidth())` pra coisa global dentro
de tela adotada; `love.resize` só via `UiScale.outside`.
