---
name: code_notes/src/systems/MusicDirector.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/MusicDirector.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/MusicDirector.lua`

Origem: `src/systems/MusicDirector.lua` em `7dbdb60d` (17 de 19 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local Sfx = require("src.systems.Sfx")`)

> src/systems/MusicDirector.lua
> Escolhe QUAL faixa toca, a partir do estado do jogo.
>
> Desenho deliberado: o diretor **observa** o estado a cada frame em vez de
> ser avisado pelas telas. Notificar exigiria uma chamada em cada uma das ~14
> transições de `currentState` espalhadas pelo main.lua, e a transição que
> alguém esquecesse de instrumentar daria "música errada" — um defeito que
> não trava, não loga e só é percebido por quem estiver ouvindo. Observar é
> idempotente: `apply()` roda todo frame e o `playMusic` só age quando o
> código muda de verdade (`currentMusic == code` é no-op no AudioManager).
>
> Fallback: faixa ausente cai para a anterior da cadeia e, no limite, para
> `menuMusic` (audio/music.mp3), que sempre existe. Mesmo contrato dos SFX
> (memory/sfx_generation.md) — soltar o arquivo em audio/music/ basta.

## L20-24 (em `MusicDirector`, junto a `MusicDirector.TRACKS = {`)

> Faixas da trilha: código -> arquivo em audio/music/.
> Fonte ÚNICA. `registerTracks` carrega a partir daqui e `pick` devolve
> códigos daqui; `tools/test_music.lua` cruza as duas listas, de modo que um
> código digitado errado num dos lados falha na suíte em vez de virar
> "essa tela ficou muda" meses depois.

## L33-36 (em `MusicDirector.TRACKS`, junto a `musicBossEclipse = "music-boss-eclipse.mp3",`)

> chefe FINAL (Rainha do Eclipse): coral + órgão + sinos + taiko, só no
> SALÃO dela (entrada, luta, morte, cash out); os outros chefes seguem na
> `musicBoss`. Gerada em Out/2026 (frente rainha-eclipse) — ver
> memory/boss_cinematics.md e known_gaps §0b (free tier: regerar).

## L42-45 (em `MusicDirector.TRACKS`, junto a `function MusicDirector.registerTracks(audioSystem)`)

> Registro por SCAN (mesmo contrato dos SFX): o arquivo dita a existência, o
> código só declara. Faixa ausente não quebra nada — o fallback cobre.
> Volume 0.6 no registro porque as faixas já vêm niveladas por loudness
> (ver memory/music_generation.md); não calibrar por palpite no call site.

## L61-63 (em `MusicDirector.registerTracks`, junto a `local FADE_FAST = 1.2`)

> Tempo de cruzamento por tipo de troca. Entrar em combate corta mais rápido
> que sair dele: a tensão precisa chegar junto com o inimigo, e o alívio pode
> demorar.

## L95-98 (em `resolve`, junto a `MusicDirector.FINAL_BOSS_ID = "eclipse_queen"`)

> O chefe final tem faixa própria, e SÓ dentro do salão dele: na caminhada
> até o castelo toca o tema comum de chefe; quando a porta abre
> (GameplayScene.inBossRoom) a faixa da rainha entra com o PRESSENTIMENTO
> da cinemática e segue pela luta, morte e cash out (roundEval devolve nil).

## L110-112 (em `isFinalBoss`, junto a `function MusicDirector.pick(state, run, nodeType, inHall)`)

> Deriva o código da faixa a partir de (estado da tela, run corrente).
> Pública para que os testes possam exercitar a decisão sem áudio nenhum.
> `inHall` = a cena está DENTRO do salão do chefe (porta já aberta).

## L121-123 (em `MusicDirector.pick`, junto a `return (nodeType == "shop") and "musicShop" or nil`)

> O mesmo state serve recompensa de batalha E loja; só a loja tem
> tema próprio. Sem a distinção, a recompensa pós-luta trocaria de
> música por 4 segundos e voltaria — pior que não trocar.

## L126-129 (em `MusicDirector.pick`, junto a `if state == "roundEval" then return nil end`)

> Cash out = pausa dentro da luta que acabou de acabar: mantém o que
> toca. No chefe isso é o tema do chefe seguindo pelo salão (cash out e
> espólios acontecem DENTRO dele, Out/2026); a faixa do ato novo só entra
> na encruzilhada, quando o nó é deixado.

## L139-142 (em `MusicDirector.pick`, junto a `local act = (run and run.actNumber) or 1`)

> Uma faixa por ato. O `resolve` cuida do resto: enquanto o mp3 de um ato
> não existe, a cadeia de FALLBACK desce pro ato anterior — soltar o
> arquivo em audio/music/ liga a faixa sem tocar em código. Em endless o
> ato passa de TotalActs e trava na última faixa da campanha.

## L150-153 (em `MusicDirector.pick`, junto a `local function tocandoAgora()`)

> Chamado todo frame pelo main.lua. `nil` de `pick` significa "mantenha o que
> está tocando" (ex.: recompensa pós-batalha, que é uma pausa dentro do ato).
> O que o AudioManager REALMENTE está tocando. Fonte da verdade — ver o
> comentário em `apply`.

## L159-160 (em `tocandoAgora`, junto a `MusicDirector.hallProbe = nil`)

> Está no salão do chefe? Pergunta à cena (GameplayScene.inBossRoom), que o
> main.lua já carregou; `hallProbe` é substituível (testes sem cena).

## L182-193 (em `MusicDirector.apply`, junto a `local atual = tocandoAgora() or MusicDirector._current`)

> COMPARA COM O QUE TOCA DE VERDADE, não com a variável própria.
>
> `_current` é um espelho, e espelho sai de sincronia: qualquer caminho
> que chame `Sfx.playMusic` direto (o menu faz), um `markCurrent` no
> momento errado, ou um play que falhou, e o diretor passa a acreditar
> que já está tocando a faixa certa — então nunca mais troca. O sintoma
> é exatamente "abro o jogo, clico em Continuar e a música do menu
> continua" (dono, Set/2026): o diretor pede a faixa do ato UMA vez, algo
> desencontra o espelho, e a partir dali ele acha que não há nada a fazer.
>
> Perguntando ao AudioManager, a decisão passa a ser tomada sobre o
> estado real e o espelho vira só cache.

## L196-200 (em `MusicDirector.apply`, junto a `if wanted ~= MusicDirector._lastWanted then`)

> DIAGNOSTICO: loga toda vez que a INTENCAO muda, mesmo quando nao ha
> troca. Sem isto, "a musica nao trocou" nao deixa rastro nenhum — o log
> de troca so aparece quando ela acontece, e o caso que interessa e
> justamente o contrario. Dispara no maximo uma vez por mudanca de
> contexto, entao nao vira ruido.

## L213-221 (em `MusicDirector.apply`, junto a `local saindoDoMenu = (atual == "menuMusic" and code ~= "menuMusic")`)

> CHEGAR corta rapido; ASSENTAR corta devagar.
>
> Entrar no chefe ja usava o corte rapido (a tensao tem que chegar junto
> com o inimigo). SAIR DO MENU PRA RUN e a mesma coisa e estava no corte
> lento: o jogador clica em Continuar, a cena do ato ja esta na tela, e a
> musica do menu ainda ocupava 2,5s de cruzamento. Foi metade da queixa
> "ainda tocando a musica do menu depois que clico em continuar" (a outra
> metade era o menu estar 2,9 dB mais alto que todas as outras faixas —
> ver o registro em main.lua).

## L225-226 (em `MusicDirector.apply`, junto a `print(string.format("[Musica] %s -> %s (estado=%s, no=%s)",`)

> Log de troca: sem isto, "a música está errada" não tem como ser
> diagnosticado a não ser adivinhando (foi o que aconteceu).

## L234-235 (em `MusicDirector.apply`, junto a `function MusicDirector.markCurrent(code)`)

> O menu chama isto ao terminar o splash; deixa o diretor em dia para não
> recomeçar a música na primeira passada do update.

