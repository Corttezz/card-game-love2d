---
name: Logotipo do trailer no menu (selo + GRIMOIRE) e vinheta de entrada
description: Out/2026, pedido do dono ("adorei o logo do fim do trailer, quero no menu"). Wordmark e selo assados do mesmo codigo do trailer, desenhados em escala inteira; vinheta do trailer na 1a entrada do menu; vida parada sutil. Ideias para o dono no fim.
type: project
---

# Logotipo do menu (src/ui/MenuBrand.lua)

Referencia: ultimos ~5 s de `card-game-trailer/build/trailer/grimoire_trailer_v7_4k.mp4`
(gerado por `card-game-trailer/tools/trailer_brand.py`, classes `Seal` e `Word`).

## O que entrou

- **Arte assada** por `python tools/menu_brand.py` (mesmo codigo do trailer, copiado sem a TV):
  - `assets/branding/wordmark.png` 257x48 = `store_art.logo(1, (6, 4))` (glifo 8 px da fonte do jogo, bloco 6x4, bisel dourado, contorno tinta + sangue seco, sombra).
  - `assets/branding/wordmark_gold.png` mascara do ouro (varredura e carimbo so tocam o ouro).
  - `assets/branding/seal.png` 113x113, o selo-bussola ACESO (estado final).
  - `assets/branding/seal_data.png` 113x113, o selo CODIFICADO para a vinheta: R = indice de paleta (0..6), G = raio 1..8 / 9 = anel+miolo, +16 = cubo, B = posicao ao longo do raio ou angulo do anel, A = instante de revelacao / 1,25.
  - `src/data/menu_brand.lua`: tamanhos, pontas dos raios, cortes das letras, 4 paletas (apagada, acesa, quente, brasa).
  - `python tools/menu_brand.py ref <T...>` grava quadros de referencia do Python; `lovec . test_one screenshot_menu_logo fidelity` compara o shader com eles (0 a 43 de 12.769 pixels divergem, todos na borda de um degrau de tempo por quantizacao de 1/255).
- **Desenho em escala inteira, por ZONAS** (revisto em 25/Out a pedido do dono: "aumenta a fonte, esta muito pequeno"): a coluna de botoes e ancorada no PE da tela (`MenuBrand.buttonColumn`: base a 97,5% da altura, espacamento 9,2% ate 80, altura 8% ate 60; o Menu usa a mesma funcao) e o logo ocupa a banda de 2,5% da altura ate 2% acima de "Continuar" (existindo ou nao, para o logo nao pular). `MenuBrand.layout` escolhe o maior P inteiro para a PALAVRA ate 42% da largura e, para o SELO, a maior escala inteira de P ate P-2 que caiba (`ZONE.sealDrop`). Desenha em coordenadas FISICAS (`scale(1/k)` dentro do UiScale), origem inteira, nearest. Resultado (palavra/selo): 720p 2/1, 1080p 3/2, 1440p 4/3, 4K 6/4 (antes 1, 2, 2, 4 para os dois). O selo fica menor que a palavra; a varredura atravessa os dois com `pxScale` no `brand_seal.glsl`.
- **GRIMOIRE e o nome em todo idioma.** A chave `menu.title` continua existindo (fallback: se a arte nao carregar, o titulo de texto antigo volta, avisado por `Debug.warn`).
- **Vinheta de entrada** (so na PRIMEIRA entrada do menu do processo, depois do boot): mesmos tempos do trailer (`MenuBrand.T`): anel pontilhado fecha, o selo se revela pelo anel, os 8 raios acendem um a um, carga com tremor de 1 px e faiscas convergindo, clarao (o selo em paleta de brasa + pulso de brilho de tela cheia de 0,16 s, sem disco) + 2 aneis de choque finos + brasas, o selo sobe, as letras carimbam uma a uma com quique e poeira, tremor de 1 px quando a ultima pousa, varredura dourada. O fundo do trailer (vinheta roxa pontilhada) cobre o menu ate o clarao e o cenario do menu entra em 0,8 s depois dele. Botoes entram a partir de 3,95 s (depois das letras pousarem), um a cada 0,08 s.
  - Shaders: `shaders/brand_seal.glsl` (a funcao `Seal.render` do trailer pixel a pixel), `shaders/brand_word.glsl` (carimbo branco/brilho + varredura), `shaders/brand_fx.glsl` (fundo, aneis e clarao numa passada de tela cheia, so durante a vinheta, com Bayer 4x4 na grade da arte).
  - Faiscas, brasas, poeira: retangulos de 1 px de arte em Lua.
  - Custo: 4 PNGs (~15 KB em disco, ~200 KB de textura) + 2 texturas minusculas; carga lazy no 1o desenho. Nada de quadros assados.
  - **Pular**: qualquer tecla, clique ou botao do controle (`Menu:skipIntro()`, chamado no topo de `love.keypressed/gamepadpressed/mousepressed` no estado menu e no `Menu:mousepressed`). O pulo consome a entrada (nao aciona botao) e cai no MESMO quadro final da vinheta completa (`test_menu_brand`).
  - `reducedMotion`: sem vinheta, logo no estado final parado; se ligar no meio, a vinheta termina na hora.
  - Som: `bootElectric` (2,55 s) e `bootImpact` (no clarao), os mesmos do trailer v7, mais baixos. Musica do menu comeca na entrada como antes (`test_music_flow`).
- **Selo grande na fase escura** (revisao do lead, 24/Out): de 0 a 2,86 s o selo e os aneis/faiscas/brasas sao desenhados numa grade propria com escala 2P (`MenuBrand.stingScale`, limitada a 62% da altura), o mesmo tamanho de tela do trailer; na subida o selo encolhe em degraus inteiros ate a escala final do selo junto com o movimento; a escala da fase escura e fixa pela altura da tela (`MenuBrand.STING_SEAL_H` = 42%, a mesma do trailer), nao depende do tamanho final (centro interpolado, origem inteira).
- **Sem carimbo duplo**: quando a vinheta vai tocar (`MenuBrand.stingPending()`), o splash do boot NAO monta as letras do titulo nem dispara flash/impacto/tremor; termina 0,35 s depois das cartas. Se a vinheta ja tocou ou ha `reducedMotion`, o splash segue como antes. Trava em `test_menu_brand`.
- **Sem disco de luz** (dono): o disco branco pontilhado do trailer (`flashT`) e o selo todo branco no 1o quadro do clarao SAIRAM.
- **Voltar ao menu** (fim de run, Colecao): NAO repete a vinheta. Versao curta: o fade de sempre e UMA varredura dourada 0,35 s depois. Decisao: a vinheta tem 4 s ate os botoes; repetir a cada volta cansa, a varredura diz "o mesmo logo" sem atrasar.
- **Vida parada** (sutil, so pixel, sem disco nem anel): varredura dourada a cada 8 a 12 s pela palavra e pelo selo; brilho em cruz numa ponta de raio a cada 1,4 a 3,2 s; 16 brasas lentas subindo em volta do logo (ciclo do trailer, piscando). Tudo some em `reducedMotion`.

## Travas

- `love . test_one test_menu_brand`: vinheta so na 1a entrada; tecla e clique pulam e consomem; pular = mesmo quadro do fim natural; reducedMotion parado por 13 s; varredura a cada 8 a 12 s; em 6 resolucoes: P inteiro, origem inteira, cabe acima do 1o botao e na metade da largura, palavra em blocos PxP uniformes.
- Capturas: `CARDGAME_HEADLESS=1 lovec . test_one screenshot_menu_logo <rotulo>` (4 resolucoes, `tools/preview_out/menu_logo/<rotulo>_WxH.png`), `... sting:1920x1080` (quadros a 20 fps), depois `python tools/menu_logo_sheet.py 1920x1080` (folha, GIF por ffmpeg, comparacao lado a lado com o trailer).

## Pontos fracos conhecidos

- Na subida o selo pula de escala em degraus inteiros (em 1080p: 4 → 3 → 2), nao e um encolhimento continuo; e o preco de manter o pixel nitido.
- A palavra continua no tamanho do menu (P), menor que no trailer; so o selo cresce na fase escura.

## Ideias para o dono (nao implementadas)

1. (feito em parte) o splash do boot ja nao carimba o titulo quando a vinheta vem; falta decidir se o splash inteiro (cartas sugadas) ainda faz sentido antes da vinheta.
2. Mesmo wordmark (sem selo) no topo do Pause, nas telas de vitoria/derrota e nos creditos.
3. Capsulas da Steam e icone da janela gerados a partir de `wordmark.png`/`seal.png` (ja e a mesma arte do `store_art.py`).
4. Botao do menu em hover ganha um brilho em cruz na borda (o mesmo `sparkle` das pontas dos raios).
5. O selo pequeno como marcador do NavCursor / item selecionado no menu (gira 1/8 a cada passo).
6. Tela de carregamento: so o selo com os raios acendendo como barra de progresso (8 raios = 8 etapas).
7. Varredura dourada no logo sincronizada com o primeiro tempo forte da musica do menu.
