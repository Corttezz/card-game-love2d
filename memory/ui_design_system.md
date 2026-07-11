---
name: UI Design System
description: Regras canônicas de UI (Jul/2026) — UiPanel (painel escuro-dourado), TextFit (texto nunca vaza), Button (variantes/i18n/alturas), escala tipográfica, tokens Palette. LER ANTES de criar/editar qualquer tela.
type: project
---

# UI Design System (v1 — Jul/2026)

Doc completo: `docs/plan/ui-design-system-v1.md`. Origem: auditoria de 36 call-sites de
Button + 12 botões caseiros + 10 overflows reais + catálogo visual.

## Regras duras

1. **Painel de sistema/modal** → `src/ui/UiPanel.lua` (`UiPanel.draw(x,y,w,h)` /
   `{depth="inner"}`). É o idioma escuro-dourado da loja (sombra + PANEL_FILL +
   dual-border dourada + cantos ornamentais). NÃO redesenhar essa gramática na mão —
   CardRewardScreen._drawPanel e PauseMenu já delegam pra cá.
2. **Texto em largura fixa** → `src/ui/TextFit.lua` (`TextFit.print(text, x, y,
   {size=, maxW=, align=})` — shrink até 8 e trunca com "..."), OU `printf` com wrap
   e altura medida. `print` cru de i18n/concat em container estreito é BUG (foi a
   fonte dos 10 overflows do playtest Jul/2026).
3. **Botão** → `components/Button.lua`. Variantes: `clean` (default), `tv` (SÓ menu
   principal), `invisible` (hitbox sobre visual próprio). `ornate` foi REMOVIDA.
   Rótulo SEMPRE i18n (genéricos em `common.skip/back/take`). O Button também
   trunca com "..." na fonte mínima — mas dimensione pro idioma mais longo (DE).
   7º arg `color` de Button:new é inerte (legado) — não usar.
4. **Cores** → tokens `Palette` (PANEL_*, BUTTON_*, AGED_GOLD*, PARCHMENT*, BLOOD,
   RUST). Nada de {0.10,0.07,0.05} inline.
5. **Fontes** (Press Start 2P): 8 micro · 9-10 caption · 12 corpo · 14 corpo-forte ·
   16 subtítulo · 18-24 título · 48 hero. `Theme.Typography` é fantasma — não usar.

## Dois idiomas visuais (intencional por ora)

- **Escuro-dourado** (UiPanel): loja, rewards, pause, round-eval → modais de sistema.
- **Pergaminho-claro** (Panel9 `panel_main`): rest, deck viewer, event, achievements,
  class selection → telas "de mundo". Unificar ou não é decisão de fase 2 com o Daniel
  (doc §6) — não migrar por conta própria.

## Onde o overflow foi corrigido (não regredir)

Collection tooltip (colunas dinâmicas), Achievements name/desc, SettingsMenu labels,
ClassSelection nome/passiva, RoundEval breakdown, DeckViewer counts, RestScreen
choice-card detail, TopBar (larguras medidas por locale + ICON_W 50), PauseMenu
(rowH dinâmico por wrap), StatusTooltip (medição própria + letter spacing),
Button/HintBar (fit+ellipsis). Teste manual: trocar idioma pra DE e passar por
todas as telas.

**Why:** playtest Jul/2026 — textos vazavam de botões/painéis em vários idiomas e
cada tela inventava seu botão/painel. **How to apply:** checklist do doc §7 antes de
qualquer tela nova; ao tocar em tela antiga com print cru, migrar pro TextFit.
