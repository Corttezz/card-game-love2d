# Revisão: corte 2 (trailer-do-zero)

_Revisora independente, 01/11/2026. Base: `corte2.md` (17:30, commit `fb606ea4`), `revisao-grimoire-corte1.md` (7 pontos) e `E:\dev\_orquestracao\tdz_c2b.txt`. Arquivos: `grimoire_zero_corte2_1080p.mp4` (17:28, regravado depois da 1ª passada), `_720p.mp4` (17:29) e `grimoire_zero_corte2_rei_720p.mp4` (17:26), todos com 64,50 s e 60 fps. O que fiz: medidas quadro a quadro (luma, quadros quase pretos < 5%, cortes, R128 por segundo) com `...\scratchpad\rev\medir.py` (saídas `d3_1080\` e `d2_rei\`); distância de cada clipe e texto ao grave, pela `edl2.py` de cada variante (Tirano com deslocamento 18,0 s; Rei com 2,57 s até o silêncio e 16,10 s depois); quadros em resolução cheia e folhas da abertura, dos salões, das correntes, da Geada, da caminhada, do golpe e da entrada no escuro (`...\rev\g2\`). Não ouvi o áudio._

## Rodada 1, NÃO APROVADO (principal e variante)

O corte 2 resolveu o que o Grimoire apontou de mais grave. **A luta do Rei agora é contínua** do nome à morte (39,44 a 56 s). **Os salões do Higgsfield se leem como salões**: o trono de lava com o crânio de chifres, o salão de gelo e o trono em chamas com uma pena passando, todos marcantes. O **quadro 0 é o pôster**: o Espantalho inteiro e as 5 cartas com nome. O **golpe final** tem flash, tremor, o Rei inteiro sem cartas na frente e um **47 enorme**. O **LETHAL do gancho** está a ×2, com o painel "40 LETHAL" grande e o flash no JOGAR. Os **textos estão exatos**, com "FROST." e "CHAINS." separados. E o silêncio da entrada chega a −31,3 LUFS de curto prazo, o melhor contraste até agora. Nenhuma troca de faixa, texto ou salão sem aprovação: a principal usa o Tirano, a variante o Rei, os textos são os aprovados e os salões são os do Higgsfield.

O que ainda segura está abaixo, com timestamp.

### Versão principal (Tirano), 1080p e 720p

1. **G1, quadros pretos: 23 quadros (0,37 s) abaixo de 5% de luma, de 34,72 a 35,08 s.** É o salão escuro logo depois do trono em chamas, antes de os olhos acenderem (`g2/preto.png`). É escuridão da cinemática do jogo, não tela desligada, mas o ponto do Grimoire diz "nenhum quadro preto" e a régua que escrevi no adendo do corte 1 é zero quadros abaixo de 5%. **Exijo** levantar o escuro do salão nesse trecho (lift do leito ou começar o `k_escuro` no quadro em que os olhos já brilham), até o pior quadro ficar ≥ 5%. O medo do escuro continua, só deixa de ser preto.
2. **G2, a caminhada tem 4,56 s, não ≤ 3 s.** `k_estrada` (27,99–29,95 s, 1,96 s) + `k_porta` (29,95–32,55 s, 2,60 s) são a **mesma estrada parada** com o castelo ao fundo: na folha a 3 quadros/s (`g2/caminhada.png`) os 14 quadros são quase idênticos, e a porta mal se mexe. Um corte no meio não muda o que se vê. **Exijo** ≤ 3 s no total para estrada + porta (ex.: 1,2 s de estrada + 1,8 s com a porta abrindo de fato, ou o próprio portão a ×2), ou trocar parte do trecho por um plano que avance a ação.
3. **G5, o "47" grande encavala com o banner do jogo.** No congelado (`g2/y_53.0.png`) o 47 fica colado embaixo do "Volley +18", e o banner do COMBO! corta a parte de cima do quadro. São dois números competindo no instante mais importante. **Exijo** o 47 numa área livre (mais abaixo, entre o banner e a coroa, ou o banner fora do recorte nesse quadro).
4. **"FROST." sobre a cabeça do Monarca** (`g2/y_24.0.png`, 22,97–25,20 s): o texto está no rosto e no topo do cajado. O assunto do plano são as cartas congeladas, mas cobrir o rosto do chefe é ruído. Mova para uma zona livre (o terço superior à direita está vazio).
5. **LETHAL no clímax** (ponto central do Grimoire, "LETAL legível"): no arco do Rei, a palavra e os 9 de vida só aparecem no `k_volta` a ×1 por 1,13 s; o ×2 do LETAL (49,1–52,83 s) mostra o Rei, a barra 47/220 e o "−47", mas **não o painel LETHAL nem a vida do herói** (`g2/y_51.0.png`). Para o público geral isso não fecha a conta "9 de vida + LETHAL = virada". **Exijo** o painel LETHAL e o HERO 9/70 legíveis no plano do LETAL, nem que o recorte ×2 se desloque para a direita/baixo em passo inteiro, ou o `k_volta` a ×2 no painel e na vida.
6. **Sincronia, um corte fora do grave:** o espólio começa a 9,60 s, **2,09 s** do grave mais próximo. É o buraco de grave do Tirano entre 7,48 e 11,69 s. Se não houver grave, o corte tem de cair num evento do jogo (a carta virando, o brilho do raro) e isso tem de estar escrito; hoje não está.

### Variante (Rei-Carniça), 720p

Tudo dos itens 1 a 5 vale igual (mesmos planos). E mais:
7. **A volta da música perde o ataque do drop.** A faixa volta a 39,44 s do filme no ponto 55,54 s da faixa, **0,28 s depois** do grave 55,26 s. O impacto de retorno ("para e volta sincronizado") entra sem o golpe de abertura do drop. **Exijo** o ponto de volta no grave (55,26 s, ou o ataque medido do drop), com o cartão do nome no mesmo quadro.
8. **Sete entradas fora do grave**, porque o deslize foi limitado a 0,45 s: cascata 4,18 s (0,46 s), gárgula e "6 ACTS." 11,69 s (0,57 s), salão de gelo 20,82 s (0,49 s), LETAL 49,1 s (0,21 s), coringa 55,96 s (0,48 s), "FROST." 22,95 s (0,70 s) e nome do Rei 39,44 s (0,28 s, o item 7). No 1080p da principal elas estão a 0,0 quadro. Na variante, a regra que o Daniel aprovou no v4 ("cada corte num grave") não vale para esses 7. **Exijo** que cada um caia num grave da faixa do Rei, ajustando a duração dos planos vizinhos (respeitando ≥ 1 s e o tempo de leitura), e não só deslizando até um limite.
9. **Salto dentro da faixa** (de 35,1 para 55,54 s da peça, escondido no silêncio): é a mesma peça, sem emenda de outra faixa, e é exatamente a correção pela montagem que o Grimoire pediu. Não reprovo. Registro como ponto para o Daniel ouvir, porque a regra dele é "uma peça contínua".

### O que está ótimo (não mexer)
- Quadro 0 com o Espantalho inteiro; o gancho a ×2 com "40 LETHAL" grande e o flash no JOGAR (`g2/y_3.0.png`).
- Os três salões do Higgsfield, legíveis e marcantes nos acentos (`g2/quad1.png`).
- "CHAINS." com o intent 20 → 10 e o "Half strike / Chain snapped!" do jogo (16,24–18,54 s).
- A luta do Rei contínua; o silêncio a −31; o pico +2,1 dB (principal) / +2,3 dB (variante); o portão, o pouso e a revelação uma vez cada.
- Loudness −14,1 LUFS, −1,1 dBTP nas três; o 720p da principal idêntico em som ao 1080p.

## Notas por critério (rodada 1)

| critério | principal | variante Rei | por quê |
|---|---|---|---|
| C1 Gameplay ≤ 2 s / quadro 0 | 10 | 10 | pôster com o Espantalho inteiro e a mão |
| C2 Sem preto | **8** | **8** | 23/24 quadros < 5% em 34,7–35,1 s |
| C3 Sincronia | 9 | **7** | principal: 1 corte no buraco de grave (6); Rei: 7 entradas fora do grave e drop atrasado (7, 8) |
| C4 Legibilidade | **8** | **8** | 47 sob o banner (3), FROST no rosto do Monarca (4), LETHAL do clímax pequeno (5) |
| C5 Ritmo | **8** | **8** | 4,56 s da mesma estrada (2) |
| C6 Pico | 9 | 9 | flash, tremor, 47 e queda acompanhada; +2,1/+2,3 dB |
| C7 Regra de 3 | 9 | 9 | Revoada, CHAINS e FROST |
| C8 Fecho | 9 | 9 | — |
| C9 Conformidade | 9 | 9 | sem 4K; textos e salões aprovados; marca "não publicável" |
| C10 Checklist do Daniel | 9 | 9 | variante: salto interno da faixa anotado para ele ouvir |
| C11 Continuidade | 9 | 9 | a luta do Rei inteira; ordem para a frente |
| C12 Está bom / legal de assistir | 9 | 9 | — |
| C13 Prende do início ao fim | **8** | **8** | a estrada parada antes da porta é o único ponto morto |
| C14 Som | 9 | 9 | silêncio −31, sem duplicações, nada de clima externo no castelo |

| ponto do Grimoire | principal | variante Rei |
|---|---|---|
| G1 Nenhum quadro preto (quadro 0 = pôster) | **8** | **8** |
| G2 Caminhada ≤ 3 s, cortes na batida | **7** | **7** |
| G3 Salões do Higgsfield legíveis e marcantes | 9 | 9 |
| G4 Luta do Rei sem interrupção | 10 | 10 |
| G5 Golpe final forte (hit-stop, tremor, flash, número grande, depois a queda) | **8** | **8** |
| G6 LETAL do gancho visível e com impacto | 9 | 9 |
| G7 Textos exatos | 10 | 10 |

**Status: NÃO APROVADO (nenhuma das duas).** Para a rodada 2: itens 1, 2, 3, 4 e 5 nas duas versões; 6 na principal; 7 e 8 na variante. São de montagem, recorte e lift; nada pede regravação nem troca de faixa, texto ou salão. `===CORTE2_PRONTO===` não pode ser marcado.


## Rodada 1b: análise de mixagem de verdade + os 5 pontos do Grimoire do corte 2 (01/11, depois de `revisao-grimoire-corte2.md`)

_Feita sobre os stems reais do corte 2 (`build\trailer\zero2\zero2_tirano\` e `zero2_rei\zero2_rei\`: `stem_music/game_sfx/game_amb/synth.wav` + `mix.wav`), com a EDL de cada variante. Script: `C:\Users\corte\AppData\Local\Temp\claude\E--dev-projects-card-game-love2d\f967decd-bccd-487a-92fd-ff59f9b0ee6d\scratchpad\rev\mixagem.py`; saídas `mix_tirano.json` e `mix_rei.json` na mesma pasta (nível por plano de cada stem, perfil de 100 ms do filme inteiro, onsets).

Método dos onsets: envelope da faixa de graves (30 a 160 Hz) do **stem de música já automatizado**, em janelas de 2 ms. Para cada corte medi a subida do envelope em ±40 ms ("subida no corte") e a maior subida a ±30 ms (≈ 2 quadros). Como referência, uma subida em ponto aleatório fica em −0,4 dB de mediana e 10 dB no p90. Calibração: o `boss-abyss_tyrant_beats.json` cai, em mediana, 33 ms antes do ataque real do grave (p10 a p90 de −107 a +93 ms), ou seja, a grade usada na montagem está certa dentro de ~2 quadros. Ainda não ouvi; isto é medida._

### 1. A música bate nos cortes?

**Principal (Tirano):** sim, na maioria. Os cortes de 11,69 / 16,24 / 18,54 / 26,53 / 27,99 s e o do golpe (52,83 s) caem em cima do ataque (subida de 13 a 71 dB no próprio quadro). Outros nove têm o ataque a ≤ 2 quadros (subida máxima de 18 a 27 dB em ±30 ms), o que é aceitável. **Fora do grave de verdade:** `ia_hall4` (20,82 s: nenhum ataque em ±30 ms, máximo 6,5 dB), `espolio` (9,60 s: 12 dB, fraco, no buraco de grave da faixa) e `k_porta` (29,95 s: 11,6 dB, fraco).

**Variante (Rei):** nos cortes do meio, melhor que a principal: 16 dos 24 têm subida de 33 a 55 dB no próprio quadro (corte num ataque depois de um decaimento). **Fora do grave de verdade:** `e2_gargula` (11,69 s, máximo 8,2 dB), `ia_hall3` (13,07 s, 6,1 dB) e `ia_hall4` (20,82 s, 4,2 dB): os primeiros acentos de salão e o "6 ACTS." não batem em grave nesta faixa. `h_cascata` (4,18 s) e `k_coringa` (55,96 s) ficam fracos (10 a 14 dB).

**Correção da minha rodada 1:** o item 7 (volta da música 0,28 s depois do drop) **está errado e o retiro**. No áudio real, o retorno a 39,44 s tem a maior subida do filme no quadro exato (de silêncio para o drop). A diferença vinha do `_beats.json` da faixa do Rei, que não lista esse ataque. Do item 8 ficam valendo só os 3 cortes acima (`e2_gargula`, `ia_hall3`, `ia_hall4`); os outros quatro estão no grave real.

### 2. O silêncio da entrada do Rei funciona?

**Sim, e é a melhor parte da mixagem.** Perfil de 100 ms (principal; a variante é igual a ±1 dB):
- 30,0 a 32,6 s (porta, groove): mix de −17 a −22 dBFS RMS;
- 32,7 a 33,9 s (salão IA do Rei): a música cai a −∞ em ~0,5 s e o mix vai a **−56 a −75**, quase silêncio digital, por cerca de 1 s;
- 34,0 a 37,2 s (escuro, olhos): **−24 a −36**, só o leito e os olhos/cliques;
- 37,3 a 38,2 s: rasantes a −16/−19; 38,9 s: pouso a −6; 39,44 s: o drop volta, com a música subindo 15,7 dB num quadro (variante: cerca de 35 dB).

O contraste com o groove anterior vai de 15 a 50 dB conforme o trecho: o ouvido percebe a música **sair** e **voltar**. Cumpre a meta. Uma observação: o salão IA do Rei, que na imagem é um acento, fica sem som nenhum. O "leito −14" declarado no `mix_sources` não aparece no mix (−56 a −75). Como silêncio funciona, mas se a ideia era o salão ter um leito, ele sumiu.

### 3. Níveis por trecho: o que mascara o quê

| trecho | música | SFX do jogo | leitura |
|---|---|---|---|
| gancho, LETHAL (2,55 s) | −14 | −18 | música na frente, ok |
| cascata / morte do Espantalho / espólio | −25 a −28 | −21 a −27 | equilibrado |
| **salão do Tirano (13,03 s, acento + EVERY BOSS)** | **−25,7** | **−13,8** | o efeito "parede de fogo" (sintetizado, ganho −4 dB) fica **12 dB acima da música**, e a música **cai 4,8 dB** no corte: o acento do salão é carregado por um ruído, não pela música |
| **salão do Monarca (20,82 s)** | −17,8 | −17,2 | a "tempestade de gelo" (−2 dB) empata com a música, e a música cai 3,5 dB no corte |
| montagem de estradas (atos 2, 4, 5, 6) | −13 a −21 | −38 a −54 | música sozinha, ótimo |
| luta do Rei (guerreiro, Revoada, volta) | −19 a −25 | −15 a −21 | música 2 a 7 dB abaixo dos SFX; aceitável numa luta |
| respiro antes do LETAL (52,3–52,8 s) | **−97** | — | respiro limpo de 0,5 s |
| golpe (52,83 s) | −24 → −14 | **−3 / −1** | impacto forte, mix a −6/−7 RMS; o baque da queda (54,7 s) bate com o corpo no chão |
| coringa (55,96 s) | −27 | −15 | música 12 dB abaixo: a revelação do coringa fica só no SFX |
| variante: nome do Rei | **−25,3** | −29,6 | o drop do Rei entra **8 dB mais baixo** que o do Tirano (−17,4) no mesmo ponto: a volta "com impacto" é mais fraca na variante |

**Achados de mixagem para o corte 3:**
- **M1 (salões):** nos dois acentos de salão a música tem de liderar. O corte deve cair no ataque mais forte da faixa (hoje `ia_hall4` nem cai em grave), e os efeitos "parede de fogo"/"tempestade de gelo" ficam 8 a 10 dB abaixo do nível atual, entrando **depois** do ataque (≥ 60 ms), não junto. Hoje a música chega a cair nesses cortes.
- **M2 (variante, volta do drop):** subir a música da variante 5 a 8 dB a partir de 39,44 s (ou baixar o que está por cima), para a volta bater como na principal.
- **M3 (sincronia):** principal: `ia_hall4`, `espolio` e `k_porta` num ataque real (ou o espólio num evento do jogo, escrito). Variante: `e2_gargula`, `ia_hall3` e `ia_hall4` num ataque real da faixa do Rei.
- **M4 (coringa):** a música está 12 dB abaixo do SFX na revelação; entre 4 e 6 dB abaixo, ela carrega a ponte para o logo.
- **M5 (leito do salão IA do Rei):** decidir se o salão tem leito (hoje inaudível) ou se o silêncio digital é intencional, e escrever.

### 4. Os 5 pontos do Grimoire do corte 2 (nota no corte 2 atual, para guiar o corte 3)

| ponto | nota no corte 2 | o que vi e medi |
|---|---|---|
| N1 virada da luta do Rei legível (9 de vida, Revoada, LETHAL antes do 47) | **5** | é o meu item 5: no ×2 do LETAL (49,1–52,83 s) não aparecem nem o painel LETHAL nem o HERO 9/70, que só ficam no `k_volta` a ×1 por 1,13 s. A Revoada é o plano 44,08–47,97 s, mas nada liga o "Murder of Crows" à vida do herói caindo (o modo deus a segura em 70) |
| N2 caminhada ≤ 1,5–2 s, ou a porta abrindo | **5** | 4,56 s (27,99–32,55 s), com quadros quase idênticos (meu item 2) |
| N3 salões pixelizados na resolução nativa antes do CRT | **6** | concordo com o Grimoire e revejo o meu 9 no G3: o tratamento a 960×540 (pixel de 2 px na tela) tem grão muito mais fino que o salão real (`castle_hall_*`, 400×256 nativos, com pixel de ~4,2 px na tela). Lado a lado, a densidade de pixel denuncia outra fonte. O certo é reduzir à **mesma grade do salão real**, limitar a paleta e ampliar por vizinho mais próximo, mantendo o que a v2 a 960 ganhou em legibilidade (contraste e silhueta do trono) |
| N4 zoom no miolo onde a carta importa (145 LIVING CARDS, luta do Rei) | **6** | no espólio a ×2 as cartas já são grandes, mas a moldura do CRT toma uns 6% de cada lado; na luta do Rei (`k_guerreiro`, `k_letal`) as cartas e o painel ficam pequenos dentro da moldura. **Atenção à regra de câmera** (§5.3 das ferramentas): zoom contínuo com escala não inteira é "cara de IA". O zoom tem de ser um degrau inteiro (×2 → ×3 da captura) por corte seco no grave, ou um recorte ×2 mais fechado, nunca um zoom digital suave |
| N5 mixagem avaliada de verdade | **feito acima** | M1 a M5 são os achados |

### Notas revisadas do corte 2 (com os 5 pontos e a mixagem)

As notas da rodada 1 ficam, com três ajustes: **G3 de 9 para 6** (ponto N3); **C14 Som de 9 para 8** (M1: acentos de salão afogados por efeito, com a música caindo); e, na variante, **C3 de 7 para 8** (retirei o item 7; ficam 3 cortes fora do grave real). Pontos do Grimoire do corte 2: N1 5 · N2 5 · N3 6 · N4 6.

**Status do corte 2: NÃO APROVADO (as duas versões).** O corte 3 tem de trazer N1, N2, N3, N4 e os achados M1 a M5, além dos itens 1, 3, 4 e 6 da rodada 1 (quadros pretos, 47 sob o banner, FROST no rosto, espólio fora do grave), que continuam valendo.
