---
name: code_notes/components/PauseMenu.lua
description: Comentários com decisão/regra/histórico colhidos de components/PauseMenu.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/PauseMenu.lua`

Origem: `components/PauseMenu.lua` em `7dbdb60d` (23 de 45 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-26 (junto a `local FontManager = require("src.ui.FontManager")`)

> components/PauseMenu.lua
> Menu de pausa (engrenagem da TopBar / ESC) — padrão Slay the Spire +
> estrutura do create_UIBox_options do Balatro (seed visível, atalhos, ação
> primária no topo).
>
> v4 (Out/2026 — dono: "muita coisinha", feio). Hierarquia de StS/Balatro:
> poucas coisas, grandes e legíveis, véu escuro atrás.
> • ZONAS fixas (memory/ui_layout_invariants.md §1), de cima pra baixo:
> CABEÇALHO  título com filetes
> RESUMO     "classe · jornada" + semente miúda (vida/ouro/baralho
> saíram: a TopBar já mostra)
> ATALHOS    três ícones — Baralho [D] · Coringas [J] · Roteiro [M]
> AÇÕES      Continuar (PRIMÁRIA) · Configurações · Salvar e sair —
> placas centradas, sem descrição
> PERIGO     "Abandonar" como link discreto; armado, vira pergunta +
> Sim/Não no mesmo lugar (2 etapas, foco no Não)
> Sem rodapé de dica (regra do projeto). Quando falta altura quem CEDE é
> o conteúdo (placas mais baixas, depois somem atalhos e semente) —
> nunca a posição das zonas. `validate()` roda no test_pause_menu.
> • Navegação por teclado/gamepad (src/ui/MenuKit.lua): setas/WASD, Enter,
> ESC; foco começa em Continuar.
> • Entrada animada (painel cai no lugar + véu), som de hover/clique.
>
> Overlay modal global: main.lua instancia, injeta callbacks via
> show(game, callbacks) e roteia update/draw/input. _G.togglePauseMenu abre/
> fecha de qualquer lugar. Registrado no InputFocus como "pause".

## L42 (em `PauseMenu`, junto a `local PAD          = 22     -- respiro interno do painel`)

> Métricas (px). Alturas de texto são MEDIDAS em cima destas.

## L66 (em `instance.confirmButtons`, junto a `instance.confirmButtons = {}`)

> Sim/Não do abandono

## L111-114 (em `hasRun`, junto a `function PauseMenu:runSummary()`)

> ===================================================================
> RESUMO DA RUN — dados puros (testável sem desenhar)
> ===================================================================
> Retorna lista de células {label, value} na ordem de leitura (2 linhas × 3).

## L154-156 (em `PauseMenu:runSummary`, junto a `local function actionDefs(self, runActive)`)

> ===================================================================
> LAYOUT
> ===================================================================

## L198 (em `open`, junto a `{ key = "guide",   hotkey = "g", icon = "question", label = I18n.t("tutorial.guide.pause_shortcut"),`)

> Guia de combos + glossário (onboarding, Out/2026)

## L204-205 (em `open`, junto a `function PauseMenu:rebuild()`)

> Monta zonas, rows, atalhos e linhas de navegação. Idempotente: roda em
> show/resize/confirmação/troca de idioma.

## L211-212 (em `PauseMenu:rebuild`, junto a `local u = 1`)

> Escala: mora no UiScale (espaço virtual ~1280x720, scale(k) no
> desenho). Aqui é 1:1; S() fica pra um ajuste fino futuro.

## L228 (em `S`, junto a `local qFont = FontManager.getFont(S(11))`)

> Pedido de confirmação do abandono: pergunta quebrada + Sim/Não.

## L234-235 (em `S`, junto a `local modes = {`)

> Modos em ordem de preferência: quem cede é o CONTEÚDO (altura das
> placas, depois os atalhos, depois a semente) — nunca a ordem das zonas.

## L268-269 (em `zones.info`, junto a `if runActive and chosen.shortcuts then`)

> ATALHOS: três placas de ícone (os MESMOS ícones dos blocos da TopBar
> que eles abrem), rótulo curto embaixo. Centradas, largura contida.

## L306-307 (em `row`, junto a `if dangerDef then`)

> PERIGO: "Abandonar" é um link discreto no pé do painel; armado, vira
> a pergunta + Sim/Não no MESMO lugar (o resto do painel não mexe).

## L339 (em `self.confirmButtons`, junto a `self.lines = {}`)

> Linhas de navegação (ordem visual, de cima pra baixo).

## L371-372 (em `PauseMenu:resize`, junto a `function PauseMenu:validate()`)

> Checagem geométrica das zonas (usada pelo test_pause_menu). Lista de
> problemas; vazia = layout válido.

## L416-418 (em `r`, junto a `function PauseMenu:_clampFocus()`)

> ===================================================================
> FOCO / NAVEGAÇÃO
> ===================================================================

## L484-486 (em `PauseMenu:disarmAbandon`, junto a `function PauseMenu:update(dt)`)

> ===================================================================
> UPDATE / INPUT
> ===================================================================

## L494-495 (em `PauseMenu:update`, junto a `local mx, my = love.mouse.getPosition()`)

> Mouse MEXEU → o foco segue o mouse. Mouse parado não rouba o foco do
> teclado (quem navega nas setas com o cursor esquecido sobre uma row).

## L506-507 (em `PauseMenu:update`, junto a `if it.rect.btn and it.rect.btn.variant == "invisible" then`)

> Rows de ação usam Button invisível (mudo): o som
> de hover sai daqui. Atalhos/confirmação já tocam.

## L536-537 (em `PauseMenu:mousereleased`, junto a `if it and it == self._pressed and it.action then`)

> Só ativa se o PRESS também nasceu neste item (o release do clique que
> ABRIU a pausa pela engrenagem não dispara nada por acidente).

## L572-575 (em `PauseMenu:keypressed`, junto a `local function S(self, v) return math.floor(v * (self._u or 1) + 0.5) end`)

> ===================================================================
> DRAW
> ===================================================================
> Métrica escalada pelo fator do último rebuild (fonte e respiro do desenho).

## L578-579 (em `S`, junto a `function PauseMenu:_drawInfo(z)`)

> Uma linha "classe · jornada" e a semente miúda embaixo. Vida/ouro/baralho
> NÃO entram: a TopBar já mostra, e repetir é ruído (v3 tinha 6 células).

## L598-599 (em `PauseMenu:_drawInfo`, junto a `function PauseMenu:_drawShortcut(s, focused)`)

> Placa de atalho: ícone grande + rótulo curto. Sem moldura em repouso
> (respiro separa); focada ganha a placa escura e o rótulo acende.

## L622-623 (em `icon`, junto a `local label = s.label`)

> rótulo apertado (4 atalhos em painel estreito, Steam Deck): sai o
> "[J]" antes de virar "Coringa..." — a tecla é atalho, o nome é a info

