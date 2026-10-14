---
name: code_notes/tools/test_music.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_music.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_music.lua`

Origem: `tools/test_music.lua` em `7dbdb60d` (13 de 31 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local TK = require("tools.testkit")`)

> tools/test_music.lua
> Testa a DECISÃO do MusicDirector — qual faixa cada contexto pede.
>
> Roda sem áudio: `pick()` é pura, não toca em `Sfx`. O que se protege aqui
> não é "a música tocou" (isso ninguém verifica em CI), é a REGRA — e a regra
> que mais corre risco é a do `cardReward`, que serve dois contextos
> diferentes com o mesmo state. Se alguém simplificar aquilo para "reward =
> musicShop", a recompensa pós-batalha passa a trocar de música por quatro
> segundos e voltar. Ninguém abre um bug com esse título.

## L20 (em `M.run`, junto a `for _, s in ipairs({ "boot", "menu", "classSelection", "collection",`)

> Telas fora da run: sempre o tema do menu.

## L32 (em `M.run`, junto a `t:eq("endless fica no tema do ultimo ato",`)

> Endless passa do ultimo ato e TRAVA na faixa dele (nao volta pro ato 1).

## L46-48 (em `M.run`, junto a `local rainha = { actNumber = Config.TotalActs, currentNode = { type = "boss", enemyId = "eclipse_queen" } }`)

> CHEFE FINAL (Rainha do Eclipse, Out/2026): faixa própria SÓ no salão
> dela — na caminhada até o castelo é o tema comum; os outros chefes
> nunca a pegam; cash out e espólios dentro do salão mantêm.

## L68 (em `rei`, junto a `t:eq("recompensa pos-batalha NAO troca de musica",`)

> A regra que este arquivo existe para proteger.

## L73-74 (em `rei`, junto a `t:eq("cash out pos-boss NAO troca de musica",`)

> Cash out no salão do chefe: o tema do chefe segue (o salão persiste até
> a encruzilhada); cash out comum também não troca.

## L80-83 (em `rei`, junto a `local produced = {}`)

> Todo código que `pick` pode devolver precisa existir de verdade: ou na
> tabela de faixas, ou como o `menuMusic` que o main.lua registra à parte.
> Um typo ("musicAct1" vs "musicact1") não trava nada em runtime — o
> `resolve` cai no fallback e a tela fica com a música do ato anterior.

## L92-93 (em `casos`, junto a `for a = 1, Config.TotalActs do`)

> Um caso de combate POR ATO: assim a varredura cresce junto com a
> campanha e uma faixa de ato novo nunca fica orfa por esquecimento.

## L111-112 (em `casos`, junto a `for code, file in pairs(MD.TRACKS) do`)

> Os arquivos precisam estar no disco. Ausência é legítima por contrato
> (o fallback cobre), mas no repo do jogo é regressão — alguém apagou.

## L118-123 (em `casos`, junto a `local AudioManager = require("engine.AudioManager")`)

> ===== SOBREPOSICAO DE FAIXAS (regressao Set/2026) =====
> O dono ouviu duas musicas juntas: "a musica da forja continuou a
> sobrepor a musica do ato". Causa: o crossfade e UM so; uma troca nova
> antes de a anterior terminar substituia o registro e a faixa que estava
> saindo nunca recebia stop(). A→B→C rapido deixava A e B tocando para
> sempre. Abrir a forja e fechar faz exatamente A→B→A em segundos.

## L159-169 (em `tocando`, junto a `for _, caso in ipairs({`)

> ===== O "CONTINUAR" (regressao Set/2026, reincidente) =====
> Dono: "ainda tocando a musica do menu dps que clico em continuar".
> O log dele mostra o diretor fazendo a coisa certa
> ("menuMusic -> musicAct3"), entao a suspeita nao e mais a DECISAO e
> sim a EXECUCAO: a faixa do menu tem que parar de verdade.
>
> Dois tempos de clique, porque sao caminhos DIFERENTES no playMusic:
> clicar depois do fade do menu terminar cai no ramo de crossfade
> normal; clicar EM CIMA do fade-in (from=nil) substitui um crossfade
> que ainda nao acabou — e foi assim que a faixa orfa nasceu da outra
> vez.

## L201-206 (em `tocando`, junto a `local AM = require("engine.AudioManager")`)

> ===== ESPELHO DESSINCRONIZADO (regressao Set/2026) =====
> "Abro o jogo, clico em continuar e a musica de fundo continua sendo a
> do menu." O diretor guardava `_current` como espelho do que tocava; se
> o espelho desencontrasse do AudioManager (o menu chama playMusic
> direto, e ha markCurrent), ele passava a achar que ja estava tocando a
> faixa certa e nunca mais trocava. Agora a decisao le o estado REAL.

## L224-225 (em `tocando`, junto a `MD.markCurrent("menuMusic")`)

> E o inverso: espelho dizendo "menu" com o ato ja tocando nao
> redispara a mesma faixa.

