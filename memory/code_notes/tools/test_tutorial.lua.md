---
name: code_notes/tools/test_tutorial.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_tutorial.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_tutorial.lua`

Origem: `tools/test_tutorial.lua` em `7dbdb60d` (11 de 36 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local TK = require("tools.testkit")`)

> tools/test_tutorial.lua
> TRAVA do onboarding v2 (Out/2026): o corvo narrador (src/systems/Tutorial +
> src/ui/Narrator) e o Guia de combos/glossário (components/GuideScreen).
> 1. toda fala do roteiro (e rodapé/ações) existe nos 5 idiomas;
> 2. ROTEIRO: a 1ª batalha anda na ordem certa, cada fala de AÇÃO espera o
> jogador fazer a coisa, nada fala com a cena em movimento (cutscene,
> viagem, banner, vez do inimigo), duas conversas nunca se sobrepõem;
> 3. CHEFE: a conversa do chefe só vem DEPOIS da cerimônia da porta e
> antes do 1º turno acabar — nunca no meio da luta;
> 4. ENTRADA: na fala, o tutorial é dono da entrada (avança/pula); na ação,
> só passa o clique dentro do recorte e só o atalho da ação pedida;
> 5. pular conversa, desligar o tutorial, "Recomeçar" e persistência em disco;
> 6. LAYOUT: corvo + balão dentro da tela, sem cobrir o recorte nem a TopBar,
> pra toda fala do roteiro, em 4 tamanhos × pt_BR/de;
> 7. o Guia lista todo combo e todo verbete nos 5 idiomas.
>
> love . test_one test_tutorial

## L141-142 (em `g.selectedCards`, junto a `do`)

> jogou a carta DIRETO na fala de "selecione": a fala de jogar não espera
> uma 2ª jogada (a conversa mede contra a mão do começo)

## L177 (em `g.selectedCards`, junto a `g.player.armor = 5`)

> duas conversas nunca ao mesmo tempo

## L189-192 (em `g.selectedCards`, junto a `do`)

> ===== 2b. voz: pool FIXO, solto no fim da conversa =====
> Cada blip reusa uma das BLIP_COUNT fontes do corvo (stop+play); antes,
> o pool do AudioManager crescia até 8 clones por variação e nunca
> devolvia — 20 conversas esgotavam vozes do OpenAL e a música calava.

## L224-228 (em `g.selectedCards`, junto a `TK.pump(g, 0.1)`)

> ===== 2c. HORA CERTA: cada dica sai na 1ª ocorrência do gatilho =====
> Playtest do dono (Out/2026): a dica do Bloqueio chegou depois de ele já
> ter usado Bloqueio várias vezes. Regra: gatilho arma na hora em que a
> coisa acontece e a conversa sai no 1º momento quieto seguinte, no mesmo
> turno; várias pendentes saem em fila, na ordem dos gatilhos.

## L232-233 (em `timing`, junto a `ProfileStats.resetTips()`)

> (a) 1ª batalha: defesa jogada na fala de JOGAR da apresentação →
> Bloqueio no turno 1, ANTES do ENCERRAR e antes de o inimigo agir

## L244-245 (em `handBackup`, junto a `Tutorial._quiet = false`)

> jogou: a carta sai da mão, a resolução corre (cena NÃO quieta) e a
> armadura entra no meio da resolução

## L314-315 (em `g.selectedCards`, junto a `{ "conduit", "playing", { "intro" }, function()`)

> Conduíte (mago): o 1º orbe na fileira. O resto do roteiro do mago
> (canalizar, pulso, evocar, estouro, Foco) mora em test_tutorial_mage.

## L406-408 (em `run.currentNode`, junto a `do`)

> ===== 4b. seleção de classe (1ª visita) =====
> Perfil NOVO de verdade (sem o override de ferramenta): só o Guerreiro
> aberto; o texto das acorrentadas tem que ser o requisito REAL.

## L472 (em `hr`, junto a `local seq = { Tutorial.activeLine() }`)

> ordem: boas-vindas → guerreiro → começar → acorrentadas → detalhes

## L516 (em `seq`, junto a `Tutorial.draw()`)

> link "Já sei jogar: desligar o tutorial" (só na 1ª fala)

