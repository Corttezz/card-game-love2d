---
name: code_notes/engine/ShadowEngine.lua
description: Comentários com decisão/regra/histórico colhidos de engine/ShadowEngine.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/ShadowEngine.lua`

Origem: `engine/ShadowEngine.lua` em `7dbdb60d` (18 de 28 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-46 (junto a `local ShadowEngine = {}`)

> engine/ShadowEngine.lua
> ============================================================================
> SHADOWENGINE v1 — sombras PROJETADAS de silhueta (Jul/2026)
> ============================================================================
> Substitui as elipses "círculo nos pés" dos objetos de destaque por uma
> sombra convincente: a SILHUETA do próprio sprite, virada de cabeça pra
> baixo a partir dos pés (o sol dos biomas vive no horizonte, atrás do
> castelo → a sombra projeta pro PRIMEIRO PLANO), achatada e cisalhada:
>
> COMPRIMENTO ∝ horário do dia (sol baixo no anoitecer = sombra longa)
> DIREÇÃO     ∝ posição do astro do bioma (ponta foge do sol, por coluna
> da tela — árvore à esquerda do sol inclina pra esquerda)
> OPACIDADE   ∝ luminância do ambiente de luz (luz difusa = sombra suave)
> TAMANHO     ∝ escala do dono (perspectiva de graça: longe = sombra
> pequena, perto = grande — "cada árvore uma sombra")
>
> REGRA DE PROFUNDIDADE (lei do projeto): a sombra desenha JUNTO do dono
> no painter — deitada no chão do slot dele, grama mais próxima cobre.
> NÃO usar nas cartas (sombra de carta é outra linguagem, já aprovada).
> Zero stencil, zero shader — só transform + tint.
>
> PEGADA (v9, Out/2026 — dono: "a fogueira é um círculo, e a sombra é o
> círculo inteiro depois dela"): a silhueta inteira virada a partir do pé
> trata TODA linha do sprite como altura. Num objeto baixo e largo (anel
> de pedras, baú, pedra, moita, cadáver) a faixa de baixo do sprite é a
> PROFUNDIDADE da pegada no chão, não altura — projetá-la punha uma cópia
> inteira do objeto deitada à frente dele. Perfil (opts):
> baseK  fração da altura do CONTEÚDO que é pegada (elipse de contato).
> A sombra nasce no CENTRO da pegada, a faixa da pegada não
> projeta e o que sobra cai em boa parte DENTRO dela — só uma
> orla sai pro lado oposto ao sol.
> riseK  fração (da altura do conteúdo) ACIMA da pegada que projeta.
> Fogueira: só as pedras — chama não tem sombra. nil = tudo.
> 0 = nada projeta (decalque no chão, ex. fissura).
> lenK   multiplicador do comprimento (atarracado = curto).
> Sem perfil (baseK 0, riseK nil) o caminho é o v8.4, pixel por pixel:
> árvore, poste, estandarte, barraca e criatura em pé não mudam.
> Trava: tools/test_world_shadows.lua.
>
> USO:
> WorldRoad (1x por frame):  ShadowEngine.setFrame(sunX, w, tod, luma)
> sprite estático:           ShadowEngine.sprite(img, feetX, feetY, s, opts)
> draw arbitrário (anim):    local tint = ShadowEngine.begin(feetX, feetY)
> if tint then <desenha com tint>;
> ShadowEngine.finish() end
> ============================================================================

## L58-60 (em `frame`, junto a `function ShadowEngine.setFrame(sunX, w, tod, luma)`)

> WorldRoad configura 1x por frame de mundo.
> sunX = x NA TELA do astro do bioma; w = largura da área do mundo;
> tod = 0(dia)..1(anoitecer); luma = LightEngine.ambientLuma().

## L64-66 (em `ShadowEngine.setFrame`, junto a `frame.len = 0.55 + 0.45 * math.max(0, math.min(1, tod or 1))`)

> sol alto (dia) = sombra curta; sol rasante (anoitecer) = comprida.
> v8.1 (feedback: "sem distorção, fiel demais; pode ser maior"):
> 0.34-0.64 → 0.55-1.00 — a sombra ESTICA de verdade

## L68-69 (em `ShadowEngine.setFrame`, junto a `local l = math.max(0, math.min(1, luma or 1))`)

> ambiente escuro = luz difusa = sombra mais suave (nunca some:
> piso 0.15 mantém o objeto ancorado no chão)

## L84-86 (em `tipShift`, junto a `function ShadowEngine.tipShiftAt(px)`)

> Mesma direção, exposta: quem FLUTUA precisa deslocar a própria sombra
> pro lado oposto ao sol (a sombra de um corpo no ar não nasce sob ele).
> Retorna 0 sem frame ativo (interiores decidem pela luz da cena).

## L92-106 (em `ShadowEngine.tipShiftAt`, junto a `local SMEAR = { { -1, 0 }, { 0.7, -0.5 }, { 0.35, 0.55 } }`)

> Sombra de um SPRITE estático (props do mundo: árvores, marcos, encounter).
> feetX/feetY = âncora dos pés no chão; s = escala do dono na cena.
> opts: alphaK (0..1), lenK, flip (espelho do dono: ±1),
> footPad (px de canvas transparente ABAIXO do conteúdo — a sombra
> ancora no PÉ DO CONTEÚDO, senão nasce com um vão)
>
> v8.3 ("silhueta arredondada"): SMEAR de 3 passadas deslocadas funde
> detalhes finos em massas arredondadas.
> v8.4 ("não quero camadas de cor — uma cor direta"): as passadas
> desenham a silhueta OPACA num canvas scratch ⅓-res com blend
> "lighten" (máximo — sobreposição NÃO acumula) e o canvas compõe UMA
> vez em preto com o alpha do frame: união arredondada, COR ÚNICA,
> borda quantizada no pixel lógico. Também elimina o escurecimento
> duplo onde sombras de árvores vizinhas se cruzam. Zero stencil.

## L131-132 (em `ShadowEngine.beginBatch`, junto a `love.graphics.setBlendMode("lighten", "premultiplied")`)

> "lighten" (max por canal) exige premultiplied: branco opaco
> sobreposto continua branco opaco — a união fica CHAPADA

## L144-146 (em `ShadowEngine.endBatch`, junto a `love.graphics.setColor(0, 0, 0, frame.alpha * (soloAlphaK or 1))`)

> alphaK SÓ vale em batch solo (uma silhueta por composite). Numa fila
> com vários donos a cor é única por construção — é o que faz sombras
> cruzadas não escurecerem em dobro (v8.4).

## L156-161 (em `NO_OPTS`, junto a `local profWarned = {}`)

> Pegada do perfil (ver cabeçalho). contentH e `s` na unidade do chamador
> (.sprite: px de arte × escala; .silhouette: px de tela × 1). Devolve
> ay     linha de ORIGEM da sombra (centro da pegada; = feetY sem perfil)
> baseH  altura da pegada (pivô da virada sobe isso a partir do pé)
> yCut   fundo do recorte em px de tela (nil = sem recorte)
> ou false quando nada projeta (riseK 0 = decalque no chão).

## L168-169 (em `footprint`, junto a `local k = tostring(opts.baseK) .. "/" .. tostring(riseK)`)

> perfil sem altura de conteúdo: avisa UMA vez e desenha como sem
> perfil (nunca some em silêncio)

## L185-187 (em `footprint`, junto a `local function cutScissor(ay, yCut)`)

> Recorte em px do canvas scratch (⅓): só as linhas entre a origem e o
> fim do trecho que projeta entram — a faixa da pegada (virada pra cima
> da origem) fica fora.

## L211-215 (em `ShadowEngine.sprite`, junto a `for pi = 1, #SMEAR do`)

> draw args: offset(-ox,-oy) → shear → scale → translate.
> oy nos pés DO CONTEÚDO (ou no topo da pegada, com perfil): topo do
> sprite tem y local negativo → shear kx desloca a ponta ⇒ pra LONGE
> do sol pede kx = -shd·K. sy NEGATIVO espelha verticalmente (sombra
> desce da origem pro primeiro plano). ×1.18: "mais gorda" (v8.2).

## L230-239 (em `ShadowEngine.sprite`, junto a `local silTint = { 1, 1, 1, 1 }   -- branco opaco: a COR vem do composite`)

> Sombra de um DRAW arbitrário (animação do inimigo): o motor monta o
> transform projetado nos pés e chama drawFn(tint) UMA VEZ POR PASSADA
> do smear (v8.3) — o chamador desenha a silhueta relativa à origem
> (pés em 0,0) com o tint recebido. Retorna false quando inativo
> (interiores → elipse legada do chamador).
> opts: alphaK (só em chamada solo), lenK, widthK (estreita a silhueta —
> corpo no ar projeta sombra MENOR), smear (raio do borrão em px),
> baseK/riseK + contentH (px de tela) = perfil de pegada do cabeçalho

## L246-247 (em `ShadowEngine.silhouette`, junto a `local ay, baseH, yCut = footprint(opts, feetY, opts.contentH or 0, 1,`)

> perfil de pegada (cabeçalho): contentH em px DE TELA do conteúdo
> (o drawFn desenha em px de tela, pé em 0,0)

## L264-266 (em `ShadowEngine.silhouette`, junto a `love.graphics.shear(shd * 0.78, 0)`)

> ordem de emissão translate→shear→scale ⇒ no ponto aplica scale
> ANTES do shear: y já flipado (positivo abaixo dos pés) → ponta
> pra longe do sol pede kx = +shd·K (sinal oposto ao .sprite)

## L269-270 (em `ShadowEngine.silhouette`, junto a `if baseH > 0 then love.graphics.translate(0, baseH) end`)

> pivô da virada no TOPO da pegada: o drawFn põe o pé em y=0, a
> linha baseH acima dele é a que cai na origem

## L281-290 (em `ShadowEngine.silhouette`, junto a `local squeue, squeueN = {}, 0`)

> FILA (props do mundo): sombra cai SOBRE a grama — mas no painter o
> tapete mais próximo desenha depois do prop e COBRIA a sombra imediata
> (campo 100% coberto = sombra invisível). Solução: os props ENFILEIRAM;
> o WorldRoad descarrega a fila depois de props+grama completos — a
> sombra escurece a grama em que cai (e o pé de quem estiver dentro
> dela, como sombra real faria). Ordem de submit = far→near (painter).
>
> (Out/2026: entradas da fila REUSADAS entre frames — era 1 tabela nova
> por prop por frame; squeueN é o tamanho vivo da fila)

## L303-304 (em `ShadowEngine.flush`, junto a `ShadowEngine.beginBatch()`)

> UM batch pra fila inteira: sombras vizinhas que se cruzam viram
> união chapada (uma cor), não escurecimento duplo (v8.4)

