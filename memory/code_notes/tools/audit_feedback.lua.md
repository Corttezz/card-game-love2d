---
name: code_notes/tools/audit_feedback.lua
description: Comentários com decisão/regra/histórico colhidos de tools/audit_feedback.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/audit_feedback.lua`

Origem: `tools/audit_feedback.lua` em `7dbdb60d` (20 de 27 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-35 (junto a `local CardDatabase = require("src.systems.CardDatabase")`)

> tools/audit_feedback.lua
> AUDITORIA DE FEEDBACK DE COMBATE (Set/2026).
>
> Pergunta que esta ferramenta responde SEM depender de ninguem lembrar:
> "para cada TIPO DE EFEITO que existe no catalogo, o codigo que o processa
> chama alguma coisa que o jogador OUVE ou VE no instante em que acontece?"
>
> Como MEDE (nao supoe):
> 1. VARRE o codigo-fonte que processa efeitos (EffectSystem, Game,
> ComboSystem), segmentando por branch `<algo>.type == "<tipo>"`.
> 2. Dentro de cada branch procura CHAMADAS DE FEEDBACK conhecidas
> (Sfx.play, FloatingText, CardFeel.burst, pushJokerProc, notifyOrbUI,
> addMessage, juice_up/hop_up/swell_up, triggerShake, ER.trigger*).
> 3. Segue UM nivel de DELEGACAO declarada (ex: `draw_cards` chama
> game:drawCard, e o feedback mora la dentro) — ver DELEGATION.
> 4. INSTANCIA o catalogo inteiro e cruza: quais cartas/jokers usam cada
> tipo — a lista NOMINAL de quem e afetado por cada lacuna.
>
> Limitacoes declaradas (o relatorio e um mapa, nao um oraculo):
> escaneamento estatico por proximidade textual dentro do branch;
> funcao cujo corpo NAO e um if-chain por tipo entra em
> FUNCTION_ATTRIBUTION (hoje so applyJokerEffects);
> feedback que mora fora de qualquer branch por tipo (ex: `exhaust`, cujo
> som esta em `if card.exhaust` no Game) aparece como mudo aqui e esta
> anotado na linha de base.
>
> CRITERIO DE FALHA (proposital): a ferramenta NAO falha por lacuna ja
> existente — elas estao documentadas em docs/auditoria-feedback-combate.md e
> em correcao por outros agentes. Ela e uma CATRACA: falha se aparecer um tipo
> de efeito MUDO que nao esta na linha de base BASELINE_SILENT (tipo novo sem
> feedback, ou tipo que PERDEU o feedback que tinha).
>
> Rodar:
> love . test_one audit_feedback     (relatorio completo)
> love . test_all                    (entra na suite, grupo `valid`)

## L42-44 (em `M`, junto a `local SIGNALS = {`)

> ===========================================================================
> 1. Sinais de feedback procurados no codigo
> ===========================================================================

## L60-62 (em `toast`, junto a `local PERCEIVED = { "som", "particula", "numero", "proc", "orbe", "fisica",`)

> Classes que contam como "o jogador PERCEBE no instante em que acontece".
> `toast` fica de fora DE PROPOSITO: o feed lateral e historico, nao evento —
> foi exatamente a queixa do dono ("sai acontecendo e fica dificil acompanhar").

## L72-73 (em `SOURCES`, junto a `local FUNCTION_ATTRIBUTION = {`)

> Funcoes cujo corpo NAO e um if-chain por tipo, mas cujo feedback pertence a
> tipos especificos. Atribuicao explicita e declarada.

## L75-77 (em `FUNCTION_ATTRIBUTION`, junto a `["EffectSystem:applyJokerEffects"] = {`)

> Out/2026 (previa de dano): a CONTA dos coringas foi pro nucleo puro
> EffectSystem:jokerSteps (sem feedback, por definicao); o proc/toast de
> cada entrada — Eco incluso — sai daqui.

## L84-85 (em `FUNCTION_ATTRIBUTION`, junto a `local DELEGATION = {`)

> DELEGACAO: se o branch de um tipo chama uma destas funcoes, o feedback dela
> conta pro tipo. Um nivel so, e declarado aqui (nada implicito).

## L90-93 (em `DELEGATION`, junto a `["_stepChannelOrb"]   = "EffectSystem:_stepChannelOrb",`)

> Set/2026: canalizar e evocar viraram BEATS proprios e o corpo saiu do
> if-chain pra estes dois helpers (a mutacao do estado precisa morar
> DENTRO do beat, nao na coleta). Sem declarar a delegacao a ferramenta le
> os tres tipos de orbe como MUDOS e acusa regressao onde houve correcao.

## L96-97 (em `DELEGATION`, junto a `["showEnemyDamage"]   = "showEnemyDamage",`)

> Numero de dano + reacao do inimigo pra magia/evoke, que antes so tinham
> burst (o jogador via a MESMA explosao pra "levou dano" e "ganhou orbe").

## L99-100 (em `DELEGATION`, junto a `["enemyHurt"]         = "enemyHurt",`)

> A reacao FISICA do inimigo saiu de showEnemyDamage pra ca quando o pulso
> de orbe passou a precisar dela SEM numero (o valor ja sai do orbe).

## L106-110 (em `DELEGATION`, junto a `local BASELINE_SILENT = {`)

> ===========================================================================
> 2. Linha de base (catraca). Tipos HOJE sem nenhum sinal percebido.
> Corrigiu um? Tire da lista NO MESMO COMMIT (o tool avisa se esquecer).
> Precisa ADICIONAR um? Entao esta introduzindo mudez nova — justifique.
> ===========================================================================

## L112-115 (em `BASELINE_SILENT`, junto a `heal_multiplier   = "multiplica a cura em silencio: sem proc, sem som, sem toast",`)

> CURADO EM VOO (ritmo-combate, Set/2026): applyHealMultiplier agora empurra
> proc. Mantido na lista de proposito enquanto a correcao assenta, pra que
> esta ferramenta NUNCA seja o motivo de o test_all ficar vermelho no meio
> de uma edicao de terceiro. O [INFO] "tipos CURADOS" cobra a remocao.

## L124-126 (em `BASELINE_SILENT`, junto a `combo_boost       = "invisivel: dobra o bonus de combo dentro do numero da carta",`)

> Coringas de combo (Out/2026): dobram Saraivada/Muralha/Par dentro do
> bonus da carta — o efeito aparece na ficha dourada da previa e no
> numero do banner, nao num proc proprio (como o *_scaling acima).

## L135-137 (em `BASELINE_SILENT`, junto a `local function typesInLine(line)`)

> ===========================================================================
> 3. Varredura estatica
> ===========================================================================

## L163-164 (em `delegatesInLine`, junto a `if line:find("[^%w_]" .. pat .. "%s*%(") then`)

> Fronteira de palavra em vez de exigir `:`/`.`: helpers LOCAIS
> (showEnemyDamage) sao chamados sem prefixo e ficariam invisiveis.

## L172-173 (em `delegatesInLine`, junto a `local function scanSources()`)

> Retorna sig = { [tipo] = { seen=true, [classe]=true, _where={...},
> _delegates={fname=true} } }

## L205-206 (em `mark`, junto a `local fname = line:match("^function%s+([%w_]+[:%.][%w_]+)")`)

> Indexa tambem `local function nome(...)`: helper local e
> destino de delegacao valido (showEnemyDamage nasceu assim).

## L258-260 (em `mark`, junto a `local function scanCatalog()`)

> ===========================================================================
> 4. Catalogo: quem usa cada tipo
> ===========================================================================

## L283-285 (em `scanCatalog`, junto a `local function perceivedClasses(entry)`)

> ===========================================================================
> 5. Relatorio + catraca
> ===========================================================================

## L346-350 (em `dump`, junto a `local FLAGS = { exhaust = true, innate = true, retain = true }`)

> Simultaneidade: quantos efeitos resolvem no MESMO instante -----
> Game:processCardInCombat roda processAdditionalEffects() em UM frame, no
> impacto da carta: todo efeito secundario da carta acontece junto do
> numero de dano/bloqueio, do burst e dos procs de joker. Quanto maior a
> contagem, mais coisa o jogador precisa ler no mesmo piscar de olhos.

## L393-394 (em `novos`, junto a `local curados = {}`)

> Linha de base obsoleta: tipo que ganhou feedback e continua listado.
> Nao falha (as correcoes estao em voo), mas avisa em alto e bom som.

