---
name: code_notes/src/ui/shop/ShopProps.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/shop/ShopProps.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/shop/ShopProps.lua`

Origem: `src/ui/shop/ShopProps.lua` em `7dbdb60d` (14 de 44 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-50 (junto a `local ImageCache = require("src.ui.ImageCache")`)

> src/ui/shop/ShopProps.lua
> PROPS VIVOS do Balcão do Mercador (Loja v3, F3, Out/2026). Módulo PURO de
> desenho: não sabe de layout, de ofertas nem de input — a cena
> (src/ui/shop/ShopScene.lua, frente loja-cena) decide ONDE cada prop fica
> e chama update/draw. Zero regra de economia aqui.
>
> API
> ShopProps.lantern.new()                      -> lanterna
> :update(dt, lookX)   lookX em [-1, 1]: a poça de luz "olha" pro objeto
> em hover, em DEGRAUS (LOOK_STEPS) perseguidos a
> LOOK_RATE passos/s. nil = volta ao centro.
> :draw(x, y, scale)   x,y = ponto do GANCHO (topo-centro do sprite).
> Desenha poça de luz + poeira + sprite, nessa ordem.
> :drawLight(x, y, s)  só a luz (poça em 3 degraus aditivos + halo da
> chama + poeira no feixe, 1 SpriteBatch) — pra cena
> que quer a luz ATRÁS das prateleiras e a lanterna
> na frente.
> :drawSprite(x, y, s) só a lanterna.
> :lightCenter(x,y,s)  -> cx, cy, r da poça (pra cena alinhar sombras).
> campos lidos por teste/preview: frame (1..3), level (índice em
> LEVELS), lookStep (inteiro em -LOOK_STEPS..LOOK_STEPS).
>
> ShopProps.diceCup.new()                      -> copo dos Dados do Escriba
> :setState("idle" | "shake" | "rolled", { a = 1..6, b = 1..6 })
> shake = hover (3 quadros + `sceneWoodKnock`
> baixo UMA vez por entrada); rolled = copo DEITADO
> e os dois dados JOGADOS no balcão com as faces.
> :syncRun(run)        lê currentRun.scribeDice (ScribeDice.state) e
> entra em rolled com a soma da visita, ou idle.
> :update(dt) / :draw(x, y, scale)   x,y = PÉ do copo (base-centro).
> :width(scale)        largura ocupada (copo + dados quando rolled).
>
> ShopProps.moth.new()                         -> mariposa
> :update(dt)          agenda uma travessia a cada MOTH_MIN..MOTH_MAX s.
> :draw(fx, fy, scale) fx,fy = centro da CHAMA (ShopProps.lantern.flameAt).
> :isFlying() / :cross()   (preview e teste forçam a travessia)
>
> ShopProps.cobweb.draw(x, y, scale)           teia estática, canto sup-esq.
> ShopProps.saleTag.draw(x, y, scale)          etiqueta vermelha torta da
> oferta do dia (o TEXTO do preço é da cena).
> ShopProps.missingAssets()                    -> lista de PNGs ausentes
> (fallback silencioso é proibido: cada miss AVISA
> uma vez e o teste falha se a lista não for vazia).
>
> reducedMotion (_G.gameSettings.reducedMotion): chama no quadro 1, luz no
> nível médio, poeira parada, copo sem chacoalho, mariposa POUSADA na
> lanterna. Dados jogados e copo deitado continuam: são informação.
>
> Doutrina: tudo em DEGRAUS (quadro, nível de luz, passo da poça, pulso da
> poeira) — mesma vida do menu v3 e do LuminaireEngine; nada interpola.

## L131-133 (em `dotImage`, junto a `local Lantern = {}`)

> ===========================================================================
> LANTERNA
> ===========================================================================

## L187-188 (em `Lantern:update`, junto a `self.frame, self.level = 1, 2`)

> sem movimento: chama parada, luz no nível médio, poça vai direto
> pro alvo (informação de "qual objeto" continua), poeira parada.

## L193 (em `Lantern:update`, junto a `if self.lookStep ~= target then`)

> perseguição a LOOK_RATE passos/s, um passo por vez (nunca contínua)

## L294-296 (em `ShopProps.lantern`, junto a `local DiceCup = {}`)

> ===========================================================================
> COPO DE DADOS
> ===========================================================================

## L339-340 (em `self.dice`, junto a `function DiceCup:syncRun(run)`)

> Lê o estado da visita (memory/scribe_dice.md): jogada feita neste nó →
> copo deitado com as faces; senão, de pé.

## L379-382 (em `DiceCup:width`, junto a `function DiceCup:draw(x, y, scale, opts)`)

> x,y = PÉ do copo (base-centro). Dados jogados à direita, ao longo da
> diagonal da mesa (`opts.slope`). Sem sombra aqui: a loja desenha a sombra
> de CONTATO (ShopPerspective, dither colado na base; elipse = flutuando).
> `opts.outline` 0..1 = contorno claro de 1 px (hover).

## L402-405 (em `DiceCup:draw`, junto a `local show = (self.state == "rolled" and self.dice) and self.dice`)

> dados: jogados (rolled) ou um dado de enfeite parado (opts.idleDie,
> Loja v5: o copo sozinho lia como uma CANECA sem preço). opts.dicePos =
> posições {dx, dy} do PÉ de cada dado relativas ao pé do copo (a loja
> põe os dados À FRENTE do copo, longe do sino); sem ela, à direita.

## L433-435 (em `ShopProps.diceCup`, junto a `local Moth = {}`)

> ===========================================================================
> MARIPOSA
> ===========================================================================

## L443 (em `Moth.PERCH`, junto a `Moth.PERCH = { x = 14, y = 6 }`)

> pouso em reducedMotion (relativo à chama)

## L482-483 (em `Moth:update`, junto a `function Moth:draw(fx, fy, scale)`)

> fx,fy = centro da chama. Voo em arco raso que passa pela chama, com
> ziguezague em degraus de 1 px (mariposa não voa reto).

## L505-507 (em `ShopProps.moth`, junto a `ShopProps.cobweb = {}`)

> ===========================================================================
> TEIA e ETIQUETA (estáticas)
> ===========================================================================

## L525-545 (em `ShopProps.saleTag.draw`, junto a `local S = nil   -- singletons da cena`)

> ===========================================================================
> FACHADA PRA CENA (contrato combinado com a frente loja-cena, Out/2026)
> A cena não instancia nada: chama estas funções na ordem do frame.
> ShopProps.load()                      cria os props e AVISA asset ausente
> ShopProps.update(dt, L, ctx)          L = ShopLayout.layout(); ctx = { t,
> reduced, hoverX, hoverY, run | dice,
> cupHover }  (run = currentRun, pra
> ler os dados da visita; ou dice={a,b})
> ShopProps.drawBack(L, ctx)            teia no canto da estante de cima +
> halo e poeira no feixe (a POÇA/cone
> na parede é da cena: use lookDx())
> ShopProps.drawLantern(rect, ctx)      sprite da lanterna no rect (escala
> inteira que cabe)
> ShopProps.flameAnchor(rect) -> x, y   centro da chama no rect da lanterna
> ShopProps.lookDx() -> px              deslocamento em DEGRAUS da luz
> (já em px de tela, segue o hover)
> ShopProps.drawDiceCup(rect, ctx)      copo apoiado no tampo (pé = y+h);
> ctx.hover 0..1 chacoalha; o estado
> jogado vem do update (run/dice)
> ShopProps.drawFront(L, ctx)           mariposa (por cima de tudo)
> ===========================================================================

## L648 (em `ShopProps.scene`, junto a `function ShopProps._reset()`)

> pra testes: esquece sheets (depois de trocar um PNG), avisos e a cena

