# Revisão do Grimoire: corte 9 (rodada 9b), revisora independente

_02/11/2026. Revisão independente, sem aproveitar a aprovação de `revisao-corte9.md` (commit 636fe396). Arquivos: `grimoire_zero_corte9_720p.mp4` e `_1080p.mp4` (Tirano, idênticos: diferença média de 0,42/255 em 3870 quadros), `grimoire_zero_corte9_rei_720p.mp4` (Rei), os três com 64,5 s a 60 quadros/s. Método: quadros a 2 e 4 quadros/s do filme inteiro, folhas a 5 e 10 quadros/s nos momentos-chave, recortes 1:1 na 1080p, detecção de cortes quadro a quadro, escala da câmera por correlação do perfil de bordas do salão (0,85 a 1,15), onsets por fluxo espectral e ataque de grave (20 a 150 Hz) nas faixas `zero9/music_tirano.wav` e `zero9_rei/music_rei.wav`, RMS do mix em janelas de 100 ms, `ebur128` e tempos de cada linha do logo nos cortes 2, 8b e 9. Evidências em `C:\Users\corte\AppData\Local\Temp\claude\rgc9\` (`t_ov_*.png`, `r_ov_*.png`, `t_anjo.png`, `r_anjo.png`, `gate_t.png`, `r_corvos.png`, `t_golpe.png`, `hp.png`, `logo_cmp.png`, `carta.png`, `fogo.png`, `textos.png`). Não ouvi._

## Veredito: REPROVADO

| versão | nota |
|---|---|
| Tirano (principal, 720p e 1080p) | **8,6** |
| Rei (variante, 720p) | **8,8** |

As duas correções da 9b estão feitas. O que segura são dois defeitos que nenhuma revisão anterior registrou, os dois mensuráveis e corrigíveis só na EDL: a vida do herói cai de 70 para 25 num corte, sem dano na tela, e o WISHLIST fica 0,6 s menos na tela do que no corte 2.

## Requisitos do Daniel

| requisito | resultado | prova |
|---|---|---|
| 1. Sem zoom em degrau, tela inteira, enquadramento estável; final só com hit-stop, flash e tremor | **Atende nas duas.** A melhor escala contra a batalha de 40,5 s é **1,00** em 44, 48, 50,2, 50,6, 51,5, 52,5, 53,5, 54,3, 55 e 57 s, nas duas versões. Golpe: imagem parada de 49,9 a 50,35 s (o respiro), flash e o "48" grande a 50,37 s, tremor e dessaturação na sequência. HUD inteiro em todos os planos de jogo. | `t_golpe.png`, `t_ov_48.png` |
| 2. Animação do logo igual ao corte 2 | **Atende na animação, não no tempo de tela.** Tempos relativos medidos pelo brilho de cada linha: corte 2 GRIMOIRE 58,850 → gênero +0,55 → WISHLIST +3,13 s; corte 9 59,433 → +0,55 → **+3,13 s**, iguais (o 8b dava +2,80). Mas o bloco inteiro começa **0,58 s mais tarde** e o filme acaba no mesmo 64,5 s, sem fade: o WISHLIST fica **1,93 s** na tela, contra **2,52 s** no corte 2. | `logo_cmp.png` (linhas: corte 2, 8b, 9) |
| 3. Textos aprovados, exatos | **Atende nas duas:** "145 LIVING CARDS.", "6 ACTS.", "EVERY BOSS / BREAKS THE RULES.", "CHAINS.", "42 CREATURES.", "FROST.", "BREAK THEM BACK.", "A ROGUELIKE DECKBUILDER" (+ "WISHLIST ON STEAM"). | `textos.png`, `t_ov_*.png`, `r_ov_*.png` |
| 4. Nada medíocre | **Não atende ainda:** ver os defeitos abaixo. | |

## As duas correções da 9b

| item | resultado | prova |
|---|---|---|
| (a) Rei: "Murder of Crows" legível ~1,1 s antes dos corvos | **Resolvido.** "ENEMY TURN" a 42,0 s; o nome cheio de **42,10 a 43,20 s (1,1 s)**, quadro segurado; os corvos partem a 43,30 s (vida 25 → 22). Mesmo quadro do anúncio da principal. | `r_corvos.png` |
| (b) Tirano: anjo no ataque forte (~26,55 s) | **Resolvido.** Corte medido a **26,550 s**. Na faixa da Tirano há onset de fluxo a −2,7 quadros (5,6× a mediana), com a mesma força do mais forte da janela (5,7× a 26,22 s). O pouso do anjo cai dentro do plano a 27,08 s; o portão continua a 27,967 s. | `t_anjo.png` |

## Pontos de `revisao-grimoire-corte8.md`, conferidos de novo

| # | ponto | no corte 9 (9b) |
|---|---|---|
| 1 | recuo na queda do Rei | **Resolvido:** escala 1,00 do golpe aos ossos, sem abrir nem fechar. |
| 2 | contorno em chama, lava e tocha | **Resolvido:** recortes 1:1 da lava (14,5 s) e do trono (31,5 s) sem borda escura no fogo. Ressalva estética: o fogo do trono, em 1:1, lê como manchas posterizadas, mais chapado que os sprites do jogo. |
| 3 | Carrion Crown chapada | **Resolvido:** inclinação leve, sombra deslocada na grade e brilho opaco; face e nome legíveis de ~55,8 a 58,35 s. A 57,95 s o brilho deixa alguns pixels brancos soltos na cabeça e no ombro esquerdo; não bloqueia. |
| 4 | face do coringa no Tirano | ok (~2,5 s legível). |
| 5 | esporo/anjo/portão no Rei | **Resolvido:** 25,07 / 26,35 / 27,58 s, os três a ≤ 1,1 quadro de onsets de 10× a 12× a mediana. |
| 6 | trecho morto antes do castelo (Tirano) | **Em parte.** As folhas do portão abrem de 28,35 a 29,15 s, mas em tela inteira o portão tem ~100 px de largura na 720p e o movimento lê pequeno; de 29,15 a 30,08 s a porta aberta fica parada. Somando portão (2,1 s), trono do Higgsfield (30,08 a 33,33 s, 3,25 s) e escuro (1,5 s), são **6,9 s sem jogo** de 27,97 a 34,84 s. O silêncio antes do chefe é intencional, mas é o trecho mais fraco do filme. |
| 7 | respiro antes do 48 | **Resolvido:** RMS do mix −16,9 (49,6 s) → −43 → **−62 a −71 dBFS** (50,0 a 50,3 s) → **−6,3** a 50,4 s, nas duas. |
| 8 | luta do Rei fragmentada | **Resolvido no enquadramento:** o Rei fica no centro, em tela inteira, de 39 a 50 s. **A continuidade da vida, não:** ver o defeito 1. |

Medidas: −14,1 LUFS nas três; pico −0,9 dBFS (Tirano) e −1,2 (Rei); LRA 8,1 e 8,5 LU; nenhum quadro < 5% de luma.

## Defeitos novos (não registrados em nenhuma revisão anterior)

### 1. A vida do herói cai de 70 para 25 num corte, nas duas versões (bloqueia)
Painel HERO: **70/70** até o fim do plano do guerreiro (Tirano 41,5 s; Rei 41,95 s) e **25/70** no quadro seguinte ao corte do "ENEMY TURN" (Tirano **41,61 s**, Rei **42,00 s**). A barra vermelha cai de cheia para ~1/3 entre dois planos, sem nenhum golpe na tela. Depois o filme mostra 25 → 22 → 13 → 9 com dano visível. É a virada do trailer: o dano que justifica o "48 LETHAL" acontece fora de quadro, e o salto se vê no maior bloco de HUD da tela. Prova: `hp.png`.

### 2. CTA mais curto que no corte 2, nas duas versões (bloqueia, pelo requisito 2 do Daniel)
WISHLIST na tela por 1,93 s, contra 2,52 s no corte 2 (medida acima). A animação é a do corte 2, mas o fecho que o Daniel aprovou segurava o selo, o nome e o WISHLIST por mais tempo, e 1,9 s é pouco para o CTA.

### 3. Sincronia mais fraca na Tirano (pesa na nota, não bloqueia sozinho)
Na faixa do Rei, os cortes caem a ≤ 1,6 quadro de onsets fortes (6× a 12,6× a mediana). Na da Tirano (~104 BPM, textura densa) a maioria cai a ≤ 3 quadros de algum onset, com estes desvios: **gancho LETHAL 2,55 s (+14 quadros até o onset mais próximo)**, morte 7,48 s (−7,8), espólio 8,60 s (−5,9), vida 43,01 s (−7,8) e queda 50,96 s (−5,4). O do LETHAL é o que mais pesa, porque é o gancho.

### 4. Ordem dos letreiros (observação para o Daniel, não bloqueia)
"EVERY BOSS / BREAKS THE RULES." → "CHAINS." → **"42 CREATURES."** → "FROST.": a contagem de criaturas fica entre os dois exemplos de regra de chefe e quebra o argumento. Mudar exige reordenar planos e texto aprovado, então só registro.

## Notas

| critério | Tirano | Rei |
|---|---|---|
| sem zoom (Daniel 1) | 10 | 10 |
| logo/fecho igual ao corte 2 (Daniel 2) | 8 (CTA 1,93 s) | 8 |
| textos exatos (Daniel 3) | 10 | 10 |
| gancho (0 a 3 s) | 9 | 9 |
| sincronia | 8 | 9,5 |
| continuidade | **7** (70 → 25 a 41,61 s) | **7** (a 42,00 s) |
| legibilidade (Murder of Crows, 48, LETHAL, carta) | 9 | 9 |
| ritmo (27,97 a 34,84 s sem jogo) | 8,5 | 8,5 |
| golpe final / respiro / queda | 9,5 | 9,5 |
| salões IA na grade | 8,5 | 8,5 |
| som (loudness, respiro, coringa) | 9 | 9 |
| prende / legal de assistir | 8,5 | 8,5 |
| **nota geral** | **8,6** | **8,8** |

## Correções para o corte 10 (todas de EDL, sem render de salão, sem trocar faixa, texto ou salão)

1. **Continuidade da vida (as duas, obrigatório).** Nenhum corte pode mudar o número do HERO sem golpe visível. Opções, em ordem de preferência: (a) tirar o plano do guerreiro (Tirano 39,20 a 41,61 s, Rei 39,48 a 42,00 s) do turno da mesma tomada `zero_carrion` em que o HERO já está em 25/70, com a mão na tela, mantendo os tempos dos cortes; (b) se esse turno não existir na tomada, encaixar o golpe que leva 70 → 25 (≤ 0,6 s, num onset) antes do "ENEMY TURN", tirando o mesmo tempo do plano do guerreiro. Prova pedida: folha a 10 quadros/s do recorte do painel HERO de 39 a 50,4 s, com a vida só caindo em quadros com golpe.
2. **Tempo de tela do fecho (as duas, obrigatório).** Voltar o bloco do logo à posição absoluta do corte 2 (GRIMOIRE 50% a ~58,85 s, gênero ~59,40 s, WISHLIST ~61,98 s), para o WISHLIST ficar **≥ 2,5 s**. Os 0,58 s saem do coringa: da parte do verso girando, antes de a face aparecer (Tirano ~55,22 a 55,8 s; Rei a partir de 54,555 s), mantendo a face legível ≥ 2 s. Os tempos relativos +0,55 / +3,13 s não mudam. Prova: `logo_cmp` igual ao meu, com o corte 10 alinhado ao corte 2 no tempo absoluto.
3. **Sincronia da Tirano (recomendado).** Levar o LETHAL do gancho (2,55 s) e a vida (43,01 s) ao onset mais próximo da `music_tirano.wav`, até ±0,25 s, sem perder a leitura do "LETHAL". Prova: tabela de cortes × onsets (fluxo e grave), com desvio ≤ 3 quadros em todos os cortes de plano.
4. **Trecho sem jogo de 27,97 a 34,84 s (recomendado, se a música deixar).** Tirar ~0,5 s da porta aberta parada (Tirano 29,15 a 30,08 s; Rei equivalente) e ~0,5 s do trono do Higgsfield, mantendo o silêncio do chefe e os tempos depois dele. Se a música não deixar, fica como está.
5. **Para o Daniel (não mexer sem ele):** a ordem "CHAINS. → 42 CREATURES. → FROST." e se "final igual" inclui o fundo e o áudio do corte 2 (hoje só a animação e os tempos relativos são iguais).

Manter tudo o que já está confirmado: sem zoom, textos, "Murder of Crows" de 1,1 s, anjo a 26,55 s, respiro, golpe, queda em escala 1,00, carta com profundidade, fogo sem contorno, zero quadro preto, −14,1 LUFS.

Continua valendo: **não publicável até trocar ou licenciar os SFX**.
