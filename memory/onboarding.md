---
name: Onboarding — dicas ancoradas, Guia de combos/glossário, tooltip da mana
description: Out/2026. Dicas de 1ª vez ancoradas no objeto (placa de pergaminho com seta, nunca rodapé), uma por vez, só com o combate parado, persistidas no perfil; Guia (tecla G / Pausa) gerado do ComboSystem e do glossário; tooltip no orbe de mana.
type: project
---

# Onboarding (Out/2026)

Auditoria de jogabilidade: nada ensinava mana, intent, "Jogar Cartas" ×
"Encerrar Turno", os combos (sem lista no jogo), coringas ativos × bancada,
orbes, Bloqueio que zera, o grimório de 2 cartas.

## Peças

| peça | arquivo |
|---|---|
| catálogo + ciclo das dicas | `src/systems/Tutorial.lua` (`TIPS`, `update`, `draw`, `overlay`) |
| placa (layout PURO + validate + draw) | `src/ui/TipPlate.lua` |
| âncoras | `Tutorial.anchor(id, x, y, w, h)` no draw de quem desenha o objeto (transformPoint → pixels reais): `HudManager` (mana, painel do herói, orbes), `EnemyHud.drawIntent` (intent), `GameplayScene._reportTutorialAnchors` (mão, JOGAR, ENCERRAR, coringas); telas de estado via `Tutorial.setScreens` (botões do evento/acampamento, slots da vitrine) |
| persistência | `ProfileStats.isTipSeen/markTipSeen/resetTips/tipsSeenCount` (grava na hora, SaveManager.writeFile) |
| liga/desliga, rever | Configurações → Jogo (`gameSettings.tipsEnabled`, "Rever as dicas") |
| Guia | `components/GuideScreen.lua` — abas Combos (ComboSystem.RULES + `DamagePreviewPanel.comboDescription` + cartas de exemplo) e Glossário (`src/data/keywords.lua`); tecla G na run, atalho "Guia [G]" na Pausa |
| tooltip da mana | `ManaOrb:draw` → `StatusTooltip.show("mana")` (`tutorial.status.mana`) |
| textos | `src/i18n/locales/tutorial/<loc>.lua` (`tutorial = require(...)` no locale) |
| trava | `tools/test_tutorial.lua`; capturas `TUT_TIP=<id> TUT_LOCALE=de ENEMY_SCENE_VIRTUAL=1920x1080 love . screenshot_enemy_scene 1_battle`, `TUT_TIP=event EVENT_ID=... love . screenshot_event de`, `love . test_one screenshot_guide de:1920x1080:2` |

## Regras

- Dica só com o combate PARADO (vez do jogador, fila vazia, mão na mesa) e
  depois de a condição valer por 0,35 s; uma por vez, 0,3 s de respiro.
- **Sem âncora visível, a dica ESPERA** — nunca aponta pro nada. Âncora some
  (troca de tela) → a dica fecha SEM marcar vista.
- A placa é o modal mais alto do `InputFocus` (`tutorialTip`, registrado por
  último): clique, Enter/Espaço/A e Esc/B fecham; o combate congela por baixo.
- Zonas (`TipPlate.validate`): dentro da tela, nunca cobre o objeto nem a
  TopBar. `prefer` por dica escolhe o lado (o intent prefere o LADO — embaixo
  mora a barra de vida; evento/descanso/vitrine preferem embaixo das opções).
  Validado em 4 tamanhos × pt_BR/de no teste.
- Ferramentas (`_G.HEADLESS_TOOL`) não mostram dica nenhuma — capturas antigas
  continuam reprodutíveis; `Tutorial._show(id)` força pra captura/teste.
- Dica nova = entrada no `TIPS` + `tips.<id>` nos 5 locales + âncora reportada
  no draw do objeto.

Ver também: [[enemies]] (ícones de intent), [[ui_layout_invariants]],
[[combo_rules]].
