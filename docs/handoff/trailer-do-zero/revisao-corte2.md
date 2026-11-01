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
