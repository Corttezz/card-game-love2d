---
name: STS TopBar & HUD
description: Anatomia completa da TopPanel do Slay the Spire (HP/gold/poções/relíquias/andar/botões) + painéis de combate (energia, pilhas, end turn) + sistema de tooltip. Blueprint pro redesign da nossa TopBar.
type: reference
---

# STS — TopPanel (barra superior) e HUD de combate

Fonte: `slay-the-spire-source/src/com/megacrit/cardcrawl/ui/panels/TopPanel.java` (1.110 linhas) + panels/ + core/OverlayMenu.java + helpers/TipHelper.java. Números em unidades ×`Settings.scale` (ref. 1920×1080).

## Layout da TopPanel (altura 128px, esquerda → direita)

```
[∞/chaves] Nome  Título   ♥ 68/75   ● 234   [poção][poção][poção]   piso 12   asc 15   (mods daily)      [mapa] [deck 24] [⚙]
[relíquia][relíquia][relíquia][relíquia]... (fileira abaixo, paginada)
```

1. **Ícone de modo** (x=46): Endless ou slots de chaves do Ato 4 (ruby/emerald/sapphire acendem conforme coletadas — objetivo de longo prazo SEMPRE visível).
2. **Nome + título** do personagem (panelNameFont 34pt branco + tipBodyFont 22pt cinza).
3. **HP**: ícone coração + `atual/max` em SALMON, topPanelInfoFont 26pt. Hover: escala 1.2, tooltip explicando HP. **PingHpEffect pulsa o coração quando HP < 25%** (TopPanel.java:268-277).
4. **Gold**: ícone moeda + valor em GOLD_COLOR. **O número ROLA até o valor real** (TopPanel.java:416-422): diff>99 → ±10/frame; diff>9 → ±3; senão ±1. Verde subindo, vermelho descendo. (Nossa TopBar já tem ease Balatro — manter; a lição extra é a cor direcional.)
5. **Poções** (x = gold+154): N slots SEMPRE visíveis (slot vazio = sprite próprio). Hover: escala 1.4 + SFX aleatório POTION_1/POTION_3 pitch var 0.1. Click abre **PotionPopUp** (usar/descartar; fora de combate "beber" só as permitidas). `flashRed()` 1s quando tenta pegar poção com slots cheios. Poção com alvo: **seta bezier de 20 segmentos** até o inimigo, igual mira de carta.
6. **Piso** (floor number, ícone próprio, CREAM_COLOR) — progresso sempre visível.
7. **Ascension** (se ativo): ícone + nível; **dourado no A20, vermelho abaixo** — flex visual.
8. **Mods do daily** (ícones 52px com tooltip cada).
9. **Direita** (3 botões 64px, espaçamento 10): **Mapa** (repouso inclinado -5°, hover 10°, ABERTO oscila seno ±15°), **Deck** (contagem de cartas sobreposta; mesmo wiggle quando aberto), **Settings** (engrenagem GIRA no hover até -90°, e roda contínuo 300°/s enquanto menu aberto). Hover em todos: blend additive (glow) + tooltip com hotkey ("Map (M)", "View Deck (D)").

## Fileira de relíquias (a "prateleira de build")

- Parte da TopPanel, linha própria abaixo: START_X=64, PAD_X=72 (ícones ~64 encostados), Y ≈ HEIGHT−100.
- `MAX_RELICS_PER_PAGE = WIDTH/75` (~25 em 1080p). Estourou → **setas de paginação** nas bordas (TopPanel.java:465-501, adjustRelicHbs recalcula hitboxes por página).
- Cada relíquia: hover→tooltip (nome+descrição via PowerTip), **counter numérico** quando tem contador interno (Pen Nib 9/10), **flash** quando triggera (feedback de "quem causou isso").
- Lição: relíquias são o "tabuleiro de sinergias" e ficam permanentemente visíveis+inspecionáveis. Nossos jokers no topo cumprem esse papel — a diferença é counter visível + flash on-trigger.

## Sistema de tooltip (TipHelper + PowerTip)

- `PowerTip {header, body, img}` — fila de tips renderizada em pilha vertical; passa de 70% da altura → nova coluna ±324px.
- Header colorido por tipo, body 22pt, box com sombra; **keywords dentro do body geram sub-tips automáticos** (dicionário GameDictionary — hover num power mostra o power E as keywords que ele menciona).
- Tudo é hitbox + tip: HP, gold, poções, piso, ascension, mods, botões (com hotkey), relíquias, powers, intents. **Nada na tela é mudo.**

## HUD de combate (OverlayMenu orquestra; ordem de render fixa)

EndTurn → Proceed → Cancel → Energy → DrawPile → DiscardPile → Exhaust → mão → tip da mão.

- **EnergyPanel** (x=198, y=190, esquerda): orb GRANDE com arte por classe + `atual/max`. Ao gastar/ganhar: `energyVfxTimer=2s` — 2 cópias do orb giram (30°/s) em blend additive + fontScale pula 2.0→1.0 lerp. Hitbox 120px com tooltip.
- **DrawPilePanel** (canto inf-esquerdo): ícone deck 128px com **BobEffect** (flutua) + círculo de contagem + nº (turnNumFont 32pt branco). Click abre view. Tooltip inclui hand size.
- **DiscardPilePanel** (canto inf-direito): idem, contagem em ROXO (Settings.PURPLE_COLOR), partículas de glow cíclicas.
- **ExhaustPanel** (acima do discard, x=WIDTH−70, y=184): SÓ APARECE quando exhaustPile>0; contagem roxa semitransparente + partícula de fumaça a cada 0.05s.
- **EndTurnButton** (x=1640, y=210): hitbox 230×110. Estados: enabled/disabled/**isGlowing** (pulso de glow a cada 1.2s) + **isWarning quando ainda há cartas jogáveis** (o botão avisa "tem mana sobrando"). Texto vira "ENEMY TURN" no turno inimigo. Console: long-press 0.4s com barra de progresso.
- Pilhas escondem deslizando pra FORA da tela (offsets −300/+WIDTH) em transições — nada some com pop.

## Cores/fontes canônicas

HP SALMON; gold #E0E000; piso CREAM #C5A86B; exhaust/discard PURPLE; energia #FFFFDC; disabled 0.7 cinza; glow additive branco. Fontes: nome 34pt, info 26pt, contagens 32pt bold, tooltip body 22pt.

## → Confronto com a nossa TopBar (components/TopBar.lua hoje)

Temos: ouro eased + juros preview, deck count + "(N na mão)", score + recorde, engrenagem com rotação hover, click deck→DeckViewer. **Não temos na barra**: HP (está no painel de baixo — ok, é escolha), **poções/consumíveis (não existem no jogo)**, **piso/ato sempre visível**, **fileira de relíquias/jokers com counter+flash** (jokers são cartas soltas no topo), **tooltips em TODOS os elementos** (só score tem), **botão mapa**, **ícones de modificadores ativos**. Sugestões priorizadas em [[STS Gap Analysis]]. Regra de ouro do StS pra copiar como filosofia: **todo elemento da barra é (a) sempre visível, (b) hover-explicável, (c) anima quando muda, (d) clicável se abre algo.**
