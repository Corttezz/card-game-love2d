# Etapa 3: roteiro (trailer-do-zero), rodada 2

_Diretora, 01/11/2026. Rodada 2 depois de `revisao-roteiro.md` (respostas em `resposta-roteiro.md`). Nome de trabalho: **"Contra as regras"**. Alvo: 1º vídeo da página da Steam, **68,5 s**, 1920×1080, 60 fps. Tomadas já gravadas (sem CRT, carta a 2 px por pixel lógico) em `%APPDATA%\LOVE\card-game-trailer-v9\trailer_zero\`: `zero_hand`, `fork_a1`, `night_a1`, `entr_moon_gargoyle`, `entr_hellhound`, `entr_ice_wyrm`, `entr_spore_mother`, `entr_fallen_angel`, `zero_carrion`, `zero_monarch`, `zero_tyrant`._

## 1. Conceito

**Gancho:** "Cada chefe quebra as regras da luta, e o seu baralho vivo é o que quebra de volta."

O filme segue **uma run em ordem**: luta do ladino no ato 1 → espólio → estrada do ato 1 → **porta do castelo do ato 1** (aqui troca a classe, uma vez: entra o guerreiro) → o Rei-Carniça entra no silêncio → drop → a luta com o Rei começa e ele quebra a regra dele (a Revoada de corvos) → **montagem para a frente** do que a run ainda vai encontrar (atos 2 → 3 com o Tirano rompendo as correntes → 4 com o Monarca congelando a mão → 5 → 6) → volta à **mesma luta** com o Rei, já no fim (9 de vida, corvos ainda em órbita) → **LETAL** a 81% → morte → coringa do chefe sobe → logo.

A montagem do meio é explicitamente "o que vem pela frente": ela sai da luta com o Rei e volta para ela no mesmo enquadramento, com o mesmo estado (chefe no trono, órbita de corvos, mão do guerreiro). Nada anda para trás.

## 2. Música

**Uma faixa, contínua, sem emenda:** `audio/music/boss-abyss_tyrant.mp3` (ACE-Step, 81,1 s). **Tempo do filme = tempo da faixa − 1,60 s.** Troquei a faixa do Rei-Carniça pela do Tirano porque a do Rei tem 20 s sem nenhum grave bem no centro do filme (item 2 da revisão); o Tirano tem graves densos do começo ao fim, segunda metade mais forte e um fim em fade. Risco declarado: é a faixa do chefe do ato 3 e o chefe-herói do filme é o do ato 1; o Tirano aparece na 1ª prova da montagem, então a faixa tem dono na imagem. Decisão de escuta do Daniel.

A música entra no grave de 2,49 s da faixa (**0,89 s do filme**), depois do liga-TV. Nos silêncios ela vai a −∞ (rampa de 0,3 s) e volta onde naturalmente estaria. 68,5 s do filme = 70,1 s da faixa: o fim é um fade de 2,5 s (66,0 → 68,5).

### Curva de energia medida (curto prazo 3 s, EBU R128, faixa já deslocada)
Medida salva em `scratchpad\tyr_st.txt` (`ffmpeg ebur128`). Máximo por segundo do filme:

| filme (s) | 1–9 | 10–13 | 14–18 | 19–22 | 23–27 | 28–31 | 32–36 | 37–40 | 41–55 | 56–58 | 59–73 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| faixa (LUFS) | −17 a −20 | −15 a −16 | −18 a −21 | −15 | −18 a −20 | −15 a −16 | −17 a −18 | **−13 a −14** | −14 a −15 | **−13** | −13 a −15 |
| bloco | gancho | espólio (rara no grave) | estrada / encruzilhada | porta | **silêncio** (música −∞) | drop + nome | luta com o Rei + Revoada | montagem começa | provas + volta ao Rei | **LETAL** | morte, coringa, logo, fade |

A faixa sozinha é plana (−13 a −21): **o contraste e o pico são feitos na mixagem**, como plano escrito:
- **Silêncio do Rei (22,6 → 28,3 s):** música −∞, depois do groove de 19–22 s (−15). Meta reescrita (item 3 da revisão): **leito** (ambiente do salão, curto prazo, sem os transientes) ≥ 15 dB abaixo do groove anterior, ou seja **≤ −30 LUFS**; **eventos** do jogo isolados, com o pico de curto prazo (janela 0,4 s) escrito: porta −16, olhos acendendo −24, cada rasante de corvo −20, pouso −14, revelação do nome −15; **zero música**.
- **Pico (LETAL, 55,76 s = 81%):** de 49,8 a 55,2 s a música desce **5 dB** (rampa de 1 s) sob a mão e o painel; **respiro de 0,6 s em −∞** (55,16 → 55,76) só com o clique do JOGAR e o voo; no grave de 57,36 s da faixa (**55,76 do filme**) o impacto do jogo entra a 0 dB relativo, a música volta a +1 dB e há **hit-stop de 3 quadros**. Alvo: maior curto prazo do filme entre 55 e 58 s, ≥ 2 dB acima de qualquer outro trecho.

## 3. Regras do corte (herdadas e verificáveis)

- Captura sem CRT, carta a 2 px; CRT e liga-TV do jogo aplicados no fim (`trailer_crt_post`).
- Só ×1 e ×2; troca de escala por corte seco no grave; pan só a 60/120 px/s por quadro.
- Quadro 0 nunca preto; de 30% a 90% (20,6 a 61,7 s) todo segundo com carta grande, criatura ou chefe em ação (o silêncio no escuro tem os olhos e os corvos); logo só depois de 61,7 s.
- **Continuidade:** jornada só para a frente (§1); **troca de classe uma vez**, na porta do ato 1 (o ladino não reaparece depois); a montagem sai e volta à luta do Rei no mesmo enquadramento e estado; criatura e chefe entram pela direita; saltos de luz intencionais marcados ◆.
- **Ritmo:** no máximo **2 rajadas** de planos < 1 s no filme todo; cada prova do gancho com **≥ 2,5 s contínuos** no plano em que a regra se lê.
- Texto: inglês, Grimoire Pixel em escala inteira, contorno; **cada texto começa e termina dentro do seu plano (nunca atravessa corte)**; nunca sobre o assunto do plano; ≥ 1 s parado a cada 13 caracteres; ≤ 4 palavras por tela. **⚠️ = texto novo, pendente do Daniel**, com a versão aprovada (ou "sem texto") de reserva.
- Salões do Higgsfield: tratados (§5.10 das ferramentas) e na ordem do §5.11 (antes de o chefe ocupar o salão, IA primeiro, 1 grave, ◆).
- Números na tela só os contados: 145 cartas, 42 criaturas, 6 atos, 6 chefes.
- Som: SFX reais do jogo pelo `audio.jsonl` de `trailer_zero` (`remix_engine.py`); marca "**não publicável até trocar ou licenciar os SFX**".

## 4. Storyboard

_Os tempos abaixo são os nominais; os exatos (encaixados nos graves medidos da faixa) estão em `corte/edl.py` (`CLIPS` e `TEXTS`), que é a fonte da montagem. Todo texto do `TEXTS` fica dentro do intervalo do seu clipe._

Tomadas: **H** `zero_hand` (ladino × Espantalho, ato 1, até o espólio com o coringa raro); **F1** `fork_a1`/`night_a1` (estrada e encruzilhada do ato 1); **E2..E6** `entr_*` (estrada de cada ato com a criatura chegando, mesmo enquadramento); **K** `zero_carrion` (estrada do ato 1 até o castelo, porta, entrada do Rei, luta, LETAL, morte, coringa); **T** `zero_tyrant`; **M** `zero_monarch`. IA = salão Higgsfield tratado.

### Gancho (0 a 9 s)

| t (s) | imagem | escala | texto | som |
|---|---|---|---|---|
| 0,00 | **H**: TV do jogo já 60% aberta sobre a mão do ladino, cartas vivas em repouso | ×2 | — | `boot-tv-power-on` sozinho |
| 0,89 | TV assentada; uma carta de ataque sobe | ×2 | — | **música entra** no grave |
| 2,1 | plano inteiro com HUD (vida, mana, Espantalho e a barra); 3 cartas selecionadas; JOGAR | ×1 | — | grave; clique do jogo |
| 3,3 → 6,0 | **cascata** (item 7): as cartas resolvem uma a uma no Espantalho, cada número sobe, o banner **COMBO! Volley +15** soma, os coringas ticam, a barra cai em degraus | ×2 no inimigo | — | um grave por carta; impacto, `combo-trigger`, `jokerTick` com tom subindo |
| 6,0 | a mão é dada de novo, uma a uma | ×2 | ⚠️ **145 LIVING CARDS.** (reserva aprovada: **BUILD A LIVING DECK.**) no terço superior, 6,0 → 8,4 | `card-deal` |
| 8,4 | 2º golpe derruba o Espantalho | ×1 | — | grave; morte do Espantalho |

### Espólio e caminho (9 a 22,6 s)

| t (s) | imagem | escala | texto | som |
|---|---|---|---|---|
| 9,4 | **H**: espólio: duas cartas viram | ×2 | — | grave |
| 10,4 | a 3ª entra por último com o **brilho de achado raro** (coringa) | ×2 | — | grave forte (−15); `card-discovered`, assinatura do coringa |
| 12,4 ◆ | **F1**: estrada do ato 1, castelo ao centro, câmera do jogo andando | ×1 | — | grave; vento e grilos |
| 14,0 | encruzilhada do ato 1 em **um plano** (1,2 s): as placas, a escolha | ×1 | — | grave; som da encruzilhada |
| 15,2 → 19,4 | **K**: a estrada do ato 1 até o castelo (mesma estrada, o castelo cresce); **troca de classe aqui**: o HUD passa a ser o do guerreiro | ×1 | — | groove; estrada |
| 19,4 → 22,6 | a porta do castelo do ato 1 se abre | ×1 | — | grave (−15) no início da porta; `castle-gate-open`; música −8 dB a partir de 21,0 |

### Silêncio e drop (22,6 a 38,4 s)

| t (s) | imagem | escala | texto | som |
|---|---|---|---|---|
| 22,6 ◆ | **IA hall1**: o trono vazio no fogo (apresentação; o Rei ainda não chegou), 1 grave | ×1 | — | baque do portão no corte; **música a −∞** |
| 23,6 ◆ | **K**: as luzes caem, o salão real vazio e escuro | ×1 | — | leito ≤ −30 |
| 24,2 → 27,0 | dois olhos acendem; três rasantes de corvo; o Rei entra **pela direita** e pousa no trono | ×1 (×2 no pouso) | — | olhos −24, rasantes −20 cada, pouso −14 |
| 27,0 → 28,3 | os corvos assentam na órbita | ×1 | — | só o salão |
| **28,33** | **drop**: cartão de nome do jogo **CARRION KING / Sovereign of Crows** | ×1 | (o cartão do jogo é o texto) | **música volta no grave** (29,93 s da faixa); `boss_reveal_sting` |
| 30,0 → 32,3 | a mão do guerreiro é dada; o Rei ergue os corvos (contagem `swarm` ao redor dele) | ×1 | ⚠️ **EVERY BOSS / BREAKS THE RULES.** (reserva aprovada: **EVERY BOSS / IS A PUZZLE.**) 30,0 → 33,2, terço superior, fora do Rei e da órbita | grave |
| 32,3 → 35,6 | **prova 1 (3,3 s contínuos):** a **Revoada**: cada golpe do Rei é um corvo da órbita mergulhando no painel do herói (embaixo à esquerda); a vida do herói cai | ×1 (Rei e painel no mesmo quadro) | — | corvos do jogo em 1º plano (`CrowSfx`), música −6 dB |
| 35,6 → 38,4 | o guerreiro responde: 2 cartas, combo, o Rei sente o golpe | ×2 | — | grave; impacto |

### O que vem pela frente: provas 2 e 3 (38,4 a 51,6 s)

| t (s) | imagem | escala | texto | som |
|---|---|---|---|---|
| 38,4 ◆ | **E2**: estrada do ato 2 (crepúsculo roxo), a gárgula surge pela curva | ×1 | ⚠️ **6 ACTS.** (reserva aprovada: **SIX ACTS.**) do início ao **fim deste plano** (sai no corte para o ato 3) | grave; ambiente do ato 2 |
| 39,6 ◆ | **E3**: estrada do ato 3 (vermelho), o cão do inferno | ×1 | | grave; brasas |
| 40,8 ◆ | **IA hall3**: o trono de lava vazio (apresentação do Tirano), 1 grave | ×1 | — | grave |
| 41,8 → 44,8 | **prova 2 (3,0 s contínuos):** **T**: o Tirano com as 3 marcas douradas na barra; um golpe cruza 75%, **a corrente rompe** e o golpe anunciado cai pela metade | ×2 (barra + intent + chefe) | ⚠️ **BREAK HIS CHAINS.** (reserva: sem texto) 42,6 → 44,6 | rompimento da corrente, impacto |
| 44,8 ◆ | **E4**: estrada do ato 4 (neve), a serpente de gelo emerge | ×1 | ⚠️ **42 CREATURES.** (reserva: sem texto) do início ao **fim deste plano** (sai no corte para o salão de gelo) | grave; sopro de gelo |
| 46,0 ◆ | **IA hall4**: o trono de gelo vazio (apresentação do Monarca), 1 grave | ×1 | — | grave; vento |
| 47,0 → 49,8 | **prova 3 (2,8 s contínuos):** **M**: a mão do guerreiro, **duas cartas congelam** (as mais caras, com o "frozen!" do jogo); um ataque derrete uma | ×2 (mão + carta) | ⚠️ **FROST LOCKS YOUR HAND.** (reserva: sem texto) 47,0 → 49,4 | gelo do jogo, derretimento |
| 49,8 ◆ | **E5 + E6**: estrada do ato 5 (mãe-esporo) 0,9 s → estrada do ato 6 (anjo caído pousando) 0,9 s (**a única rajada**) | ×1 | — | graves; chuva; pouso do anjo |

### Volta à luta, pico e fim (51,6 a 68,5 s)

| t (s) | imagem | escala | texto | som |
|---|---|---|---|---|
| 51,6 ◆ | **K**: de volta ao salão do Rei, **mesmo enquadramento**, órbita de corvos no ar; o guerreiro com **9 de vida** | ×1 | — | música −5 dB; batimento de vida baixa do jogo |
| 52,8 → 55,16 | duas cartas sobem; o painel da prévia acende **LETHAL** | ×2 (mão + painel) | (o LETHAL do jogo é o texto) | hover; clique |
| 55,16 → 55,76 | JOGAR; as cartas sobem | ×2 | — | **respiro: música −∞** 0,6 s, só o clique e o voo |
| **55,76** | **golpe LETAL**, hit-stop de 3 quadros, número enorme, a barra zera | ×2 → ×1 | — | **pico**: impacto do jogo + voz do Rei + música de volta (+1 dB) |
| 56,8 → 59,6 | morte em câmera lenta: dessaturação, o corpo cai | ×1 | ⚠️ **BREAK THEM BACK.** (reserva: sem texto) 57,2 → 59,4 | morte, corvos fugindo |
| 59,6 → 61,8 | o **coringa "Carrion Crown" sobe do corpo girando** com o brilho de conquista e para | ×2 (carta parada no fim) | — | revelação do coringa |
| 61,8 → 64,0 | a carta **continua o giro no mesmo sentido** da subida (sentido do `BossTrophy`) e a face vira o selo; GRIMOIRE em letras de pixel | ×1 | GRIMOIRE / ⚠️ **A ROGUELIKE DECKBUILDER** (reserva: sem a linha de gênero) | `forge-reveal`, letras com `pack-card-reveal` |
| 64,0 | WISHLIST | ×1 | **WISHLIST ON STEAM** (aprovado) | grave; selo sintetizado |
| 66,0 → 68,5 | a moldura fica; o salão escuro atrás do logo, um corvo pousado | ×1 | (fica) | fade da música; **último som: carta puxada** |

Rajadas < 1 s no filme: só E5/E6 (49,8 s). IA = 1,0 s; encruzilhada = 1,2 s. O respiro de 0,6 s é de som, não de plano.

## 5. Verificações programadas no corte 1

| critério | medida |
|---|---|
| quadro 0 / gameplay ≤ 2 s / HUD ≤ 5 s | quadro 0 (carta viva), 2,1 s (HUD) |
| microtrailer (0,33..0,87 × 68,5 = 22,6 / 29,5 / 36,3 / 45,7 / 52,6 / 59,6 s) | trono IA na porta, nome do Rei, guerreiro golpeando, serpente / trono de gelo, LETHAL no painel, coringa subindo |
| silêncio | leito ≤ −30 LUFS (curto prazo, sem transientes) em 23,6 a 28,3 s; eventos nos níveis do §2; zero música |
| pico | maior curto prazo do filme entre 55 e 58 s, ≥ 2 dB acima de qualquer outro trecho |
| sincronia | cada corte a ≤ 2 quadros de um grave medido (exceto os do silêncio, que caem em som do jogo) |
| continuidade | jornada para a frente; uma troca de classe; luma por plano, saltos > 25% só nos ◆ |
| leitura | carta-assunto ≥ 30% da altura; provas ≥ 2,5 s contínuos; texto ≥ 1 s/13 caracteres parado, nunca sobre o assunto |
| ritmo | ≤ 2 rajadas < 1 s |
| loudness | −14 LUFS integrado, ≤ −1 dBTP |
