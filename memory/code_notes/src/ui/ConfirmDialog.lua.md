---
name: code_notes/src/ui/ConfirmDialog.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/ConfirmDialog.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/ConfirmDialog.lua`

Origem: `src/ui/ConfirmDialog.lua` em `7dbdb60d` (3 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-23 (junto a `local Button      = require("components.Button")`)

> src/ui/ConfirmDialog.lua
> Diálogo de confirmação MODAL e genérico (singleton).
>
> Nasceu do known_gaps 25: "Jogar" com uma corrida salva sobrescrevia o save
> sem perguntar — um clique distraído no menu apagava horas de run. O StS
> tem slot único também, mas CONFIRMA. Daí uma peça reutilizável em vez de
> outra confirmação embutida numa tela (a do PauseMenu é inline na row).
>
> Uso:
> ConfirmDialog.show({
> title   = I18n.t("confirm.new_run_title"),
> body    = I18n.t("confirm.new_run_body"),
> confirm = I18n.t("confirm.new_run_yes"),
> cancel  = I18n.t("common.back"),
> danger  = true,                 -- botão de confirmar vermelho
> onConfirm = function() ... end,
> onCancel  = function() ... end, -- opcional
> })
>
> É registrado no InputFocus (main.lua) como MODAL: engole mouse/teclado/
> roda e apaga o hover de trás. ESC = cancelar, ENTER = confirmar.
> Layout recalculado em show() e resize() (memory/resize_pattern.md) — a
> altura do painel vem do wrap REAL do corpo, nunca de constante.

## L103-104 (em `state.buttons`, junto a `local cancelBtn = Button:new(px + PAD, by, half, BTN_H,`)

> Cancelar à ESQUERDA, confirmar à direita (ação destrutiva longe do
> caminho natural do olho; ENTER confirma, ESC cancela).

## L123 (em `ConfirmDialog.hide`, junto a `local handle = { ownsNavigation = true }   -- navega sozinha (setas/Enter)`)

> Objeto registrável no InputFocus (precisa de métodos com ':').

