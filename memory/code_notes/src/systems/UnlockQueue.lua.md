---
name: code_notes/src/systems/UnlockQueue.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/UnlockQueue.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/UnlockQueue.lua`

Origem: `src/systems/UnlockQueue.lua` em `7dbdb60d` (4 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local ProfileStats = require("engine.ProfileStats")`)

> src/systems/UnlockQueue.lua
> FILA DE REVELAÇÕES do menu (Out/2026, pedido do dono: "igual ao Balatro:
> terminou a run e voltou pro menu, mostra tudo o que desbloqueou").
>
> Quem ENCHE a fila:
> * UnlockSystem.onRunEnded  → addRunResult(result): classes novas, cada
> nível de maestria seguido das cartas do pacote dele, as demais cartas
> liberadas e o Selo novo (vitória, derrota, abandono, endless — toda run
> termina por lá);
> * AchievementSystem.unlock → addAchievement(id), na hora em que acontece.
> Quem ESVAZIA: components/UnlockShowcase.lua, um painel por vez no menu.
>
> A fila mora no PERFIL (`pendingReveals`) e vai pro disco a cada mudança:
> fechar o jogo (ou ele cair) antes de ver as revelações não as perde — elas
> aparecem no próximo boot, quando o menu abrir.
>
> Item: { kind = "card"|"class"|"mastery"|"seal"|"achievement",
> id = <carta|classe|conquista>, classId = ..., level = n, n = selo }

## L24-25 (em `UnlockQueue`, junto a `UnlockQueue.MAX = 40`)

> Teto: uma fila de revelações não é histórico. Um perfil migrado (ou uma
> ferramenta que desbloqueia tudo) não pode empilhar 200 painéis.

## L44-45 (em `UnlockQueue.peek`, junto a `local function add(q, it)`)

> Acrescenta sem repetir (mesma carta liberada por dois caminhos, conquista
> que o teste desbloqueia duas vezes...). Não grava: quem chama decide.

## L89-91 (em `UnlockQueue.addAchievement`, junto a `function UnlockQueue.addRunResult(result)`)

> Resultado de UnlockSystem.onRunEnded → itens, na ordem em que se leem:
> classe nova (o maior evento), cada nível de maestria com as cartas do
> pacote dele logo atrás, as cartas restantes (marcos), o Selo novo.

