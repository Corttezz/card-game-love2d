# Testes do CRT (20/Out/2026)

Nada disto está no jogo. Batalha real do Ato 1, 1920x1080, hora 0.85, Espantalho Amaldiçoado, 5 cartas na mão, HUD completo, CRT no nível "normal" (força 0.75). Gerado por `lovec . test_one screenshot_crt_variantes`; shaders em `tools/crt_variants/`.

Arquivos: `<variante>.png` (tela cheia), `folha_contato.png` (todas lado a lado), `recorte_canto_*` e `recorte_centro_*` (2x), `recortes_*_todos.png` (o mesmo recorte de todas numa folha, inclusive as cartas), `sem_crt.png` (a cena crua).

## O que o CRT faz hoje
Moldura de plástico de 20 px com 4 facetas e lábio iluminado, canto quase reto (raio 0,012), domo leve, aberração cromática só horizontal (cerca de 1 px no centro, 3 px no canto), halo de 4 amostras quase invisível, scanline senoidal de 2,6% (some na prática), grade RGB de 3 px com ±4%, vinheta leve, sombra do vidro no topo, ruído e flicker de menos de 1%. O "surto" ocasional e a zona calma da loja não entram nestas fotos.

O que mais denuncia que é falso:
1. **Cunha preta nos cantos**: a imagem curva se afasta da moldura e sobra uma faixa preta chapada entre a imagem e o plástico (fica pior no canto). Em TV de verdade a moldura encosta na imagem.
2. Canto do tubo reto demais; tubo real tem canto bem arredondado.
3. Scanline e máscara fracas a ponto de não existirem, e iguais no centro e na borda.
4. Sem desfoque nem erro de convergência na borda (é onde o tubo real perde foco).
5. Sem reflexo da imagem no chanfro da moldura, sem reflexo no vidro.
6. Brilho do fósforo (halation) imperceptível; lanterna e cartas não "sangram" luz.

## Variantes (uma ideia cada, forte nas bordas, centro legível)
- **atual**: referência. Limpo e legível; lê como "filtro" e não como TV por causa da cunha preta e da textura que não aparece.
- **A_bezel_curvatura**: moldura mais grossa (34 px), canto arredondado de verdade, curvatura maior e a imagem refletida (borrada) no chanfro da moldura, mais sombra funda na beira do vidro. Pró: a moldura ganha profundidade. Contra: puxa a interface para dentro e a cunha preta continua; o painel de Coringas encosta na curva.
- **B_mascara_aperture**: grade de abertura RGB de verdade + scanline cuja largura muda com o brilho, fraca no centro (22%) e forte nas bordas (85%). Pró: é a textura que todo mundo reconhece como CRT, dá para ver no recorte 2x. Contra: escurece um pouco as áreas escuras e em telas menores que 1080p pode gerar moiré; texto da borda fica com "tela" por cima, mas lê.
- **C_halation_bloom**: brilho do fósforo que sangra para os vizinhos escuros (não clareia área chapada), mais largo nas bordas. Pró: lanterna, nomes das cartas e céu ganham o brilho quente de tubo. Contra: borda das cartas e texto pequeno ficam um pouco "macios"; sozinho é sutil.
- **D_convergencia_bordas**: os três canhões desalinham em direção radial (vermelho para fora, azul para dentro, um pouco na vertical), zero no centro, até 6 px no canto. Pró: é o defeito mais "de TV velha" e não toca no centro. Contra: no canto o texto do painel de Coringas e a moeda ficam com franja colorida visível; não dá para usar mais forte que isso.
- **E_vinheta_desfoque_bordas**: o foco cai e a vinheta escurece só perto das bordas e cantos, com leve perda de cor. Pró: puxa o olho para o centro (inimigo e mão), muito natural. Contra: HUD dos cantos (vida, mana, Coringas, engrenagem) fica mais escuro e borrado; o dono já reclamou disso uma vez (v3.7).
- **F_vidro_reflexo**: reflexo suave de uma janela no canto superior esquerdo, borda do vidro clareada (fresnel), linha de brilho na curva do topo e preto um pouco levantado. Pró: dá o "vidro na frente". Contra: discreto demais no céu claro do Ato 1; o reflexo só aparece nas partes escuras.
- **G_forte_combinado**: H + B + C + D + E + F com intensidades menores e curvatura maior. Pró: é a que mais parece uma TV de verdade. Contra: cantos da interface mais escuros e borrados, interface empurrada para dentro; exigiria atualizar `CRTShader.screenToContent` (curvatura nova) e retestar o clique nas bordas.
- **H_moldura_segue_imagem**: mesma curvatura e mesma imagem de hoje, mas a abertura da moldura passa a acompanhar a borda curva da imagem, com canto arredondado e o reflexo da imagem no chanfro. Pró: mata a cunha preta, que é o defeito que mais denuncia; centro idêntico ao atual e o mapeamento do mouse não muda. Contra: a moldura fica mais larga no meio de cada lado (é a própria curvatura de hoje aparecendo).

## Minha recomendação
**H como base** (resolve a borda sem mexer em nada que se lê) **+ B moderada** (a textura de tubo, forte só na borda) **+ D bem leve no canto**. Se quiser mais "TV", somar um pouco de E só nos cantos extremos, sem escurecer os painéis de vida e mana. C e F são tempero: valem pouco sozinhos. G mostra o teto, mas custa legibilidade na borda.
