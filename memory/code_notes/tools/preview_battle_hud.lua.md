---
name: code_notes/tools/preview_battle_hud.lua
description: Comentários com decisão/regra/histórico colhidos de tools/preview_battle_hud.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/preview_battle_hud.lua`

Origem: `tools/preview_battle_hud.lua` em `7dbdb60d` (16 de 33 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-19 (junto a `local M = {}`)

> tools/preview_battle_hud.lua
> Renderiza um frame simulado de batalha pra validar o novo HUD visual.
> Usar: love . preview_battle_hud → saída em ~/.local/share/love/card-game/preview_battle_hud.png
>
> MODOS:
> (sem arg) HUD em repouso    →  preview_battle_hud.png
> cap       Bloqueio no teto  →  preview_battle_hud.png
> orb       CANALIZAÇÃO em voo + orbe SAINDO por overflow, no meio da
> animação → preview_battle_hud_orb.png. É o único caminho visual
> pro pedido "deixar claro se está dando dano ou canalizando":
> mostra o cometa do elemento ENTRANDO na fileira e o fantasma do
> orbe expulso SAINDO dela, ao mesmo tempo, para comparar os dois
> sentidos num quadro só.
> pulse     ONDE cada pulso de fim de turno ATERRISSA →
> preview_battle_hud_pulse.png. COMPOSIÇÃO deliberada: no jogo os
> três pulsos são beats sequenciais (0,40s cada), aqui os três
> caem no mesmo quadro de propósito, porque o que se valida é o
> LUGAR — raio no inimigo, gelo no painel do herói, sombra no
> próprio orbe. Um quadro por elemento não deixaria comparar.

## L40-42 (em `M.run`, junto a `local capMode = _G.PREVIEW_HUD_CAP`)

> Bloqueio: 7 por padrão. `love . preview_battle_hud cap` sobe pro TETO,
> que é o único jeito de ver o "/30" e o halo âmbar do cap (o indicador
> só aparece a partir de 70% — abaixo disso ele seria ruído).

## L52-54 (em `game.player.buffs`, junto a `game.jokerSlots = {`)

> Coringas ATIVOS: estados contínuos que vivem no joker e não no player.
> O PlayerBuffPills deriva pill+tooltip deles (regen/sangria/retenção/
> roubo de vida) — antes eram completamente invisíveis.

## L61-62 (em `game.jokerSlots`, junto a `game.player.orbs = {`)

> OrbRow (Jul/2026): 2 orbes + 1 slot vazio — valida numero com Foco,
> marcador FIFO e o aro apagado do cap.

## L67-68 (em `game.player.orbs`, junto a `local orbMode = _G.PREVIEW_HUD_ORB`)

> Modo `orb`: a fileira CHEIA é o estado que produz overflow — é nele que
> o jogador perde o fio ("um orbe sumiu e eu não vi por quê").

## L71-73 (em `game.player.orbs`, junto a `if _G.PREVIEW_HUD_ORBS then`)

> Modo `orbs`: os CINCO tipos lado a lado, no tamanho de uso e sobre o
> fundo real. E o unico jeito de saber se eles se distinguem ENTRE SI --
> um de cada vez, ampliado, engana (ui_layout_invariants / doutrina §5).

## L104-107 (em `game.enemy.statusEffects`, junto a `{ name = "burn",       stacks = 4, duration = 2 },`)

> QUEIMADURA ao lado do VENENO de proposito: os dois sao DoT e o
> defeito que criou este status foi justamente confundi-los. Validar
> lado a lado e a unica forma de saber se a distincao funciona
> (doutrina de defeitos, 5 e 7).

## L111-114 (em `game.enemy.statusEffects`, junto a `{ name = "fury",       stacks = 2, duration = 9 },`)

> FURIA e ENFURECIDO junto de propósito: com VULNERAVEL e QUEIMADURA
> sao QUATRO pills laranja na mesma row do inimigo. Se elas competirem,
> e aqui que se ve -- e o remedio e FORMA, nao matiz (laranja e a cor
> certa pra fogo e pra raiva; clarear troca identidade por metrica).

## L118-119 (em `game.enemy.statusEffects`, junto a `game.enemy.armor = 9`)

> Estados do inimigo que eram invisíveis: armadura (o dano sumia sem
> explicação) e o modo agressivo abaixo de 30% de vida (×1.5 de dano).

## L148-150 (em `bbox`, junto a `if _G.PREVIEW_HUD_ORBS_EVOKE then`)

> Mao FALSIFICADA com uma carta de Evocar sob o mouse: exercita o caminho
> REAL do preview (OrbRow.update le game.hand e acende previewMode), que e
> onde os numeros viram valor de EVOKE e o glifo da sombra vira DANO.

## L160-162 (em `effects`, junto a `local PlayerBuffPills = require("src.ui.PlayerBuffPills")`)

> Hover FALSIFICADO sobre a pill de Espinhos: exercita o caminho REAL
> (StatusPill.drawRow detecta o hover → StatusTooltip.show → draw), então
> a captura também prova que o tooltip do estado novo resolve no i18n.

## L176-179 (em `love.mouse.getPosition`, junto a `if _G.PREVIEW_HUD_ORBS_EVOKE then`)

> OrbRow.update ZERA previewMode e so o preenche se receber `game` -- e o
> hud:update acima roda sem ele. Entao o preview tem que ser armado DEPOIS,
> imediatamente antes do draw (mesma ordem do jogo real, onde a cena passa
> o game nos dois).

## L187-191 (em `love.mouse.getPosition`, junto a `if orbMode then`)

> ===== Modo `orb`: captura a ANIMAÇÃO, não o repouso =====
> O primeiro hud:draw acima existe pra popular OrbRow.slotPos (as
> notificações ancoram no slot e sem posição não desenham nada). Só então
> disparamos os dois acontecimentos e adiantamos o relógio até o meio do
> voo, para o quadro mostrar o gesto e não o resultado.

## L216-222 (em `love.mouse.getPosition`, junto a `if _G.PREVIEW_HUD_ORBS_ANIM then`)

> ===== Modo `orbs anim`: a fileira VIVA, com as gemas fora de fase =====
> A gema tem um loop idle sutilíssimo (assets/sprites/orbs_anim/) e cada
> slot corre com fase própria. Num quadro parado isso é justamente o que dá
> pra provar: se as cinco pedras estivessem em sincronia, a faixa de luz
> estaria no mesmo lugar nas cinco; aqui ela está num ponto diferente em
> cada uma. Adiantamos meio ciclo pra pegar a faixa no meio da travessia,
> em vez do quadro de repouso (que é, por construção, a arte de hoje).

## L237-240 (em `love.mouse.getPosition`, junto a `if pulseMode then`)

> ===== Modo `pulse`: onde cada pulso deixa marca =====
> O primeiro hud:draw acima existe pra popular OrbRow.slotPos (o burst de
> sombra ancora no orbe). Disparamos as três aterrissagens direto pelo
> EffectSystem (mesma função que o beat chama) e adiantamos as partículas.

## L247-254 (em `love.mouse.getPosition`, junto a `local CF = require("src.systems.CardFeel")`)

> Âncora do inimigo FALSIFICADA (mesmo idioma do hover falso de mouse
> acima): o estado fake não tem sprite, então EnemyRenderer.getLastPos
> devolve nil e o burst no inimigo — justamente o que se quer ver —
> nunca sairia. Emprestamos o centro que a própria ferramenta usou pro
> placeholder, e o caminho REAL de landPulse roda inteiro.
> As particulas sao pequenas (1-3px) de proposito: e a mesma linguagem
> do impacto de carta. Entao a ferramenta tambem IMPRIME onde cada
> burst nasceu — a captura confirma o gesto, o texto confirma o LUGAR.

