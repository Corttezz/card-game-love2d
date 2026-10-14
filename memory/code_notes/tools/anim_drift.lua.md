---
name: code_notes/tools/anim_drift.lua
description: Comentários com decisão/regra/histórico colhidos de tools/anim_drift.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/anim_drift.lua`

Origem: `tools/anim_drift.lua` em `7dbdb60d` (3 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-38 (junto a `local M = {}`)

> tools/anim_drift.lua
> ONDE uma animacao muda, quadro a quadro — e se ela DESLOCA em vez de animar.
>
> Existe por causa de duas queixas do dono sobre os marcos do ato 2 (Set/2026):
> "a bandeira ficou estranha, ela SE MEXE DO LUGAR"
> "a fogueira fica FLICANDO a sombra e alguns detalhes, esta muito na cara
> que e IA"
>
> As duas sao o mesmo defeito de raiz, e nenhuma trava existente pegava:
> o gerador redesenha o sprite INTEIRO por quadro, entao (a) a silhueta
> inteira anda um pixel pra la e pra ca — o olho le como o objeto escorregando
> do lugar, nao como pano ondulando — e (b) partes que deviam ficar PARADAS
> (sombra de contato, pedras, detalhes) tremem de quadro a quadro. Tremor em
> coisa que deveria estar parada e exatamente o que se le como "cara de IA":
> nenhum animador desenharia a sombra de novo, errado, a cada quadro.
>
> As travas anteriores mediam "frame 0 == base" e "nada fora da mascara".
> Nenhuma das duas ve isto: aqui TUDO esta dentro da mascara, e o frame 0
> continua perfeito. O defeito vive ENTRE os quadros do meio.
>
> Mede tres coisas por animacao:
>
> DESLOCA   correlacao do centro de massa: se o centroide da silhueta anda
> mais que ~0.35px entre quadros vizinhos, o objeto esta se
> mudando de lugar em vez de deformar no lugar.
>
> RODAPE    fracao de pixels que mudam no TERCO DE BAIXO. E onde moram a
> sombra de contato e a base — a parte que o jogador espera
> plantada. Fogo/brasa pintados no rodape sao excecao legitima
> (abismo), por isso o numero e reportado, nao reprovado sozinho.
>
> DISPERSO  quantos "ilhas" de mudanca existem no quadro. Animacao boa tem
> POUCAS regioes coerentes (a chama; a barra do pano). Muitas
> ilhas pequenas espalhadas = chuvisco, que e o tremor.
>
> love . anim_drift                      -- todas as anims de marco
> love . anim_drift highlands            -- filtra por substring

## L91-92 (em `mudancas`, junto a `local function ilhas(mask, w, h)`)

> Conta ilhas conexas na mascara (flood fill 4-vizinhos), ignorando as de
> 1-2 pixels (ruido de compressao).

## L160-173 (em `medido`, junto a `local tipos = { "battle", "elite", "event", "rest", "shop", "shop_hover" }`)

> VEREDITO POR COMPARACAO COM O ATO 1, NAO POR LIMIAR INVENTADO.
>
> A primeira versao deste tool reprovava por numero absoluto (ilhas > 6) e
> acusou 36 de 36 — INCLUSIVE as do ato 1, que o dono nunca reclamou e que
> sao o padrao de qualidade da casa. Detector que marca tudo nao
> discrimina nada, e teria me feito mandar refazer o conjunto inteiro.
>
> O defeito nao existe num arquivo: existe ENTRE o marco do bioma e o
> marco EQUIVALENTE do ato 1. `landmark_rest` muda 2,2% do terco de baixo
> (so a chama); o `highlands_landmark_rest` muda 17,4% — oito vezes mais,
> porque o braseiro, as runas e o entulho estao sendo REDESENHADOS a cada
> quadro em vez de segurados da base. Foi exatamente isso que o dono
> descreveu: "fica flicando a sombra e alguns detalhes, esta muito na cara
> que e IA".

