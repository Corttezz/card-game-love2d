# Revisão independente: corte 12 (trailer)

_Revisora, 03/11/2026. Read-only._

_Arquivos:_
- _principal: `grimoire_trailer_c12_720p.mp4` (69,6 s, 4174 quadros);_
- _variante: `grimoire_trailer_c12_loja_720p.mp4` (72,6 s, 4354 quadros);_
- _stems de música: `*_music.f32` (estéreo, 48 kHz), com o ganho de `*_gain.txt` aplicado (+8,7 / +8,8 dB);_
- _base de comparação: `grimoire_trailer_c11g_rei_720p.mp4` (11g rev 2)._

_Pedido do Daniel: `E:\dev\_orquestracao\tdz_c12.txt`, bloco `<decision>`. Registro: `corte12.md` (4060bbd5)._

_O que medi:_
- _`ebur128=peak=true` no 720p final;_
- _RMS do stem de música em janelas de 20 ms e 0,25 s;_
- _RMS do mix por seção contra o 11g;_
- _folhas a 1, 3, 4 e 5 quadros/s (filme, portão e porta, loja);_
- _texto 1:1 contra o 11g;_
- _luma por quadro, bitrate._

_Evidências em `C:\Users\corte\AppData\Local\Temp\rev12\`. Não ouvi._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.**

## Veredito

| versão | nota | resultado |
|---|---|---|
| **principal** (sem loja) | **9,4** | **PASS** |
| variante com loja | 8,8 | piora o filme; não usar |

O corte vai com a versão principal. A variante é um A/B opcional pedido pelo Daniel ("só se ficar melhor de verdade"), e ficou pior. Por isso ela não reprova o corte: recomendo descartá-la.

## Pontos do Daniel

| # | pedido | resultado |
|---|---|---|
| 1 | música do Rei-Carniça, versão única | **Feito.** Só a faixa do Rei. A montagem dos salões continua nos ataques fortes (a mesma do 11g Rei, grave de +16 a +41 dB). |
| 2 | portão: música abaixando até zero, só o castelo abrindo; entrada do chefe com o som dela, sem música; depois a luta como no 11g | **Feito.** Stem de música (RMS de 0,25 s): −9 a −20 dBFS até 44,75 s, depois **−42 (45,00) → −57 (45,25) → −70 (45,50) → −102 (45,75)**. Do portão ao fim da entrada (45,68 a 50,66 s): **máx. −95,7 dBFS**, mediana −103. O mix nesse trecho fica em −22 a −10 dB (portão, porta e a entrada do Rei com rasante e cartão), então não há buraco de silêncio. A porta abre na tela (o arco escurece quadro a quadro). A música volta em 50,71 s, no primeiro quadro da luta. **Ressalva:** a descida dura ~0,75 s, no fim do último salão. Ele disse "vai ficar abaixando". Um fade de 1,5 a 2 s, começando no meio do ROT COLOSSUS, leria mais como "abaixando" do que como corte. Não reprovo. |
| 3 | final sem música, só os sons da animação | **Feito.** Depois do golpe, o stem cai de −23 (59,5 s) para < −50 em 61,25 s e para −98 em 62,75 s. Do preto ao fim do logo (62,70 a 69,50 s): **máx. −96,2 dBFS**, mediana −108. O mix no logo fica em −16 a −43 dB, só os sons da animação, com nível total igual ao 11g (−22,3 contra −21,8 dB). |
| 4 | loja (opcional, só se ficar melhor) | **Testada e pior.** Ver a seção da variante. |
| 5 | textos mais evidentes, sem ficar estranhos | **Feito.** Lado a lado com o 11g (`txt.png`), "BUILD A LIVING DECK." está maior, com a faixa escura mais forte atrás, sem tapar a ação, na mesma fonte. Mesma redação, "SIX BOSSES." mantido. "ONE HAND CAN BREAK A KING." agora fica ~3,2 s e é legível. Não fica estranho. |

## Critérios de aceite

| item | principal | loja |
|---|---|---|
| a) loudness / pico real (`ebur128` com peak=true, resumo) | **I −14,1 LUFS, LRA 12,0 LU, Peak −1,2 dBFS** | I −14,1 LUFS, LRA 11,7, Peak −1,2 dBFS |
| b) música < −50 dB, do portão ao fim da entrada | 45,68 a 50,66 s: máx. −95,7 | 48,68 a 53,66 s: máx. −92,7 |
| b) música < −50 dB, no final inteiro | 62,70 a 69,50 s: máx. −96,2 | 65,69 a 72,49 s: máx. −96,1 |
| c) golpe letal sobre a música (pico de 100 ms contra a música de 2,5 a 0,5 s antes, minha janela de sempre) | **+16,7 dB** (11g: +12,8) | +16,6 dB |
| c) morte nas cartas, mesma janela | **+15,5 dB** (11g: +9,6; 11f: +3,6) | +15,4 dB |
| d) escala e logo | Sem zoom: só a TV ligando, o glitch de 27,4 s e o rasante do jogo, os mesmos avisos do 11g. Logo com 390 de 390 quadros, 1,36/255 do 11g. Quadros < 5% de luma: 135 (TV, fundo do logo, rabo final). | igual; 136 quadros escuros |
| e) textos | ok (acima) | ok |
| f) portão sem o HUD 70/70 | **ok:** o portão começa limpo, sem HUD, nas folhas a 4 e 5 quadros/s | ok |
| bitrate 720p | 13,8 Mb/s | 13,5 Mb/s |

## A mixagem nova deixou cartas e Coleção baixas demais?

**Não.** Ficou um pouco mais baixa, mas dentro do aceitável. RMS por seção contra o 11g rev 2:

| seção | c12 | 11g | diferença |
|---|---|---|---|
| atos (3 a 15 s) | −25,9 | −24,0 | −2,0 dB |
| cartas | −16,6 | −14,9 | −1,6 dB |
| Coleção | −21,4 | −19,7 | −1,7 dB |
| criaturas | −15,9 | −15,3 | −0,7 dB |
| salões | −14,1 | −15,6 | +1,5 dB |
| luta | −11,0 | −13,2 | +2,3 dB |

O registro da diretora fala em "~4 dB". Pela minha medida, são 1,6 a 1,7 dB nas cartas e na Coleção. O arco ficou mais claro: começa calmo e cresce até a luta (LRA 12,0). Como o golpe das cartas ficou bem mais forte que no 11g (+15,5 contra +9,6 dB), a seção não perdeu impacto. Se o Daniel achar baixo no fone, +1,5 dB na cama das cartas e da Coleção resolve sem mexer no resto.

## Variante com a loja

**Piora o filme.**
- São 3 s (29,4 a 32,4 s) de uma prateleira de loja **parada**: a mesma composição em 9 quadros seguidos da folha, sem compra, sem mão, sem movimento. Fica entre as cartas grandes da Coleção e o Espantalho, um trecho que hoje sobe em energia.
- A música da loja interrompe a faixa do Rei. O mix fica em −22 a −26 dB, com um pico de −14, e o filme dá uma "parada" no meio da subida.
- A loja do jogo é um bom argumento de venda, mas só funcionaria com ação: comprar uma carta, a carta voando para o deck, o ouro descendo. Uma prateleira estática não serve.
- Não reprova o corte, porque era um teste opcional. **Nota 8,8**, e a recomendação é não usar.

## A) Notas por ponto do feedback (principal)

| # | ponto | 11g rev 2 (Rei) | c12 |
|---|---|---|---|
| 1 | textos | 9 | **9,5** |
| 2 | abertura dos seis atos | 9,5 | 9,5 |
| 3 | qualidade de imagem | 9,5 | 9,5 |
| 4 | chefes no ritmo | 9,5 | 9,5 |
| 5 | sensação épica (silêncio no portão e entrada só com o som do chefe) | 9,5 | **9,5** |
| 6 | jogar cartas satisfatório | 9,5 | 9,5 |
| 7 | coleção | 9,5 | 9,5 |
| 8 | entradas, Espantalho | 9 | 9 |
| 9 | final do Grimoire (agora só com os sons da animação) | 10 | 10 |
| 10 | geral | 9,5 | 9,5 |
| — | continuidade de números | 9,5 | 9,5 (luta e cartas são as mesmas tomadas e cortes do 11g; só o portão mudou) |

Nenhum critério caiu em relação ao 11g rev 2. Os textos subiram e os dois golpes de morte ficaram mais fortes.

## Recomendações (não seguram o PASS)

1. A descida da música antes do portão poderia durar 1,5 a 2 s em vez de ~0,75 s, para ler como "abaixando".
2. Descartar a variante com loja. Se a loja voltar, só com ação (compra, carta voando, ouro).
3. Se o Daniel achar as cartas e a Coleção baixas, subir +1,5 dB só na cama delas.

**Não publicável até trocar ou licenciar os SFX.** Ninguém ouviu as mixagens, e o julgamento final de gosto é do Daniel.

===CORTE12_PRONTO===
