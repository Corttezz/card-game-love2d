# Revisão independente: corte 11g (corte 11, revisão 7), versões Tirano e Rei

_Revisora independente (revisora-grimoire), 03/11/2026. Não li nenhum `revisao-corte11*.md` da revisora do time antes de dar as notas. As alegações da diretora (`corte11g.md`, `corte11g_provas\`) foram tratadas como alegação e medidas de novo, direto dos mp4. Não ouvi as mixagens: o som foi avaliado por loudness, envelope RMS, banda grave e onsets._

## Que arquivo foi revisado (importante)

- Revisei as **cópias entregues** `C:\Users\corte\grokbot_entrega\corte11g_720p.mp4` (sha256 `4e51ba0b…`) e `corte11g_rei_720p.mp4` (`384add0a…`). No início eram idênticas byte a byte (`cmp`) aos arquivos de `build\trailer\` do commit 6d8811f6.
- **Durante a revisão (04:32), `grimoire_trailer_c11g.mp4` e `grimoire_trailer_c11g_720p.mp4` (Tirano) foram re-renderizados em `build\trailer\`**, e o `tools/trailer_c11g_cut.py` do repositório do trailer está modificado sem commit. O 720p passou de 120.874.616 para 110.624.816 bytes. A versão Rei não mudou.
- Por isso, toda medição e toda folha do Tirano foram refeitas sobre a cópia entregue. O `.gray` extraído antes da troca é idêntico ao da cópia entregue (`cmp`). **Esta revisão vale para o 11g entregue, não para o que está em `build\` agora.**

Provas em `revisao-grimoire-corte11g_provas\`: folhas JPG, mais `medicoes.txt` com todas as saídas numéricas. Os scripts ficaram fora do repo, em `%TEMP%\claude\rgc11g\`.

## Veredito

| versão | 11f (minha nota) | **11g** | passa (9,0 e claramente melhor)? |
|---|---|---|---|
| **Tirano** (principal, escolha do Daniel) | 8,8 | **8,9** | **não, por pouco** |
| **Rei** (alternativa) | 9,1 | **9,2** | **sim** |

O 11g resolve o que eu pedi para o clímax:
- os corvos agora correm a 1,8x;
- o golpe letal tem hit-stop, flash e shake, sem zoom, e passa a música;
- os salões do Tirano ganharam um grave de verdade em cada troca.

Mas a correção 4 (a morte nas cartas) **piorou o som da jogada de cartas**, que é justamente o "satisfatório" que o Daniel pediu:
- o golpe de −30 está 6 dB mais baixo que no 11f;
- ele chega 0,25 s depois do flash, já dentro do glitch para a Coleção, e a cauda é cortada pela Coleção muda;
- no Tirano, o golpe que mata fica **abaixo** da música de 1 s antes;
- o inimigo continua sem ser visto caindo.

No Tirano, isso se soma a três trocas de salão do meio que ainda batem fraco. Por isso a nota fica abaixo de 9.

## Medições (as minhas)

| item | Tirano | Rei | prova |
|---|---|---|---|
| duração / vídeo | 67,4 s, 1280x720 60 fps, 14,3 Mb/s (o 1080p não foi usado; ver acima) | 68,4 s, 14,4 Mb/s (1080p 34,5 Mb/s) | ffprobe |
| loudness | −14,0 LUFS, pico real −1,3 dBFS, LRA 10,6 | −14,0 LUFS, −0,9 dBFS, LRA 9,2 | `ebur128=peak=true` (confere com a diretora) |
| quadro 0 / pretos | luma 8,2 (TV desligada, como no v8 e no 11f); preto só de 0,53 a 0,78 s e na cauda | igual | `medicoes.txt` |
| flashes | no máximo 2 flashes distintos por segundo (as 4 subidas em 16,42 a 16,47 s são um flash só) | igual | abaixo do limite de 3 por segundo |
| zoom | nenhuma mudança de enquadramento nas folhas a 2, 4, 10 e 20 q/s. A carta que cresce em 24,4 s é animação do jogo. O shake do golpe letal é deslocamento, não escala. | igual | `t_2qps_*.jpg`, `t_golpe_letal_20qps.jpg` |
| final Grimoire | 390 de 390 quadros do `logo_sting.mp4`, diferença média 1,6/255 (máx. 2,22) | igual | `medicoes.txt` |
| continuidade de vida na luta | 41/70 → 41 → 41 → 9/70 nos cortes; chefe 124 → 65 → 30 → 21/220, contínuo | igual (em 51,85 s a vida está rolando por causa do −55 da Imolação, não é salto) | `t_hp_cortes.jpg`, `r_hp_cortes.jpg` |

Linha do tempo do Tirano: TV ligando 0 a 3 s → seis atos 3 a 16,3 s (música entra em 12,6) → cartas 16,5 a 24,7 → Coleção 24,7 a 29,9 → criaturas 29,9 a 39,6 → salões 39,6 a 45,3 → portão 45,3 a 46,5 → entrada do Rei 46,5 a 49,8 → luta 49,8 a 57,8 → morte 57,8 a 60,5 → final 60,8 a 67,3.

### Os quatro itens do escopo do 11g

**1. Grave nas trocas de salão do Tirano.** Banda de 20 a 150 Hz, pico no corte contra a mediana de 1 s antes:

| corte (s) | 39,58 | 40,70 | 41,83 | 42,70 | 44,13 | portão 45,33 |
|---|---|---|---|---|---|---|
| **11g**: subida do grave | +16,3 | **+6,3** | **+7,5** | +9,4 | +13,2 | +11,4 dB |
| 11f: subida do grave | +9,0 | +3,5 | −1,5 | +1,8 | +4,0 | +2,3 dB |
| 11g: pico do mix contra a música (RMS de 100 ms, cama sem duck) | +12,3 | +5,2 | **+2,4** | +5,4 | +7,3 | +5,9 dB |
| Rei 11g: subida do grave, para comparar | +31 | +28 | +8,5 | +24 | +30 | +17 dB |

- **Melhorou de verdade:** em média, cerca de +7 dB de grave por corte em relação ao 11f, e nenhum corte fica negativo.
- **Ainda fraco no meio:** em 40,70, 41,83 e 42,70 a própria faixa do Tirano tem grave alto (cama de −8 a −13 dB) e o impacto sobe só 6 a 9 dB.
- **O ataque chega atrasado:** o pico do impacto vem 80 a 180 ms **depois** do corte de imagem. É o ataque lento do `boss_land_impact`.
- **A faixa continua plana:** os onsets da faixa sozinha nesses cortes são de 2,3 a 3,4x, com grave de 0,1 a 2,9x (`medicoes.txt`). Quem marca o tempo é o efeito sonoro, não a música.
- **Os números da diretora não se reproduzem:** os "8,4x a 20,9x" não aparecem com o meu método de onsets sobre o mix (0,3 a 2,2x de grave no onset mais próximo). Com a medida de energia acima, a melhoria é real, mas menor que a alegada.
- **Sobre a alegação da revisora do time ("40,710 s, +3,6 dB, a mais fraca"):** eu acho o mais fraco em **41,83 s** (+2,4 a +3,4 dB). O 40,70 vem logo depois (+4,5 a +5,2 dB). A conclusão é a mesma: o meio da montagem é o ponto fraco.

**2. Corvos a 1,8x.**
- Tirano: 52,70 a 55,55 s, ou seja, **2,85 s** (eram 5,4 s).
- Rei: 53,22 a 56,37 s, ou seja, 3,15 s (eram 5,0 s).
- A vida segue contínua: herói 41 → 9, chefe 30 → 21 (`t_corvos_4qps.jpg`, `t_hp_cortes.jpg`).
- **Resolvido.**

**3. Golpe letal.**
- Imagem (Tirano, a partir de 57,18 s; Rei, a partir de 58,12 s):
  - 5 quadros congelados (diferença entre quadros de 0,1 a 0,2);
  - flash branco (luma de 55 para 187), que some em 5 quadros;
  - shake de 57,38 a 57,72 s, que amortece sozinho;
  - corte para a morte dessaturada em 57,78 s;
  - nenhum zoom (`t_golpe_letal_20qps.jpg`).
- Som:
  - música cai a −35 dB antes do golpe e o golpe vem a −1,7 dB;
  - **Tirano: +12,4 dB** sobre a música **sem duck** de 1,6 a 0,6 s antes (+14,5 contando a cama já em duck);
  - **Rei: +7,2 dB** (+8,9);
  - grave: +26,5 dB (Tirano) e +28,2 dB (Rei).
- A diretora alegou +19,6 / +17,9; a revisora do time, +11,1 / +8,5. Os meus números ficam perto dos da revisora do time. A meta de ≥ 12 dB **é atingida no Tirano e não no Rei**, porque a música do Rei está mais alta 1 s antes (−9 dB).
- Pelo contraste vale e grave, os dois golpes agora leem como impacto. **Resolvido no Tirano e quase resolvido no Rei.**

**4. Morte nas cartas** (`t_cartas_morte_10qps.jpg`, `r_cartas_morte_10qps.jpg`).
- **Imagem:** as cartas ficam na frente do inimigo **0,3 s** em vez de 1,2 s. O −30 e o flash (24,42 s no Tirano, 24,10 s no Rei) aparecem, e o glitch para a Coleção vem em 24,67 s.
  - O inimigo continua **sem ser visto caindo**: o último quadro em que o bruto aparece inteiro é 23,9 s (Tirano), ainda com 7/55.
  - A morte se lê pelo "−30" em cima da carta, não pelo monstro.
- **Som (regressão):** pico do mix em [t−0,05; t+0,35]:

| | 11f Tirano | 11g Tirano | 11g Rei |
|---|---|---|---|
| pico | −9,4 dB (sustentado −10 a −11 por 0,35 s) | −15,5 a −17,2 dB, um estalo de 50 ms | −13,0 dB |
| contra a música de 1 s antes | +3,9 dB | **−4,2 dB** | **−2,3 dB** |
| contra o vale logo antes | +19 dB | +13 dB | +6 dB |

  - O golpe que mata soa **6 a 7 dB mais baixo que no 11f**: confirmo a alegação da revisora do time.
  - Ele cai **0,25 s depois do flash** (o flash é em 24,42 s e o som em 24,66 s, junto com o glitch).
  - A cauda é cortada pela Coleção muda.
  - Resultado: a jogada termina num estalo pequeno que se confunde com o som do glitch. **Não está resolvido, e no som piorou.**

### Pendências antigas

| item | estado no 11g | segura a nota? |
|---|---|---|
| porta escura de 1,5 s | resolvida desde o 11e: o portão (estrada) dura 1,1 s e vai direto ao rasante roxo (`t_saloes_4qps.jpg`) | não |
| duck nos golpes do combo das cartas | Tirano: +7,5 / +11,2 / +10,4 dB nos três primeiros golpes. O 4º e o 5º (22,66 e 23,23 s) ficam em +2,8 e −3,3 dB, porque a música já subiu. Rei: +6 a +7 dB. | pouco |
| HUD "HERO 70/70" no portão | continua: Tirano de 45,35 a 45,57 s (~0,2 s), Rei de 45,80 a 46,03 s (`t_portao_hud_20qps.jpg`, `r_portao_hud_20qps.jpg`). A luta abre com 41/70. | pouco |
| "SIX BOSSES." sobre cinco salões | igual (decisão do Daniel) | não pontuo |

## Pontos do Daniel (citação literal de `tdz_c11.txt`, 02/11 22:30)

| # | o que ele disse (literal) | Tirano | Rei | evidência e comparação com o 11f |
|---|---|---|---|---|
| 1 | "Esses techs que você tá colocando aí são muito ruins. Tu não colocou chains, tipo, por que correntes? Por que a gente quer enfatizar isso? Isso é algo, só um detalhe do jogo." | 8,5 | 8,5 | Igual ao 11f: SIX ACTS. ONE ROAD TO THE CASTLE / BUILD A LIVING DECK / EVERY CARD COMES ALIVE / A BESTIARY OF THE CURSED / SIX BOSSES / ONE HAND CAN BREAK A KING. Nada de CHAINS/FROST. A fonte e a posição continuam as mesmas dos cartões que ele odiou no 10d, e "SIX BOSSES." aparece sobre cinco salões. |
| 2 | "Não faz o menor sentido ali a entrada já ser as cartas. As entradas poderiam ser iguais a como estava em alguns teasers para trás: seis atos mostrando um pouquinho sobre cada um deles, meio que andando para frente em cada ato, com som ambiente calminho." | 9,0 | 9,0 | Igual ao 11f: seis atos de ~2,3 s andando pela estrada (floresta, noite, inferno, gelo, pântano, crepúsculo). Só ambiente, de −23 a −31 dB RMS, até a música em 12,6 s (`t_2qps_1.jpg`, linhas 1 a 4). |
| 3a | "...ele só mostra os vídeos na hora de falar que tem vários, vários beings, vários bosses. Aí foi mostrando cada vídeo um após o outro, e isso que eles trocavam de vídeo, seguindo ali o ritmo e o tempo da música. Isso eu achei muito legal." | **8,6** (era 8,0) | 9,3 | Tirano: agora cada troca tem um baque grave, de +6 a +16 dB (era −1,5 a +9). Mas o meio da montagem é fraco (+2,4 a +5,4 dB no mix), o pico chega 80 a 180 ms depois do corte e o tempo vem do efeito sonoro, não da música. Rei: igual ao 11f, com o grave da própria faixa (+17 a +31 dB). Nas duas, a montagem **não foi estendida**: 5 salões de ~1,15 s, ~5,8 s. |
| 3b | "...pelo menos você mostrou os vídeos do Riggs Field por algum motivo. Os vídeos ficaram com uma qualidade muito ruim, mas muito ruim mesmo." | 8,5 | 8,5 | Os mesmos salões do 11f: nítidos a 14 Mb/s, mas ainda vídeo de IA (Higgsfield). |
| 3c | "O ideal é que dê uma sensação de algo épico, algo legal, que o seu jogar as cartas seja algo satisfatório." | **8,8** (era 8,6) | **9,1** (era 9,0) | Melhorou o clímax: corvos em 2,85 s e golpe letal com hit-stop, flash e shake a +12,4 dB (Rei +7,2). Piorou a jogada de cartas: o golpe que mata está 6 a 7 dB mais baixo, 0,25 s atrasado, cortado, e a morte segue invisível. |
| 3d | "Pode mostrar o deck em determinado momento ali, a coleção, com as cartas liberadas, mostrando tudo ali descendo." | 9,0 | 9,0 | Igual: a grade rola ~3 s e duas cartas abrem grandes (Blood Sword, Helm of Valor). |
| 3e | "É legal a gente mostrar também as entradas de algumas criaturas. A entrada do Espantalho é bem legal, e a entrada de algumas outras é legal também." | 9,3 | 9,3 | Igual: Espantalho, Grifo, Anjo Caído e Serpe de gelo, de 29,9 a 39,6 s. |
| 4 | "...a gente tinha uma finalização ali do Grimoire sendo preenchido com ícone, animações e extensões, e isso tudo se perdeu nessa sua versão. Você nem que jogou fora algo que está funcionando em cinco, seis versões anteriores." | 10 | 10 | 390 de 390 quadros, 1,6/255, idêntico ao v8. |

Regras permanentes:
- Sem zoom: ok.
- Impacto só por hit-stop, flash e shake: agora sim, no golpe letal.
- Análise por quadros e medição: feita.

## Comparação com os melhores anteriores

Base: as minhas medições do v8, v6 e 10d nas revisões anteriores, e as do 11f acima.

| ponto | v8 | v6 | 11f | **11g** | 11g contra o melhor anterior |
|---|---|---|---|---|---|
| abertura com 6 atos e ambiente | só o ato 1 | 6 atos + citação placeholder | 6 atos, dissolve curto | igual | **melhor** que v8/v6; igual ao 11f |
| jogada de cartas satisfatória | `deck8` (466) | mago | 55 → 7 → morte coberta, golpe a −9,4 dB | 55 → 7 → morte coberta, golpe a −16 dB | melhor que v8/v6 em história; **pior que o 11f no som** |
| coleção | não tem | maior (6 cartas + coringas/pacotes) | grade + 2 | igual | pior que o v6 |
| criaturas / Espantalho | sem Espantalho | não tem | com Espantalho | igual | melhor |
| montagem dos chefes no ritmo | 5 salões no drop | 4 salões | Rei forte, Tirano sem grave | Rei forte, Tirano com grave colado | Rei igual ou melhor; Tirano melhor que o 11f, ainda abaixo do drop do v8 e do Rei |
| clímax | luta para no meio | morte dessaturada | corvos 5,4 s, golpe sem peso | corvos 2,85 s, hit-stop + flash + shake | **melhor** que todos |
| final Grimoire | referência | igual | igual | igual | igual |
| textos | rúnicos + citações | citações | 6 cartões | igual | melhor, com a ressalva do item 1 |

- **Rei:** claramente melhor que o v8 e o v6 no conjunto (abertura, criaturas, clímax), igual no final e na montagem. É melhor que o 11f no clímax e só um pouco pior na jogada de cartas.
- **Tirano:** melhor que o 11f no clímax e na montagem. Mas o momento que o Daniel disse que amou (a troca de chefes no ritmo) ainda bate menos que no Rei e no drop do v8, e a jogada de cartas perdeu o soco. Não é "claramente melhor" o bastante para passar.

## Ele vai gostar? (honesto)

- **Rei:** provavelmente sim. A lista dele está toda lá, na ordem dele, com o final que ele amava, e agora o clímax tem peso. O risco é a jogada de cartas terminar num estalo: ele pediu "jogar as cartas seja algo satisfatório", e a carta que mata é o momento em que ele vai prestar atenção.
- **Tirano:** é a versão que ele escolheu como principal. Melhorou onde eu mais criticava: corvos, golpe letal e troca de salões com baque. Ainda assim, é provável que ele sinta a montagem dos chefes "menos no ritmo" que a do Rei, porque a faixa não acompanha os cortes e o baque chega um pouco depois do corte. Some a isso o mesmo estalo na carta que mata.

## Correções sugeridas para a próxima revisão (sem captura nova)

1. **Morte nas cartas** (Tirano 24,42 s, Rei 24,10 s): é a mais importante, vale para as duas versões e é a única coisa que o 11g piorou.
   - Pôr o som do golpe −30 **no quadro do flash**, e não 0,25 s depois.
   - Subir +6 a +8 dB, até ficar ≥ 6 dB acima da música de 1 s antes.
   - Deixar a cauda (0,3 a 0,4 s) atravessar o glitch para dentro da Coleção. Hoje a Coleção é muda e corta o som.
   - Se houver no take quadros em que as cartas já saíram e o bruto cai, usar 0,3 s deles antes do glitch.
2. **Salões do Tirano** (40,70 / 41,83 / 42,70 s):
   - Adiantar o impacto em ~0,1 a 0,15 s, para o **pico** cair no quadro do corte.
   - Aprofundar o duck da música nesses três cortes para −8 dB por 200 ms. A cama ali é de −7 a −10 dB.
   - Meta: ≥ +8 dB no mix em cada troca.
3. **Golpe letal do Rei** (58,22 s): começar o duck ~0,3 s mais cedo ou mais fundo, para passar de +7 para ≥ +12 dB sobre a música de antes.
4. **Portão** (Tirano 45,35 a 45,57 s; Rei 45,80 a 46,03 s): entrar ~0,25 s mais tarde, quando o HUD 70/70 já sumiu.
5. **Pendentes com o Daniel:** "SIX BOSSES." sobre cinco salões, e se a montagem deve ser estendida (hoje 5,8 s).

Com 1 e 2, eu esperaria Tirano ~9,1. Com 1 e 3, Rei ~9,4.

## Itens em aberto

- Ninguém, nem eu, ouviu as mixagens.
- SFX do plano free do ElevenLabs: substituir ou licenciar antes de publicar.
- Salões feitos em IA (Higgsfield): o Daniel não gostou da qualidade. Rotular e declarar o uso de IA se for publicado.
- O Tirano em `build\trailer\` foi re-renderizado durante esta revisão, com o script de corte modificado sem commit. O que for entregue depois precisa de revisão nova.

## Comandos usados

- `cmp` e `sha256sum` contra as cópias entregues.
- `ffprobe -show_entries format=duration,bit_rate:stream=width,height,r_frame_rate`.
- `ffmpeg -vf scale=96:54,format=gray -f rawvideo` + `ana.py` (cortes, pretos, onsets das faixas próprias, M_IN = 12,6, P0 = 21,0 Tirano / 36,0 Rei, conferidos em `trailer_c11g_cut.py`).
- `onsets.py` (força, posição e grave do onset) e `bass.py` (energia de 20 a 150 Hz no corte contra 1 s antes).
- `hit2.py` (RMS de 100 ms, pico contra duas camas: [−1,6; −0,15] s e [−1,6; −0,6] s) e `env2.py` (envelope de 20 e 50 ms).
- `ffmpeg -af ebur128=peak=true`.
- `logo.py` (390 quadros contra `brand/logo_sting.mp4`).
- `sheet.py` (folhas a 2, 4, 10 e 20 q/s com recortes); `hp720.py` (vida nos cortes).
