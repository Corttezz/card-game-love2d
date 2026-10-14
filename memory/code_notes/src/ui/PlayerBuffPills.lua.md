---
name: code_notes/src/ui/PlayerBuffPills.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/PlayerBuffPills.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/PlayerBuffPills.lua`

Origem: `src/ui/PlayerBuffPills.lua` em `7dbdb60d` (15 de 20 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-22 (junto a `local StatusPill = require("src.ui.StatusPill")`)

> src/ui/PlayerBuffPills.lua
> Row horizontal de pills mostrando os estados ativos do jogador.
> Delega renderização pro StatusPill (mesmo componente usado por EnemyHud).
>
> Fontes de dado:
> player.strength   (int) — pill só aparece se > 0
> player.dexterity  (int) — idem
> player.buffs      (tabela {name, duration, stacks}) — focus, thorn, ...
> game.jokerSlots   (DERIVADOS) — efeitos contínuos que vivem no joker e não
> no player, mas mudam a regra da batalha inteira
> (reflexo, cura/dano por turno, Bloqueio retido).
>
> POR QUE OS DERIVADOS (Set/2026, pedido do dono sobre "Barreira de Fogo"):
> reflexo de dano, regeneração, sangria e retenção de Bloqueio decidem o turno
> do jogador e não apareciam em LUGAR NENHUM — só no texto da carta que já
> saiu da mão. Agora todo estado que altera regra tem pill + tooltip.
>
> LAYOUT POR ZONAS (memory/ui_layout_invariants.md §1): esta row ocupa uma
> BANDA de altura fixa (BAND_HEIGHT) logo acima do HudPlayerPanel. Quando há
> pills demais quem cede é a ESCALA das pills — a banda nunca cresce nem
> quebra linha, então o OrbRow (banda de cima) nunca é invadido. O OrbRow lê
> BAND_HEIGHT/BAND_GAP daqui em vez de repetir números mágicos.

## L32 (em `PlayerBuffPills`, junto a `PlayerBuffPills.BAND_HEIGHT = BADGE_SIZE`)

> Contrato de zona lido pelo OrbRow.

## L36-38 (em `PlayerBuffPills`, junto a `local PERMANENT_THRESHOLD = 90`)

> Buff com duração >= isto é, na prática, "a batalha inteira" (o código usa 99
> pra focus e afins). Mostrar "dura 99 turnos" é um dado falso com cara de
> verdade — estes viram a variante `desc_permanent` no tooltip.

## L41-45 (em `PlayerBuffPills`, junto a `local JOKER_DERIVED = {`)

> Efeito de joker ativo → nome da pill.
> `on_defend_damage` NÃO entra aqui de propósito: desde Set/2026 o reflexo é um
> ESTADO ARMADO — a carta/joker chama player:addBuff("thorn", 1, v) e o dano só
> sai quando o inimigo bate. O buff já representa o total (carta + joker), então
> derivar do joker TAMBÉM contaria o mesmo reflexo duas vezes na pill.

## L58 (em `HAS_PERMANENT_DESC`, junto a `local ORDER = {`)

> Ordem canônica: pill não dança de lugar entre frames.

## L62-63 (em `ORDER`, junto a `"weak_self", "frail", "vulnerable_self", "poison_self", "burn_self",`)

> Debuffs do inimigo (Out/2026) depois dos buffs: o que te ajuda primeiro,
> o que te atrapalha no fim da row.

## L67-68 (em `ORDER`, junto a `local DEBUFF_PILL = {`)

> Debuff do jogador (player.debuffs) → pill. Sufixo _self: o tooltip fala com
> o jogador ("seus ataques causam 25% menos"), não com o alvo genérico.

## L87-89 (em `PlayerBuffPills:update`, junto a `function PlayerBuffPills.collect(player, game)`)

> Coleta a lista unificada de estados visíveis do player.
> Exposta (não-local) porque o teste tools/test_status_pills.lua audita esta
> lista sem desenhar nada.

## L122-123 (em `e`, junto a `for _, d in ipairs(player.debuffs or {}) do`)

> Debuffs aplicados pelo inimigo (golpes do kit). Duração é a real: o
> decremento acontece no fim do turno do inimigo (Player:decayDebuffs).

## L137-138 (em `e`, junto a `for _, joker in ipairs((game and game.jokerSlots) or {}) do`)

> Derivados dos coringas ATIVOS (jokerSlots = só os ativos; bancada não
> conta, ver memory/jokers_and_hand_layout.md).

## L176-177 (em `PlayerBuffPills.getBandTop`, junto a `local function availableWidth(panelX)`)

> Largura disponível pra banda: do painel até a metade da tela. O resto da
> faixa é do ManaOrb (canto inf-direito) e das cartas da mão.

## L182 (em `availableWidth`, junto a `function PlayerBuffPills.getPillSize(count, panelX)`)

> Tamanho efetivo das pills neste frame (encolhe só quando não cabe).

## L194-195 (em `PlayerBuffPills:draw`, junto a `local y = PlayerBuffPills.getBandTop(panelY) + (PlayerBuffPills.BAND_HEIGHT - size)`)

> Pill encolhida fica ancorada no RODAPÉ da banda: o TOPO da banda é fixo,
> que é o que o OrbRow usa pra não colidir.

## L202 (em `PlayerBuffPills:draw`, junto a `pulseHalo = true,`)

> buffs pulsam pra chamar atenção

## L205-206 (em `PlayerBuffPills:draw`, junto a `for i, b in ipairs(buffs) do`)

> Âncora do corvo (src/systems/Tutorial, conversa `focus` do mago): a
> pill de Foco, na mesma geometria que o drawRow acabou de usar.

