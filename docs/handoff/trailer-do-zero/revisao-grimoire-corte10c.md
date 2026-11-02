# Revisão do Grimoire: corte 10c, revisora independente

_02/11/2026. Revisão independente. Não li `revisao-corte10c.md` nem `revisao-corte10b.md`; do corte 10c li só `corte10c.md` como alegação da diretora. Arquivos: `grimoire_zero_corte10c_720p.mp4` (Tirano) e `grimoire_zero_corte10c_rei_720p.mp4` (Rei), 64,5 s a 60 quadros/s, mais a 1080p da Tirano para recortes 1:1. Comparação com os cortes 2, 9 e 10b. Método: quadros de 0,25 s (folha a 2 quadros/s no trecho que não mudou, 4 a 20 quadros/s na luta), folhas a 10 quadros/s dos painéis de vida de 37 a 52 s, detecção de cortes e de quadro escuro em todos os 3870 quadros, diferença quadro a quadro contra o 10b e o 9, escala da câmera por correlação do perfil de bordas (0,85 a 1,15), onsets (fluxo espectral e ataque de grave de 20 a 150 Hz) no `stem_music.wav` de cada versão, `medir2.py` (TDZ_EDL=edl10c), `ebur128` e RMS do mix em janelas de 100 ms. Scripts e brutos em `C:\Users\corte\AppData\Local\Temp\claude\rgc10c\`. Provas em `revisao-grimoire-corte10c_provas\`. Não ouvi._

## Veredito: Tirano APROVADA no limite, Rei REPROVADA

| versão | nota |
|---|---|
| Tirano (principal) | **9,0** |
| Rei (variante) | **8,7** |

Os dois bloqueios do corte 9 estão resolvidos nas duas versões: a vida do herói só cai com golpe na tela, e o WISHLIST fica 2,517 s, igual ao corte 2. A Tirano chega à barra, com três defeitos pequenos que ainda valem corrigir. O Rei fica abaixo porque **os quatro cortes novos da luta caem no contratempo da faixa do Rei**, cerca de 0,58 s antes dos tempos fortes (a revisora da equipe viu dois, são quatro). Pela regra, o corte não vai ao Daniel até o Rei passar de 9. A correção é só de EDL.

## Requisitos do Daniel

| requisito | resultado | prova |
|---|---|---|
| Sem zoom em degrau, tela inteira, enquadramento estável; golpe só com hit-stop, flash e tremor | **Atende nas duas.** Escala medida contra o quadro de 44,0 s: **1,00** em todos os pontos de 38,9 a 50,15 s (correlação 0,77 a 1,00). Da queda ao coringa, contra 51,0 s: 0,99 a 1,02 (o 1,02 de 53,4 a 54,9 s acompanha o letreiro e a correlação baixa, não é zoom; as folhas mostram o mesmo quadro). Golpe: tela clara e parada de 49,8 a 50,35 s, flash e "21" a 50,37 s, tremor e dessaturação depois. | `luta_tirano_4qps.png`, `golpe_tirano_50.2-51.0s.png`, `queda_coringa_tirano_4qps.png` |
| Fecho do logo igual ao corte 2 | **Atende.** Brilho por faixa: GRIMOIRE 50% a **58,850 s**, gênero a **59,400 s**, WISHLIST a **61,983 s** nas duas e no corte 2. WISHLIST na tela **2,517 s** (corte 2: 2,517 s). De 59 s ao fim a diferença para o corte 2 é constante (~4/255): é o fundo (o salão do Rei com o corpo no chão, no lugar do salão do corte 2). | `fecho_corte2_x_10c.png` |
| Textos aprovados, exatos | **Atende nas duas.** 0 a 38,9 s igual ao 10b (diferença máxima 0,26/255) e, de 9 a 38 s, igual ao corte 9, onde já conferi os textos. "145 LIVING CARDS.", "6 ACTS.", "EVERY BOSS / BREAKS THE RULES.", "CHAINS.", "42 CREATURES.", "FROST.", "BREAK THEM BACK.", "A ROGUELIKE DECKBUILDER", "WISHLIST ON STEAM". | `queda_coringa_tirano_4qps.png`, `fecho_corte2_x_10c.png` |
| Nada medíocre | Tirano: sim, no limite. Rei: não, pela sincronia da luta. | abaixo |

## Os bloqueios do corte 9

| item | resultado | prova |
|---|---|---|
| 1. Vida do herói 70 → 25 num corte | **Resolvido nas duas.** HERO 41/70 do primeiro quadro com HUD (38,90 s) até o primeiro corvo (Tirano 42,90 s; Rei 43,20 s). Depois cai a cada mergulho, sempre com o painel vermelho do golpe: Tirano 38, 37, 36, 34, 33, 31, 29, 26, 25, 24, 22, 21, 19, 17, 14, 13, 12, 10, **9** (46,30 s); Rei 39, 38, 37, 35, 33, 30, 29, 28, 26, 25, 23, 21, 18, 17, 16, 14, 13, 11, **9** (46,60 s). 9/70 até o golpe. Nenhum número do herói muda num corte. | `vida_heroi_tirano_37-52s_10qps.png`, `vida_heroi_rei_37-52s_10qps.png` |
| Barra do Rei | **Contínua nas duas.** 102/220 no primeiro quadro (o `k_nome` não tem HUD); Colossus Blow com −39 a 39,6 s; Twin Strike com −33, contagem 58 → 41 → 34 → 31 → 30; 30 durante os corvos; tique de fogo com "WEAKNESS!" e −9 no corpo, 30 → 25 → 23 → 21 (Tirano 46,9 a 47,1 s; Rei 47,3 a 47,5 s); 21 com a prévia −21 e LETHAL até o golpe. Única quebra: no Rei, o corte de 41,379 s pega a contagem do Twin Strike no meio (34 → 30); a carta do golpe está na tela no quadro anterior, então não conta como salto sem golpe. | `barra_rei_*_10qps.png`, `tique_fogo_menos9_tirano.png` |
| 2. WISHLIST 1,93 s | **Resolvido:** 2,517 s nas duas (acima). | `fecho_corte2_x_10c.png` |
| 3. Sincronia da Tirano (LETHAL 2,55 s, vida 43,01 s) | **Não mexido** (0 a 38,9 s é o 10b). O LETHAL do gancho continua a +6,4 quadros de um onset fraco (3,0×) e a +13,4 do forte (6,8×). Era recomendação, não bloqueio. O plano da vida mudou de lugar com a regravação. | `ana.py` (saída na seção de sincronia) |
| 4. Trecho sem jogo 27,97 a 34,84 s | **Não mexido** (igual ao 10b e ao 9). Recomendação, não bloqueio. | `t_ov.png` no scratch |

## Pontos de `revisao-grimoire-corte8.md` e o resto do corte 9

| ponto | no 10c |
|---|---|
| Recuo na queda do Rei | **Mantido resolvido:** escala 1,00 do golpe à queda nas duas. |
| Contorno em chama, lava e tocha | Trecho igual ao 9 (0 a 38 s), sem mudança. |
| Carrion Crown com profundidade | **Ok:** face e nome legíveis de 55,3 a 57,77 s na Tirano (2,5 s); de 56,3 s em diante é o último quadro limpo segurado, com brilho e inclinação, sem a faixa "COMBO!" da tomada nova. |
| Esporo, anjo, portão (Rei) | Iguais ao 9: 25,07 / 26,355 / 27,585 s, a ≤ 1,5 quadro de onsets de 10× a 18×. |
| Respiro antes do golpe | **Mantido:** RMS do mix −25 (49,7 s) → −45 → **−65 a −73 dBFS** (50,0 a 50,3 s) → **−6 dBFS** a 50,4 s, nas duas. |
| "Murder of Crows" legível ~1,1 s (9b) | **Piorou um pouco, nas duas.** O nome grande aparece por ~0,3 s (Tirano 42,05 a 42,34 s; Rei 42,35 a 42,65 s) e depois encolhe para o rótulo pequeno do jogo sobre o peito do Rei (legível a 1:1, ~13 px de altura). O nome fica ~0,85 s na tela antes do primeiro corvo. No 9b o nome grande ficava 1,1 s. Na Tirano o corte de 42,343 s cai bem na troca de tamanho. | `murder_of_crows_10c_x_9.png`, `murder_of_crows_*_20qps.png` |

## Medidas gerais

| medida | Tirano | Rei |
|---|---|---|
| quadro 0 | luma 54/255, não preto | 55/255 |
| quadros < 5% de luma | **0** (mínimo 15,9/255 a 34,3 s, o escuro intencional) | **0** |
| loudness integrada | −14,2 LUFS | −14,1 LUFS |
| pico | −1,1 dBFS | −1,1 dBFS |
| LRA | 7,1 LU | 7,3 LU |
| margem do golpe (S, `medir2`) | **+2,1 dB** (limite 2) | +2,7 dB |
| golpe M / maior M fora do golpe | −9,0 / −7,6 (a 55,6 s, o som do coringa) | −8,9 / −7,4 (a 55,0 s) |
| silêncio antes do chefe (S, 1 s a 1 s) | −14,0 −15,9 −23,0 −30,6 −24,7 | −14,4 −16,1 −23,2 −31,1 −25,2 |
| clima externo dentro do castelo | nenhum | nenhum |

O momento mais alto em M é o coringa, não o golpe, nas duas (já era assim no 9 e no 10b; o golpe subiu de −10,3 para −9,0 M na Tirano). Em S o golpe é o pico. Registro, não reprovo.

## Sincronia da luta nova (onsets do `stem_music.wav` de cada versão)

**Tirano** (tempos fortes a cada ~0,29 s): os cortes novos caem perto de onsets, com força média.

| corte | t0 | onset mais perto |
|---|---|---|
| `k_guerreiro` | 38,930 | −2,0 q (5,6×); grave +0,8 q |
| `k_inimigo` | 41,495 | −2,1 q do onset de 6× a 41,46 |
| `k_vida` | 42,343 | −1,1 q de um onset fraco (2,9×); os de 4× estão a 42,03 e 42,61 |
| `k_letal` | 47,207 | −1,7 q (4,2×) |
| `k_letal_b` | 48,647 | −2,3 q (4,6×) |
| `k_golpe` | 50,360 | −0,5 q (11,4×) |

**Rei** (tempos fortes a cada ~1,25 s: 39,47 · 40,74 · **41,96** · **43,24** · 44,48 · 45,75 · 46,69 · **48,25** · **49,50** · golpe): os quatro cortes novos do meio caem na metade do intervalo, ~0,58 s antes do tempo forte.

| corte | t0 | tempo forte seguinte | distância |
|---|---|---|---|
| `k_inimigo` | 41,379 | 41,96 (10×) | −0,58 s; nenhum onset > 2,5× a ±0,5 s; subida do grave 3,1 dB |
| `k_vida` | 42,656 | 43,24 (7×) | −0,58 s |
| `k_letal` | 47,672 | 48,25 (13×) | −0,58 s |
| `k_letal_b` | 48,926 | 49,50 (12×) | −0,57 s |

Na faixa do Rei, o resto do filme corta a ≤ 1,6 quadro de onsets de 6× a 18×. Esses quatro são os únicos cortes de plano fora do tempo, todos no trecho mais importante, e por isso pesam.

## Defeitos encontrados no 10c

### 1. Rei: os quatro cortes novos no contratempo (bloqueia a variante)
Medido acima. Correção só de EDL: `k_inimigo` 41,379 → **41,96**, `k_vida` 42,656 → **43,24**, `k_letal` 47,672 → **48,25**, `k_letal_b` 48,926 → **49,50** (o `k_letal_b` fica com 0,86 s até o golpe). Ao mover `k_inimigo`, o guerreiro ganha 0,58 s; conferir que o −33 e a contagem até 30 terminam antes do corte. Ao mover `k_vida`, o "Murder of Crows" grande ganha tempo na tela, o que também ajuda o defeito 3.

### 2. Dois números diferentes no golpe final (as duas, não bloqueia sozinho)
De 50,40 a 50,90 s o "21" grande do overlay divide a tela com o "−33" do próprio jogo, pequeno, logo acima e à esquerda da cabeça do Rei (legível na 1080p, ~70 px de largura). O "21" é a vida que o golpe tira; o "−33" é o dano do Immolate. Quem lê os dois vê o número do clímax se contradizer, justo no corte que existe para a conta fechar. Correção: mostrar **33** no overlay (o dano real, igual ao do jogo) ou tirar o "−33" do jogo nesses 0,5 s. Prova: `golpe_21_x_menos33_tirano_1080p_50.55s.png`.

### 3. "Murder of Crows" grande só ~0,3 s (as duas, não bloqueia sozinho)
Medido acima. Correção sugerida: segurar o quadro do nome grande (o hit-stop de 12 quadros hoje está em 42,095 s na Tirano e 42,379 s no Rei) até somar ~0,8 s de nome grande antes do primeiro corvo, ou começar o `k_vida` mais tarde na tomada.

### 4. Faixa "COMBO! Volley +6" em relance (as duas, pequeno)
A faixa roxa do combo entra no fim do `k_guerreiro` e é cortada no meio (Tirano 41,15 a 41,49 s, a faixa entrando com o efeito de pixel; Rei 41,2 a 41,37 s). Lê como um clarão de texto sem leitura. Com o corte do Rei movido para 41,96 s ela fica inteira; na Tirano, terminar o `k_guerreiro` antes de 41,15 s (há onset de 4× a 41,18) ou deixá-la ler. Prova: `combo_volley_relance_tirano_41.2s.png`.

### 5. Ritmo do turno dos corvos (observação)
O `k_vida` tem 4,9 s (Tirano) e 5,0 s (Rei) do mesmo plano aberto: corvos pequenos e o painel do herói contando. A continuidade agora é real e o painel vermelho a cada golpe dá leitura, mas é o plano mais longo da luta. Não reprovo por isso; se a música deixar, tirar 0,5 a 1 s entre o 4º e o 6º corvo.

## Notas

| critério | Tirano | Rei |
|---|---|---|
| sem zoom (Daniel 1) | 10 | 10 |
| fecho igual ao corte 2 (Daniel 2) | 10 | 10 |
| textos exatos (Daniel 3) | 10 | 10 |
| gancho (0 a 3 s) | 9 | 9 |
| sincronia | 8,5 (gancho LETHAL igual ao 9) | **7,5** (quatro cortes da luta no contratempo) |
| continuidade de vida e números | 9 ("21" × "−33" no golpe) | 9 |
| legibilidade (Murder of Crows, LETHAL, 21, carta) | 8,5 | 8,5 |
| ritmo | 8,5 | 8,5 |
| golpe, respiro, queda | 9,5 | 9,5 |
| salões IA na grade | 8,5 | 8,5 |
| som (loudness, respiro, coringa) | 9 | 9 |
| prende / legal de assistir | 9 | 8,5 |
| **nota geral** | **9,0** | **8,7** |

## Para o corte 10d (EDL e overlay; sem regravar, sem trocar faixa, texto ou salão)

1. **Rei, obrigatório:** cortes da luta em 41,96 / 43,24 / 48,25 / 49,50 s (defeito 1). Prova pedida: tabela de cortes × onsets da `stem_music` do Rei com desvio ≤ 3 quadros em todos os cortes de plano, e de novo a folha da vida a 10 quadros/s.
2. **As duas, recomendado:** número do golpe igual ao do jogo, **33** (defeito 2).
3. **As duas, recomendado:** "Murder of Crows" grande ≥ 0,8 s antes do primeiro corvo (defeito 3).
4. **As duas, recomendado:** faixa "COMBO!" fora do corte, ou inteira (defeito 4).
5. Continuam abertos do corte 9, recomendados: LETHAL do gancho da Tirano no onset (2,55 s → ~2,77 s, onset de 6,8×) e o trecho sem jogo de 27,97 a 34,84 s.

Manter: continuidade da vida, WISHLIST 2,517 s, escala 1,00, respiro, queda, coringa, zero quadro preto, −14,1/−14,2 LUFS. A margem do golpe da Tirano está em +2,1 dB, colada no limite: qualquer mudança de mix no 10d precisa medir de novo.

## Para o Daniel (não decidi)
- "42 CREATURES." entre "CHAINS." e "FROST." continua quebrando o argumento das regras de chefe.
- "Final igual ao corte 2": a animação e os tempos são iguais; o fundo é o salão do Rei com o corpo, não o do corte 2, e o áudio do fecho não comparei por ouvido.
- O trecho da luta mostra o herói já em 41/70 e o Rei em 102/220 no primeiro número que aparece; daí em diante só há golpes. Vale saber que é uma luta preparada.

**Não publicável até trocar ou licenciar os SFX.**
