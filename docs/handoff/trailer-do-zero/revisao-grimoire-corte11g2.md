# Revisão independente: corte 11g revisão 2 FINAL (com limitador de áudio), versões Tirano e Rei

_Revisora independente (revisora-grimoire), 03/11/2026. Não li `revisao-corte11g.md` nem `revisao-corte11g2.md` (revisora do time). As alegações da diretora (`corte11g.md`) foram medidas de novo, direto dos mp4. Não ouvi as mixagens: o som foi avaliado por loudness, envelope RMS, banda grave e onsets._

## Que arquivo foi revisado

- `C:\Users\corte\grokbot_entrega\corte11g_720p.mp4` (Tirano), sha256 `70f9f6ef…ae402`, e `corte11g_rei_720p.mp4` (Rei), sha256 `3aec5769…e498b`. Os dois são idênticos byte a byte aos `grimoire_trailer_c11g*_720p.mp4` de `build\trailer\` (04:59). Esta é a versão final, depois do limitador.
- Provas: `revisao-grimoire-corte11g2_provas\`, com as folhas JPG/PNG e o `medicoes.txt` (todas as saídas numéricas). Os scripts ficaram fora do repo, em `%TEMP%\claude\rgc11g2\`.

## Veredito

| versão | 11f | 11g rev 1 (minha) | **11g rev 2 final** | passa (≥ 9,0 e claramente melhor)? |
|---|---|---|---|---|
| **Tirano** (principal, escolha do Daniel) | 8,8 | 8,9 | **9,0** | **sim, no limite** |
| **Rei** (alternativa) | 9,1 | 9,2 | **9,3** | **sim** |

O que a rev 2 resolveu:
- **A morte na jogada de cartas.** Era o único ponto que a rev 1 tinha piorado, e agora está certa nas duas versões: o golpe cai no quadro do flash, fica 9 a 10 dB acima da música e a cauda atravessa o glitch para dentro da Coleção.
- **O golpe letal do Rei** passou da meta de 12 dB.

O que continua igual:
- as três trocas de salão do meio do Tirano;
- o HUD 70/70 no portão;
- o inimigo, que nunca é visto caindo.

Achado novo desta versão final: **a cadeia de normalização comprimiu os golpes grandes em 6 a 12 dB** (detalhes abaixo). As margens finais ainda batem as metas, mas é o motivo de o Tirano parar em 9,0 e não subir mais.

Ele vai gostar? A estrutura é a que ele pediu e o final é o que ele amava. Três riscos de gosto ficam fora do alcance da edição e podem derrubar o corte de novo:
- os cartões de texto continuam com a mesma fonte e a mesma posição dos "techs" que ele odiou;
- os salões de IA, cuja qualidade ele chamou de "muito ruim", são justamente a montagem que ele amou;
- "SIX BOSSES." aparece sobre cinco salões.

## Verificação da etapa do limitador (ninguém tinha revisado)

- **Vídeo:** o 720p de antes do limitador não existe mais, porque o `render11g.sh` sobrescreve o arquivo no lugar. Por isso, a identidade do stream de vídeo **não pode ser provada byte a byte**. O que dá para provar:
  - o script aplica o limitador com `-c:v copy`;
  - o bitrate de vídeo é 14,04 / 14,11 Mb/s, igual ao alegado antes do limitador;
  - a duração é a mesma, 4040 / 4099 quadros;
  - o corte é o mesmo da prévia de revisão anterior ao limitador (`grimoire_trailer_c11g_review.mp4`, 1080p a 30 q/s): diferença mediana de 0,97/255 em 96x54, e os únicos quadros diferentes estão nos cortes, por causa da amostragem a 30 q/s.
  - Conclusão: **edição de imagem idêntica; stream de vídeo copiado, segundo o script.**
- **Loudness final:** Tirano −14,1 LUFS, pico real **−1,2 dBTP**, LRA 10,4. Rei −14,1 LUFS, **−1,1 dBTP**, LRA 8,8. Confere com a diretora, e o problema de pico real apontado pela revisora do time está resolvido.
- **Margens depois do limitador:** confirmo as da diretora, dentro de 0,5 dB, com a janela dela (pico contra a mediana da música de 2,5 a 0,5 s antes). O golpe letal fica em **+18,9 dB no Tirano** (ela alegou +19,0) e **+13,4 dB no Rei** (+13,7).
- **Achado: a normalização comprime os golpes.** A prévia de revisão (`*_review.mp4`, renderizada antes do loudnorm, a −20,2 / −21,0 LUFS) tem os golpes grandes muito mais altos em relação à música. Os golpes pequenos ficam iguais (±1 dB):

| golpe, pico contra a música de 1,6 a 0,15 s antes | prévia sem normalização | final | perda |
|---|---|---|---|
| Tirano, morte nas cartas (24,42 s) | +18,4 | +10,1 | −8,3 dB |
| Tirano, golpe letal (57,28 s) | +26,8 | +20,9 | −5,9 dB |
| Rei, morte nas cartas (24,10 s) | +20,4 | +8,7 | −11,7 dB |
| Rei, golpe letal (58,22 s) | +22,1 | +14,9 | −7,2 dB |
| Rei, salões (39,5 a 44,4 s) | +11,5 a +14,3 | +5,3 a +9,5 | −3 a −6 dB |
| golpes pequenos das cartas (19,4 a 22,5 s) | +4,7 a +6,8 | +4,7 a +7,1 | ≈ 0 |

  - **Causa provável:** a prévia já tem pico real de −1,0 dBTP a −20 LUFS. Levar a −14 LUFS pede +6 dB de ganho, o que poria o pico em ~+5 dBTP. Nesse caso o `loudnorm` do ffmpeg abandona o modo `linear=true` e passa a comprimir dinamicamente.
  - **Ressalva:** a prévia é um proxy de 160 kb/s renderizado antes da revisão 2 ser commitada (04:47 e 04:54). Assumo que é a mesma mixagem, e a coincidência dos golpes pequenos sustenta isso.
  - **Correção barata para a próxima vez:** ganho fixo seguido de um limitador de pico real (ou deixar o golpe a −3 dBTP na mixagem e limitar só o excedente), em vez do `loudnorm`. Isso devolveria 6 a 12 dB de soco sem tocar no vídeo.

## Minha lista de correções do 11h (`tdz_c11h.txt`): o que foi resolvido

| # | pedido | medição na rev 2 final | estado |
|---|---|---|---|
| 1 | Morte nas cartas: som no quadro do flash, +6 a +8 dB, cauda atravessando para a Coleção | Tirano: flash em 24,417 s, o envelope salta de −23,6 para **−6,0 dB em 24,40 s**, fica entre −2 e −7 dB até 24,65 e segue a −10 dB até a Coleção (24,75 a 24,85). Pico −2,9 dB, **+10,1 dB** sobre a música (era −4,2). Rei: salto em 24,10 s, pico −2,7, **+8,7 dB** (era −2,3), cauda de −8 a −15 dB dentro da Coleção (24,43 a 24,65). Grave +16,5 / +14,9 dB. | **resolvido** |
| 2 | Trocas de salão do Tirano em 40,70 / 41,83 / 42,70 s: impacto no quadro do corte e +8 dB ou mais | Subida do grave de **+6,2 / +7,9 / +10,5 dB** (a rev 1 tinha +6,3 / +7,5 / +9,4). O pico do grave continua **80 / 100 / 180 ms depois** do corte. No mix, contra a música de 1 s antes: **+4,8 / +3,7 / +6,2 dB** (rev 1: +5,2 / +2,4 / +5,4). | **não resolvido** (não mudou) |
| 3 | Margem do golpe letal do Rei ≥ 12 dB | **+14,9 dB** (contra a música de 1,6 a 0,15 s antes), +13,4 dB (2,5 a 0,5 s antes), +9,2 dB contra o clímax dos corvos. Grave +28,1 dB. Folha: `r_golpe_letal_20qps.jpg`. | **resolvido** |
| 4 | HUD 70/70 antes do portão | Tirano: visível de 45,40 a 45,60 s, ~0,2 s (`t_portao_hud_20qps.jpg`). Rei: de 45,85 a 46,15 s, ~0,3 s (`r_portao_hud_20qps.jpg`, `r_portao_hud_b_10qps.jpg`). | **não resolvido** (menor) |
| 5 | Inimigo caindo, se houver material | O bruto aparece pela última vez atrás das cartas em ~24,1 s, depois o flash e a Coleção (`t_cartas_morte_10qps.jpg`). Não há queda. | **não resolvido**; não sei se o material existe |

Observação: o 11h nunca foi enviado. A diretora fez a rev 2 a partir da revisão do time, e mesmo assim os itens 1 e 3 coincidem com os meus.

## Verificações gerais

| item | Tirano | Rei | prova |
|---|---|---|---|
| duração / vídeo | 67,3 s, 1280x720 60 q/s, 14,0 Mb/s, AAC 320k | 68,3 s, 14,1 Mb/s | `medicoes.txt` |
| quadro 0 / pretos | luma 8,2 (TV desligada, como no v8); preto só de 0,53 a 0,78 s e no último quadro | igual | `medicoes.txt` |
| flashes | no máximo 2 flashes distintos por segundo. O "4" do script vem de rajadas de um flash só (16,42 a 16,47 s; 39,57 a 39,60 s). | igual | abaixo do limite de 3 por segundo |
| zoom | nenhuma mudança de enquadramento nas folhas a 2 q/s (`t_2qps.jpg`, `r_2qps.jpg`). O golpe letal é congelamento, flash e deslocamento; o corte para a morte é em 57,78 s. | igual | `t_golpe_letal_20qps.jpg` |
| golpe letal (imagem) | quadros congelados de 57,18 a 57,28 s, flash branco em 57,30, shake de 57,35 a 57,75, morte dessaturada em 57,80 | idem a partir de 58,12 s | folhas a 20 q/s |
| continuidade de vida | herói 41 → 41 → 41 → 9 → 9; chefe 65 → 30 → 21 → 21, contínuo | igual (60/65 é a vida rolando na Imolação, não um salto) | `t_hp_cortes.png`, `r_hp_cortes.png` |
| final Grimoire | 390 de 390 quadros do `logo_sting.mp4`, diferença média 1,6/255 (máx. 2,22) | igual | `medicoes.txt` |
| corvos | 52,70 a 55,55 s (2,85 s) | 53,22 a 56,37 s (3,15 s) | cortes em `medicoes.txt` |

## Pontos do Daniel (citação literal de `tdz_c11.txt`, 02/11 22:30)

| # | o que ele disse (literal) | Tirano | Rei | evidência; comparação com a rev 1 |
|---|---|---|---|---|
| 1 | "Esses techs que você tá colocando aí são muito ruins. Tu não colocou chains, tipo, por que correntes? Por que a gente quer enfatizar isso? Isso é algo, só um detalhe do jogo." | 8,5 | 8,5 | Igual: nada de CHAINS/FROST. São seis cartões que vendem o jogo, mas com a mesma fonte e a mesma posição dos que ele rejeitou, e "SIX BOSSES." sobre cinco salões (`t_saloes_4qps.jpg`). |
| 2 | "Não faz o menor sentido ali a entrada já ser as cartas. As entradas poderiam ser iguais a como estava em alguns teasers para trás: seis atos mostrando um pouquinho sobre cada um deles, meio que andando para frente em cada ato, com som ambiente calminho." | 9,0 | 9,0 | Igual: TV liga, seis atos andando de 3 a 16,3 s, só ambiente até a música em 12,6 s (`t_2qps.jpg`, linhas 1 e 2). |
| 3a | "...ele só mostra os vídeos na hora de falar que tem vários, vários beings, vários bosses. Aí foi mostrando cada vídeo um após o outro, e isso que eles trocavam de vídeo, seguindo ali o ritmo e o tempo da música. Isso eu achei muito legal." | 8,6 | 9,3 | Tirano sem mudança: as trocas do meio ficam em +3,7 a +6,2 dB no mix, com o grave atrasado 80 a 180 ms, e o ritmo vem do efeito sonoro, não da faixa (os onsets da faixa nos cortes são de 3,8 a 4,7x, com grave de −1,9 a +2,7 dB). Rei: a própria faixa acerta os cortes (12 a 15x, +16 a +46 dB de grave, a ≤ 4 quadros), mas no mix final a margem caiu para +5 a +9,5 dB por causa da normalização. Montagem **não estendida** nas duas: 5 salões, ~5,8 s. |
| 3b | "...pelo menos você mostrou os vídeos do Riggs Field por algum motivo. Os vídeos ficaram com uma qualidade muito ruim, mas muito ruim mesmo." | 8,5 | 8,5 | Os mesmos salões feitos no Higgsfield: nítidos a 14 Mb/s, mas ainda vídeo de IA. Ele reclamou da imagem, e isso não mudou. |
| 3c | "O ideal é que dê uma sensação de algo épico, algo legal, que o seu jogar as cartas seja algo satisfatório." | **9,1** (era 8,8) | **9,3** (era 9,1) | A jogada agora termina com o golpe no flash, a +9 a +10 dB, e cauda dentro da Coleção. Clímax com corvos a 1,8x e golpe letal com hit-stop, flash, shake e duck. Abaixo de 9,5 porque a morte ainda não se vê e porque a normalização tirou 6 a 12 dB de soco. |
| 3d | "Pode mostrar o deck em determinado momento ali, a coleção, com as cartas liberadas, mostrando tudo ali descendo." | 9,0 | 9,0 | Igual: grade de 24,8 a 29,9 s (`t_cartas_morte_10qps.jpg`, últimos quadros). |
| 3e | "É legal a gente mostrar também as entradas de algumas criaturas. A entrada do Espantalho é bem legal, e a entrada de algumas outras é legal também." | 9,3 | 9,3 | Igual: Espantalho, Grifo, Anjo Caído e Serpe, de 29,9 a 39,6 s. |
| 4 | "...a gente tinha uma finalização ali do Grimoire sendo preenchido com ícone, animações e extensões, e isso tudo se perdeu nessa sua versão. Você nem que jogou fora algo que está funcionando em cinco, seis versões anteriores." | 10 | 10 | 390 de 390 quadros, idêntico ao v8. |

Regras permanentes:
- Sem zoom: ok.
- Impacto só por hit-stop, flash e shake: ok.
- Análise por quadros e medição: feita.

## Comparação com os melhores anteriores

Base: as minhas medições do v8, v6 e 10d nas revisões anteriores, do 11f e da rev 1.

| ponto | v8 | v6 | 11f | 11g rev 1 | **11g rev 2** | rev 2 contra o melhor anterior |
|---|---|---|---|---|---|---|
| abertura com 6 atos e ambiente | só o ato 1 | 6 atos + citação placeholder | 6 atos | igual | igual | **melhor** que v8 e v6 |
| jogada de cartas satisfatória | `deck8` | mago | golpe a −9,4 dB, morte coberta 1,2 s | golpe a −16 dB, atrasado e cortado | **golpe no flash a −2,9 dB, +10 dB, cauda** | **melhor que todos** |
| coleção | não tem | maior (6 cartas + coringas) | grade + 2 | igual | igual | pior que o v6, melhor que o v8 |
| criaturas / Espantalho | sem Espantalho | não tem | com | igual | igual | melhor |
| montagem dos chefes no ritmo | 5 salões no drop | 4 salões | Rei forte, Tirano sem grave | Tirano com grave atrasado | igual à rev 1 | Rei igual ou melhor; **Tirano ainda abaixo do drop do v8** |
| clímax | luta para no meio | morte dessaturada | sem peso | hit-stop + flash + shake | igual, Rei agora acima de 12 dB | **melhor** |
| final Grimoire | referência | igual | igual | igual | igual | igual |
| textos | rúnicos + citações | citações | 6 cartões | igual | igual | melhor no conteúdo; a forma é a que ele rejeitou |

- **Rei:** claramente melhor que v8, v6, 11f e rev 1 no conjunto.
- **Tirano:** claramente melhor que v8 e v6 em abertura, cartas, criaturas e clímax. É pior que o v8 (e que o Rei) só no ponto que ele mais elogiou, a troca de chefes no ritmo. Por isso fica em 9,0, e não acima.

## Ele vai gostar? (honesto)

- **Rei:** provavelmente sim. A lista dele está toda lá, na ordem pedida, a jogada de cartas agora fecha com soco, e o final é o dele.
- **Tirano:** provavelmente sim na estrutura. O risco concreto é o momento dos chefes: na versão principal, a música do Tirano não "troca junto". Quem marca o corte é um baque que chega um pouco depois. Ele disse que amou exatamente a sincronia.
- **Nas duas:** a rejeição do 10d teve muito de gosto (cartões de texto e qualidade dos vídeos de IA), e esses dois elementos continuam. Não é defeito técnico do corte, mas é o maior risco de ele não gostar.

## Correções sugeridas (só áudio, sem render de vídeo nem captura nova)

1. **Normalização** (as duas versões): trocar o `loudnorm` por ganho fixo + limitador de pico real, para recuperar 6 a 12 dB nos golpes grandes (morte nas cartas, golpe letal, salões do Rei). Conferir de novo −14 LUFS e ≤ −1 dBTP.
2. **Salões do Tirano** (40,70 / 41,83 / 42,70 s): adiantar o impacto 0,1 a 0,15 s, para o pico do grave cair no quadro do corte, e aprofundar o duck da música nesses três cortes. Meta: ≥ +8 dB no mix.
3. **Portão** (Tirano 45,40 a 45,60 s; Rei 45,85 a 46,15 s): este exige mexer na imagem. Entrar ~0,25 s mais tarde ou cobrir o HUD 70/70. É menor e pode ficar para depois.
4. **Inimigo caindo:** só se houver material capturado. Senão, deixar como está.

Com 1 e 2, eu esperaria Tirano ~9,2 e Rei ~9,4. Nenhuma das duas exige render de vídeo.

## Itens em aberto

- Ninguém, nem eu, ouviu as mixagens. Antes do Daniel, alguém deveria ouvir pelo menos a morte nas cartas e o golpe letal.
- A identidade byte a byte do vídeo antes e depois do limitador não pode ser provada, porque o arquivo intermediário foi sobrescrito. Ver a seção do limitador.
- SFX do plano free do ElevenLabs: substituir ou licenciar antes de publicar.
- Salões feitos em IA (Higgsfield): o Daniel não gostou da imagem. Rotular e declarar o uso de IA se for publicado.
- "SIX BOSSES." sobre cinco salões, e qual música é a principal: decisões do Daniel.

## Comandos usados

- `sha256sum` (cópias entregues contra `build\trailer\`).
- `ffprobe -show_entries format=duration,bit_rate:stream=...`.
- `ffmpeg -vn -af ebur128=peak=true`.
- `ffmpeg -vf scale=96:54,format=gray -r 60 -f rawvideo` + `ana.py` (cortes, pretos, onsets das faixas próprias, P0 = 21,0 Tirano / 36,0 Rei).
- Alinhamento dos quadros finais contra a prévia `*_review.mp4` (desvio de −4 quadros, mediana 0,97).
- `hit3.py` (RMS de 100 ms, pico em [t−0,05; t+0,35] contra quatro janelas de cama).
- `bass.py` (20 a 150 Hz, pico e atraso contra a cama).
- `env2.py` (envelope de 50 ms).
- `logo.py`, `fl.py`, `sheet.py`, `hp720.py`.
