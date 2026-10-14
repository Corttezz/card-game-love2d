---
name: code_notes/tools/bake_orb_anim.lua
description: Comentários com decisão/regra/histórico colhidos de tools/bake_orb_anim.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/bake_orb_anim.lua`

Origem: `tools/bake_orb_anim.lua` em `7dbdb60d` (9 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-38 (junto a `local M = {}`)

> tools/bake_orb_anim.lua
> Gera os frames do loop idle das GEMAS do mago (assets/sprites/orbs_anim/).
>
> love . bake_orb_anim [halfW] [frames] [fps]
> > saída no diretório de save, em bake/orbs_anim/<tipo>/frame_NNN.png
> (copiar pra assets/ SÓ depois de olhar o contact sheet)
>
> POR QUE ISTO EXISTE, e não um job de PixelLab (Set/2026)
> ============================================================================
> O pedido do dono foi "animações bem sutis ali na arte delas, bem sutíssimas".
> O caminho normal do projeto (animate_object v3, memory/card_icon_animation.md)
> foi tentado PRIMEIRO, nas cinco gemas, com a redação que a memória registra
> como vencedora (ciclo curto de 4 + movimento positivo mínimo). As cinco foram
> REPROVADAS no contact sheet, cada uma pelo mesmo motivo de fundo — o v3
> redesenha o sprite inteiro a cada frame e num canvas de 48px com interior
> facetado ele tem liberdade demais:
> lightning — a pedra inteira bombeava de âmbar pra amarelo claro;
> ice       — o interior virava uma mancha branca e o contorno mexia;
> fire      — o frame do meio desbotava pra pêssego (cor fora da paleta);
> dark      — as facetas ferviam, com um buraco preto no meio do ciclo;
> holy      — os RAIOS encolhiam (silhueta mudando, o veto mais claro).
> Nenhuma delas é "sutilíssima", e três violam a regra de que a informação não
> pode piorar (cor do elemento = identidade que o jogador lê).
>
> A resposta não foi insistir no adjetivo proibitivo (a memória já registra que
> isso não resolve), foi TROCAR O MÉTODO: aqui o frame não é redesenhado, é
> DERIVADO do PNG que já está no jogo. Cada pixel só pode andar UM degrau pra
> cima na rampa de cor DO PRÓPRIO SPRITE — a paleta do frame animado é um
> subconjunto da paleta do frame parado. Isso torna impossível, por
> construção:
> * inventar cor nova (não existe cor fora da paleta original);
> * mudar a silhueta (nenhum pixel transparente vira opaco, e vice-versa);
> * mexer no contorno (pixel escuro, abaixo de MIN_LUM, nunca é tocado).
>
> O que se move é UMA coisa só: uma faixa diagonal de luz atravessando a pedra
> devagar, como a luz pegando a faceta. Frame 0 é byte a byte o PNG estático
> (a faixa nasce FORA da gema), e o último frame também — a emenda do loop é
> zero por construção, não por medida.

## L46-48 (em `ELEMS`, junto a `local MIN_LUM = 0.30`)

> Pixel abaixo disto é contorno/sombra: NUNCA é promovido. É o que mantém a
> borda escura da gema idêntica em todos os frames (a silhueta lida de longe
> é a borda, não o miolo).

## L50-57 (em `ELEMS`, junto a `local MAX_STEP = 0.16`)

> Degrau máximo de luminância que ainda conta como "a mesma cor, mais clara".
> Acima disso o vizinho na rampa é outra família de tom e a promoção viraria
> troca de cor.
> 0.16 foi MEDIDO, não escolhido: com 0.34 (o primeiro corte) a rampa grossa da
> gema de raio dava saltos de meio tom e a faixa lia como "metade da pedra
> acendeu". Limitar o degrau faz a dosagem se adaptar sozinha a cada pedra —
> gema de rampa fina (gelo, sombra) cintila, gema de rampa grossa quase não
> muda, que é exatamente o certo: onde o degrau é grande, mexer é gritar.

## L80-83 (em `hueDist`, junto a `local function buildRamp(data)`)

> Rampa do sprite: cada cor opaca ganha um "gêmeo mais claro" escolhido entre
> as cores que o PRÓPRIO sprite já usa. Critério: mesma família de tom (matiz e
> saturação próximos), um degrau de luminância acima. Sem candidato, a cor é o
> próprio gêmeo (pixel que não tem pra onde subir simplesmente não muda).

## L109-110 (em `c`, junto a `local score = hueDist(c.h, d.h) * 4.0`)

> Matiz pesa mais que tudo: é ele que separa "laranja mais
> claro" de "cinza da cravação" na mesma faixa de brilho.

## L117 (em `c`, junto a `c.twin = (best and hueDist(c.h, best.h) < 0.09) and best or c`)

> Matiz longe demais = famílias diferentes; melhor não mexer.

## L123-125 (em `c`, junto a `local function bandHit(x, y, center, halfW)`)

> A faixa de luz: uma reta diagonal (canto inferior-esquerdo -> superior-
> direito) que atravessa a pedra ao longo do ciclo. `center` anda de fora a
> fora, então os frames das pontas são idênticos ao original.

## L131-136 (em `bandHit`, junto a `function M.run(halfWArg, framesArg, fpsArg)`)

> Os três números do ciclo, e por que são estes:
> frames 24 @ fps 12 = 2,0s de volta completa. A faixa anda ~3,3px por
> frame; com 16 frames ela pulava 5px e o brilho lia como degrau, não como
> luz correndo (a pedra tem 48px — 5px é um décimo dela de uma vez).
> halfW 5 = faixa de 10px: cada pixel fica aceso ~3 frames (0,25s), tempo de
> o olho registrar um reflexo sem virar pisca-pisca.

## L158-159 (em `relatorio`, junto a `local span = (w - 1) * 0.70710678`)

> span = metade da diagonal projetada; +halfW+1 de margem garante faixa
> COMPLETAMENTE fora da pedra nos dois extremos do ciclo.

