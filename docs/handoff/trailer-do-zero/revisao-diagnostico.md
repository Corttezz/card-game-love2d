# Revisão: etapa 1, diagnóstico (trailer-do-zero)

_Revisora independente, 01/11/2026. Base: `diagnostico.md` (13.113 bytes, 14:22). Conferi por conta própria a folha de quadros de A e B (1 quadro/s), a curva EBU R128 de curto prazo do B_som (720p) e a contagem de cartas no código. Critérios: os 10 de `trailer-kinetic-referencias.md` e os trailers do gênero (StS, Balatro, Inscryption, Monster Train, Cobalt Core, Dicey Dungeons)._

## Rodada 1, nota 7,5/10

O diagnóstico é bom e honesto. Ele acerta no defeito nº 1 (ninguém consegue ver as cartas) e no nº 2 (paisagem com legenda no lugar de jogo), e fiz as duas leituras de forma independente antes de abrir o arquivo. Também acerta em "EVERY BOSS IS A PUZZLE" escrito sobre salão vazio, no som em parede e no fecho longo sobre preto. A tabela "o que funciona" é útil e aponta as cenas certas (entrada do Rei-Carniça, Coleção em close do v4/v6, nomes de chefe do v3/v4). A nota não é maior porque há um número errado que ia virar texto de trailer, uma medição subestimada e quatro decisões que o diagnóstico deixa abertas e que o roteiro não pode herdar abertas.

### Problemas concretos

1. **"137 LIVING CARDS" está desatualizado.** O número vem do v6. Hoje o catálogo tem **145 cartas** (`src/data/cards/`: basic 27, warrior 33, mage 42, rogue 37, boss 6), ou **139** sem os 6 coringas de chefe. O diagnóstico propõe usar "um número enorme verdadeiro: 137 cartas" (seção 4). Se isso chegar à tela, é um claim falso. **Todo número que for para a tela tem de ser recontado no código, com o comando registrado no roteiro.** Isso vale também para inimigos (o `memory/enemy_voices.md` fala em 42 criaturas), chefes (6) e atos (6).
2. **A pausa do chefe no B_som está subestimada.** O diagnóstico diz que fica "3 a 5 dB" abaixo do resto. Medi o curto prazo em 1 s: 28 a 29 s de −11 a −12,6 LUFS; 30 a 37 s de −16 a −20,4; volta a −10,7 em 43 s. A diferença é de **5 a 9 dB**, não de 3 a 5. A conclusão continua certa (a pausa não chega aos ≥ 15 dB que a própria referência pede), mas o número tem de estar certo, porque vira meta no corte 1. Peço a meta escrita como número: **pausa ≥ 15 dB abaixo do trecho anterior, medida em curto prazo de 3 s.**
3. **Choque com o pedido nº 1 do Daniel, sem solução.** A direção final pede "quadro 0 já com uma carta viva". O Daniel pediu (v7 → v8) que a TV ligue **antes** da música. Isso só se resolve com uma regra explícita, por exemplo: a TV liga em ≤ 0,8 s com a carta viva já no vidro desde o quadro 0, e a música entra depois. O diagnóstico precisa dizer como cumpre os dois. Não se descarta pedido do dono em silêncio.
4. **Salões do Higgsfield: falta decisão.** O diagnóstico critica os "salões vazios" (B 38 a 46 s; C 26 a 39 s), mas não diz se o b-roll de IA (`ai_4k/hall1..5`, o coração verde a 41 a 43 s do B, a lava a 40 s) fica ou sai. São vídeo de IA (o Daniel rejeita "cara de IA" e só aceita IA como ponte curta re-pixelizada) e não são o jogo. O pedido nº 9 dele ("salões nos acentos") pede que entrem. **Exijo uma posição:** proponho os `castle_hall_1..6` reais do jogo com o chefe dentro, e IA no máximo como ponte de ≤ 1 s, declarada. Como isso contraria um pedido antigo do Daniel, a decisão tem de ser levada a ele.
5. **O gancho não foi escolhido.** A seção 2 lista sete recursos únicos (prévia LETAL, coringas, mecânica de cada chefe, forja, loja, mundo-domo, cartas vivas). A regra dos três de Derek Lieu, citada pelo próprio diagnóstico, exige **um** gancho mostrado 2 a 3 vezes. O diagnóstico termina sem dizer qual. Minha leitura: o que só o Grimoire tem e que se vê sem som é **"chefe com mecânica-assinatura visível"** (corvos, runas, correntes, geada, raízes, lua), sustentado por "carta viva" como textura. Pode ser outro, mas tem de ser **uma frase** antes do roteiro.
6. **Viabilidade do close não foi avaliada.** "Câmera dentro do jogo (recorte de captura 4K ou captura headless com zoom)": as tomadas em `%APPDATA%\LOVE\card-game-trailer-v9\trailer\` são 1080p. A carta na mão tem cerca de 128×192 px na tela (96×144 lógicos × 1,333). Ampliar isso num recorte de 1080p dá escala não inteira, com pixel tremendo e serrilhado na fonte, que é exatamente a "cara de IA" que o Daniel rejeita. O diagnóstico tem de dizer (ou deixar como item obrigatório para `ferramentas.md`) **como sai uma carta com ≥ 1/3 da altura do quadro em escala inteira**: captura headless em 4K ou maior, zoom de câmera dentro do jogo ou Coleção/inspeção, e se o CRT já vem embutido na tomada (se vier, recortar amplia o scanline também).
7. **Não mediu o microtrailer nem o teste mudo.** O critério 2 e o padrão Steam nº 8 pedem os 6 trechos de 1 s. Num trailer de ~60 s eles caem por volta de 10/20/30/40/50/55 s e, no B, pegariam estrada vazia (20 s), olhos no escuro (32 s) e logo (55 s+). Isso reforçaria a conclusão nº 2 com número. Peço a tabela "microtrailer simulado" para A, B e C (3 linhas).
8. **Faltam o alvo e o formato.** O diagnóstico não diz o que o "do zero" vai entregar: 1º vídeo da página (60 a 75 s, gameplay < 2 s) ou peça de 30 s. O roteiro precisa disso antes de começar. Recomendo: corte 1 = **1º vídeo da página, 60 a 70 s**; o 30 s sai depois como recorte.
9. **"História de uma luta" depende de captura roteirizada.** Perigo, virada e golpe letal não saem de uma tomada qualquer. É preciso uma luta encenada (modo cheat: vida baixa, mão escolhida, LETAL na prévia). O diagnóstico deveria marcar isso como dependência da etapa de ferramentas. Fica registrado aqui.

### O que exijo para aprovar o diagnóstico
- [ ] Corrigir 137 para o número real, com o comando de contagem; regra "número na tela = número contado no código".
- [ ] Corrigir a pausa para 5 a 9 dB e fixar a meta de ≥ 15 dB (curto prazo de 3 s).
- [ ] Regra escrita que concilia "TV liga antes da música" com "carta viva no quadro 0".
- [ ] Posição sobre os salões do Higgsfield, marcada como decisão do Daniel.
- [ ] O gancho em uma frase.
- [ ] Alvo do corte 1 (duração e uso).
- [ ] Como se obtém uma carta legível em escala inteira (ou o item explicitamente passado para `ferramentas.md`, com dono).
- [ ] Tabela do microtrailer simulado de A/B/C (opcional para aprovar, recomendada).

Os itens 1, 2, 5 e 8 bastam para eu dar 9. Os itens 3, 4 e 6 podem ser resolvidos no roteiro ou nas ferramentas, desde que estejam escritos lá.

## Régua nova (regra do Daniel, 01/11): nota por critério, aprovação só com ≥ 9 em TODOS

A partir desta etapa cada revisão traz uma nota por critério. Só aprovo quando **todos** os critérios tiverem nota ≥ 9. Se um critério ficar em 8 ou menos, há outra rodada antes de liberar. `===CORTE1_PRONTO===` só pode ser marcado depois de eu aprovar o corte 1. Depois disso o Grimoire ainda revisa e pode devolver o corte.

**Critérios que vou usar no corte 1** (os 10 de `trailer-kinetic-referencias.md` mais os da regra nova): C1 gameplay até 2 s · C2 sem preto · C3 sincronia corte/texto ↔ grave · C4 legibilidade (carta e texto) · C5 ritmo · C6 pico em 75 a 82% · C7 regra de 3 do gancho · C8 fecho · C9 conformidade (cenários válidos, moldura, flashes, −14 LUFS, marca "não publicável" nos SFX) · C10 checklist do Daniel · C11 **continuidade entre planos** (posição, luz, cor, direção do movimento, nada pulando) · C12 **está bom / é legal de assistir** · C13 **prende do início ao fim** (sem trecho morto; curva de energia) · C14 som (contraste: pausa ≥ 15 dB, som do jogo solo nos momentos certos, ponto final sonoro).

### Notas por critério do diagnóstico (rodada 1)

| critério da etapa | nota | por quê |
|---|---|---|
| D1 Precisão das medições | 7 | "137" desatualizado (são 145); pausa medida como 3 a 5 dB quando é 5 a 9 |
| D2 Cobertura (todas as versões, imagem + som) | 9 | v3 a C e os `_som`, por quadro, onda, R128 e cortes |
| D3 Causa raiz (por que está ruim) | 9 | cartas ilegíveis, paisagem com legenda, parede de som, sem história, chefes viraram cenário: concordo com tudo e cheguei às mesmas conclusões sozinha |
| D4 Uso das referências do gênero | 8 | boa tabela "o que nos falta"; não mede o microtrailer simulado nem o teste mudo |
| D5 Acionabilidade (o roteiro sai daqui?) | 6 | o gancho não foi escolhido, faltam alvo/duração e a viabilidade do close |
| D6 Respeito às regras e pedidos do Daniel | 6 | o quadro 0 com carta choca com "TV antes da música" sem conciliação; os salões de IA ficaram sem posição |
| D7 Continuidade e "prende" (o diagnóstico enxerga isso?) | 7 | aponta imagem parada e falta de curva de emoção, mas não analisa a continuidade entre planos (direção de movimento, salto de luz/cor entre ato e ato no chicote, ex.: B 13→14 s azul-noite → vermelho) |

**Status: NÃO APROVADO** (D1, D4, D5, D6 e D7 abaixo de 9). Para D7, peço uma linha sobre continuidade nas versões atuais (saltos de cor/luz entre os atos em chicote, inimigo que muda de lado, a moldura que "respira" no corte) para o roteiro já nascer com essa regra.

## Rodada 2, nota 8,8/10 (resposta-diagnostico.md + §6 do diagnóstico, 14:3x)

Conferi as afirmações novas no código e no worktree. `audio/sfx/boot-tv-power-on.mp3` existe (`main.lua:1074`, `bootTvPowerOn`). `tools/trailer_record.lua` lê `TRAILER_SIZE` (l. 1418), `TRAILER_NOBEZEL` (l. 1430) e `TRAILER_CRT` (l. 1466). A contagem de 145 / 139 bate com a minha. Os itens 1 a 9 foram aceitos e escritos como regra, e a regra do microtrailer ("entre 30% e 90%, todo segundo tem carta grande ou criatura em ação") é melhor do que eu pedi.

### Ressalvas que seguem para o roteiro (não bloqueiam, vou medir no corte 1)
- **A frase do gancho é interna, não texto de tela.** "Cada chefe quebra as regras da luta, e o seu baralho vivo é o que quebra de volta." tem cerca de 80 caracteres e, pela regra de 1 s a cada 13 caracteres, ficaria mais de 6 s parada. Na tela, no máximo 3 palavras por cartão (ex.: "BOSSES BREAK RULES." / "YOUR DECK BREAKS BACK."). Os textos novos dependem de OK do Daniel, porque os aprovados são outros cinco.
- **Câmera virtual em recorte ×3:** um passo de 1 px da captura vira um salto de 3 px no filme. Num pan lento a 60 fps isso aparece como degrau, e é justamente o "nada pulando" da regra nova. Peço que o teste da etapa 2 inclua **um pan e um zoom-in de 2 s** em ×2 e em ×3, olhados em recorte 1:1, e que a decisão (passo inteiro com movimento rápido/easing curto ou corte seco entre enquadramentos fixos) fique escrita em `ferramentas.md`.
- **Geada na mão:** ela só aparece em ato 4 com 4+ acúmulos na compra. A captura encenada tem de garantir as 2 cartas congeladas **visíveis e grandes** (é o elo chefe ↔ carta do gancho). Se só ficar legível no recorte ×3, esse plano é obrigatoriamente ×3.
- **Teste mudo** continua pendente; aceito que seja feito no corte 1 (eu faço a leitura muda por quadros e registro).

### Notas por critério (rodada 2)

| critério | r1 | r2 | por quê |
|---|---|---|---|
| D1 Precisão das medições | 7 | 9 | números recontados com comando; dB corrigido |
| D2 Cobertura | 9 | 9 | — |
| D3 Causa raiz | 9 | 9 | — |
| D4 Referências do gênero | 8 | 9 | microtrailer simulado medido e virou regra |
| D5 Acionabilidade | 6 | 9 | gancho, alvo (60 a 70 s, 1º vídeo) e caminho do close definidos |
| D6 Regras do Daniel | 6 | 9 | TV liga antes da música conciliada (§6.3); IA fora e levada ao Daniel (§6.4) |
| D7 Continuidade e "prende" | 7 | **7** | ainda sem a análise de continuidade entre planos que pedi na régua nova (a resposta foi escrita antes dela) |

**Status: NÃO APROVADO, falta um item.** Para fechar o D7, peço um §7 curto no diagnóstico listando os saltos de continuidade das versões atuais, com timestamp, e a regra que o roteiro herda. Exemplos que vi no B: 13→14 s céu azul-noite → vermelho no chicote entre atos, sem ponte de luz; 20→21 s o grifo entra num plano e no seguinte a câmera está em outro ato com o mesmo texto ainda na tela; 31→32 s castelo noturno → escuro total sem o movimento continuar; 53→54 s luta → bússola sem nenhum gesto ligando os dois. Basta a lista e uma regra de 3 linhas (direção do movimento mantida no corte, luz/cor com ponte ou contraste intencional, objeto em foco na mesma região do quadro de um plano para o outro). Com isso dou 9 em todos e o diagnóstico fica aprovado. A etapa de ferramentas pode andar em paralelo.

## Rodada 3, APROVADO (diagnóstico §7 + resposta, 14:29)

O §7 é exatamente o que faltava. Os timestamps batem com a minha folha do B: 10,75 s (espólio → estrada), o chicote entre atos de 13 a 19 s, 22,5 → 23,75 s (frase atravessando grifo/anjo), 38,75 s (captura → IA) e 45,75 → 46,5 s (trono vazio). O trono vazio e a volta no tempo da jornada (loja do ato 3 → porta do ato 1, 29,5 s) eu não tinha visto, e são defeitos reais. As 7 regras são verificáveis e vão virar o critério C11 do corte 1. Vou medir a regra 2 (luminância ≤ 25% entre planos sem motivo) com a curva de luma da `trailer_kinetic_metrics.py` e as regras 3 e 4 por quadros.

Duas notas para o roteiro: (a) a regra 2 não pode matar o contraste. Porta, entrada do chefe e golpe letal **devem** saltar, e o roteiro tem de marcar quais cortes são "salto intencional" para eu não reprovar um acento. (b) A regra 1 (mesmo enquadramento entre atos) depende de a câmera do WorldRoad parar no mesmo `rel` em todos os atos. Confirmem nas tomadas que o horizonte fica na mesma altura; se não ficar, o recorte compensa.

**Decisão do Grimoire registrada (01/11):** só salões REAIS (`castle_hall_1..6`) com o chefe dentro, nada de b-roll Higgsfield/IA até o Daniel decidir, e **parar antes de qualquer 4K**. Isso confirma o §6.4. Vou reprovar automaticamente (C9) qualquer quadro de IA no corte 1 e qualquer render 4K feito sem liberação.

| critério | r1 | r2 | r3 |
|---|---|---|---|
| D1 Precisão | 7 | 9 | 9 |
| D2 Cobertura | 9 | 9 | 9 |
| D3 Causa raiz | 9 | 9 | 9 |
| D4 Referências | 8 | 9 | 9 |
| D5 Acionabilidade | 6 | 9 | 9 |
| D6 Regras do Daniel | 6 | 9 | 9 |
| D7 Continuidade e "prende" | 7 | 7 | 9 |

**Status: APROVADO, ≥ 9 em todos.** Pode seguir para `ferramentas.md` e `roteiro.md`.

## Adendo (01/11): decisão do Daniel sobre os salões do Higgsfield

**O Daniel decidiu MANTER os salões do Higgsfield nos acentos da música**, como no pedido original nº 9. Isso substitui a mensagem anterior do Grimoire e o §6.4 do diagnóstico. Os `castle_hall_1..6` reais entram como complemento onde ajudarem a leitura do jogo, e os acentos ficam com o Higgsfield. A declaração de IA na Steam fica com o Daniel e não bloqueia. **Deixo de tratar isso como pendência e não reprovo pela presença dos salões de IA.**

O que continua sendo critério de qualidade é a **integração**, porque o próprio diagnóstico (§7, 38,75 s) mediu uma quebra de estilo: a captura tem tons terrosos e o Higgsfield vem saturado, com outro contraste. A regra 6 do §7 ("um estilo de imagem") passa a ser lida assim no corte 1:
- os salões de IA passam pela mesma grade de cor/luminância da captura vizinha (rampa da regra 2, ou salto marcado como acento intencional);
- mesma grade de pixel e o mesmo CRT por cima do quadro final (nada de vídeo IA "liso" dentro da moldura);
- cada salão no acento, sem ocupar o lugar da prova do gancho: o chefe/regra quebrando aparece em captura real;
- sem salto de estado: se o chefe já pousou, o salão de IA não pode mostrar o mesmo salão vazio logo em seguida (o caso do trono vazio de 45,75 s).

Vou medir isso no C11 (continuidade) e no C12 (está bom), não no C9. A aprovação do diagnóstico continua valendo, e o roteiro precisa refletir a decisão.
