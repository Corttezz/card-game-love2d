# Realismo do cenário do ato 1: pesquisa e brief visual

Data: 18/Out/2026. Frente "realismo-cenario". Base: main `9a418a04`.

## 1. O que as referências fazem (com números)

### Perspectiva atmosférica em pixel art (Raymond Schlitter, Pixelblog 11 e 62)
- A cena é construída em PLANOS. O plano mais próximo é o mais saturado e tem o maior contraste luz/sombra; cada plano que recua perde saturação e ganha a cor do céu.
- Matiz: em céu azul claro, o verde da grama próxima é o mais quente; os planos seguintes caminham para o azul. Em floresta (distância implícita curta), o deslocamento é menor e pode ir para o amarelo da borda iluminada.
- Detalhe por plano: plano próximo tem lâminas de grama individuais e um tom escuro a mais; o seguinte tem tufos de 1 a 2 px; o terceiro não tem lâmina nenhuma. A mesma regra vale para nuvens e árvores: as de longe reaproveitam o verde de sombra das de perto e perdem o contorno interno.
- Sombra das montanhas distantes reaproveita um tom do céu (mais azul e mais escura que a luz local).
- Uma faixa de névoa na base das montanhas funde a montanha ao chão.
- Paleta de 15 a 16 cores na cena inteira: o longe usa MENOS cores que o perto.
- Valores que extraio para três planos (céu azul-acinzentado, luz quente): saturação 100 % / 75 % / 50 %; contraste 100 % / 80 % / 60 %; matiz puxado ao céu 0 % / 15 % / 35 %; tons por elemento 4 a 5 / 3 / 2.

### Desafio PixelJoint "Atmospheric perspective" (regras do concurso)
- Cada camada que recua: menos detalhe, menos saturação, menos contraste, matiz puxado para a cor do meio (água azul = azul).

### Sombra e luz em pixel art (fóruns PixelJoint, Pixnote, Aseprite)
- Sombra muda de MATIZ, não só de valor: sombra esfria (azul, verde, roxo), luz esquenta. Baixar só o brilho fica chapado e sujo; baixar saturação na sombra fica lama. Sombra = mesma saturação ou um pouco mais, matiz frio, valor mais baixo.
- Direção de luz CONSISTENTE na cena inteira é a regra número um.
- Número de degraus por tamanho: 2 (16 px), 3 (32 px), 4 a 5 (64 px ou mais).

### Árvore (tutoriais de shading de árvore, paintovers do PixelJoint)
- Copa em tufos (blobs), nunca uma massa única; cada tufo tem lado iluminado e lado em sombra; os tufos mais perto do tronco ficam em sombra, os do topo na luz.
- O tronco escurece logo abaixo da copa (a copa projeta sombra sobre ele) e na base.
- Vãos mais escuros (entre tronco e folhagem) ficam limpos, sem dither.
- Sombra de floresta não vai ao preto: luz rebatida preenche.

### Graveyard Keeper (artigo técnico do programador)
- Sombra = sprite da silhueta girado em torno do pé, muito achatado na vertical; cor preta, sem skew (testaram e tiraram). Até 4 sombras por objeto (sol + 3 luzes).
- Luz pontual: sprite tem normal map; se a luz está na frente, ilumina; se atrás, cai rápido.
- Dia/noite: ambiente mais escuro e azulado à noite, 10 LUTs por hora do dia; a INTENSIDADE das luzes pontuais também muda com a hora.

### Octopath Traveler / HD-2D (entrevistas Square Enix e Unreal)
- Profundidade vem de CAMADAS com luz própria, sombras projetadas por luz pontual, profundidade de campo (desfoque no longe e no muito perto) e vinheta. O olho lê "longe" por: menos nitidez, menos contraste, cor do ambiente.

### Luz de fogueira em pixel art (guias de fogo)
- A chama vende pelo que ilumina: halo quente na parede atrás, chão tingido de laranja, borda quente nos objetos próximos virados para o fogo. Rampa da chama: núcleo quase branco, laranja, vermelho na borda, nunca marrom.

### O que o próprio projeto já aprendeu (memory/lighting_engine.md, worldroad_scene.md)
- Luz em pixel art se DESENHA na paleta; gradiente translúcido colado em silhueta lê como sujeira. Poça de chão posterizada com dither é aceita (padrão Stardew).
- Fade atmosférico em pixel art opaca = brilho/cor, nunca alpha.
- Sombra composta por MULTIPLICAÇÃO com a cor de sombra do bioma (já em vigor): escurece sem pintar roxo.
- O jogo real roda com hora do dia entre 0,62 e 1,0 (entardecer progressivo por andar). A captura "dia" (tod 0) é artefato da ferramenta: julgar pelo "meio" e pelo "pôr do sol".

## 2. Diagnóstico medido (18/Out, `tools/preview_out/realismo/01_diag/`)

| medida | valor | leitura |
|---|---|---|
| sol dos campos | `celestial.xr = 0.79` (alto, à direita) | sombras caem para baixo e para a esquerda; o lado iluminado da copa é o direito |
| `fields_tree_0` | lum copa esq 39 / dir 49; topo 58 / embaixo 26 | iluminada da DIREITA e de cima; raízes visíveis |
| `fields_tree_1` | esq 51 / dir 49; topo 65 / embaixo 39 | luz de cima, sem lado; raízes + capim na base |
| `fields_tree_2` | esq 48 / dir 39; topo 57 / embaixo 33 | iluminada da ESQUERDA (contrária ao sol) |
| espelho (`PropVariation.flip`) | aleatório | metade das árvores com o lado iluminado contra o sol |
| árvore em t=1 / 0,5 / 0,22 | 400 a 560 px / 180 a 200 px / 90 a 100 px | proporção por distância correta (`persp`) |
| poste (`lantern.size`) | 4,2 contra árvore 4,6 | poste de 2,5 m com a altura de uma árvore de 10 m: errado |
| sombra projetada (tod 0,5) | ×0,73 no pé, ×0,84 na ponta | em grama escura quase não aparece |
| névoa de profundidade | `fogCurve 2,4` | só os últimos 25 % de profundidade recebem névoa; árvore em t=0,5 tem a cor cheia |
| poça da fogueira | radiusK 0,55 × intensidade 0,55×0,55 | menor que no "antes" |

## 3. Brief visual do ato 1 (campos) por plano

Convenção: t é a profundidade do WorldRoad (0 = crista, 1 = base da tela). Planos: PERTO t > 0,6; MEIO 0,3 a 0,6; LONGE < 0,3.

| elemento | PERTO | MEIO | LONGE |
|---|---|---|---|
| árvore: cor | cor cheia, saturação 100 %, contraste 100 % | saturação ~80 %, brilho ~92 %, 8 a 10 % de névoa | saturação ~55 %, brilho ~78 % (pôr do sol: mais escuro, não mais claro), 25 a 35 % da cor da névoa |
| árvore: detalhe | sprite cru, nítido | sprite cru | sprite SUAVIZADO (meia resolução): sem tufo individual |
| árvore: luz | lado iluminado virado para o sol (direita), copa com topo claro e embaixo escuro | idem | silhueta: o lado some, só massa |
| árvore: sombra no chão | silhueta da copa, 3 degraus, forte no pé (×0,55 a 0,62), diagonal para baixo-esquerda | mesma forma, mais curta | quase nenhuma (uma faixa de contato) |
| árvore: base | faixa de contato escura mais larga que o tronco, tufos de grama na frente da raiz | faixa fina | nada |
| poste | ~2,5 m: ~55 a 65 % da árvore adulta; sombra de haste nítida | idem | só a luz |
| chão | textura e grama com lâminas, tom mais claro | lâminas pequenas, tom médio | sem lâmina, mais ESCURO e um pouco mais azul (pedido do dono) |
| fogueira | poça quente no chão (raio ~2 larguras do círculo de pedras), grama e troncos vizinhos tingidos de laranja, chama com brilho | | |

## 4. Fontes
- https://slynyrd.com/blog/2018/11/16/pixelblog-11-landscape-pixeling
- https://www.slynyrd.com/blog/2026/5/27/pixelblog-62-landscape-backgrounds
- https://pixeljoint.com/2024/06/10/6979/submit_news.asp
- https://gamedeveloper.com/programming/graveyard-keeper-how-the-graphics-effects-are-made
- https://www.unrealengine.com/en-us/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style
- https://pixnote.net/en/learn/shading
- https://community.aseprite.org/t/how-do-i-make-cohesive-color-palettes-on-aseprite/7983
- https://www.sprite-ai.art/gallery/fire
- https://www.creativebloq.com/digital-art/how-depict-forest-light-31619667
