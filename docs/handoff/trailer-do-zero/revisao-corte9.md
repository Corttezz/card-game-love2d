# Revisão: corte 9 (trailer-do-zero)

_Revisora independente, 02/11/2026. Base: `corte9.md` (commit edc2bf40), o feedback do Daniel (00:46, prioridade máxima), `revisao-grimoire-corte8.md` (00:07, fonte oficial, commit 83eea09e), `instrucao-corte9-0006.md`, as exigências extras do Grimoire (queda, respiro, Rei do mesmo lado) e os critérios de sempre. Vídeos: `grimoire_zero_corte9_1080p.mp4` (01:12), `_720p.mp4` (01:13) e `_rei_720p.mp4` (01:25); stems em `build\trailer\zero9\` e `zero9_rei\`. Método: luma de todos os quadros e loudness (`medir.py`), mixagem por plano (`mixagem.py`), respiro em janelas de 100 ms no `mix.wav`, força de ataque do grave e fluxo espectral (`flux.py`), deslocamento do fundo quadro a quadro no filme inteiro (correlação de fase), escala da câmera pelas posições das quatro tochas da parede, comparação dos finais com todos os cortes anteriores (`final_fp.py` e tempos das linhas do logo), folhas a 1, 4, 5, 10 e 20 quadros/s e recortes 1:1. Tudo em `C:\Users\corte\AppData\Local\Temp\claude\E--dev-projects-card-game-love2d\f967decd-bccd-487a-92fd-ff59f9b0ee6d\scratchpad\rev\c9\`. Não ouvi._

## Feedback do Daniel (00:46)

| pedido | veredito | o que medi |
|---|---|---|
| sem zoom em degrau, tela inteira, enquadramento estável; golpe só com hit-stop, flash e tremor | **atende nas duas** | Folha a 1 quadro/s do filme inteiro (`q\todo_t.png`, `q\todo_r.png`): todos os planos de jogo em tela inteira, com HUD completo. Escala da câmera pelas tochas: batalha (48,8 s) tochas a x = 385 / 523 / 1399 / 1537; golpe (50,6 s) 363 / 498 / 1379 / 1520 (mesmo espaçamento, deslocadas ~20 px pelo tremor); queda com a mesma escala da batalha (casamento 1,00 em 51 a 54 s nas duas). Nenhum pan nosso: os únicos trechos com o fundo andando são movimentos do próprio jogo (tremor nos golpes, a estrada girando no plano do anjo, a entrada do Rei, a animação dos salões IA). Golpe: hit-stop no quadro com o "48" grande, **flash** (luma 66 → 172 → 55 em 5 quadros, 50,37 s) e **tremor** (50,42 a 50,60 s). Ler a tela inteira não sofre: "48 LETHAL", "HERO 9/70", "Murder of Crows" (Tirano) e o "48" leem bem na 1080p e na 720p (`q\chave_t.png`). |
| final igual ao de um corte anterior | **atende no bloco do logo (corte 2, conferido)** | Tempos das linhas do logo medidos pelo brilho de cada linha: GRIMOIRE → gênero → WISHLIST = **+0,51 / +3,10 s** no corte 9 e nos **cortes 2, 3 e 4**; **+0,51 / +2,76 s** nos cortes 5 a 8b; corte 1 diferente (+0,40 / +1,25). Alinhado pelo GRIMOIRE, a diferença só nos pixels do texto e do selo é **1,36/255 contra o corte 2** (1,14 contra o 3, 1,38 contra o 4) e 2,1 a 2,3 contra os cortes 5 a 8b. Confirmo a prova da diretora: o bloco do logo é o do grupo 2 a 4, e o corte 2 é uma escolha válida. **Não é idêntico quadro a quadro:** o fundo é a sala escura em tela inteira (a tomada do corte 2 sem zoom mostraria o painel do jogo, justificativa aceita), a posição absoluta está 0,59 s mais tarde e o áudio do final é o do corte 7/8b (diferença relativa 0,05), não o do corte 2 (1,49). Se o Daniel quis dizer o final inteiro, com a mesma imagem e o mesmo som do corte 2, isso precisa ser perguntado a ele: com a faixa atual, a música do corte 2 no logo não caberia sem outra passagem. |

## Os 16 itens do Grimoire

| # | ponto | diretora | minha conferência | no corte 9 |
|---|---|---|---|---|
| 00:07-1 | recuo na queda | falso como zoom | **Falso como zoom**, conferido: a escala é constante do golpe aos ossos (tochas e casamento de escala). | Sem zoom, sem recuo. **O critério extra do Grimoire ("o Rei nunca de corpo inteiro") fica superado pela decisão do Daniel:** em tela inteira o Rei aparece de corpo inteiro o tempo todo, e não há recuo nem salto. |
| 00:07-2 | contorno em chama, lava e tocha | real | **Real** (8b: bordas de arco e suporte encostadas na luz). | **Resolvido** (`q\fogo9.png`, 1:1): nenhuma borda escura no fogo do trono, nas tochas ou na lava; os pilares mantêm o contorno. |
| 00:07-3 | Carrion Crown chapada | real | **Real.** | **Resolvido** (`q\carta9.png`): inclinação leve, sombra na grade e brilho opaco de 2 tons, com a face e o nome legíveis em todos os quadros. |
| 00:07-4 | face do coringa no Tirano | falso | **Falso** (8b: face de 55,63 s, assentada ~2,6 s). | ok |
| 00:07-5 | esporo/anjo/portão no Rei | real | **Real.** | **Resolvido:** 1,29 / 1,23 / 2,49 s. Pouso a 26,355 s (grave de 48 dB a +0,1 quadro) e portão a 27,585 s (48,6 dB a 0,0 quadro), o ataque ratificado. As folhas abrem ~0,9 s depois do corte (`q\gate.png`). |
| 00:07-6 | caminhada antes do castelo (Tirano) | real | **Em parte** (2 s de criatura parada, não 3 a 4). | Esporo 1,44 s, anjo 1,15 s, portão 2,11 s com as folhas abrindo ~0,6 s depois do corte (`q\cast_t.png`, `q\gate.png`). **Mas o corte do anjo saiu da batida:** ver abaixo. |
| 00:07-7 | respiro antes do 48 | real | **Real.** | **Resolvido** e mais fundo que o pedido: no `mix.wav`, de picos de −13/−15 dBFS (49,5 a 49,7 s) para **−47 → −72 dBFS de 49,8 a 50,3 s** (0,5 s abaixo de −45) nas duas versões; o golpe volta a −5/−6. Queda acima de 30 dB, como eu tinha fixado. |
| 00:07-8 | luta do Rei / Rei pulando de lado | real | **Real.** | **Resolvido:** em tela inteira o Rei fica no centro em toda a luta (41 a 50 s); cortes nos ataques (Rei: vida 43,25 s a +0,1 quadro de 40 dB, LETHAL 45,75 s a +0,5 de 57 dB; Tirano: 43,01 e 45,80 s a ≤ 1,2 quadro). |
| 00:06-1 | salões | — | — | Coberto pelo 00:07-2; o FROST continua sem contorno nas partículas. |
| 00:06-2 | brilho em quadrados translúcidos | — | — | Coberto pelo 00:07-3. |
| 00:06-3 | escuro ≤ 1,5 s | real | **Real** (8b: ~3,2 s abaixo de 45 de luma). | **Resolvido:** olhos no escuro de 33,34 a 34,84 s (1,5 s) nas duas, sem salto visível no pulo da tomada (`q\escuro_t.png`, 10 quadros/s). |
| 00:06-4 | virada com três enquadramentos | — | — | Coberto pelo 00:07-8 (tela inteira, um enquadramento só). |
| 00:06-5 | Rei 25 a 28 s | — | — | Coberto pelo 00:07-5. |
| 00:06-6 | Rei ~0:51 volta ao aberto | — | **Falso** (pré-checagem) | Sem zoom, não se aplica. |
| 00:06-7 | anúncio Murder of Crows ~1,1 s (Rei) | real | **Real.** | **NÃO RESOLVIDO, PIOROU: o nome não aparece no Rei.** Ver abaixo. |
| 00:06-8 | gancho | falso em parte | **Falso.** | ok: o quadro 0 já tem a mão inteira, o HUD e o Espantalho com a cabeça. |

## O que segura

### Rei: "Murder of Crows" sumiu (ponto 00:06-7 e ponto 2 do corte 8, C4, C11)
Folha a 10 quadros/s da área do nome (`q\mc_r.png`) e quadros cheios a 42,05, 42,6, 43,2, 43,4 e 43,8 s (`q\mrei.png`): de 42,0 a 43,25 s o quadro segurado é o do banner **"ENEMY TURN"**, com o Rei de asas abertas, e **sem o nome do golpe**. Depois do corte de 43,25 s os corvos já estão batendo (vida 22, 21). O nome não aparece em nenhum quadro da variante. Na principal ele está lá (41,95 a ~43,0 s, `q\mc_t.png`). O `corte9.md` diz "nome legível 1,1 s (quadro do nome segurado 66 quadros)", mas o quadro segurado no Rei (tomada 2187) não é o do nome. Isso também quebra o "igual nas duas versões" do ponto 2 do corte 8. **Exijo** segurar, no Rei, o quadro da tomada em que "Murder of Crows" está cheio (o mesmo da principal), por ~1,1 s, com os corvos partindo no corte de 43,25 s.

### Tirano: pouso do anjo fora da batida (C3)
O corte para o anjo a **26,819 s** tem só 11,8 dB de subida no grave; o ataque forte mais próximo é **26,552 s (19,7 dB), a −16 quadros**. No fluxo espectral não há onset forte em ±0,6 s nesse trecho da faixa, então a referência é o grave, como nos cortes anteriores (no 8b o pouso estava a +1,3 quadro de um ataque de 15,8 dB). Esporo (25,38 s, +0,4 quadro) e portão (27,968 s, +2,2 quadros de 16,9 dB) estão no tempo. **Exijo** o corte do anjo em 26,552 s: esporo 1,17 s e anjo 1,42 s, sem mexer no portão.

## Medidas

| | principal (Tirano) | variante (Rei) |
|---|---|---|
| quadros < 5% de luma | 0 de 3870 | 0 de 3870 |
| loudness / pico / LRA | −14,1 LUFS / −1,0 dBTP / 8,1 LU (1080p = 720p) | −14,1 / −1,2 / 8,5 |
| margem do pico | +2,4 dB | +3,1 dB |
| coringa: música abaixo do SFX | 4,7 dB | 5,2 dB |
| respiro antes do 48 | −47 a −72 dBFS por 0,5 s | −47 a −72 dBFS por 0,5 s |
| silêncio da entrada / tom de sala | música −174 a −180 no trono e no escuro, volta de +57 dB no nome | idem, volta de +73 dB |
| música no fecho | até 64,5 s, com fade | até 64,5 s, com fade |

## Notas

| critério | Tirano | Rei | | ponto | Tirano | Rei |
|---|---|---|---|---|---|---|
| C1 Gameplay ≤ 2 s / quadro 0 | 10 | 10 | | G1 nenhum quadro preto | 10 | 10 |
| C2 Sem preto | 10 | 10 | | G2 caminhada | 9 | 9 |
| C3 Sincronia | **8** (anjo a −16 q) | 9 | | G3 salões | 9 | 9 |
| C4 Legibilidade | 9 | **8** (golpe sem nome) | | G4 luta do Rei sem interrupção | 10 | 10 |
| C5 Ritmo | 9 | 9 | | G5 golpe final forte | 9 (sem zoom, com flash, tremor e "48") | 9 |
| C6 Pico | 9 (+2,4) | 10 (+3,1) | | G6 LETAL do gancho | 10 | 10 |
| C7 Regra de 3 | 9 | 9 | | G7 textos exatos | 10 | 10 |
| C8 Fecho | 9 | 9 | | N1 virada legível | 9 | 9 |
| C9 Conformidade | 9 | 9 | | N2 caminhada / porta | 9 | 9 |
| C10 Checklist do Daniel | 9 | 9 | | N3 salões na grade | 9 | 9 |
| C11 Continuidade | 9 | **8** (versões diferentes na Revoada) | | N4 sem zoom (Daniel) | 10 | 10 |
| C12 Legal de assistir | 9 | 9 | | N5 mixagem | 9 | 9 |
| C13 Prende | 9 | 9 | | final do logo (Daniel) | 9 | 9 |
| C14 Som | 9 | 9 | | 16 itens do Grimoire | 9 ou mais, menos 00:07-6 (**8**, pela batida) | 9 ou mais, menos 00:06-7 (**7**) |
| **Q queda do Rei** | **9** | **9** | | | | |

## Status
- **Principal (Tirano): NÃO APROVADO**, por um item: o pouso do anjo a 26,819 s, 16 quadros fora do ataque de 26,552 s.
- **Variante (Rei): NÃO APROVADO**, por um item: o anúncio "Murder of Crows" não aparece (o quadro segurado é o do "ENEMY TURN").

As duas correções são de EDL, sem render de salão. Com elas, as duas versões ficam com 9 ou mais em tudo. Fica para o Daniel a dúvida sobre o "final exatamente igual" (bloco do logo igual ao do corte 2, fundo e áudio não). `===CORTE9_PRONTO===` não marcado.

## Rodada 9b (commit c12dea9b; vídeos de 01:47, 01:48 e 01:51): APROVADO nas duas versões

_Mesmos nomes de arquivo do corte 9, regravados. Medidas em `C:\Users\corte\AppData\Local\Temp\claude\E--dev-projects-card-game-love2d\f967decd-bccd-487a-92fd-ff59f9b0ee6d\scratchpad\rev\c9b\` (`q\mc_r.png` a 10 quadros/s, `q\mrei.png` com quadros cheios a 42,2, 42,7, 43,2 e 43,35 s)._

- **Rei, "Murder of Crows": resolvido.** O nome cheio aparece a partir de ~42,1 s e fica parado até 43,2 s (**~1,1 s**), no mesmo quadro da principal (Rei de asas fechadas, intent 4×4, "Murder of Crows" sobre ele). No corte de 43,25 s os corvos partem (vida 25 → 23). As duas versões agora mostram o mesmo anúncio (ponto 2 do corte 8 e item 00:06-7).
- **Tirano, anjo: resolvido.** Corte a **26,55 s**, exatamente no ataque de grave de 19,7 dB (0,0 quadro). O esporo fica com 1,17 s e o anjo com 1,42 s; o portão continua a 27,968 s (+1,2 quadro de 16,3 dB). O "corte" que o detector acusa a 27,08 s é o pouso do anjo dentro do plano (antes a 27,35 s), não um corte de plano.
- **Nada mais mudou:** no Rei, os cortes são idênticos aos do corte 9; na Tirano só mudaram esses dois pontos. Zero quadros < 5% nos três arquivos. Tirano −14,1 LUFS, −0,9 dBTP, LRA 8,1, margem do pico **+2,5 dB**; Rei −14,1, −1,2, 8,5, **+3,1 dB**. Coringa com a música 4,7 dB (Tirano) e 5,2 dB (Rei) abaixo do SFX. Golpe, respiro, queda, carta, salões e logo como medidos acima.

### Notas (9b)
Iguais às do corte 9, com as mudanças abaixo: **Tirano C3 Sincronia 9**, item 00:07-6 **9**; **Rei C4 Legibilidade 9**, **C11 Continuidade 9**, item 00:06-7 **9**. Todos os critérios ficam com 9 ou mais nas duas versões, inclusive **Q = 9**, os 16 itens do Grimoire e os dois pontos do Daniel (sem zoom: 10; final do logo: 9).

Fica registrada a dúvida para o Daniel: o bloco do logo é igual ao do corte 2 (tempos e texto), mas o fundo e o áudio do final não são idênticos ao corte 2.

## Status final do corte 9
- Principal (Tirano) 1080p e 720p (9b): **APROVADO**.
- Variante (Rei-Carniça) 720p (9b): **APROVADO**.

Continuam valendo: **não publicável até trocar ou licenciar os SFX**; ninguém ouviu as mixagens.

===CORTE9_PRONTO===
