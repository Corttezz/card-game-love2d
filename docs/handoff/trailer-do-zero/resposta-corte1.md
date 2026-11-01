# Resposta à revisão do corte 1 (rodada 1)

_Diretora, 01/11/2026. Os dois arquivos (`grimoire_zero_corte1_1080p.mp4` e `_720p.mp4`) foram regravados com os mesmos nomes. Fonte dos tempos: `corte/edl.py`; plano de som: `corte/mix.py`._

| # | ponto | resposta |
|---|---|---|
| 1 | quadro 0 (pôster) | **Corrigido.** O liga-TV começa no quadro 66 (`crt_pass.py`, `TV_SKIP`): o vidro inteiro aberto, cartas legíveis, Espantalho acima; nada de preto. O ruído do liga-TV ainda deixa a imagem um pouco dessaturada no quadro 0 e assenta em ~0,3 s. |
| 2 | cascata escondida | **Corrigido.** As cartas jogadas ficam na frente do inimigo **no próprio jogo** enquanto resolvem; o que escala na tela é o painel da prévia, que soma 0 → 8 → 21 → 31 → 40/40. Recorte ×2 (340,200) com cartas + Espantalho + painel (3,07–7,24 s), e a morte do Espantalho num ×2 próprio (7,24–9,99 s). |
| 3 | "145 LIVING CARDS." sobre cartas minúsculas | **Corrigido.** Foi para o espólio a ×2 (9,99–11,78 s), no topo do quadro, sobre as cartas grandes, sem tocar em nenhuma. |
| 4 | LETHAL gasto no 7º segundo | **Mantido, com motivo.** É preparação e pagamento: a abertura ensina o que é LETHAL (o contador chegando a 40/40 contra um inimigo comum), e o clímax repete a palavra contra o chefe com 9 de vida, a 81%. Sem a abertura, o LETHAL do pico é uma palavra que o espectador não sabe ler. Se a revisora ou o Grimoire preferirem, a alternativa é regravar `zero_hand` com o painel escondido. |
| 5 | Revoada ilegível | **Corrigido.** Dois planos ×2: o Rei anunciando "Murder of Crows" com a órbita (1,70 s) e os corvos chegando ao painel do herói com o "Weak" (2,28 s). O Rei aparece de lado na borda direita do 2º plano (o corpo dele vai até a coluna do painel; nenhum ×2 pega os dois inteiros); fica como presença fora de quadro. A vida do herói não cai porque o gravador usa o modo deus; o efeito visível é o "Weak". |
| 6 | legenda sobre as correntes | **Corrigido.** Sem legenda nossa: o texto do jogo ("Half strike / Chain snapped! +1 damage") é a legenda. Recorte (480,240) com o rosto do Tirano, o intent 20 → 10 e o texto, o mesmo antes e depois. |
| 7 | LETAL atrás das cartas | **Corrigido.** O hit-stop de 3 quadros é no quadro da morte (60,80 s da tomada), a ×2 no Rei (480,200), sem cartas na frente; a morte segue a ×2. A barra do Rei não aparece: o jogo esconde o HUD na cinemática de morte; a leitura do golpe final é o número + a dessaturação + o corpo caindo. |
| 8 | Rei cortado no ×2 do LETAL | **Corrigido.** Recorte (480,150): o Rei inteiro, o painel LETHAL e as cartas. |
| 9 | clima de fora no salão | **Corrigido.** Dentro dos clipes do castelo só entra ambiente `pl:boss*` (`amb_only` no plano). Conferido no `mix_sources.json`: zero eventos de clima externo nos intervalos do castelo. |
| 10 | portão duas vezes | **Corrigido.** Nenhum SFX que começou antes do corte entra no clipe seguinte (`no_carry`). `castleGateOpen` só a 20,35 s. |
| 11 | pouso duas vezes | **Corrigido** (mesma regra). `bossLandImpact` só a 27,77 s; `bossRevealSting` a 28,33 s (nome) e 61,49 s (coringa, outro momento). |
| 12 | ato 5 faltando | **Corrigido.** E5 (mãe-esporo) voltou a 49,50–50,95 s; o ato 3 é o salão + Tirano. Sem rajadas (o menor plano tem 1,00 s). |
| 13 | liga-TV não está sozinho | **Corrigido.** Eventos da tomada antes de 0,89 s são descartados; de 0 a 0,89 s só o liga-TV. |
| 14 | empilhamento | **Corrigido.** Um evento por código a cada 3 quadros por tomada (`events_last` do `mix.py`). Os `wx:` com o mesmo código no mesmo instante que ainda aparecem são vozes diferentes do clima (variantes em crossfade do jogo, começaram em instantes diferentes), não cópias. |
| 15 | silêncio curto | **Melhorou com 9 e 10:** curto prazo −19,5 / −24,5 / −25,7 / −21,1 em 24–27 s, contra −13,2 do groove; momentâneo: olhos −25,3, rasantes −19,2, pouso −13,4, nome −16,1. |

Mudanças no motor compartilhado (`trailer-revisao-som/remix_engine.py`): três opções novas (`no_carry`, `clip_mute_until`, `amb_only`), todas desligadas por padrão; os planos antigos de A/B/C não mudam de resultado.

Peço nova leitura dos dois arquivos.
