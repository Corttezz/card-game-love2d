---
name: code_notes/src/ui/CoinBurst.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/CoinBurst.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/CoinBurst.lua`

Origem: `src/ui/CoinBurst.lua` em `7dbdb60d` (14 de 17 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local CoinBurst = {}`)

> src/ui/CoinBurst.lua
> Moedas que voam até o contador de ouro quando o jogador GANHA ouro.
>
> Singleton global, no molde do FloatingText: `update`/`draw` são chamados uma
> vez em `main.lua`, então funciona em QUALQUER estado — por cima da loja, do
> evento, do cash out, do mapa. Uma tela que ganha ouro não precisa saber que
> este módulo existe.
>
> POR QUE ISTO EXISTE. O cash out (RoundEvalScreen) tinha moedas animadas e
> todo o resto do jogo não: clicar "Continuar" na loja creditava o bônus de
> pular com um texto subindo e mais nada ("ganha gold, então tem que ter a
> animação que fizemos ao colher recompensa, SEMPRE que ganhar gold" — dono,
> Set/2026). O mesmo evento econômico tinha dois pesos conforme a tela.
>
> Por isso o disparo mora em `TopBar:_onGoldDelta`, que já é o funil por onde
> TODO delta de ouro passa (a barra compara `currentGold` a cada frame). Ligar
> tela por tela reabriria exatamente o buraco que motivou o componente: a
> próxima fonte de ouro nasceria sem animação e ninguém perceberia.

## L24-26 (em `coins`, junto a `local MIN_COINS, MAX_COINS = 3, 12`)

> Escala Balatro-ish: o número de moedas cresce com o ganho mas SATURA. Três
> de ouro e quarenta de ouro têm pesos diferentes sem que quarenta vire festa
> — a mesma dosagem que o som do ganho já usa logo acima.

## L29-43 (em `coins`, junto a `local FLIGHT   = 0.55      -- tempo de voo de cada moeda, em segundos`)

> Cada moeda percorre um ARCO com tempo de chegada FIXO, em vez de física
> livre com gravidade e atração.
>
> A primeira versão era física (velocidade inicial aleatória + gravidade +
> atração crescente ao contador) e gerou dois defeitos que o dono viu na
> tela: moedas que já tinham chegado continuavam sendo integradas e ficavam
> ORBITANDO o contador enquanto sumiam ("umas partículas de moeda ficam meio
> que rodando e caindo"), e as que ainda vinham faziam curvas largas e lentas,
> algumas DESCENDO antes de subir. Num efeito de recompensa isso lê como bug,
> não como vida.
>
> Com arco parametrizado, a chegada é garantida (t=1 é o contador, sempre),
> toda moeda leva o mesmo tempo, e não existe estado depois do fim. O preço é
> não ter variação emergente — que aqui não faz falta: quem dá variedade é o
> leque de origem, o stagger e a rotação.

## L47 (em `coins`, junto a `local FADE     = 0.16`)

> tempo de sumiço depois de encostar no contador

## L51-54 (em `rand`, junto a `function CoinBurst.spawn(amount, tx, ty, ox, oy)`)

> amount  : quanto de ouro entrou (define quantas moedas)
> tx, ty  : destino (o contador na TopBar)
> ox, oy  : origem opcional; sem ela as moedas nascem logo abaixo do destino,
> que é o comportamento certo quando não se sabe QUEM pagou.

## L59-61 (em `CoinBurst.spawn`, junto a `if _G.gameSettings and _G.gameSettings.reducedMotion then return end`)

> reducedMotion tira o MOVIMENTO, nunca a INFORMAÇÃO: o valor continua
> subindo como FloatingText na TopBar, que é quem informa. Aqui só há
> enfeite, então some inteiro.

## L74-75 (em `CoinBurst.spawn`, junto a `arc = ARC * rand(0.55, 1.0) * (i % 2 == 0 and 1 or -1),`)

> Arco por moeda: lados alternados e alturas diferentes espalham
> o feixe sem nenhuma moeda sair da rota.

## L101-103 (em `CoinBurst.update`, junto a `local e = 1 - (1 - k) * (1 - k)`)

> easeOutQuad na posição: sai rápido e ASSENTA no contador, em vez
> de chegar a toda e precisar frear (frear era o que dava a
> impressão de órbita).

## L108-113 (em `CoinBurst.update`, junto a `local dx, dy = c.tx - c.x0, c.ty - c.y0`)

> O arco desloca PERPENDICULARMENTE à rota, não em Y. Como a
> origem fica logo abaixo do contador, deslocar em Y só esticaria
> a subida e as moedas viriam em coluna; perpendicular abre o
> leque de verdade, em qualquer direção que a origem esteja.
> sin(pi*k) vale 0 nas duas pontas, então o arco nasce e morre
> exatamente na origem e no alvo e nunca desloca a chegada.

## L126-127 (em `CoinBurst.update`, junto a `Sfx.play("coinClink", {`)

> Pitch sobe com a ordem de chegada: a fileira soa como uma
> escala subindo, que é o que o cash out já faz.

## L134-135 (em `CoinBurst.update`, junto a `c.s = c.s * (1 + dt * 1.8)`)

> Encostou: um pop curto no lugar e some. Nada mais é integrado,
> então não há como sobrar movimento depois do fim.

## L153-156 (em `CoinBurst.draw`, junto a `icon.image:setFilter("nearest", "nearest")`)

> NEAREST, senão o PNG de 64px reduzido pra ~20 sai borrado e
> a moeda deixa de ser pixel art no meio de uma tela que é
> toda pixel art. O filtro é por-imagem no LÖVE e o default
> é linear, então não dá pra assumir que veio certo do loader.

## L162-163 (em `CoinBurst.draw`, junto a `love.graphics.setColor(0.95, 0.80, 0.28, c.a)`)

> Sem o PNG, disco dourado. Moeda que some porque o ícone não
> resolveu seria fallback silencioso (ui_layout_invariants §3).

## L173-174 (em `CoinBurst.clear`, junto a `function CoinBurst._coins() return coins end`)

> Introspeccao para o teste de regressao: precisa olhar o estado de CADA
> moeda (pousada? moveu depois de pousar?), nao so a contagem.

