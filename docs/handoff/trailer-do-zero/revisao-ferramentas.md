# Revisão: etapa 2, ferramentas (trailer-do-zero)

_Revisora independente, 01/11/2026. Base: `ferramentas.md` (10.014 bytes, 14:34). Conferi o worktree `card-game-trailer-zero` (commit `52a262c3`, `TRAILER_OUT`), a tomada de teste `%APPDATA%\LOVE\card-game-trailer-v9\trailer_zero_teste\deck8.mkv` (231 MB + `audio.jsonl`; as tomadas antigas em `trailer\` continuam lá) e abri os recortes `x2_13.png` e `x3_13.png` em tamanho real. Régua: ≥ 9 em todos os critérios para aprovar._

## Rodada 1, NÃO APROVADO

O inventário é sério. A decisão de tirar o CRT da captura e aplicá-lo por cima do quadro final está certa, e o teste ×2 prova o ponto principal do diagnóstico: no `x2_13.png` leem-se "Leech Blade", o tooltip inteiro ("Deal 6 damage. Heal 2 HP."), "ATTACK 6/8/4/5", a arte das cartas e o Bruto acima. É outro filme em relação ao A/B/C. Também acho certo proibir zoom contínuo (só troca de plano ×1/×2/×3). O que falta é provar que a imagem continua **pixel íntegro e com a cara do jogo** depois de todo o tratamento, e que a câmera virtual não pula.

### Problemas concretos

1. **O pixel irregular não vem do recorte, vem do jogo, e já aparece no ×2.** No `x2_13.png` a carta em hover (Leech Blade) já tem colunas e linhas de largura desigual: a moldura e o "Leech Blade" do cabeçalho saem tortos. Isso é a escala 1,333 do jogo (96×144 → 128×192) somada ao tilt 3D do hover. No `x3_13.png` o defeito fica evidente: as letras do cabeçalho da carta e as bordas da ilustração "dançam" (3 e 4 px alternados) e a borda da cobra parece serrilhada. É exatamente a "cara de IA / borrado sobre pixel art" que o Daniel rejeita, agora ampliada. **Exijo testar uma escala inteira das cartas só no gravador** (variável `TRAILER_CARD_SCALE=1` ou `2` sobrescrevendo `Config.Cards.BASE_SCALE`/`HOVER_SCALE` dentro do `trailer_record`, sem mudar o jogo). Com a carta a 1× ou 2× do pixel lógico, o recorte ×2/×3 sai com pixel quadrado e uniforme. Se a mão quebrar de layout nessa escala, digam e mostrem. Critério: no recorte, **toda coluna de pixel da arte da carta com a mesma largura** (medir numa linha horizontal da ilustração da carta em repouso, fora do hover).
2. **O ×3 está reprovado do jeito que está.** "Insert curto de ≤ 1 s" não salva um plano que é justamente o close da carta, o lugar onde o espectador para para olhar. Ou o ×3 só entra depois de o item 1 resolver a escala, ou sai do roteiro (fica ×2 + Coleção/`inspect` para o close máximo).
3. **O teste de câmera que pedi não foi feito.** Na revisão do diagnóstico (rodada 2) pedi um pan e um zoom-in de 2 s em ×2 e ×3, vistos 1:1. O doc define a regra ("passos de 1 px da captura") sem prova. A ×2, 1 px da captura = 2 px na tela. Um pan de 1 px a cada 2 quadros (30 px/s na captura) já se lê como degrau a 60 fps. **Exijo**: um mp4 curto (≤ 4 s, 1080p) de pan lento, pan rápido e corte seco ×1 → ×2, com a velocidade mínima escrita a partir da qual o pan não "pula" (ou a decisão de não usar pan, só enquadramentos fixos + corte no grave). Isso alimenta direto o C11 do corte.
4. **O CRT aplicado depois tem de ser o CRT do jogo.** "Máscara/ring do Kinetic Film + scanline na escala do filme" pode virar um filtro genérico, e o Daniel aprovou o CRT do jogo (`shaders/crt.glsl`: curvatura, máscara, aberração, brilho de borda). **Exijo** um quadro lado a lado: o mesmo instante da tomada **com** CRT do jogo (×1) e **sem** CRT + CRT de pós (×1). A diferença tem de ser imperceptível no plano aberto. Se o caminho mais fiel for rodar o próprio `crt.glsl` offline sobre o quadro final (LÖVE headless, ou porte do shader para o compositor), escrevam qual.
5. **Liga-TV reproduzido no compositor:** mesma exigência. Comparar com a tomada `poweron` do jogo (folha de 10 quadros de cada), porque é um pedido literal do Daniel e tem de parecer a TV do jogo, não uma transição de editor.
6. **Integração dos salões do Higgsfield sem método nem teste.** "Re-pixelizar na grade, cor do salão real do mesmo chefe" ainda não diz como. **Exijo** o método (ex.: reduzir à grade de pixel do `castle_hall_*` correspondente com vizinho mais próximo, quantizar na paleta do salão real, ajuste de luma/saturação medido contra o salão real, CRT por cima) e **1 quadro de teste** do `hall1_carrion` ao lado do `castle_hall_1` real tratado igual. Não é pendência de licença (o Daniel decidiu manter); é qualidade, e o diagnóstico mediu a quebra de estilo em 38,75 s.
7. **HUD no 1º vídeo.** O padrão Steam nº 1 pede gameplay "com HUD visível". O ×2 corta mana, vida e barra do inimigo. A lista de tomadas precisa garantir, nos primeiros ~5 s, um enquadramento com o HUD lido (×1, ou ×2 posicionado na mão + orbe de mana + vida). Isso é decisão do roteiro, mas a tomada tem de existir.
8. **Tooltip cobrindo a mão.** No teste, o tooltip da Leech Blade cobre metade das outras três cartas. Para o trailer, a ferramenta precisa permitir escolher se o tooltip aparece (prova do texto da carta) ou não (mão inteira visível). Escrevam se o gravador controla isso (hover sem tooltip / tooltip ao lado).
9. **Luta encenada: falta o roteiro técnico.** A tabela diz "função nova" para `zero_fight`, `zero_monarch` e `zero_tyrant`, sem dizer quais chamadas do `__cheatApi` existem e quais faltam. Para a Geada, a regra real é 4+ acúmulos na compra congelando as 2 cartas mais caras (ver `BossMechanics`/`memory/boss_mechanics.md`); para o Tirano, a corrente rompe ao cruzar 75%. Peço a lista concreta (chamada → estado esperado → como se confere na folha). Pode ficar para a entrega das tomadas, mas com dono e com a prova por folha de quadros.

### O que já está bom (não mexer)
- Trocar `TRAILER_OUT` para não apagar as tomadas antigas: necessário e feito.
- 1 `lovec`, headless, identidade `card-game-trailer-v9`, 0 crédito, nada de 4K, ACE-Step sem gerar seções coladas, SFX do jogo com a marca "não publicável": tudo conforme.
- Proibir zoom contínuo e reservar o ×1 para situar.

## Notas por critério (rodada 1)

| critério da etapa | nota | por quê |
|---|---|---|
| F1 Inventário e veredito | 9 | completo, com o motivo de cada ferramenta, proibidos claros |
| F2 Teste real e verificável | 9 | tomada e recortes conferidos no disco |
| F3 Imagem íntegra / cara do jogo | 6 | pixel irregular já no ×2 (escala 1,333 + tilt); ×3 serrilhado; CRT e liga-TV de pós sem comparação com o do jogo |
| F4 Cobertura das tomadas para o roteiro | 8 | lista boa; faltam tomada com HUD, controle do tooltip e o teste de integração do Higgsfield |
| F5 Conformidade e riscos | 9 | — |
| F6 Câmera e continuidade (nada pulando) | 6 | regra sem prova; o teste de pan/zoom pedido não foi feito |
| F7 Viabilidade da luta encenada | 7 | identificada, mas sem a lista de chamadas e sem a prova da Geada/corrente |

**Status: NÃO APROVADO.** Para aprovar: itens 1, 3, 4 e 6 com prova (imagem ou mp4 curto no scratchpad, com o caminho no `ferramentas.md`), 2 decidido, e 7, 8 e 9 escritos. O roteiro pode começar em paralelo, mas os planos ×3, o CRT de pós e os salões de IA ficam condicionados a estas provas.

## Rodada 2 (ferramentas §5 + resposta-ferramentas.md, 14:51)

Abri as provas no scratchpad da diretora (`...\7f9e50b0-...\scratchpad\crop\`) e **medi o pan por conta própria**. Fiz uma correlação de fase quadro a quadro numa faixa horizontal do `teste_camera.mp4`. No trecho de 15 px/s o deslocamento por quadro sai 0, 0, 0, −2, 0, 0, 0, −2 (pula, como ela disse). A 60 px/s sai −2 em todos os quadros e a 120 px/s, −4 em todos (uniforme). A regra do §5.3 (pan só a 1 ou 2 px de captura por quadro, posição pelo número do quadro, escala só por corte seco no grave) está provada.

| item | veredito | o que vi |
|---|---|---|
| 1 carta em escala inteira | **resolvido** | `full2_13.png`: a carta parada sai com blocos uniformes; aceito o limite declarado (carta em voo/juice ainda irregular → close só de carta parada) |
| 2 ×3 | **resolvido** | saiu; o ×2 sobre carta a 2 px já dá 4 px por pixel lógico |
| 3 câmera | **resolvido e conferido** | medição minha acima |
| 4 CRT de pós | **resolvido** | é o próprio `crt.glsl` via `CRTShader`; 2,4/255 de diferença onde o conteúdo é igual. Melhor do que eu pedi |
| 5 liga-TV | **resolvido** | `tv_comparacao.png`: as 10 fases batem (preto, ponto, linha, faixa abrindo, rolagem, assentada). O conteúdo das duas fileiras difere (ato 1 × ato 3) porque são gravações diferentes; a TV é a mesma |
| 6 Higgsfield integrado | **parcial** | ver abaixo |
| 7 HUD | aceito | depende do roteiro: vou cobrar o plano ×1 com HUD antes de 5 s no corte |
| 8 tooltip | resolvido | `TRAILER_TOOLTIP=0` |
| 9 luta encenada | aceito | tabela chamada → estado → prova; a prova por folha vem com as tomadas |

### O que ainda segura a aprovação: os salões do Higgsfield (`hall_comparacao.png`)
1. **O tratado ficou lavado.** Ao lado do real e do IA cru, o tratado perdeu contraste e brilho de destaque: a chama do arco virou um laranja acinzentado, as tochas apagaram e as pedras ficaram num cinza-marrom chapado. A média de luma bate (43,1 contra 42,5), mas o **desvio** não, e o olho lê "foto desbotada", não o salão do jogo. Igualar média e desvio no LAB e depois quantizar em 48 cores achatou os extremos. **Exijo uma v2** que preserve os destaques (chama, tochas) e o preto profundo: por exemplo, igualar por histograma/percentis (p2, p50, p98) em vez de média/desvio, ou proteger a camada emissiva (pixels de luma > p97 no cru) antes de quantizar. A saturação também precisa descer para ±10% do real, como a própria diretora anotou.
2. **Continuidade de objeto e de estado.** O plano real (`castle_hall_1`) mostra o arco com fogo e **nenhum trono**; o plano IA fechado mostra um **trono vazio** no arco. Cortar "real aberto → IA fechado" faz aparecer um trono que não existia no plano anterior. E, se o Rei-Carniça já pousou, o trono vazio repete o defeito de estado do §7 do diagnóstico (45,75 s do B). **Exijo a regra escrita**: cada salão de IA entra só **antes** de o chefe ocupar o salão (como acento do drop/apresentação), nunca logo depois de um plano real do mesmo salão com o chefe dentro; e, quando IA e real do mesmo chefe forem vizinhos, ou a IA vem primeiro (apresentação) ou há um plano de outra coisa entre os dois. É a regra 4 do §7 aplicada aos salões.

### Observações menores (não seguram, vou medir no corte)
- **Mão a 2 px:** no `full2_13.png` a carta Blur sai do quadro por baixo e cobre metade da Backstab, e o título "Executioner" fica escondido atrás da Twin Fangs. No plano ×1 com HUD isso parece mão bagunçada. Para as tomadas: mão de no máximo 5 cartas, ou nenhuma carta com o título coberto no instante usado.
- **Verdade do gameplay:** o inimigo do teste aparece com 466/466 de vida e o jogador com 60/60 (build de gravador). Na luta encenada os números na tela têm de ser plausíveis para o ato mostrado (vida do jogador baixa por cheat é encenação aceitável; um inimigo do ato 1 com vida de chefe do ato 6 não é). Vou conferir na folha da `zero_fight`.

## Notas por critério (rodada 2)

| critério | r1 | r2 | por quê |
|---|---|---|---|
| F1 Inventário e veredito | 9 | 9 | — |
| F2 Teste real e verificável | 9 | 10 | todas as provas no disco, uma delas refeita por mim |
| F3 Imagem íntegra / cara do jogo | 6 | **8** | carta, CRT e TV resolvidos; o salão de IA tratado ficou lavado |
| F4 Cobertura das tomadas | 8 | 9 | HUD, tooltip e integração com método |
| F5 Conformidade e riscos | 9 | 9 | — |
| F6 Câmera e continuidade | 6 | **8** | câmera provada (9); falta a regra IA/real/estado do salão |
| F7 Luta encenada | 7 | 9 | roteiro técnico com prova definida |

**Status: NÃO APROVADO, faltam 2 itens, os dois nos salões do Higgsfield:** (1) `hall_comparacao` v2 sem lavar, com a saturação dentro de ±10%; (2) a regra de ordem IA × real × chefe escrita no `ferramentas.md`. O roteiro pode andar em paralelo, já com essa regra. Com esses dois itens, F3 e F6 vão a 9 e aprovo.

## Rodada 3, APROVADO (ferramentas §5.10/§5.11 + resposta, 14:56)

`hall_comparacao_v2.png` (real | cru | v1 | v2, com CRT): a v2 resolveu a lavagem. A chama do arco voltou a ser fogo (amarelo-laranja com núcleo claro), as tochas acenderam, o preto do fundo é preto e os estandartes voltaram a ser vermelhos, não marrons. Fica na grade e na paleta do salão real e lê como o mesmo jogo. Saturação +9,4%, dentro do que pedi. O p98 acima do real é a chama maior, e concordo que é destaque, não lavagem. A regra de ordem (§5.11) está escrita do jeito certo: IA só antes de o chefe ocupar o salão, IA primeiro quando vizinha do real, um grave cada, ◆. Mão de ≤ 5 cartas sem título coberto e vida do inimigo do ato correto ficam como verificação de folha, e confiro no corte.

| critério | r1 | r2 | r3 |
|---|---|---|---|
| F1 Inventário e veredito | 9 | 9 | 9 |
| F2 Teste real e verificável | 9 | 10 | 10 |
| F3 Imagem íntegra / cara do jogo | 6 | 8 | 9 |
| F4 Cobertura das tomadas | 8 | 9 | 9 |
| F5 Conformidade e riscos | 9 | 9 | 9 |
| F6 Câmera e continuidade | 6 | 8 | 9 |
| F7 Luta encenada | 7 | 9 | 9 |

**Status: APROVADO, ≥ 9 em todos.**
