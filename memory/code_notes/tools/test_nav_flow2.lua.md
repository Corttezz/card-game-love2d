---
name: code_notes/tools/test_nav_flow2.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_nav_flow2.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_nav_flow2.lua`

Origem: `tools/test_nav_flow2.lua` em `7dbdb60d` (6 de 17 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local H = require("tools.test_nav_flow")`)

> tools/test_nav_flow2.lua
> 2º roteiro SÓ POR GAMEPAD (D-pad/A/B/Y/RB) — as telas que o 1º não passa:
> coleção (grade, rolagem, zoom) → conquistas → run → gerenciador de
> coringas (ativa/bancada) → deck pela TopBar → roteiro pela TopBar →
> vitória da luta → loja → PACOTE (compra, abre, escolhe) → batalha final
> → tela de VITÓRIA → endless.
>
> NAV_PART=2 love . nav_flow        (sai com 0/1; NAV_W/NAV_H/NAV_SHOTS)
>
> Cobre também: troca de Selo na seleção de classe (LB/RB) e a escolha de
> maldição do ciclo do endless.
> Trapaças declaradas (não são navegação): coleção toda revelada, coringa entregue, inimigo
> com 1 de vida, encruzilhadas forçadas (loja, batalha) e a batalha final
> marcada como chefe do último ato.

## L34-35 (em `M.script`, junto a `require("src.systems.UnlockSystem").setRevealAll(true)`)

> COLEÇÃO (trapaça declarada: todas as cartas "descobertas" — o perfil do
> tool nasce vazio e carta "?" não abre zoom)

## L47 (em `M.script`, junto a `check("coleção: D-pad volta à 1ª carta",`)

> volta pra 1ª carta (a inicial, sempre descoberta) e abre o zoom

## L194-195 (em `winTurn`, junto a `for _ = 1, 4 do`)

> A numa carta = prévia; A de novo na MESMA carta = escolhe (o pacote
> fecha). É o "clique de novo pra confirmar" do mouse, pelo pad.

## L241-242 (em `winTurn`, junto a `for _ = 1, 8 do`)

> tela final navega sozinha (MenuKit): 1º item = Endless. Ela segura a
> entrada enquanto a barra de maestria anima — A de novo se ignorado.

## L251-252 (em `winTurn`, junto a `for _ = 1, 30 do`)

> MALDIÇÃO DO CICLO (endless): cash out → espólio → a encruzilhada abre
> a escolha obrigatória; D-pad até a 2ª maldição, A escolhe

