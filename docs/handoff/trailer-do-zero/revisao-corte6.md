# Revisão: corte 6 (trailer-do-zero)

_Revisora independente, 01/11/2026. Base: `corte6.md` (commit efe8747b), `revisao-grimoire-corte5.md` (10 pontos, commit 09ac75f6) e os critérios de sempre. Vídeos: `grimoire_zero_corte6_1080p.mp4`, `_720p.mp4` e `_rei_720p.mp4`. Método: luma de todos os quadros, cortes e loudness (`medir.py`, saída em `...\scratchpad\rev\c6\t1080.txt`, `t720.txt`, `rei.txt`); mixagem por plano sobre os stems reais `build\trailer\zero6\zero6_tirano\` e `zero6_rei\zero6_rei_rei\` (`mixagem.py` → `mix6_tirano.json`, `mix6_rei.json`); força de ataque do grave (30 a 160 Hz, ±30 ms) em cada corte; onsets de banda cheia por fluxo espectral em mel, reimplementado à mão porque o librosa não está instalado aqui (`...\rev\flux.py`); folhas a 5, 10 e 20 quadros/s e recortes 1:1 em `...\rev\c6\q\` (scratchpad da sessão: `C:\Users\corte\AppData\Local\Temp\claude\E--dev-projects-card-game-love2d\f967decd-bccd-487a-92fd-ff59f9b0ee6d\scratchpad\rev\`). Não ouvi._

## Os 10 pontos do Grimoire: real ou falso, conferido por conta própria

| # | ponto | diretora | minha conferência | situação no corte 6 |
|---|---|---|---|---|
| 1 | zoom que recua (~0:53) | real (soco de câmera da cinemática do jogo) | **Real no corte 5**, e a causa é a que ela diz. Conferi as provas `tirano/p1_*`. | **Resolvido nas duas.** Hit-stop ×2 congelado com o "48" e depois ×3 fixo: o tamanho do pixel de captura medido fica em 13 a 14 px de 51,0 a 54,4 s (1080p), e o fundo (pilares, arcos) não sai do lugar quadro a quadro de 50,85 a 51,95 s (`q\zoom_t.png`, `q\zoom_r.png`). O que muda é só o Rei se ajoelhando. O detector acusa um "corte" a 51,35 s (Tirano) e a 51,17 s (Rei): é o corpo baixando e as velas aparecendo atrás das asas, não um degrau. |
| 2 | caminhada de 6 s antes do castelo | real | **Real** (corte 5: 4,57 s Tirano / 5,03 s Rei). | **Resolvido**: esporo 1,0 s + anjo 1,0 s nas duas (`q\cast_t.png`, `q\cast_r.png`). **Mas abriu uma regressão de sincronia no Rei** (ver abaixo). |
| 3 | portão do Rei parece imagem parada com zoom digital | falso | **Falso.** Folhas fechadas → abrindo → abertas dentro do plano, sem degrau de zoom (`q\cast_r.png`, 27,1 a 30,0 s); `castleGateOpen` no plano. | ok |
| 4 | 48 só na UI pequena | falso | **Falso** (já na minha pré-checagem do corte 5, `p6/zoom5.png`). No corte 6 o "48" vermelho grande está sobre a coroa nas duas (`q\queda_t.png`, `q\queda_r.png`). | ok |
| 5 | BREAK THEM BACK. entra durante a queda | real | **Real no corte 5** (texto 0,04 s depois do impacto, com a poeira subindo). | **Resolvido**: o corpo bate, a poeira baixa sobre quadros segurados e o texto entra cerca de 0,65 s depois (Tirano, 1,37 s na tela) e 0,6 s depois (Rei, 1,27 s). Os dois passam da régua de 1 s a cada 13 caracteres (16 → 1,23 s). Queda da cedida ao impacto continua ≤ 2,5 s. |
| 6 | Carrion Crown parada só ~1 a 1,5 s | real | **Real.** O texto do Grimoire mistura espólio e coringa (o espólio mostra Poison Dart e Rain of Blades), mas a carta nomeada é a Carrion Crown e o "~1 a 1,5 s" bate com o plano do coringa de 1,22 s. A leitura da diretora está certa. | **Resolvido**: face assentada e legível de ~55,4 a 58,3 s nas duas, cerca de 2,9 s, com o nome embaixo (`q\cor_t.png`, `q\cor_r.png`). |
| 7 | só o verso, sem a face | falso | **Falso na letra** (corte 5: face legível ~1,2 s, `p6/coringa5.png`). | ok, e agora com folga. |
| 8 | "145 LIVING CARDS." sem ponto | falso | **Falso.** O ponto está no quadro nas duas (`q\esp.png`). | ok |
| 9 | salões do Higgsfield com ruído/paleta | em parte | **Em parte**, de acordo. A grade de 5 px já estava certa; os pixels soltos procediam. | **Resolvido**: no trono (1:1, corte 5 a 33,6 s × corte 6 a 31,1 s, `q\trono56.png`) as manchas de fogo viraram áreas limpas, sem pixel isolado, e a paleta é a mesma. No gelo a diferença é pequena, mas não há ruído (`q\gelo56b.png`). Nenhum salão trocado. |
| 10 | onsets do Rei nos 5 cortes | tabela librosa | **Tabela confirmada.** No meu fluxo espectral, queda (50,78 s), coringa (54,555 s) e logo (58,30 s) estão no onset mais forte em ±0,6 s, a ≤ 2 quadros dele (a diferença de ~2 quadros contra a tabela dela é um deslocamento fixo do meu método). Revoada está num onset mediano, e o LETHAL do gancho não tem ataque forte em ±0,6 s em nenhum dos dois métodos. No grave, o coringa tem 14,8 dB (no limite) e há um baque de 28,8 dB 8 quadros depois. A regra do Grimoire (banda cheia) está cumprida, então fica só registrado. | ok |

**Afirmação do `corte6.md` que não confere:** "o plano da queda agora acaba antes de a carta entrar no quadro". **Não acaba.** Na principal, a Carrion Crown sobe e gira por baixo de "BREAK THEM BACK." e sobre o corpo de ~54,65 a 54,88 s (14 quadros, face → verso → face → quina → verso, `q\carta_t.png`). O plano do coringa então recomeça com verso e quina antes da face, e o giro lê duas vezes. No Rei isso dura ~6 quadros (54,45 a 54,55 s, `q\carta_r.png`).

## Versão principal (Tirano), 1080p e 720p: NÃO APROVADO

O que está bom: zero quadros < 5% nos 3870 quadros dos dois arquivos; −14,1 LUFS, −1,0 dBTP, LRA 9,2 (1080p = 720p); coringa com a música **4,6 dB abaixo do SFX** (−20,7 / −16,1); golpe no ataque (10 ms); salão do trono com tom de sala e música zerada até o nome (volta de +57 dB no cartão, no ataque, a 0 ms); pouso (26,38 s, 1,3 quadro de um ataque de 15,8 dB) e portão (27,38 s, 0 ms do grave) no tempo. Os cortes depois do castelo andaram junto com a música: as distâncias aos ataques são idênticas às do corte 5 aprovado. Pico: −9,6 LUFS de curto prazo no clímax contra −11,7 no melhor trecho fora dele (janela de 3 s já fora do clímax), **margem de 2,1 dB**. Passa, mas raspando.

### O que segura

1. **A música acaba seca a 60,6 s e o fecho fica sem trilha (C8, C14).** Com a passagem nova, a faixa do Tirano chega ao fim do arquivo 2,47 s antes. No stem a música está em −19 dB a 60,1 s, cai para −39 a 60,5 s e é zero digital a partir de 60,7 s, sem fade. Daí até 64,5 s (3,9 s) o logo segue sem música, e **"WISHLIST ON STEAM" (62,17 s) entra em silêncio musical** (mix de −19 a −53 dB, só efeitos). No corte 5 aprovado a música ia até 63,0 s, debaixo do fade final. O próprio `corte6.md` registra isso ("o filme segue até 64,5 s"), mas o resultado é um fecho que soa como se a trilha tivesse acabado antes do trailer. **Exijo** música até o fim do filme, ou um final de verdade (fade ou acorde final) que pouse no GRIMOIRE/selo e emende num tom que segure o wishlist, sem o corte seco a −19 dB. Sem trocar de faixa: a mesma peça, outro trecho ou outro arranjo do final dela.
2. **A carta aparece debaixo de "BREAK THEM BACK." (C11).** São os 14 quadros descritos acima. Corrigir como o `corte6.md` diz que já estava: segurar o corpo caído (sem a carta) até o corte de 54,88 s, que está num ataque forte (grave de 35 dB a −1,4 quadro), ou cortar antes de a carta nascer.

### Notas da versão principal

| critério | nota | | ponto | nota |
|---|---|---|---|---|
| C1 Gameplay ≤ 2 s / quadro 0 | 10 | | G1 nenhum quadro preto | 10 |
| C2 Sem preto | 10 | | G2 caminhada | 10 |
| C3 Sincronia | 9 | | G3 salões legíveis e marcantes | 9 |
| C4 Legibilidade | 9 | | G4 luta do Rei sem interrupção | 10 |
| C5 Ritmo | 9 | | G5 golpe final forte | 9 |
| C6 Pico | 9 (margem 2,1 dB) | | G6 LETAL do gancho | 10 |
| C7 Regra de 3 | 9 | | G7 textos exatos | 10 |
| C8 Fecho | **8** (wishlist sem música) | | N1 virada legível | 9 |
| C9 Conformidade | 9 | | N2 caminhada / porta | 10 |
| C10 Checklist do Daniel | 9 | | N3 salões na grade nativa | 9 |
| C11 Continuidade | **8** (carta sob o texto, giro duplo) | | N4 zoom em degraus progressivos | 10 |
| C12 Está bom / legal de assistir | 9 | | N5 mixagem | **8** (fim da música) |
| C13 Prende do início ao fim | 9 | | correções do corte 4 | 9 em todas |
| C14 Som | **8** (corte seco da faixa a 60,6 s) | | 6 pontos do corte 4 | 9 em todos |
| Q queda do Rei | 9 | | 10 pontos do corte 5 | 1 a 10: 9 ou mais em todos |

## Variante do Rei (720p): NÃO APROVADO

O que está bom: zero quadros < 5%; −14,1 LUFS, −1,2 dBTP, LRA 8,4; pico −9,0 contra −12,1 fora do clímax (**+3,1 dB**); coringa com a música **4,9 dB abaixo do SFX** (−21,7 / −16,8); a música segue até o fim, debaixo do fade do logo; queda (50,78 s, ataque de 55,9 dB a −0,5 quadro) e logo no tempo; Revoada (42,0 s, 18,3 dB a 0,6 quadro). O silêncio da entrada continua íntegro (música a −108 no escuro, volta de +73 dB no nome, no ataque).

### O que segura

1. **Os dois cortes novos antes do castelo saíram da batida (C3).** Na variante a faixa antes do silêncio é contínua, então encurtar a montagem moveu o pouso e o portão para fora do grid. No corte 5 os dois estavam no ataque (5 e 70 ms). Agora:

| corte | t (s) | grave ±30 ms | ataque forte mais próximo | fluxo espectral |
|---|---|---|---|---|
| esporo | 25,07 | 56,3 dB | no corte (−1,0 q) | ok |
| pouso do anjo | 26,07 | 22,2 dB | no corte (+0,5 q), mas | o onset mais forte em ±0,6 s (11,4) está em **26,31 s, +14 quadros** |
| portão | 27,07 | **6,6 dB (fraco)** | **27,31 s, +14,2 quadros** (20,8 dB) | mais forte em 27,55 s (9,2) |

O portão é um corte guiado pelo evento, como aceitei no corte 4, mas lá o ataque fraco foi escrito no `corte4.md` e o corte 5 o tinha posto no tempo. Aqui a regressão não está registrada. **Exijo** o portão do Rei num ataque forte (27,31 s fica a 0,24 s: esporo e anjo podem ganhar 0,12 s cada, ou o anjo começa em 26,31 s), mantendo os 2 s antes do castelo dentro de ~2,3 s.

2. **Mesma carta sob o texto, mais curta** (~6 quadros a 54,45 a 54,55 s). Mesma correção da principal.

### Notas da variante do Rei

Iguais às da principal, menos:

| critério | nota |
|---|---|
| C3 Sincronia | **8** (pouso e portão fora da batida) |
| C6 Pico | 10 (+3,1 dB) |
| C8 Fecho | 9 (música até o fim) |
| C14 Som / N5 | 9 |
| C11 Continuidade | 9 (carta por ~6 quadros, giro quase limpo) |

## Status

- **Principal (Tirano): NÃO APROVADO.** Fim seco da música a 60,6 s com wishlist sem trilha (C8, C14, N5 em 8) e carta debaixo do texto por 14 quadros (C11 em 8). O resto passou, e os 10 pontos do Grimoire estão resolvidos ou eram falsos, com prova.
- **Variante do Rei: NÃO APROVADO.** Pouso e portão fora da batida depois do encurtamento (C3 em 8). Os 6 quadros da carta entram na mesma rodada.

São três ajustes de EDL/mixagem, sem tocar em texto, salão nem faixa. `===CORTE6_PRONTO===` não marcado.
