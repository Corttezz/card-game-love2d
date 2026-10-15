---
name: cheat_mode
description: Modo cheat (love . cheat / jogar_cheat.bat) para ver o fluxo exato do jogo correndo por atos, nós, chefes e telas; painel F1, atalhos, save isolado, rush automático e a trava test_cheat_mode
type: reference
---

# Modo cheat (`love . cheat`)

Pedido do dono (Out/2026): abrir o JOGO NORMAL com botões que matam inimigo, pulam
caminhos e atos, para ver cada fluxo de verdade (cinemática de morte, troféu do
coringa do chefe, cash out, recompensa com revelação rara, encruzilhada, loja,
descanso, evento, porta do castelo, viagem pela estrada, vitória, endless, game over).

## Como abrir

- `jogar_cheat.bat` na raiz (mesmo padrão do `jogar.bat`) ou `love . cheat`.
- Só em DEV. Em RELEASE o `Release.filterArgs` zera os args e o `CheatMode.claimArgs`
  também descarta `cheat` sem ligar nada: o jogo abre normal.
- O arg `cheat` é consumido em `love.load` ANTES da decisão de ferramenta, então
  `_G.HEADLESS_TOOL` NÃO liga: janela grande, intro, menu, música, tudo como sempre.
  Erro no modo cheat mostra a tela de erro do jogo (o `Release.errorhandler` ignora o arg).

## Save isolado

- `CheatMode.isolateSaves` troca a identidade para `<identidade>-cheat`
  (`%APPDATA%/LOVE/card-game-cheat`). Run, perfil, desbloqueios e conquistas do cheat
  ficam lá; o save real nunca é escrito.
- Na primeira vez copia (só leitura do real) `settings.lua` e `i18n_settings.lua`,
  para a janela, o volume e o idioma serem os do dono.
- `_G.CHEAT_MODE` desliga a Steam (`SteamBridge.init`), catálogo inteiro liberado
  (`UnlockSystem.setOverrideAll(true)`), as 3 classes abertas.
- O tutorial do corvo fica desligado no cheat (`gameSettings.tipsEnabled = false`
  no 1º quadro) para não segurar o rush; Configurações → Jogo religa se quiser.

## Arquivos

- `src/systems/CheatMode.lua`: estado, ações e o rush. Fala com o `main.lua` pela
  ponte `_G.__cheatApi` (definida no escopo de arquivo do main, sem `local` novo:
  `game`, `state`, `showMapSelection`, `showRoundEval`, `onNodeChosen`, `startGame`,
  `returnToMenu`, `screens`).
- `src/ui/CheatActions.lua`: catálogo de botões (id, seção, atalho, rótulo,
  quando vale) e seções por estado.
- `components/CheatPanel.lua`: o painel (pergaminho, `Theme.Colors`, `FontManager`),
  adotado pelo `UiScale` (em `UiScale.MODULES`). Layout puro + `validate()`.
- Ganchos no `main.lua`: `claimArgs` no `love.load`, `update` no fim do `love.update`,
  `draw` antes do cursor, `keypressed`/`mousepressed`/`mousereleased` no topo.
- Textos em `src/i18n/locales/cheat/<locale>.lua` (5 idiomas).

O painel NÃO é registrado no `InputFocus`: overlay registrado vira o topo e apaga o
hover da cena (e um overlay que captura congela o combate). Ele consome só os cliques
dentro do próprio retângulo e não congela nada.

## Painel e atalhos

F1 mostra/esconde (clicar no título também recolhe; a aba "CHEAT F1" reabre).
Em combate: duas colunas no canto superior direito, acabando acima do JOGAR.
Fora do combate: uma coluna estreita à direita, longe dos caminhos da encruzilhada.

| Seção | Botão | Atalho | Caminho real |
|---|---|---|---|
| Combate | Matar | F2 | `Enemy:takeDamage` + `settleEnemyDamage`; espera a mão ser dada e a cena quieta (chegada, porta, entrada do chefe); chefe faz cinemática de morte e troféu |
| | Vencer já | F3 | `_onEnemyDeath` sem a cinemática; o `GameplayScene.update` abre o cash out |
| | Morrer | F4 | vida 0 (fura o modo deus): game over real |
| | Vida cheia | F5 | |
| | Modo deus | F6 | liga/desliga: `Player.takeDamage`/`loseHealth` viram nada |
| | Mana sem fim | F7 | liga/desliga: mana volta ao máximo todo quadro |
| | Mão nova | F8 | descarta a mão e compra de novo |
| Corrida | Batalha, Elite, Mini-chefe, Chefe, Loja, Descanso, Evento | Ctrl+B, E, M, C, L, D, V | sai do nó atual, abre a encruzilhada real com um caminho só daquele tipo e "clica" nele (`WorldRoad.forkMousePressed`): viagem, porta, salão, tudo |
| | Pular andar | F9 | encruzilhada do andar seguinte (escolha sua) |
| | Chefe do ato | F10 | andar 8 do ato atual pela encruzilhada |
| | Vencer jogo | F11 | chefe do ato 6 + golpe armado: morte, troféu, tela de vitória real com Endless |
| | Ato N, início | Ctrl+1..6 | ato N, andar 1, encruzilhada; bioma e inimigos do ato |
| | Ato N, chefe | Ctrl+Shift+1..6 | ato N direto no chefe |
| Recursos | +100 ouro | Ctrl+G | `earnGold` |
| | Coringa raro | Ctrl+J | raro/lendário que a run não tem (stream `misc`) via `Game:addJokerToRun` |
| | Coringa chefe | Ctrl+H | o coringa do chefe do bioma do ato |
| | Forçar raro | Ctrl+R | a PRÓXIMA recompensa traz um coringa (`ShopSystem.forceNextRewardJoker`, vale uma vez): mostra a revelação dourada |
| Rush | Rush automático | F12 | ver abaixo |

## Rush automático

Liga/desliga (F12). A cada tela espera `CheatMode.RUSH_GAP` (0,9 s) e escolhe a 1ª
opção: mata o inimigo assim que a mão é dada, cash out, 1ª carta da recompensa
(espera a revelação rara terminar), sai da loja, 1º caminho da encruzilhada, cura no
descanso (no seletor de carta aperta Voltar), 1ª opção possível do evento, 1ª maldição
do endless. PARA SOZINHO quando chega num chefe (com o chefe vivo, para o dono matar
e ver a cinemática) e na vitória/game over.

## Trava

`love . test_one test_cheat_mode` (último item do `test_all`): args (DEV, release,
ordem no `main.lua`), isolamento real de identidade (save real intacto), modo deus,
e um BOOT COMPLETO (`love.load({})`) dirigindo o `main.lua` de verdade: matar → cash
out, forçar coringa → coringa na recompensa com revelação, painel sem sobreposição e
longe dos caminhos, pular para os 7 tipos de nó → tela certa e inimigo do bioma,
morte do chefe com cinemática, ato 3/ato 4 chefe, vencer já, vencer campanha →
vitória, rush andando sozinho e parando no chefe, morrer → game over.

Capturas: `CARDGAME_HEADLESS=1 lovec . test_one screenshot_cheat [LxA]` (padrão
1600x900, `TOOL_LOCALE`), grava `cheat_{menu,combate,mapa,recolhido}_LxA.png` na
pasta de save da ferramenta e imprime os caminhos.
