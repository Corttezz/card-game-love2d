---
name: Dados do Escriba (mini-jogo de ouro da loja)
description: Out/2026 — aposta opcional na loja (2d6, Baixo/Sete/Alto, EV ~justo), uma jogada por visita, Rng "shop" + resultado no save no mesmo frame; onde mora a regra, a tela, a arte e as travas.
type: project
---

# Dados do Escriba (Out/2026)

Pedido do dono: "um mini-game de economia poderia ser interessante — precisa
de pixel art". Uma aposta OPCIONAL no rodapé da loja ("Dados do Escriba",
entre "Novas ofertas" e "Continuar").

## Regra (src/systems/ScribeDice.lua — lógica pura)

- Dois dados. Aposta: **Baixo** (soma 2-6, 15/36, paga ×2,5), **Sete**
  (6/36, ×6), **Alto** (8-12, 15/36, ×2,5). EV 1,04 / 1,00 / 1,04 — justo
  de propósito: a mesa vende VARIÂNCIA ("tenho $22, a bancada custa $30"),
  não renda. A chance exibida na ficha é CONTADA das 36 combinações.
- Fichas por ato: `{4, 8, 16} × (1 + 0,3×(ato-1))` arredondadas pra PAR
  (×2,5 sempre inteiro). A6 = 10/20/40. Números em `Config.Economy.DICE`.
- **Uma jogada por visita**: estado em `currentRun.scribeDice` com chave do
  nó (ato|andar|#mapHistory); resíduo de outro nó é descartado ao consultar.
- **Anti save-scum**: dados do stream `shop` do Rng; a tela grava o
  checkpoint (`game:checkpointRun`) no MESMO frame do lançamento, antes de
  a animação revelar a soma. Continuar mostra a mesa usada com a mesma soma.
- Não farmável: teto = nº de lojas da corrida × ficha maior do ato.

## Tela (components/ScribeDiceScreen.lua)

Modal registrado no InputFocus como `scribeDice` (main.lua: `_G.scribeDiceScreen`
/ `_G.openScribeDice(game, onClose)` — _G pelo teto de upvalues). Layout em
ZONAS puro (`layout(sw,sh)` + `validate`), recalculado por frame (resize de
graça); cresce em telas ≥1600×900. Teclado/gamepad via MenuKit (fileiras
apostas → fichas → ações). Rolagem 1,15s com faces cosméticas
(`love.math.random`, só visual) e três batidas `sceneWoodKnock`; vitória
`coinTotalThud`+`cashOutChime`, derrota `sceneStoneThud`. reducedMotion
pula o quique, não a informação.

## Arte

- `assets/sprites/minigame/dice_cup.png` — PixelLab `create_image_pro`, estilo
  de `vouchers/interest_cap.png` (tools/pixellab_scribe_dice.py gen/pick).
- `die_1..6.png` (22×22) — desenhados pixel a pixel pelo mesmo script
  (`faces`): a CONTAGEM de pips é a informação que decide a aposta e gerador
  de IA erra contagem.

## Travas e captura

- `love . test_one test_scribe_dice` (no test_all): odds/EV 0,9..1,1, fichas
  pares e crescentes, 1 jogada/loja, ouro cobrado/pago, determinismo por
  seed, save→load volta USADA com a mesma soma, layout em 6 tamanhos, tela
  headless.
- `love . screenshot_shop dice` (+ SHOP_W/H/LOCALE/SEED/TAG, SHOP_DICE_BET).

**Why:** mini-jogo de ouro sem odds claras ou repetível vira exploit ou
armadilha. **How to apply:** mexer em pagamento → rodar test_scribe_dice
(EV trava); nova mesa/jogo de azar → mesmo contrato (Rng da run + save no
frame do sorteio + limite por nó). Ver [[rng_and_offers]], [[balance_curves]].
