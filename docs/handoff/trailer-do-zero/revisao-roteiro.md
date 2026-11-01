# Revisão: etapa 3, roteiro "Contra as regras" (trailer-do-zero)

_Revisora independente, 01/11/2026. Base: `roteiro.md` (13.201 bytes, 14:56). Conferi no código os chefes por ato (`src/data/enemies.lua`: 1 Rei-Carniça, 2 Lich, 3 Tirano, 4 Monarca, 5 Colosso, 6 Rainha), as criaturas citadas (espantalho, gárgula, cão do inferno, serpente de gelo, mãe-esporo e anjo caído existem nos atos indicados), o rótulo LETHAL (`DamagePreviewPanel`, locale en) e a revoada (`swarm` no kit do Rei). Também medi a curva de loudness de curto prazo da faixa `boss-carrion_king.mp3` e conferi os graves no `_beats.json` (64 graves; nenhum entre 35,19 e 55,26 s da faixa). Régua: ≥ 9 em todos os critérios, com nota prevista para o filme que este roteiro produziria._

## Rodada 1, NÃO APROVADO

É o melhor roteiro de trailer que este projeto já teve. Mostra a carta legível no quadro 0, conta uma luta com perigo e LETAL, faz a música sair de verdade, prova o gancho três vezes com a regra na imagem e fecha com o coringa do chefe subindo do corpo e virando o selo, uma ponte de fecho com cara de Balatro. O microtrailer planejado (serpente, porta, corvo, carta derretendo, LETAL, coringa) é ótimo. Mas há um defeito estrutural de continuidade que a própria diretora proibiu no §7, a música está encaixada ao contrário da imagem no meio, e o ato III está congestionado demais para ser lido.

### Problemas concretos

**1. A jornada anda para trás, duas vezes (regra 5 do §7, escrita pela própria diretora).**
- 19,7 → 28 s: montagem dos atos 2 a 6 até o crepúsculo do ato 6; a porta do castelo a 28 a 31 s é, portanto, o castelo **do ato 6**. Mas quem está dentro (31 a 39,5 s) é o **Rei-Carniça, chefe do ato 1**. O espectador atento vê o fim da estrada e depois o primeiro chefe.
- 42,3 a 50,8 s: **Monarca (ato 4) antes do Tirano (ato 3)**.
- 52,0 s: "volta ao salão do Rei-Carniça" para o LETAL, depois do ato 3 e do ato 4.
- E a troca ladino → guerreiro acontece sem marca (o ladino responde ao anjo a 26,2 s; o guerreiro aparece com 9 de vida a 52 s).

**Exijo uma ordem que só ande para a frente.** Duas saídas que funcionam: **(a)** a jornada vai só até o castelo do **ato 1** (estrada do ato 1 → porta → Rei-Carniça entra → drop), e a montagem dos atos 2 a 6 vira, **dentro do drop**, a prova do gancho em ordem crescente: estrada do ato 3 → salão IA → Tirano/correntes → estrada do ato 4 → salão IA → Monarca/Geada (com "6 ACTS / 42 CREATURES" sobre essas estradas), voltando ao Rei para o LETAL como **luta intercalada já em curso**. Isso é aceitável se o retorno for claramente "a mesma luta" (mesmo enquadramento, chefe já no trono, a revoada da 39,76 s ainda no ar), sem parecer volta no tempo. **(b)** O LETAL contra o chefe mais avançado mostrado (Monarca), com o Rei-Carniça só na entrada e na 1ª prova. A (a) preserva a cinemática do Rei e a faixa dele, e é a que recomendo. Seja qual for a escolhida, a troca de classe acontece **uma vez**, num corte natural (a porta do castelo) e sem voltar.

**2. A música está encaixada ao contrário da imagem no meio do filme.** Medi a faixa: groove em −14 a −17 LUFS (curto prazo) até 35,2 s da faixa; trecho calmo em **−22 a −24 sem nenhum grave** de 36 a 54,5 s; volta a −18 → −15 em 55 s. Com o deslocamento de −15,5 s, isso quer dizer:
- A **montagem por corte de correspondência** (19,7 a 28 s do filme), que é a sequência que **mais precisa de pulso** (cortes no grave como no v4 que o Daniel aprovou), cai **inteira no trecho sem grave**. Os cortes ficam presos a SFX esparsos, e é o centro do filme (30 a 45% da duração): risco alto de "morno" e de o C3 falhar ali.
- O **silêncio** do chefe (31 a 37 s) vem depois de 11 s de música já a −23. Silêncio depois de calmo é quase imperceptível. A meta de ≥ 15 dB "abaixo do trecho anterior" exigiria o ambiente a cerca de −38 LUFS, e o contraste dramático (o que o Daniel pediu: "a música sai e volta com impacto") some. Silêncio funciona depois de **cheio**.
- **O "pico" da faixa não é pico.** A partir de 70 s ela fica em −13,6 a −15, só 1 a 2 dB acima do groove de 16 a 35 s. O arco promete −11 no LETAL, mas a faixa não entrega isso sozinha.

**Exijo** que o roteiro traga uma curva de energia **medida** (curto prazo da faixa já com o deslocamento, sobreposta aos blocos) e que o encaixe faça: montagem em cima do groove com graves; trecho calmo usado como descida para a porta; silêncio depois de groove cheio; e o pico feito pela mixagem, escrito como plano (ex.: groove abaixado de 4 a 6 dB nos 6 s antes do LETAL, respiro de 0,6 s em −∞, impacto do jogo + clímax a 0 dB relativo, hit-stop). Opções concretas: mudar o deslocamento, reordenar (montagem antes da reward), ou testar o Tirano, que tem frases de ~9,2 s com graves fortes. A escolha é da diretora, mas o corte 1 tem de passar no C3 (cortes no grave) também na montagem.

**3. A meta do silêncio está mal definida e é impossível do jeito que está escrita.** "Nada de música (≤ −32 LUFS de curto prazo)" convive no mesmo trecho com olhos, asas, três rasantes de corvo e o pouso, que são justamente os sons do jogo que o Daniel quer ouvir. O pouso sozinho passa de −32 numa janela de 3 s. Reescrevam a meta assim: **leito** (ambiente do salão, medido sem os transientes) ≥ 15 dB abaixo do groove anterior; **eventos** do jogo como picos isolados, cada um com o seu nível escrito (ex.: corvo −20, pouso −14 de pico de curto prazo de 0,4 s); **zero música**. É isso que vou medir.

**4. O ato III (39,76 a 54,5 s) tem 14 planos em 15 s, três chefes e quatro textos.** Rajadas: 42,3 (0,7 s) → 43,0 (0,5 s) → 43,5; 53,9 (0,6 s); e o salão IA a 31,0 (1,0 s). O critério 5 permite no máximo 2 rajadas abaixo de 1 s, e aqui há pelo menos 4. Pior: **cada prova do gancho precisa ser lida** (duas cartas congelando e uma derretendo; uma corrente rompendo e o intent caindo pela metade), e o roteiro dá 1,5 a 2,5 s a cada uma, picados em ×1/×2. **Exijo** cada prova com **≥ 2,5 s contínuos no plano em que a regra se lê** (×2 na mão para a Geada; ×2 na barra + intent para as correntes), e o salão IA + o chefe real em no máximo 2 planos antes dela. Se não couber, corte o 3º chefe para uma única imagem de corrente rompendo e fique com 2 provas completas mais a revoada (a regra de três admite 2 a 3).

**5. "FROST." e "CHAINS." não explicam nada.** Uma palavra solta lê como etiqueta. O espectador sem som não sabe que a geada **trava as suas cartas** nem que romper a corrente **corta o golpe dele**. Ou o texto diz a regra em ≤ 4 palavras (ex.: "FROST LOCKS YOUR HAND." / "BREAK HIS CHAINS."), ou não tem texto e a imagem carrega tudo. O meio-termo de uma palavra só ocupa a tela sem informar.

**6. Textos novos sem o OK do Daniel e sem marcação.** Os aprovados eram cinco (SIX ACTS / ONE ROAD TO THE CASTLE / BUILD A LIVING DECK / YOUR CARDS DECIDE WHAT SURVIVES / EVERY BOSS IS A PUZZLE / WISHLIST ON STEAM). O roteiro troca ou acrescenta "145 LIVING CARDS.", "6 ACTS." (em vez de SIX ACTS.), "42 CREATURES.", "EVERY BOSS / BREAKS THE RULES." (no lugar do PUZZLE aprovado), "FROST.", "CHAINS.", "BREAK THEM BACK." e "A ROGUELIKE DECKBUILDER". Pode, mas cada um tem de estar marcado ⚠️ como pendente do Daniel, com a versão aprovada de reserva ao lado. Não é bloqueio para o corte 1; é bloqueio para "pronto".

**7. O gancho dos primeiros 8 s não tem o "uau".** Situar o jogo, sim: carta, JOGAR, número, COMBO. Mas é a luta mais fraca do jogo (espantalho do ato 1) e nada escala. Monster Train explode algo em 1,6 s; Balatro faz o número subir em cascata. Recomendo que o 1º golpe (3,36 s) seja a **cascata visível**: 3 cartas resolvendo uma a uma, o "COMBO! Volley" somando, um coringa ticando "×2" e o número final grande. Tudo isso existe no jogo (procs em sequência, `JokerProcFx`). É a escalada do gênero no 3º segundo, sem trocar de inimigo.

**8. 14,6 s de estrada em ×1 (13,4 a 28 s).** A encruzilhada sozinha leva 3,8 s (15,9 a 19,7). É o mesmo "paisagem com legenda" do diagnóstico, ainda que agora com criaturas na segunda metade. Encruzilhada em **1 plano** (≤ 1,3 s), e o tempo devolvido vai para as provas do item 4.

**9. Detalhes de continuidade a acertar no storyboard:**
- 26,2 s: "cartas na mão respondem ao anjo" com o ladino no ato 6, sendo que o ladino só apareceu no ato 1. Se a troca de classe ficar na porta, ok; senão, é mais um salto.
- 39,76 s: os corvos mergulham "no painel do herói", embaixo à esquerda, e o texto "EVERY BOSS / BREAKS THE RULES." fica no terço superior. Confiram que o texto não cobre o Rei nem a órbita de corvos (o assunto daquele plano).
- 59 → 61,2 s: o coringa sobe e a carta "gira e a face vira o selo". Bom, mas definam a direção do giro igual à da subida (`BossTrophy`), para não inverter o movimento no corte para o logo.

### O que está muito bom (não mexer)
- TV do jogo a 60% no quadro 0 + `boot-tv-power-on` sozinho + música no 1º grave (pedido 1 do Daniel cumprido sem preto).
- Plano ×1 com HUD a 2,1 s; "145 LIVING CARDS." sobre a mão sendo dada, sem cobrir a carta.
- Rei entrando pela direita e pousando (direção mantida do B), cartão do nome do jogo como texto, "LETHAL" do próprio jogo como texto.
- Coringa do chefe → selo → GRIMOIRE / A ROGUELIKE DECKBUILDER / WISHLIST, fecho de 6,8 s com o salão e um corvo atrás, e último som = carta puxada.
- Microtrailer planejado e verificações do §5.

## Notas por critério (rodada 1, nota prevista para o filme deste roteiro)

| critério | nota | por quê |
|---|---|---|
| C1 Gameplay ≤ 2 s / quadro 0 | 10 | carta viva a ×2 no quadro 0, HUD a 2,1 s |
| C2 Sem preto | 9 | nenhum plano preto; silêncio no escuro com olhos é imagem |
| C3 Sincronia | 7 | a montagem cai no trecho da faixa sem graves (item 2) |
| C4 Legibilidade | 8 | carta ótima; as provas do gancho com 1,5 a 2,5 s picados; FROST/CHAINS sem sentido |
| C5 Ritmo | 7 | 14,6 s de estrada ×1 e ≥ 4 rajadas < 1 s no ato III |
| C6 Pico | 7 | no tempo certo (80%), mas a faixa não sobe ali e falta o plano de mixagem do pico |
| C7 Regra de 3 | 9 | três provas com a regra na imagem |
| C8 Fecho | 9 | 6,8 s, gênero + CTA, imagem do jogo atrás |
| C9 Conformidade | 9 | cenários válidos, IA do Daniel com regra, números contados, marca "não publicável" |
| C10 Checklist do Daniel | 9 | TV antes da música, porta, chefe inteiro, música contínua, salões nos acentos |
| C11 Continuidade | **5** | jornada para trás duas vezes (ato 6 → chefe do ato 1; ato 4 → ato 3 → ato 1) e troca de classe sem marca |
| C12 Está bom / legal de assistir | 8 | a ideia é forte; o meio congestionado e o hook sem escalada tiram brilho |
| C13 Prende do início ao fim | 7 | o centro (19 a 31 s) sem pulso e o ato III ilegível de tão denso são os dois pontos de abandono |
| C14 Som | 7 | silêncio depois de trecho calmo; meta de −32 incompatível com os SFX pedidos |

**Status: NÃO APROVADO.** Para a rodada 2 exijo: itens 1, 2, 3 e 4 resolvidos no storyboard (com a curva de energia medida), 5 e 8 decididos, 6 marcado, 7 e 9 respondidos. As tomadas que não dependem da ordem (H, R, N1..N6, K, M, T, F) podem ser gravadas já, porque a reordenação é de montagem.

## Rodada 2 (roteiro rodada 2 + resposta-roteiro.md, 15:13)

Li o roteiro novo inteiro e as folhas das tomadas já gravadas (`scratchpad\tk\`: `zero_monarch.jpg`, `zero_tyrant.jpg`). Nas duas o HUD é do guerreiro (70 de vida), coerente com a troca única de classe. Na do Monarca leem-se "frozen!" e as cartas congeladas na mão; na do Tirano, o COMBO! Volley +15 / Pair +4 e os números grandes. A rodada 2 resolveu o essencial:
- **Ordem:** ato 1 → porta do ato 1 → Rei → "o que vem pela frente" em ordem crescente (2 → 3/Tirano → 4/Monarca → 5 → 6) → volta à **mesma luta** no mesmo enquadramento e estado. A progressão de vida bate: a Revoada derruba a vida a 32 a 35 s, e ela volta com 9 a 51,6 s. Troca de classe uma vez, na estrada do ato 1. Nada anda para trás.
- **Música:** a troca para o Tirano põe a montagem sobre a parte mais forte da faixa e o silêncio depois de um groove. O plano de mixagem do pico está escrito (−5 dB, respiro de 0,6 s, impacto 0 dB, +1 dB, hit-stop) com a meta medível "≥ 2 dB acima de qualquer outro trecho".
- **Silêncio:** meta reescrita do jeito certo (leito ≤ −30 sem transientes; cada evento com nível).
- **Provas:** 3,3 / 3,0 / 2,8 s contínuas, no plano em que a regra se lê; uma rajada só.
- **Textos:** todos os novos marcados ⚠️ com reserva; "BREAK HIS CHAINS." e "FROST LOCKS YOUR HAND." agora dizem a regra. Tempos de leitura conferidos: todos acima de 1 s/13 caracteres.
- **Gancho** com a cascata e **estrada** enxuta (1,6 + 1,2 s).

### O que ainda falta (pequeno, mas é continuidade)
1. **Dois textos atravessam corte, contra a regra 7 do §7.** (a) ⚠️ "6 ACTS." vai de 38,4 a 40,4 s e atravessa o corte ◆ de 39,6 s (ato 2 roxo → ato 3 vermelho): é a frase atravessando cor oposta, o mesmo defeito que o diagnóstico mediu no B a 22,5 → 23,75 s. (b) ⚠️ "42 CREATURES." vai de 44,8 a 46,6 s e atravessa o corte de 46,0 para o **salão IA do Monarca**: o texto que fala de criaturas termina sobre um trono vazio. **Exijo**: ou o texto acaba no corte (6 ACTS. 38,4 → 39,6 tem 1,2 s para 7 caracteres, o que basta; 42 CREATURES. 44,8 → 46,0 tem 1,2 s para 13 caracteres, também basta, no limite), ou a frase fica fixa e a imagem acompanha com o mesmo enquadramento (corte de correspondência), escolhido de propósito e escrito como tal. Prefiro acabar no corte.
2. **Microtrailer, fatia 1 (22,6 s) = salão IA.** A 1ª das 6 fatias do microtrailer da Steam cai exatamente no plano do Higgsfield. É permitido (decisão do Daniel), mas desperdiça a fatia com o único plano que não é o jogo. Recomendo empurrar o salão IA meio grave (a fatia passaria a pegar a porta abrindo ou os olhos) ou aceitar e registrar. Não bloqueia.
3. **Faixa do Tirano sob o Rei-Carniça:** registrado como decisão de escuta do Daniel, ok. Na Entrega, deixem explícito que existe a versão de reserva com a faixa do Rei e o que ela custa (o meio sem grave).
4. **Mão ≤ 5 cartas:** na folha `zero_tyrant` o primeiro turno mostra 6 cartas. Confiram no instante usado (regra da rodada 2 das ferramentas).

## Notas por critério (rodada 2, previstas)

| critério | r1 | r2 | por quê |
|---|---|---|---|
| C1 Gameplay ≤ 2 s / quadro 0 | 10 | 10 | — |
| C2 Sem preto | 9 | 9 | — |
| C3 Sincronia | 7 | 9 | faixa com graves no filme inteiro; cortes do silêncio em som do jogo, declarados |
| C4 Legibilidade | 8 | 9 | provas ≥ 2,8 s; textos dizem a regra |
| C5 Ritmo | 7 | 9 | 1 rajada; estrada enxuta |
| C6 Pico | 7 | 9 | plano de mixagem escrito, com meta medível; a prova é no corte |
| C7 Regra de 3 | 9 | 9 | — |
| C8 Fecho | 9 | 9 | — |
| C9 Conformidade | 9 | 9 | — |
| C10 Checklist do Daniel | 9 | 9 | música contínua e séria; troca da faixa marcada como decisão dele |
| C11 Continuidade | 5 | **8** | ordem e estado resolvidos; dois textos atravessam corte (item 1) |
| C12 Está bom / legal de assistir | 8 | 9 | a cascata no 3º segundo, a porta, o silêncio e o LETAL formam um arco de verdade |
| C13 Prende do início ao fim | 7 | 9 | centro com pulso; ato III legível |
| C14 Som | 7 | 9 | silêncio depois do groove; metas por evento |

**Status: NÃO APROVADO, falta só o item 1** (C11 em 8). É uma linha em cada um dos dois textos. Com isso aprovo o roteiro. O corte 1 pode seguir montando já com essa correção.
