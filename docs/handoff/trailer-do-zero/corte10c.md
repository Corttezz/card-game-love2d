# Corte 10c (trailer-do-zero)

_Diretora, 02/11/2026. Base: `revisao-corte10b.md` (a7b3d112, Tirano 8,9 e Rei 8,9, reprovado: Rei 131 → 48 no corte do LETHAL). Decisão do Lead (`E:\dev\_orquestracao\tdz_c10c.txt`): **opção 1, regravar a luta do Rei-Carniça** para a barra do Rei chegar ao golpe final só por golpes reais e os corvos levarem o herói para baixo na tela._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX** (ElevenLabs free). Música ACE-Step local. Salões do Higgsfield nos acentos (decisão do Daniel).

## 1. Roteiro da regravação (escrito antes de gravar)

### Por que a tomada antiga não servia
- O `newRun` do gravador liga o **modo deus** do cheat. Os corvos batiam e a vida do herói não caía. Por isso a tomada antiga **ajustava** a vida: `swarm_staged` (herói → 25) e `lethal_pick` (Rei → 48).
- Na tomada nova, o modo deus fica **desligado** na luta, e toda mudança de número depois do primeiro quadro usado vem de um golpe que se vê.

### Como captura
- Mesmo gravador (`E:\dev\projects\card-game-trailer-zero\tools\trailer_record.lua`, branch `trailer-do-zero`) e mesmo comando da tomada antiga: `CARDGAME_HEADLESS=1`, identidade `card-game-trailer-v9`, 60 fps, 1920×1080, sem CRT, sem moldura, sem barra do topo, `en`, `TRAILER_CARD_PX=2`, `TRAILER_TOOLTIP=0`, `TRAILER_NIGHT=0.85`, um `lovec` só.
- Saída numa pasta **nova**, `trailer_zero_c10c\`. A tomada antiga e o seu `audio.jsonl` ficam intactos.
- Tomada nova: `zero_carrion_c10c`.
- Nada de janela visível, save real, matar processo ou crédito pago.

### Preparo, antes do primeiro quadro que entra no filme
Feito no começo do turno 1, enquanto a mão ainda está chegando. Nenhum desses quadros é usado.
- O Rei recebe **6 corvos na revoada** (status `swarm`, o mesmo que a Call of Crows soma).
- O próximo golpe dele é a **Murder of Crows**, que dá 2 + 6 = **8 golpes de 4**, e o anúncio "8×4" aparece no intent.
- O herói começa o trecho em **41/70**, sem armadura (luta já em andamento).
- A vida do Rei é posta em **dano do turno 1 + 30**, calculado pela prévia de dano do próprio jogo (`DamagePreview.simulate`).
- Como o HUD não aparece no `k_nome` (cinemática), o primeiro número que o espectador vê é o deste ponto. Depois dele, nenhum número muda sem golpe.

### Turnos que vão para a tela
| turno | o que acontece | Rei | herói |
|---|---|---|---|
| 1, guerreiro | 4 cartas de ataque, as de maior dano, uma de cada vez; números de dano sobre o Rei; o Rei passa de 30% e fica **ENFURECIDO** | X → ~30 | 41 |
| ENEMY TURN | faixa, "Murder of Crows", **8 corvos mergulham, um golpe de 4 cada** | ~30 | 41 → 37 → 33 → … → **9** |
| 2, guerreiro | YOUR TURN, mão nova, cartas de ataque escolhidas, a prévia acende **LETHAL**, Play Cards | ~30 → 0 no golpe | 9 |
| fim | morte do Rei, queda e o coringa "Carrion Crown" subindo | | |

- Sem mão na tela na queda da vida do herói: no turno do inimigo a mão não aparece. Também não há segundo "ENEMY TURN".
- A Murder of Crows deixa o herói Fraco (×0,75 no dano do turno 2). A prévia já conta isso, então o LETHAL só acende se o golpe mata de verdade.

### Montagem
- A tomada nova entra **do guerreiro em diante** (guerreiro, turno inimigo, vida, LETHAL, golpe, queda e coringa).
- De 0 a ~38,9 s fica tudo da tomada antiga (porta, escuro e nome do Rei), quadro a quadro igual ao corte 10b.
- Os cortes ficam nos onsets da faixa, como antes. O golpe final fica a 50,36 s, onde a música explode, e o número do golpe passa a ser o da nova tomada.

## 2. O que a gravação deu (`trailer_zero_c10c\zero_carrion_c10c.mkv`, 3442 quadros, `audio.jsonl` próprio)

A primeira tentativa não teve turno do inimigo: jogar as cartas não encerra o turno. Corrigi o roteiro (aperta End Turn, como a tomada antiga) e gravei de novo, na mesma pasta nova. Marcas do `audio.jsonl` (segundos da tomada):

| tomada (s) | evento | Rei | herói |
|---|---|---|---|
| 20,87 | preparo (marca `staged`, quadros não usados) | 220 → 102 | 70 → 41 |
| 26,08 | **Colossus Blow −39** | 102 → 63 | 41 |
| 27,63 | **Twin Strike −33**, ENFURECIDO | 63 → 30 | 41 |
| 29,7 a 30,4 | ENEMY TURN; 30,4 "Murder of Crows" (intent 4×8) | 30 | 41 |
| 31,10 a 34,37 | **8 corvos, −4 cada**, a 0,47 s um do outro | 30 | 41 → 37 → 33 → 29 → 25 → 21 → 17 → 13 → **9** |
| 35,13 | **−9 no Rei** (tique de fogo, número e "WEAKNESS!" no corpo) | 30 → 21 | 9 |
| 38,4 a 42,2 | YOUR TURN, 2 cartas de ataque, prévia **21/21 LETHAL** | 21 | 9 |
| 43,67 | **Immolate −33**: o Rei morre | 21 → 0 | 9 |
| 44,15 a 51,1 | morte, queda, coringa "Carrion Crown" (mesmos tempos da tomada antiga, deslocados de −8,75 s) | | |

A vida não é ajustada em nenhum ponto depois do preparo: modo deus desligado, sem `swarm_staged` e sem `lethal_pick`.

## 3. Montagem (`corte/edl10c.py`)

De 0 a 38,93 s (Tirano) / 38,895 s (Rei) é a tomada antiga, igual ao 10b (diferença 0,0 nos segundos 0 a 36). Do guerreiro em diante entra a tomada nova:

| plano | Tirano (filme) | Rei (filme) | tomada (s0) | o que mostra |
|---|---|---|---|---|
| `k_guerreiro` | 38,93 a 41,495 | 38,895 a 41,379 | 25,43 / 25,40 | cartas voando; **−39 a 39,498 s** (onset de 8,9× / 37×); −33 |
| `k_inimigo` | 41,495 a 42,343 | 41,379 a 42,656 | 29,85 / 29,45 | ENEMY TURN e "Murder of Crows", com 12 quadros de hit-stop no letreiro |
| `k_vida` | 42,343 a 47,207 | 42,656 a 47,672 | 30,60 / 30,53 | 8 corvos levam o herói de 41 a 9; −9 no Rei |
| `k_letal` + `k_letal_b` | 47,207 a 50,36 | 47,672 a 50,36 | 39,55 e 41,91 / 42,19 | mão do turno 2, **21/21 LETHAL**, Play Cards, cartas voando (o corte entre os dois fica num patamar: Rei 21, herói 9) |
| `k_golpe` | 50,36 a 50,96 | 50,36 a 50,78 | 44,20 | golpe com hit-stop; o número grande agora é **21**, a vida que o golpe tira (era 48) |
| `k_queda` | 50,96 a 55,22 | 50,78 a 54,555 | 44,70 | queda do Rei e "BREAK THEM BACK." nos mesmos tempos |
| `k_coringa` | 55,22 a 57,77 | 54,555 a 57,77 | 49,60 | face do coringa; 1,3 s ao vivo e o último quadro limpo segurado (75 / 115 quadros) |

- Sem mão na queda do herói e sem segundo ENEMY TURN: os 8 golpes de corvo caem no turno do inimigo.
- **Coringa:** a tomada nova tem uma faixa "COMBO! Volley +6" atrasada sobre a carta de 48,3 a 49,55 s. O plano começa em 49,60 s, quando ela já saiu, e o fim (51,1 s) é a carta sumindo, por isso o último quadro limpo fica segurado com o mesmo hit-stop, profundidade e brilho do 10b.
- `mix2.py` lê o `audio.jsonl` das duas tomadas juntas (`zero10c/audio_merged.jsonl`).

## 4. Provas (`corte10c_provas\`)

- **`<versão>\p1_vida_hero_39.0-50.4s_10qps.png`:** 41 até o primeiro corvo (Tirano 42,9 s; Rei 43,2 s), depois 39/37, 34/33, 32/30/29, 27/25, 22/21, 20/18/17, 15/13, 10/9, cada queda com o painel vermelho do golpe; 9 até o fim.
- **`<versão>\p1_barra_rei_39.0-50.4s_10qps.png`:** 102 no primeiro quadro (o `k_nome` não tem HUD); −39 com a carta sobre o Rei; −33 → 30; 30 até o tique; 27/23/22/21 com o −9 no corpo; 21 com a prévia −21 até o Play.
- **Nenhum número muda em corte.**
- **Sem zoom:** os avisos da escala são os mesmos do 10b (escuro de 35 a 36 s, corte de 8,533 s, giro do coringa no logo).
- **Fecho:** GRIMOIRE 58,850 / gênero 59,400 / WISHLIST 61,983 s nas duas, WISHLIST 2,517 s. Máscara dourada contra o corte 2: Tirano média 0,974, Rei 0,923, iguais ao 10b.
- **Sincronia:**
  - Tirano: cortes novos a ≤ 0,6 quadro de um onset; o −39 a −0,1 q.
  - Rei: cortes novos ≤ 0,6 q, e o golpe a +7,9 q, como antes (volta da música depois do respiro).
- **0 quadros < 5% de luma** nas três.
- **Som:**
  - Tirano: −14,1 LUFS / −1,2 dBTP, LRA 7,1, margem do pico +2,1 dB, coringa 5,0 dB.
  - Rei: −14,1 LUFS / −1,3 dBTP, LRA 7,3, margem +2,7 dB, coringa 5,7 dB.

## Para o Daniel
- O trecho da luta mostra o herói já ferido (41/70) e o Rei com 102/220. Esses dois valores são o primeiro número que aparece no filme (preparo no começo do turno, fora dos quadros usados). Daí em diante só há golpes.
- Arquivos: `grimoire_zero_corte10c_1080p.mp4`, `grimoire_zero_corte10c_720p.mp4` e `grimoire_zero_corte10c_rei_720p.mp4` em `E:\dev\projects\card-game-trailer\build\trailer\`.
