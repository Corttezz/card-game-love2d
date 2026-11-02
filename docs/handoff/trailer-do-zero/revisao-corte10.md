# Revisão independente: corte 10 (trailer-do-zero)

_Revisora, 02/11/2026. Arquivos: `grimoire_zero_corte10_1080p.mp4` e `_720p.mp4` (Tirano) e `grimoire_zero_corte10_rei_720p.mp4` (Rei), os três com 64,5 s a 60 quadros/s. Base: `revisao-grimoire-corte9.md` (255c8668) e `corte10.md` (c7f66cc3). Medi tudo de novo sem aproveitar as provas da diretora: luma, cortes e loudness (`medir.py`), tempos do logo pelo brilho de cada linha (bandas fixas, comparados com o corte 2 e o corte 9), ataque de grave (30 a 160 Hz) e fluxo espectral nas faixas `zero9/music_tirano.wav` e `zero9_rei/music_rei.wav`, folhas a 10 e 15 quadros/s do plano novo, recortes 1:1 na 1080p das barras de vida do herói e do Rei, e md5 dos quadros de 20 a 30 s contra o corte 9. Evidências em `scratchpad/rev/c10/` (`t_dreno.png`, `r_dreno.png`, `t_corte_dreno.png`, `hp_all.png`, `t_gancho.png`, `t_coringa.png`, `r_coringa.png`). Não ouvi._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.**

## Veredito: REPROVADO nas duas versões

| versão | nota | bloqueia |
|---|---|---|
| Tirano (1080p e 720p) | **8,8** | continuidade 8 |
| Rei (720p) | **8,9** | continuidade 8 |

O fecho e a sincronia estão corrigidos e conferem com a minha medida. O que segura é o plano novo da vida: o número do herói agora cai na tela, mas sem nada que o cause, e no mesmo corte a vida do Rei salta 70 pontos.

## 1. Vida do herói, plano `k_dreno` (as duas): em parte

**O que está certo.** O painel HERO não salta mais num corte. A 10 quadros/s ele desce 70 → 53 → 36 → 29 → 26 → 25 com o painel vermelho e tremor (Tirano de 40,9 a 41,3 s; Rei de 40,72 s, com 25/70 segurado de 41,21 a 41,77 s), e depois 25 → 22 → … → 9 com os corvos. Nenhum outro corte muda o número do HERO.

**O que não está, e bloqueia:**

a) **Não existe golpe na tela.** Nos quadros de 40,93 a 41,47 s (Tirano) e 40,72 a 41,9 s (Rei) o Rei está parado no trono e só abre as asas depois de a vida já estar em 25. É o turno do jogador: a mão de 5 cartas está na tela e "Play Cards" está aceso. Só depois aparece "ENEMY TURN" (Tirano 41,506 s, Rei 42,00 s). A causa fica invertida: o herói perde 45 de vida e só então o turno do inimigo começa. O intent do Rei mostra **4×4** (16), e a perda é 45. A correção pedida pelo Grimoire era "encaixar o golpe que leva 70 → 25". O painel vermelho e o tremor mostram o dano, mas não mostram um golpe. A própria diretora registra isso: "sem o golpe de um monstro na tela".

b) **A vida do Rei salta de 201 para 131 no mesmo corte, sem dano** (recortes 1:1, `hp_all.png`). No fim do plano do guerreiro a barra do Rei mostra **201/220** (Tirano 40,88 s; o "−24" do Twin Strike ainda está na tela). No primeiro quadro do `k_dreno` mostra **131/220** (Tirano **40,90 s**, Rei **40,72 s**). São 70 pontos em um corte, na barra que fica logo acima do Rei, no centro da tela. A causa está na EDL: o guerreiro vem do quadro 1394 a 1496 da tomada `zero_carrion` e o dreno do quadro 2113 em diante, então ~10 s de luta (617 quadros) ficam de fora.

**Erro meu:** esse salto já existia no corte 9, no corte do "ENEMY TURN" (201 → 131, Tirano 41,61 s, Rei 42,00 s). Nem eu nem o Grimoire registramos. Pela mesma regra que reprovou o HERO ("nenhum corte pode mudar o número sem golpe visível"), ele também bloqueia.

**Correção pedida (só EDL, mesma tomada, sem trocar faixa, texto ou salão):**
1. Olhar a tomada entre os quadros 1496 e 2113. Se ali estiver o turno em que o guerreiro leva o Rei de ~200 para 131, tirar o plano do guerreiro desse turno, mantendo os tempos dos cortes, para a barra do Rei chegar a 131 na tela.
2. O dreno precisa de uma causa visível. Se a revoada encenada (`swarm_staged`) tiver corvos ou um ataque na tomada antes do quadro 2113, abrir o `k_dreno` alguns quadros antes, para o golpe entrar no onset. Se não houver nada visível na tomada, o dreno não pode ficar no turno do jogador. Ponha "ENEMY TURN" / "Murder of Crows" antes da queda, para os corvos serem a causa, ou regrave a tomada com um golpe visível. Regravar é decisão do Daniel: pare e traga a proposta antes.
3. Prova: a mesma folha do painel HERO a 10 quadros/s, mais uma folha da barra do Rei de 39 a 50,4 s, com cada mudança de número só em quadros com golpe visível.

## 2. Fecho: resolvido

Medido por mim pelo brilho de cada linha (limiar de 50% do brilho final):

| arquivo | GRIMOIRE | gênero | WISHLIST | WISHLIST na tela |
|---|---|---|---|---|
| corte 2 1080p | 58,850 | 59,400 | 61,983 | 2,517 s |
| corte 9 1080p | 59,433 | 59,983 | 62,567 | 1,933 s |
| **corte 10 1080p / 720p** | **58,850** | **59,400** | **61,983** | **2,517 s** |
| **corte 10 Rei 720p** | **58,850** | **59,400** | **61,983** | **2,517 s** |

Idêntico ao corte 2 no tempo absoluto. A face do coringa fica legível ~2,5 s (Tirano, de 55,2 s) e ~3,2 s (Rei, de 54,6 s), com "Carrion Crown", inclinação e sombra. Ela entra direto, sem o verso girando, o que funciona com o sting. O fundo e o áudio do fecho continuam diferentes do corte 2 (fundo em tela inteira, sem zoom): a dúvida segue com o Daniel e não reprovo por ela.

## 3. Sincronia da Tirano: resolvida

Ataque de grave (subida em 30 ms) e fluxo espectral, medidos por mim:

| evento | t | grave | fluxo |
|---|---|---|---|
| LETHAL do gancho | 2,817 | +6,7 dB a −1,6 q | pico a −2,5 q |
| espólio | 8,533 | +6,6 dB a −0,2 q | 3,0× a −2,9 q |
| dreno | 40,900 | +5,8 dB a −1,2 q | 3,9× a −1,8 q |
| Revoada | 41,506 | +9,6 dB a −1,6 q | 2,0× a −4,6 q |
| vida (corvos) | 43,212 | +5,4 dB a −1,3 q | 4,2× a −3,4 q |
| LETHAL | 45,800 | +6,3 dB a −1,8 q | −3,0 q |
| queda | 50,960 | +10,3 dB a −2,4 q | −5,4 q |

Todos os cortes de plano ficam a ≤ 2,4 quadros de um ataque de grave. A faixa da Tirano é densa e os picos são fracos (1,6× a 4×), por isso dou 9 e não mais. O "LETHAL" aparece no painel entre 2,80 e 2,83 s (folha `p4`, conferida). No Rei, o dreno cai a −0,6 q de um ataque de **+37,8 dB**, o "ENEMY TURN" a −1,8 q (+12,6 dB) e a vida a −1,2 q (+20,1 dB). O LETHAL do gancho do Rei (2,633 s) está igual ao do corte 9 e não foi pedido.

## 4. Trecho sem jogo de 27,97 a 34,84 s: não feito, aceito

O silêncio vai de 30,08 a 36,97 s, e a música volta no ponto da segunda passagem. Encurtar o vídeo ali adiantaria a segunda metade inteira e tiraria o fecho dos tempos absolutos do corte 2, que o Daniel pediu. O Grimoire condicionou o pedido a "se a música deixar", então aceito e dou 9 ao ritmo. **Risco:** o Grimoire deu 8,5 a esse critério no corte 9, e nada mudou nele.

## Sem regressão

- md5 dos quadros de 20 a 30 s idêntico ao corte 9, nas duas.
- Cortes detectados iguais aos do corte 9 de 11,68 a 39,2 s (Tirano) e de 8,43 a 39,48 s (Rei).
- **0 quadros < 5% de luma** nas três.
- Tirano: −14,1 LUFS, −1,1 dBTP, LRA 8,0. Rei: −14,0 LUFS, −1,2 dBTP, LRA 8,2. A 1080p e a 720p da Tirano dão as mesmas medidas.
- Sem zoom: escala igual em todos os planos de jogo que conferi (dreno, ENEMY TURN, vida, LETHAL, golpe, queda). O plano novo usa a tela inteira, com o HUD completo.
- Textos exatos. "Murder of Crows" fica ~1,1 s no Rei e ~1,3 s na Tirano.

## Notas

| critério | Tirano | Rei |
|---|---|---|
| sem zoom (Daniel 1) | 10 | 10 |
| fecho igual ao corte 2 (Daniel 2) | 9,5 | 9,5 |
| textos exatos (Daniel 3) | 10 | 10 |
| gancho (0 a 3 s) | 9,5 | 9 |
| sincronia | 9 | 9,5 |
| **continuidade** (dreno sem golpe no turno do jogador; Rei 201 → 131 no corte) | **8** (40,90 s) | **8** (40,72 s) |
| legibilidade (LETHAL, Murder of Crows, 48, carta) | 9 | 9 |
| ritmo (silêncio de 30,08 a 36,97 s, aceito) | 9 | 9 |
| golpe final / respiro / Q (queda do Rei) | 9,5 | 9,5 |
| salões IA / contorno | 9 | 9 |
| som (loudness, respiro, coringa 5,0 / 5,9 dB) | 9 | 9 |
| prende / legal de assistir | 9 | 9 |
| **geral** | **8,8** | **8,9** |

C1–C14, G1–G7 e N1–N5 de sempre ficam ≥ 9 nas duas, com uma exceção: a continuidade, com nota 8 nas duas versões. Por isso não marco o corte como pronto.
