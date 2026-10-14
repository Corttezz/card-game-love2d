---
name: code_notes/tools/screenshot_packopen.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_packopen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_packopen.lua`

Origem: `tools/screenshot_packopen.lua` em `7dbdb60d` (30 de 56 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-46 (junto a `local M = {}`)

> tools/screenshot_packopen.lua
> Captura frames da cinemática de abertura de booster pack.
>
> Roda:
> love . screenshot_packopen            → TUDO: prateleira + sequencia
> completa dos dois tipos opostos.
> É o comando pra revisar o trabalho
> inteiro sem decorar argumento.
> love . screenshot_packopen sheet      → folha de contato: os 5 tipos no
> MESMO instante, pra comparar
> identidade lado a lado
> love . screenshot_packopen 2          → folha de contato na fase 2
> love . screenshot_packopen 2:arcana   → UM tipo, UMA fase (tela cheia)
> love . screenshot_packopen arcana     → um tipo na fase padrão (1)
> love . screenshot_packopen seq        → SEQUÊNCIA: Bufão e Espectral em
> 5 instantes cada (parado, wobble,
> estouro, cartas, assentado) — é o
> que mostra a cinemática inteira
> love . screenshot_packopen states     → MATRIZ DE ESTADOS: um PNG por
> estado da tela de escolha (hover,
> selecao, 5 cartas, reducedMotion,
> janelas baixa/larga...) + validacao
> geometrica das zonas em cada um
> love . screenshot_packopen hover      → HOVER: a faixa de info sobre uma
> carta, em VARIAS alturas de janela
> (e a unica captura que mostra a
> faixa -- ela so existe no hover)
> love . screenshot_packopen shelf      → PRATELEIRA: os 5 sleeves lacrados
> lado a lado, linha de cima normal
> e linha de baixo com hover forçado
> (halo, cantoneiras, faíscas)
>
> Fases (segundos de timeline):
> 0 = 0.4s  sleeve materializado, antes do wobble
> 1 = 0.9s  PICO DO ESTOURO — é aqui que a identidade por tipo aparece
> 2 = 1.6s  cartas materializando em cascata
> 3 = 2.4s  linha de cartas + banner
> 4 = 3.5s  estado de escolha (idle)
>
> Sufixo @idioma em qualquer modo captura noutra lingua:
> love . screenshot_packopen states@de    -> matriz de estados em alemao
> love . screenshot_packopen @en          -> tudo em ingles
> Sem sufixo e sempre pt_BR (idioma de referencia do projeto).
>
> Saída: <save dir>/packopen_<kind>_phase<N>.png
> (no Windows: %APPDATA%/LOVE/card-game/)

## L68-69 (em `PHASE_TIMES`, junto a `local SEQ = {`)

> Sequência narrativa: os instantes que contam a cinemática. Nomeados porque
> "phase3" não diz nada quando se abre a pasta de screenshots dias depois.

## L73-75 (em `SEQ`, junto a `{ name = "3estouro",  t = 0.95 },  -- pico: flash + burst + onda`)

> 0.80 → 0.95: cada tipo tem burstTime proprio (0.45 do Bufao ate 0.80 do
> Espectral), entao nenhum instante unico pega os dois no auge. 0.95 e o
> meio-termo: Bufao ja assentando, Espectral perto do maximo.

## L83 (em `SEQ_KINDS`, junto a `local KINDS = { "Standard", "Buffoon", "Arcana", "Celestial", "Spectral" }`)

> Ordem da folha de contato = ordem de raridade/preço na loja.

## L93-98 (em `PACK_ID`, junto a `local captureLocale = "pt_BR"`)

> "2:arcana" / "arcana" / "2" / "seq" / "shelf" / nil → mode, phase, kind|nil
> Idioma da captura. main.lua ja forca pt_BR nos tools visuais, MAS o
> bootSystems daqui chama I18n.init(), que reaplica o idioma PERSISTIDO e
> desfaz o force -- era por isso que as capturas saiam em alemao sem
> ninguem pedir. Agora o idioma e explicito: pt_BR por padrao, e sufixo
> `@xx` no argumento pra testar outro ("states@de").

## L102-104 (em `parseArg`, junto a `if not raw then return "all", nil, nil end`)

> Sem argumento = TUDO. Antes o default era so a folha de contato no
> instante do estouro, e quem rodava o comando nu nunca via nem o pacote
> parado nem as cartas reveladas — justamente o que precisava de revisao.

## L107-108 (em `parseArg`, junto a `local base, loc = raw:match("^(.-)@(%a[%w_]*)$")`)

> Tira o @idioma ANTES de qualquer comparacao de modo, senao
> "states@de" nao casa com nenhum modo e cai no default.

## L161-163 (em `bootSystems`, junto a `local function simulate(kind, targetT, size)`)

> Abre um pacote do tipo pedido e avança a simulação até `targetT`.
> Limpa o EventManager antes — sem isso a timeline do pacote anterior
> continuaria disparando em cima deste (a folha de contato reusa o processo).

## L166-171 (em `simulate`, junto a `CardParticles.clear()`)

> CardParticles/ParticlesManager sao GLOBAIS e sobrevivem entre pacotes.
> Sem este clear, as particulas do pacote anterior (emitidas pelo
> materialize das cartas dele, na COR dele) continuam vivas e aparecem no
> frame do proximo — o Espectral saia com pontinhos ambar do Bufao
> espalhados pela tela. Contaminacao do tool, nao do jogo: numa partida
> real so existe um pacote aberto por vez.

## L217-219 (em `drawScene`, junto a `local function shoot(screen, path)`)

> Renderiza a cena num canvas e grava. Canvas em vez de captureScreenshot
> porque este ultimo so entrega UM frame por execucao — com canvas dá pra
> gerar a sequência inteira numa rodada só.

## L231-233 (em `shoot`, junto a `local function runShelf(keepGoing)`)

> PRATELEIRA: os 5 sleeves lacrados, linha de cima em repouso e linha de
> baixo com hover forcado. É a única captura que mostra a melhoria do item
> parado na loja (halo, cantoneiras, faíscas, respiração).

## L244 (em `runShelf`, junto a `love.graphics.setColor(0.20, 0.16, 0.12, 1)`)

> Fundo sépia da loja (o sleeve tem que se destacar DISSO).

## L249-257 (em `runShelf`, junto a `local ROWS = {`)

> 3 linhas de comparacao. A ultima existe pra decidir NO OLHO se o booster
> shader (efeito pre-existente, que tinge e passa um sweep por cima da
> ilustracao) ajuda ou atrapalha — a doutrina desta rodada e parar de
> cobrir a arte, e o shader tambem e uma camada sobre ela.
> Duas linhas. A comparacao "com shader" saiu daqui depois que o default
> virou arte pura: o shader foi REESCRITO apos aquela decisao (faixa
> estreita no lugar do filme), entao a linha nao demonstrava mais o que
> levou a descarta-lo -- so confundiria quem abrisse o PNG. Quem quiser
> reavaliar usa `love . screenshot_packopen sheen`, que forca shader=true.

## L290-298 (em `ROWS`, junto a `local SHEEN_PHASES = { { name = "repouso", y = 80, phase = 5.0 },`)

> DIAGNOSTICO DE SHEEN: desenha os 5 sleeves em ESCALA 1:1, em posicoes fixas
> e conhecidas, com o shader ligado. Como 1:1 + nearest nao reamostra nada, da
> pra recortar o retangulo exato e comparar PIXEL A PIXEL com o PNG de origem
> que e o teste objetivo de "o foil esta lavando a arte?". As coordenadas
> estao no print pra ferramenta externa recortar sem adivinhar.
> Duas fases CONGELADAS do ciclo de foil (ver shaders/booster.glsl):
> repouso  = 70% do tempo, quando nao ha faixa nenhuma -> tem que sair
> IDENTICO ao PNG de origem;
> passagem = o instante em que o reflexo cruza o meio -> e o pico permitido.

## L303-307 (em `runSheen`, junto a `_G.gameSettings = _G.gameSettings or {}`)

> Congela a respiracao idle: ela reescala o sleeve em +-1.2%, o que
> REAMOSTRA a arte e desalinha os pixels em ~1.5px. Sem isso a medicao
> "quanto o shader desviou da arte" mede interpolacao, nao shader.
> (Diagnostico historico: o shader esta DESLIGADO por padrao desde Set/2026,
> entao este modo so serve pra reavaliar a decisao com shader = true.)

## L336-337 (em `runSheen`, junto a `local function forceHover(screen, idx)`)

> Forca o estado de hover numa carta. O tool nao move o mouse do SO, entao
> marca a flag que Card:updateMouse marcaria e replica o crescimento do hover.

## L345-347 (em `forceHover`, junto a `local WINDOW_SWEEP = { {1024, 768}, {1024, 600}, {1280, 540} }`)

> HOVER: o unico modo que mostra a faixa de info. Varre alturas de janela
> porque o defeito relatado pelo dono ("tooltip muito em cima") so aparecia em
> tela baixa -- validar so em 1024x768 nao provaria nada.

## L360-362 (em `runHover`, junto a `for _, dim in ipairs({ {1024, 768}, {1280, 540} }) do`)

> Pacote de 5 cartas: packCardScale encolhe a fileira, entao rowTop muda e
> a faixa de info tem que continuar bem posicionada. E o caso de borda mais
> facil de esquecer, porque o pacote padrao tem 3.

## L375-384 (em `runHover`, junto a `local Layout = require("src.ui.PackChoiceLayout")`)

> ===========================================================================
> MATRIZ DE ESTADOS da tela de escolha
> ===========================================================================
> A tela tem MUITO mais estados do que "aberto". Cada combinacao de hover,
> selecao, quantidade de escolhas restantes, numero de cartas, reducedMotion e
> tamanho de janela e um estado que pode quebrar sozinho. Capturar todos e o
> que faz defeito aparecer sem precisar de sorte -- foi assim que apareceram a
> etiqueta ilegivel e o nome em idioma trocado.
>
> Cada entrada: { nome, fn(screen) que prepara o estado, [janela], [size] }

## L429-432 (em `runStates`, junto a `local tw, th2 = (win and win[1] or ow), (win and win[2] or oh)`)

> setMode SO quando o tamanho muda de fato, e limpando o cache de
> canvas das cartas: trocar o modo de video invalida o CONTEUDO dos
> canvases, e CardFrame devolveria o canvas vazio do cache (a carta
> some e sobram so selo e moldura).

## L445-448 (em `runStates`, junto a `for _ = 1, 10 do`)

> ORDEM IMPORTA: assentar PRIMEIRO, preparar o estado DEPOIS.
> screen:update() chama card:updateMouse() com o mouse REAL do SO, que
> zera o isHovered forcado -- fazer o prep antes dos ticks apagava
> justamente o hover que o estado queria capturar.

## L456-457 (em `runStates`, junto a `local sw, sh = love.graphics.getDimensions()`)

> VALIDACAO GEOMETRICA: prova que nenhuma zona invade outra, em vez de
> confiar no olho. E o teste que o layout por acumulacao nunca teve.

## L474-482 (em `runStates`, junto a `local function runGrow()`)

> ===========================================================================
> NASCER GRANDE != CRESCER
> ===========================================================================
> Toda validacao anterior criou a tela JA no tamanho final, o que nunca
> exercita o caminho do bug do dono (abrir numa janela pequena e dar
> fullscreen). Este modo faz a tela CRESCER de verdade e compara o resultado
> com uma tela NASCIDA no tamanho grande: se o resize estiver completo, as
> duas imagens sao praticamente identicas. Qualquer diferenca e layout que
> ficou para tras.

## L485 (em `runGrow`, junto a `local SMALL = { 800, 600 }`)

> Nunca pedir janela maior que o desktop: setMode trava.

## L495-496 (em `setSize`, junto a `end`)

> NAO limpa cache de proposito: o objetivo aqui e REPRODUZIR o que
> o jogo faz de verdade no love.resize.

## L512 (em `settle`, junto a `setSize(BIG[1], BIG[2])`)

> (B) MESMA tela, agora cresce -- e o caminho do dono (tecla f)

## L569-575 (em `M.run`, junto a `if mode == "resizeflow" then`)

> ── RESIZEFLOW: o teste que faltava. NASCER grande != CRESCER. ──
> O dono: "quando o jogo esta aberto numa janela pequena e eu dou full
> screen, essa tela e toda desconfigurada". Todas as validacoes anteriores
> criavam a tela JA no tamanho final, o que nunca exercita o caminho do
> bug: layout cacheado no :show() de um tamanho e reaproveitado noutro.
> Aqui abrimos pequeno, avancamos ate assentar, e SO ENTAO mudamos o
> tamanho e chamamos resize() -- exatamente o que love.resize faz.

## L578-580 (em `M.run`, junto a `local FLOW = {`)

> Tamanhos deliberadamente ABAIXO da area util do desktop: pedir uma
> janela maior que a tela trava o setMode em algumas configuracoes de
> Windows (foi o que aconteceu na 1a versao deste modo, com 1920x1080).

## L658-661 (em `FLOW`, junto a `local last`)

> ── Folha de contato: 5 tipos, mesma fase, um PNG cada. ──
> Renderiza num canvas por tipo (em vez de captureScreenshot, que só
> captura UM frame por execução) — assim os 5 saem de uma rodada só e
> dá pra abrir os arquivos lado a lado.

## L671 (em `FLOW`, junto a `if last then`)

> Mostra o último na janela só pra não piscar em preto antes de sair.

