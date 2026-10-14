---
name: code_notes/tools/test_pause_menu.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_pause_menu.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_pause_menu.lua`

Origem: `tools/test_pause_menu.lua` em `7dbdb60d` (5 de 28 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-23 (junto a `local TK = require("tools.testkit")`)

> tools/test_pause_menu.lua
> Trava do MENU DE PAUSA v3 + CONFIGURAÇÕES v3 (Out/2026).
>
> O que garante:
> 1. pausa abre/fecha (ESC, Enter em Continuar, clique) e o foco nasce em
> Continuar; clique só dispara se o PRESS nasceu no mesmo item;
> 2. abandono exige 2 etapas, foco cai no "Não" (default seguro), ESC
> desarma sem fechar, e só "Sim" chama onAbandon (uma vez);
> 3. atalhos D/J/M fecham a pausa e abrem a tela certa;
> 4. Configurações: abas, ←/→ ajusta, Enter alterna, tudo PERSISTE em disco
> (SaveManager) e no runtime (_G.gameSettings, CombatBeats.speed);
> VOLTAR chama onClose (a pausa se reabre) e ESC também;
> 5. RESIZE com janela falsificada (memory/ui_layout_invariants.md §2 —
> "nascer grande ≠ crescer"): validate() sem violação em 7 tamanhos,
> nos estados normal / confirmando / cada aba, em pt_BR e DE;
> 6. as chaves novas existem nos 5 locales.
>
> Efeitos colaterais isolados: settings.tool.lua é restaurado byte a byte,
> locale/CombatBeats.speed/gameSettings voltam ao que eram, e a janela/vsync
> reais nunca são tocados (stubs).
>
> love . test_one test_pause_menu
> love . test_all

## L41 (em `restoreWindow`, junto a `local function resizeTo(screens, w, h)`)

> Espelha o love.resize real: limpa fontes ANTES de avisar a tela.

## L151 (em `callbacks`, junto a `pause:show(game, callbacks)`)

> ===== 2. abandono em 2 etapas =====

## L180 (em `callbacks`, junto a `local noRun = PauseMenu:new()`)

> sem run: sem atalhos, sem abandono, resumo vazio

## L312-313 (em `sizes`, junto a `do`)

> o validate() ENXERGA sobreposição (teste do teste: um validador
> que nunca acusa nada passaria em qualquer layout quebrado)

