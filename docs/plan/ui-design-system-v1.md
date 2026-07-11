# Design System de UI — v1 (Jul/2026)

Origem: pedido do Daniel ("padronizar botões, nenhum texto escapando, visual mais agradável")
+ 3 auditorias completas (36 call-sites de Button, 12 botões caseiros, 10 pontos de overflow,
catálogo da linguagem visual). Este doc é a REFERÊNCIA: toda UI nova segue as regras daqui.

---

## 1. Idioma visual canônico: ESCURO-DOURADO (grimório dark)

O idioma da loja — o mais desenvolvido e o aprovado em playtest — é o padrão para
**modais e painéis de sistema**. Fonte única: **`src/ui/UiPanel.lua`**.

```
UiPanel.draw(x, y, w, h)                      -- painel principal
UiPanel.draw(x, y, w, h, { depth = "inner" }) -- subpainel
```

Gramática (não redesenhar na mão — usar o helper):
sombra INK (4,4 α0.45) → miolo `PANEL_FILL` ≈ {0.10,0.07,0.05} (Panel9 `panel_inner`
quando o asset existe) → outline `AGED_GOLD` lw3 → inner `AGED_GOLD_DARK` lw1 →
bevel topo → 4 cantos ornamentais `AGED_GOLD_LIGHT`.

Texto sobre painel escuro: título `AGED_GOLD_LIGHT` (com sombra ink), corpo
`PARCHMENT_LIGHT`, secundário `PARCHMENT`, perigo `BLOOD`/`BLOOD_LIGHT`, accent `RUST`.

**Quem já usa**: CardRewardScreen (loja/rewards), PauseMenu, e (procedural similar)
RoundEvalScreen. **Pergaminho-claro (`panel_main`)** continua nas telas "de mundo"
(Rest sobre a fogueira, DeckViewer, Event, Achievements, ClassSelection) — a migração
delas é decisão ESTÉTICA da fase 2 (ver §6), não técnica.

## 2. Texto NUNCA vaza: `src/ui/TextFit.lua`

Regra dura: **todo texto de UI dentro de largura fixa passa por TextFit ou por
`printf` com wrap + altura medida**. `love.graphics.print` cru de string i18n/concat
em container estreito é bug.

```
TextFit.print(label, x, y, { size = 12, maxW = colW })            -- shrink→ellipsis
TextFit.print(label, x, y, { size = 12, maxW = w, align = "center" })
local font, text = TextFit.fit(label, 12, maxW)                    -- forma manual
```

Mesma receita do Button (que também trunca com "..." desde esta entrega) e da HintBar.
Aplicado em: Collection tooltip (colunas dinâmicas), Achievements (name/desc),
SettingsMenu (labels), ClassSelection (nome/passiva), RoundEval (breakdown),
DeckViewer (counts), RestScreen (choice-card detail), PauseMenu (rowH dinâmico),
StatusTooltip (medição própria v2), TopBar (larguras medidas por locale).

## 3. Botões: SEMPRE `components/Button.lua`

- **Variantes**: `clean` (default — qualquer ação), `tv` (SÓ menu principal/idioma
  CRT-OSD), `invisible` (só hitbox sobre visual próprio — cartas, rows, choice-cards).
  `ornate` foi REMOVIDA (zero usos).
- **Rótulo**: SEMPRE `I18n.t(...)`. Rótulos genéricos em `common.*` (skip/back/take).
  Zero string PT hardcoded em botão (varrido nesta entrega: Pular/Voltar/PEGAR/RESGATAR).
- **Texto nunca vaza**: o componente encolhe a fonte até 8 e trunca com "..." — mas
  dimensione o botão pra caber o idioma mais longo (não confie na truncagem).
- **Cor semântica**: `setColorScheme("green")` = confirmar/comprar; `("red")` =
  cancelar/perigo; default dourado = ação neutra. O 7º arg `color` de `Button:new`
  é LEGADO INERTE — não passe (limpeza pendente nos 8 call-sites antigos).
- **Alturas de referência** (clusters reais do jogo): 32 compacto (settings/mini),
  42-46 ação padrão, 60 principal (menu/play). Larguras: dimensionar pelo texto do
  idioma mais longo + 24px de respiro.

## 4. Tipografia (Press Start 2P — assets/fonts/pixel.ttf)

Escala de facto (consolidada da auditoria — use estes degraus):
**8** micro · **9-10** caption/hint · **12** corpo · **14** corpo-forte/título de bloco ·
**16** subtítulo · **18-24** título de tela · **48** hero.
`Theme.Typography` é escala FANTASMA (ninguém usa) — não adotar; drenar Theme.lua (§6).

## 5. Cores: só via `Palette`

Tokens semânticos (Palette.lua:95-114) são a interface: `PANEL_FILL/OUTLINE/OUTLINE_INNER/
TEXT/TEXT_DIM`, `BUTTON_*`. Não hardcodar {0.10,0.07,0.05} inline (a auditoria achou
vários — os novos helpers centralizam). `SUCCESS/WARNING/ERROR/INFO` ainda apontam pro
neon legado — recalibrar pro grimório na fase 2.

## 6. Fase 2 (decisões estéticas — apresentar ao Daniel antes)

1. **Unificar telas pergaminho-claro?** Opção A: migrar Rest/Deck/Event/Achievements/
   ClassSelection pro escuro-dourado (1 idioma só). Opção B: manter claro como idioma
   de "telas de mundo" e escuro para "modais de sistema" (recomendada — contraste
   intencional), padronizando apenas tipografia/espagamentos.
2. **`panel_gold`**: gerar via PixelLab (spec já existe em Panel9.SPECS) pra momentos
   de celebração (victory, level-up de selo).
3. **Status colors grimório**: SUCCESS→MOSS claro, ERROR→BLOOD, WARNING→AGED_GOLD,
   INFO→STEEL_LIGHT.
4. **Drenar `src/Theme.lua`** (Typography/Gradients/Utils órfãos; Colors → Palette).
5. **Migrar release-handling caseiro** (RestScreen/PauseMenu/EventScreen varrem
   `b.hover` no mousereleased) pra delegação `btn:mousepressed/mousereleased` (usa
   pressed/onePress do widget).
6. **Prefixo "PASSIVA:" hardcoded** na ClassSelection → i18n `class_select.passive_label`.
7. Moldura pixel-art dedicada pro PauseMenu (PixelLab), se o Daniel quiser identidade
   própria além do UiPanel.

## 7. Checklist pra UI nova (colar em PR/memória)

- [ ] Painel → `UiPanel.draw` (ou Panel9 `panel_main` se tela de mundo)
- [ ] Botão → `Button` com variant certa + rótulo i18n + largura pro idioma mais longo
- [ ] Todo texto em largura fixa → `TextFit` ou `printf` medido
- [ ] Cores → tokens `Palette`
- [ ] Fontes → degraus da escala (§4)
- [ ] Testou com locale DE (o mais largo)?
