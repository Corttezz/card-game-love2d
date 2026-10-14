---
name: code_notes/src/data/enemies.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/enemies.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/enemies.lua`

Origem: `src/data/enemies.lua` em `7dbdb60d` (15 de 54 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-59 (junto a `local Enemies = {}`)

> src/data/enemies.lua
> ============================================================================
> INIMIGOS — roster por ato + kit de golpes por criatura (Out/2026)
> ============================================================================
> Auditoria de conteúdo (Out/2026): TODO inimigo jogava igual. Havia uma
> tabela de intents só (atacar / golpe forte ×1.6 / defender / +2 de dano)
> dividida pelas 21 criaturas, e a identidade de cada uma morava apenas no
> sprite. Ninguém debuffava o jogador, ninguém batia várias vezes, nenhum
> golpe tinha nome, e o chefe era um saco de vida maior.
>
> Este arquivo é DADO PURO (sem lógica). Quem lê: src/systems/EnemyRoster.lua
> (sorteio do roster) e src/entities/Enemy.lua (rolagem e execução do golpe).
>
> ── KIT (chave = id do sprite, a mesma do EnemyRenderer) ───────────────────
> hpMul / dmgMul   escala sobre a curva do ato (ActSystem). Gosma = parruda
> e fraca; diabrete = frágil e venenoso.
> opener           golpe do PRIMEIRO turno (o cartão de visita da criatura).
> moves            golpes sorteáveis (ver abaixo).
> phases           { { at = 0.5, id, dmgMul, moves, opener } } — troca de
> kit ao cruzar a fração de vida (Rainha do Eclipse).
> passive          { regenPct } — estado permanente desde o 1º turno.
> veil             { level = "type_only" | "hidden", chance = 0..1 } — a
> criatura ESCONDE o próprio intent (Out/2026): o HUD mostra
> o ícone sem número (type_only) ou só "?" (hidden), em
> `chance` dos anúncios (padrão 1). Combina com a névoa do
> bioma (src/data/intent_fog.lua) pelo pior nível; cartas
> de Revelar e o pulso do orbe de Raio dissipam. Vale
> também dentro de uma fase (Rainha no Eclipse). O golpe
> continua congelado: só a LEITURA muda.
>
> ── GOLPE ───────────────────────────────────────────────────────────────────
> id        chave i18n `enemy_kit.moves.<id>` (nome + descrição no tooltip).
> kind      categoria de LEITURA (ícone do HUD): attack | strong | multi |
> defend | buff | debuff | heal | charge | summon.
> A execução lê os CAMPOS, não o kind — um golpe pode ter dano,
> bloqueio e debuff juntos ("bloqueia e golpeia").
> weight    peso no sorteio (stream "enemy" do Rng).
> mult      dano POR GOLPE = floor(dano do inimigo × mult).
> hits      quantos golpes (multi). Bloqueio absorve cada um, mas o teto de
> Bloqueio por ato faz a soma vazar.
> swarm     hits += pilhas do status `swarm` do inimigo (revoada).
> pierce    ignora o Bloqueio do jogador.
> armor     bloqueio ganho = getDefendAmount() × armor.
> strength  +dano PERMANENTE = max(2, floor(dano base × strength)).
> heal      cura = floor(vida máxima × heal).
> debuff    { name, duration, stacks } NO JOGADOR: weak (−25% no dano dos
> seus ataques), frail (−25% no Bloqueio das suas defesas),
> vulnerable (+50% de dano recebido), poison / burn (dano por
> turno que ignora Bloqueio). Pode ser lista (vários debuffs).
> summon    pilhas de `swarm` somadas ao inimigo.
> next      id do golpe FORÇADO no turno seguinte (carga → golpe).
> every     forçado a cada N turnos (turno % every == 0).
> minTurn   não sai antes deste turno.
> maxRow    máximo de usos seguidos (padrão 2; o 3º igual é proibido).
>
> INVARIANTE (CLAUDE.md §6): o intent é CONGELADO no anúncio. O número que o
> jogador vê no HUD é o teto do que acontece — Fúria/buff entre o anúncio e a
> execução só valem no próximo intent.
> ============================================================================

## L63-68 (em `Enemies`, junto a `Enemies.ROSTER = {`)

> ── ROSTER POR ATO ──────────────────────────────────────────────────────────
> Cada ato: 3 comuns, 2 elites, mini-chefe DISTINTO dos elites, 1 chefe.
> Sorteio pelo stream "enemy", sem repetir o último inimigo enfrentado.
> REGRA (dono, Out/2026): só criatura DO BIOMA do ato — nada de emprestar
> sprite de outro ato ("monstros sem relação com o bioma"). A fonte da
> pertença é HOME_BIOME abaixo; test_enemies cruza as duas tabelas.

## L96-97 (em `boss`, junto a `Enemies.HOME_BIOME = {`)

> Bioma de ORIGEM de cada criatura (o ato cuja arte/cenário ela habita).
> Declarado à parte do ROSTER de propósito: é o que impede o "empréstimo".

## L113-119 (em `Enemies.HOME_BIOME`, junto a `Enemies.DAMAGE_SCALE_BY_ACT = { 1.15, 1.10, 0.92, 0.88, 0.84, 0.84 }`)

> ── ESCALA DE DANO POR ATO (calibrada pela bateria do piloto, Out/2026) ─────
> As curvas de dano do Config.Acts foram afinadas para o kit ANTIGO, cujo
> golpe médio valia ~0,76× o dano base (50% ataque, 16% forte ×1,6, resto
> sem dano). Os kits batem em média ~1,0–1,1× e ainda debuffam — sem esta
> escala o guerreiro do piloto caiu de 60% para 15% de vitória (morrendo nos
> chefes dos atos 3-4). O começo SOBE um pouco de propósito: a auditoria
> mediu 0,0–0,2 de dano sofrido por turno nos atos 1-2 (zero tensão).

## L122-124 (em `Enemies.DAMAGE_SCALE_BY_ACT`, junto a `Enemies.BOSS_DAMAGE_SCALE = 0.90`)

> Chefes por cima da escala do ato: a mecânica-assinatura (carga, perfurante,
> revoada, peste, eclipse) já é o perigo — com o dano cheio, os chefes dos
> atos 4-6 respondiam por ~2/3 das mortes do piloto (bateria v4, Out/2026).

## L131-132 (em `Enemies.KITS`, junto a `generic = {`)

> Kit legado: os quatro intents de antes, para Enemy:new sem kit (testes,
> modo clássico). Mesmos pesos e mesma regra de pressão.

## L177-178 (em `debuff`, junto a `carrion_king = {`)

> CHEFE A1 — invoca a revoada: cada Chamado soma corvos, e a Revoada bate
> uma vez por corvo. Quanto mais a luta demora, mais golpes por turno.

## L215-216 (em `moves`, junto a `tower_lich = {`)

> CHEFE A2 — escudo de gelo a cada 3º turno (a janela de burst é o turno
> SEGUINTE, quando o escudo cai) e drena: Fragilidade + cura.

## L277-278 (em `debuff`, junto a `abyss_tyrant = {`)

> CHEFE A3 — carrega o Fogo Infernal: um turno inteiro telegrafando, o
> golpe seguinte é o maior da luta e queima.

## L295 (em `frost_wight`, junto a `veil = { level = "type_only", chance = 1 },`)

> espectro da neve: anda DENTRO da nevasca — o número nunca aparece

## L315-316 (em `debuff`, junto a `winter_monarch = {`)

> CHEFE A4 — lâminas que atravessam o Bloqueio e um inverno que fragiliza
> tudo a cada 3º turno.

## L344-345 (em `debuff`, junto a `rot_colossus = {`)

> CHEFE A5 — nuvens de peste no jogador e regeneração própria: a luta
> longa é dele.

## L361-363 (em `debuff`, junto a `eclipse_queen = {`)

> ===================== ATO 6 — CORTE DO ECLIPSE =====================
> CHEFE A6 — duas lutas numa: abaixo de 50% de vida o ECLIPSE fecha, o
> kit troca e o dano sobe.

## L389-390 (em `debuff`, junto a `hollow_farmer = {   -- camponês oco: ergue o forcado um turno e crava no seguinte`)

> ===================== CRIATURAS NOVAS (Out/2026, frente inimigos-arte) =====================
> A silhueta já anuncia o golpe: o kit segue o conceito que veio com a arte.

## L658 (em `moves`, junto a `Enemies.PLAYER_DEBUFFS = { weak = true, frail = true, vulnerable = true,`)

> Status que o inimigo põe no JOGADOR (fonte única do contrato com Player/HUD).

