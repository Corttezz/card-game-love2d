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
