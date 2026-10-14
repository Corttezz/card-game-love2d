---
name: code_notes/tools/screenshot_class_select.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_class_select.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_class_select.lua`

Origem: `tools/screenshot_class_select.lua` em `7dbdb60d` (3 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-21 (junto a `local M = {}`)

> tools/screenshot_class_select.lua
> Seleção de classe v4 ("página do grimório", Out/2026 — memory/class_emblems.md).
> Renderiza cada estado num CANVAS do tamanho pedido com a janela
> FALSIFICADA (getWidth/getHeight) — setMode repetido dentro de tool trava
> (memory/ui_layout_invariants.md). Passa pelo UiScale de verdade (a tela é
> adotada no love.load). Gera, no save dir:
> class_select_<W>x<H>_<estado>.png
> estados:
> fresh    — perfil novo: só o guerreiro liberado, foco nele
> locked   — perfil novo, foco no ladino bloqueado (silhueta + condição)
> all      — todas liberadas, foco no mago (resumo)
> details  — mago com o marcador DETALHES aberto
> starter_hover — carta inicial em hover (lift + tooltip ao lado)
> inspect  — a inspeção da Coleção aberta na carta inicial
> seal     — Selo 7, foco no guerreiro, mouse na faixa do selo (regra)
> seal_cap — Selo 7, foco no ladino que só vai até o 1 (aviso de teto)
> pick     — momento da escolha (anel + faíscas)
> denied   — clique em COMEÇAR numa bloqueada (tremor; NÃO inicia run)
> 1280x800 sai com o multiplicador do Steam Deck (125%), como no aparelho.
> CS_LOCALE=de troca o idioma; CS_SIZES=1024x768,1920x1080 filtra tamanhos.
> love . test_one screenshot_class_select

## L51-52 (em `hoverRect`, junto a `local function scenario(US, name)`)

> Cenários do UnlockSystem (monkeypatch das 3 funções do contrato — vale
> tanto pro stub quanto pra versão real da frente progressão).

## L116-117 (em `M._orig`, junto a `do`)

> TIRA DE ANIMAÇÃO: cada emblema em 8 instantes (0.15s) + versão
> acorrentada — valida o idle procedural sem precisar de vídeo.

