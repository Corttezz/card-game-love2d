---
name: code_notes/tools/check_loop.lua
description: Comentários com decisão/regra/histórico colhidos de tools/check_loop.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/check_loop.lua`

Origem: `tools/check_loop.lua` em `7dbdb60d` (4 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-46 (junto a `local M = {}`)

> tools/check_loop.lua
> Mede se as faixas de música fecham o LOOP sem emenda audível, e se são
> distinguíveis umas das outras.
>
> Existe porque música do jogo toca em `loop = true` para sempre: o defeito
> não aparece na primeira passada, aparece na virada — e a virada acontece
> 20s depois, quando ninguém está mais olhando. `check_sfx` mede o envelope
> do arquivo inteiro e não diz nada sobre o ponto onde o fim encosta no
> começo. Este diz.
>
> Uso:
> love . check_loop            -- todos os audio/music/*.mp3
> love . check_loop act        -- filtra por substring
>
> Mede quatro coisas:
>
> SALTO   diferença de amplitude entre a ÚLTIMA amostra e a PRIMEIRA.
> É o clique. Acima de ~0.05 se ouve como "tec" a cada volta.
>
> RMS ini / RMS fim   energia dos 400ms de cada ponta. Se o fim está muito
> mais quieto que o começo (fade-out que o modelo colou sozinho),
> a volta soa como alguém religando o som. Razão saudável fica
> entre 0,5x e 2,0x.
>
> DC      offset médio. Sinal com DC longe de zero dá estalo garantido na
> emenda mesmo com salto pequeno.
>
> BRILHO  taxa de cruzamentos por zero, em kHz. É um proxy barato (O(n),
> sem FFT) do centroide espectral: grave cruza o zero poucas vezes,
> agudo cruza muito. Responde, SEM OUVIR, a pergunta "essas faixas
> são distinguíveis umas das outras?".
>
> POR QUE A COLUNA BRILHO EXISTE (Set/2026). A primeira leva da trilha tinha
> os três atos e o boss com centroide espectral de 107, 173, 139 e 154 Hz —
> quatro retumbos graves quase idênticos, com ~85% da energia abaixo de
> 200 Hz. Cada arquivo, isolado, passava em tudo: envelope bom, loop fechado,
> loudness certa. O dono ouviu e disse "cada ato tem que ser uma música
> diferente". Nenhuma métrica de arquivo único pega isso, porque **o defeito
> não existe num arquivo: existe entre dois**. Depois de reescrever os prompts
> descrevendo ARRANJO (instrumento, andamento, modo) em vez de CLIMA, os
> mesmos quatro foram para 1005, 2393, 541 e 1137 Hz.
>
> Daí as duas regras que este tool aplica:
> brilho < 0,15k = retumbo, não música;
> duas faixas a menos de 20% de distância em brilho vão soar como a mesma
> coisa, por mais diferente que o prompt tenha sido.

## L81-82 (em `rmsRange`, junto a `local crossings, prev = 0, mono(0)`)

> Brilho por cruzamentos de zero. Um seno de f Hz cruza 2f vezes por
> segundo, entao zcr/2 aproxima a frequencia dominante.

## L121-131 (em `files`, junto a `if love.filesystem.getInfo("audio/music.mp3") then`)

> A MUSICA DO MENU MORA FORA DE audio/music/ E POR ISSO NUNCA FOI MEDIDA.
>
> Ela e a faixa mais antiga do jogo (audio/music.mp3, anterior a trilha
> por contexto) e ficou de fora da varredura so por causa do caminho —
> exatamente o tipo de buraco que a regra "meca a EMENDA, nao o item"
> existe pra fechar. Quando finalmente foi medida (Set/2026) tinha 1,1s
> de silencio digital na cabeca e 1,4s na cauda: a cada 3 minutos o menu
> ficava ~2,5s MUDO, e ninguem sabia porque nenhuma ferramenta olhava.
>
> Ela tambem entra na comparacao de BRILHO, que e o que pega "a faixa do
> ato soa igual a do menu".

## L166-167 (em `bright`, junto a `table.sort(bright, function(a, b) return a.b < b.b end)`)

> O defeito que motivou a coluna BRILHO nao existe num arquivo isolado:
> existe entre dois. Por isso a comparacao roda aqui, sobre o conjunto.

