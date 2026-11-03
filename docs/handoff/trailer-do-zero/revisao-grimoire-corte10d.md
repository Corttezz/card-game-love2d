# Revisão do Grimoire: corte 10d, revisora independente

_02/11/2026. Revisão independente. Não li `revisao-corte10d.md`, `revisao-corte10c.md` nem nenhum `revisao-corteN.md` da equipe. Do 10d li só `corte10d.md` e `edl10d.py` como alegação da diretora. Arquivos: `grimoire_zero_corte10d_720p.mp4` (Tirano), `grimoire_zero_corte10d_rei_720p.mp4` (Rei) e `grimoire_zero_corte10d_1080p.mp4` (Tirano, recortes 1:1); comparação com o 10c e o corte 2. Método: diferença quadro a quadro (96×54, todos os 3870 quadros) contra o 10c e o corte 2; folhas a 10 quadros/s dos painéis de vida do herói e da barra do Rei de 38,8 a 50,9 s; folhas a 20 e 60 quadros/s do "Murder of Crows" e da troca de intenção; escala da câmera por correlação do perfil de bordas com três quadros de referência (44, 46 e 52 s); onsets do `stem_music.wav` de cada versão (fluxo espectral e subida de grave 20 a 150 Hz, meu `ana.py`); `medir2.py` com `TDZ_EDL=edl10d` e `TDZ_MUSIC=tirano|rei`. O librosa não está instalado no Python desta máquina e não instalei; a sincronia saiu de duas medidas próprias (fluxo e RMS do `medir2`). Scripts e brutos em `C:\Users\corte\AppData\Local\Temp\claude\rgc10d\`. Provas em `revisao-grimoire-corte10d_provas\`. Não ouvi._

## Veredito: APROVADO nas duas versões

| versão | nota |
|---|---|
| Tirano (principal) | **9,2** |
| Rei (variante) | **9,1** |

O bloqueio do Rei no 10c está resolvido: os quatro cortes da luta caem agora a ≤ 2 quadros de onsets de 10× a 13× a mediana. As quatro recomendações do 10c foram cumpridas nas duas versões ("33" igual ao "−33" do jogo, "Murder of Crows" grande 0,80 s, "COMBO! Volley +6" inteira, plano dos corvos da Tirano encurtado). Nenhum número de vida muda num corte. As duas passam de 9,0. Fico um pouco abaixo da revisora da equipe (9,3 / 9,3) por três coisas pequenas que continuam ali, listadas no fim; nenhuma segura a aprovação.

## Requisitos do Daniel

| requisito | resultado | prova |
|---|---|---|
| Sem zoom em degrau, tela inteira, enquadramento estável; golpe só com hit-stop, flash e tremor | **Atende nas duas.** Escala medida de 38,9 a 57,4 s a cada 0,25 s contra três referências: todos os pontos com correlação ≥ 0,5 ficam entre **0,99 e 1,01** (o ±1% é o tremor e as faíscas). Os poucos valores fora (1,12 a 1,14, ou 0,86) têm correlação 0,15 a 0,33, ou seja, o letreiro do coringa ou a tela escura, não zoom. Golpe: tela parada de 49,9 a 50,35 s, flash e "33" a 50,37 s, tremor e dessaturação depois. | `golpe_tirano_49.7-51s.png`, `golpe_rei_49.7-51s.png`; saída do `scale.py` no scratch |
| Fecho do logo igual ao corte 2 | **Atende.** De 55,0 s ao fim as duas versões do 10d são **idênticas ao 10c quadro a quadro** (diferença média 0,00, máxima 0/255). No 10c eu já tinha medido GRIMOIRE 58,850 s, gênero 59,400 s, WISHLIST 61,983 s e WISHLIST 2,517 s na tela, iguais ao corte 2. O logo e o letreiro se sobrepõem ao corte 2; o que muda é o fundo (salão do Rei com o corpo no chão). | `fecho_rei_10d_x_corte2_61.5s.png` |
| Textos aprovados, exatos | **Atende.** Tirano idêntica ao 10c de 0 a **41,5 s**; Rei idêntico de 0 a **38,9 s** (diferença 0,00/0). A luta não tem texto de overlay novo além do "33". | `medidas_cortes_onsets.txt` |
| Nada medíocre | Sim nas duas, ver notas. | abaixo |

## Pontos do 10c, um a um

| ponto do 10c | no 10d | prova |
|---|---|---|
| 1. Rei: quatro cortes da luta no contratempo (bloqueava) | **Resolvido.** `k_inimigo` 41,993 s: onset de 13,3× a −1,8 q. `k_vida` 43,270: 11,2× a −2,0 q. `k_letal` 48,274: 10,7× a −1,7 q. `k_letal_b` 49,528: 13,5× a −1,8 q. (Os quatro cortam ~30 ms depois do ataque do onset, o que é o lado certo.) No `medir2`, `k_vida`, `k_letal` e `k_letal_b` têm subida de 25,7 / 28,3 / 28,0 dB; `k_inimigo` sai "FRACO" (8,7 dB) só porque o onset está na borda da janela de ±30 ms. | `medidas_cortes_onsets.txt` |
| 2. "21" do overlay × "−33" do jogo | **Resolvido.** O overlay mostra **33**, e o "−33" do Immolate aparece no mesmo quadro, acima e à esquerda da cabeça do Rei. 33 contra 21 de vida restante é golpe com sobra, que é o que o LETHAL prometia. | `golpe_33_igual_menos33_tirano_1080p_50.55s.png` |
| 3. "Murder of Crows" grande ~0,3 s | **Resolvido.** Nome grande de **42,95 a 43,70 s** na Tirano e de **42,45 a 43,20 s** no Rei: **0,80 s** nas duas, antes do primeiro corvo. Depois encolhe para o rótulo do jogo. No Rei o corte de 43,270 s cai bem na troca de tamanho, e isso não incomoda. | `murder_of_crows_tirano_20qps.png`, `murder_of_crows_rei_20qps.png` |
| 4. "COMBO! Volley +6" em relance | **Resolvido.** Faixa inteira e parada de ~41,2 a 42,2 s na Tirano (~1,0 s) e de ~41,0 a 41,8 s no Rei (~0,9 s), com entrada e saída dentro do plano. | `combo_e_nome_tirano_40.8-44s.png`, `combo_e_nome_rei_40.6-43.8s.png` |
| 5. Plano dos corvos longo | **Tirano resolvido:** `k_vida` 3,70 s + `k_vida_b` 0,57 s (era 4,9 s). **Rei:** continua 5,0 s, como a diretora disse; aceitável, porque cada mergulho tira vida com painel vermelho. | folhas de vida |
| Gancho LETHAL da Tirano fora do onset (aberto desde o 9) | **Não mexido** (quadros idênticos ao 10c). Recomendação, não bloqueio. | identidade 0 a 41,5 s |
| Trecho sem jogo 27,97 a 34,84 s (aberto desde o 9) | **Não mexido.** Recomendação, não bloqueio. | identidade |
| Margem do golpe da Tirano colada no limite | **Igual:** +2,1 dB (Rei +2,8 dB). Mix sem mudança. | `medir2` abaixo |

## Continuidade de vida e números (folhas a 10 quadros/s)

| versão | herói | Rei |
|---|---|---|
| Tirano | 41/70 de 38,9 a 43,9 s, sem mudança no corte de 42,343 nem no de 43,794. Primeiro corvo a 44,0 s, depois 38, 37, 36, 34, 33, 31, 29, 26, 25, 24, 22, 21, 19, 17, 14, 13, 12, 10, **9** (47,4 s), cada queda com o painel vermelho. 9/70 de 47,4 s até o golpe; o corte novo de 47,498 s pega 9 dos dois lados. | 102 → Colossus Blow −39 → Twin Strike 58, 41, 34, 31, **30** (41,6 s), tudo antes do corte de 42,343. 30 durante "ENEMY TURN" e os corvos (o corte de 47,498 pega 30 dos dois lados). Tique de fogo 30 → 25 → 24 → 22 → 21 (47,6 a 47,9 s). 21 com a prévia −21 e LETHAL até o golpe; "33" no golpe. |
| Rei | 41/70 de 38,9 a 43,4 s. Corvos de 43,5 a 46,9 s: 38, 37, 36, 34, 33, 31, 30, 29, 26, 25, 24, 22, 21, 19, 18, 17, 14, 13, 12, 10, **9**. 9/70 até o golpe. | 102 → −39 → Twin Strike 45, 37, 32, 31, **30** (41,5 s), antes do corte de 41,993 (o salto 34 → 30 do 10c sumiu). 30 nos corvos. Tique de fogo 26 → 23 → 21 (47,5 a 47,7 s), dentro do plano `k_vida`. 21 até o golpe. |

**Nenhum número de vida muda num corte, nas duas.** Provas: `vida_heroi_tirano_38.8-50.9s_10qps.png`, `vida_heroi_rei_38.8-50.9s_10qps.png`, `barra_rei_tirano_38.8-50.9s_10qps.png`, `barra_rei_rei_38.8-50.9s_10qps.png`.

Uma ressalva, que não é de vida: na **Tirano**, o corte `k_vida_b` → `k_letal` de **48,067 s** pula a passagem de turno. No mesmo quadro do corte a intenção do Rei passa de **4×8 para 6×8**, a mão aparece já dada, a mana vai de 0 para 5 e a prévia da direita troca. Medido a 60 quadros/s: 4×8 até o último quadro do `k_vida_b`, 6×8 no primeiro do `k_letal` (salto de imagem 13,9 no quadro 2884). Era igual no 10c (corte de 47,207 s). No **Rei** a troca 4×8 → 6×8 acontece dentro do plano (47,8 → 47,9 s), então lá não há salto. Não reprovo: é a virada de turno, quem joga lê como corte de tempo. Prova: `intencao_4x8_6x8_no_corte_48.067_tirano_60qps.png`, `letal_tirano_47.3-50.3s.png`, `letal_rei_47.6-50.4s.png`.

## Sincronia (onsets do `stem_music.wav` de cada versão)

**Rei** (tempos fortes ~1,25 s): todos os cortes de plano da luta agora no tempo forte.

| corte | t0 | onset mais forte em ±0,5 s |
|---|---|---|
| `k_guerreiro` | 38,895 | −2,5 q, só 3,4× (grave +23,7 q). Tempo fraco, igual desde o 10b. |
| `k_inimigo` | 41,993 | −1,8 q, **13,3×** |
| `k_vida` | 43,270 | −2,0 q, **11,2×** |
| `k_letal` | 48,274 | −1,7 q, **10,7×** |
| `k_letal_b` | 49,528 | −1,8 q, **13,5×** |
| `k_golpe` | 50,360 | silêncio antes do golpe; grave +1,4 q (65,8 dB) |
| `k_queda` | 50,780 | −1,4 q, 17,4× |

**Tirano** (tempos a cada ~0,29 s, grade densa): os cortes da luta mudaram de lugar e caem em onsets médios.

| corte | t0 | onset mais perto | `medir2` (subida RMS) |
|---|---|---|---|
| `k_guerreiro` | 38,930 | −2,0 q, 5,5× | 15,2 dB ok |
| `k_inimigo` | 42,343 | +0,2 q, **2,8×** (o forte de 5,6× está a 42,03) | 10,8 dB ok |
| `k_vida` | 43,794 | −2,7 q, 4,9× | 10,2 dB ok |
| `k_vida_b` | 47,498 | −1,9 q, 4,4× | 10,9 dB ok |
| `k_letal` | 48,067 | −1,8 q, 4,5× | 16,4 dB ok |
| `k_letal_b` | 49,216 | −2,2 q, 4,9× | 8,1 dB "fraco" |
| `k_golpe` | 50,360 | −0,5 q, 11,2× | 81,4 dB ok |

Todos a ≤ 2,7 quadros de um onset. A alegação da diretora de "≤ 0,1 quadro" não bate com a minha medida: eu acho os cortes 30 a 45 ms depois do onset. É diferença de método (pico do fluxo × início do ataque), não defeito, e cortar logo depois do ataque é o lado bom. O `k_inimigo` da Tirano ficou num onset fraco (no 10c estava a −2,1 q de um de 6×); em 0,29 s de grade não se ouve como contratempo, mas é o corte menos firme da luta.

## Medidas gerais

| medida | Tirano | Rei |
|---|---|---|
| quadro 0 | luma 54,4/255, não preto | 54,7/255 |
| quadros < 5% de luma | **0** (mínimo 15,7 a 34,3 s, o escuro intencional) | **0** |
| loudness integrada (`medir2`, mp4) | −14,1 LUFS | −14,2 LUFS |
| pico | −1,1 dBFS | −1,1 dBFS |
| LRA | 6,9 LU | 7,4 LU |
| margem do golpe (S) | **+2,1 dB** (limite 2) | +2,8 dB |
| golpe M / maior M fora do golpe | −9,0 / −7,6 | −8,9 / −7,5 |
| silêncio antes do chefe (S, 1 s a 1 s) | −14,0 −15,9 −23,0 −30,6 −24,7 | −14,4 −16,1 −23,3 −31,2 −25,3 |
| clima externo dentro do castelo | nenhum | nenhum |

O mix é o mesmo do 10c: o maior M continua sendo o som do coringa, não o golpe. Em S o golpe é o pico. Registro, não reprovo.

## Notas

| critério | Tirano | Rei |
|---|---|---|
| sem zoom (Daniel 1) | 10 | 10 |
| fecho igual ao corte 2 (Daniel 2) | 10 | 10 |
| textos exatos (Daniel 3) | 10 | 10 |
| gancho (0 a 3 s) | 9 | 9 |
| sincronia | 8,5 (gancho LETHAL; `k_inimigo` em onset fraco) | 9 (luta no tempo forte; 38,895 fraco) |
| continuidade de vida e números | 9,5 (salto de intenção na virada de turno) | 10 |
| legibilidade (combo, Murder of Crows, LETHAL, 33) | 9,5 | 9,5 |
| ritmo | 8,5 (~1,45 s de "ENEMY TURN" e nome antes do primeiro corvo) | 8,5 (corvos 5,0 s) |
| golpe, respiro, queda | 9,5 | 9,5 |
| salões IA na grade | 8,5 | 8,5 |
| som (loudness, respiro, coringa) | 9 (margem +2,1) | 9 |
| prende / legal de assistir | 9,5 | 9 |
| **nota geral** | **9,2** | **9,1** |

## O que fica (nada bloqueia)

1. **Tirano, margem do golpe +2,1 dB**, colada no limite de 2. Qualquer mexida de mix precisa medir de novo.
2. **Tirano, `k_inimigo` 42,343 s em onset fraco (2,8×).** Se houver um 10e: 42,03 s tem 5,6× mas cortaria a faixa do combo antes de 1 s; a melhor troca é deixar como está.
3. **Rei, `k_guerreiro` 38,895 s em tempo fraco** (3,4×), desde o 10b. Sugestão para um próximo corte: 39,47 s, o tempo forte seguinte, se o nome do Rei aguentar mais 0,58 s.
4. **Tirano, virada de turno no corte de 48,067 s** (4×8 → 6×8, mão e mana aparecem). Igual ao 10c. Se incomodar o Daniel, pegar 0,3 s antes no `k_letal` para mostrar a troca de intenção dentro do plano.
5. Continuam abertos do corte 9 (recomendações): LETHAL do gancho da Tirano no onset (2,55 → ~2,77 s) e o trecho sem jogo de 27,97 a 34,84 s. Salões e ritmo com 8,5.

## Para o Daniel (não decidi)
- "42 CREATURES." entre "CHAINS." e "FROST." continua quebrando o argumento das regras de chefe.
- "Final igual ao corte 2": animação e tempos do logo são iguais; o fundo é o salão do Rei com o corpo, não o do corte 2. O áudio do fecho ninguém comparou por ouvido.
- Ninguém ouviu os mixes. Tudo aqui é medida.

**Não publicável até trocar ou licenciar os SFX.**
