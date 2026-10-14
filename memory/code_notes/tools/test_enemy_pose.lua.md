---
name: code_notes/tools/test_enemy_pose.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_enemy_pose.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_enemy_pose.lua`

Origem: `tools/test_enemy_pose.lua` em `7dbdb60d` (20 de 23 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local TK = require("tools.testkit")`)

> tools/test_enemy_pose.lua
> Regressões dos defeitos de Set/2026 (cena do elite + chefe flutuando):
>
> 1. ELITE não briga no salão do chefe (isInteriorNode é a fonte única).
> 2. Toda cena de interior tem LINHA DE CHÃO declarada, e ela cai na laje
> — `height * 0.68` fixo punha o pé do chefe do ato 2 na PAREDE.
> 3. Todo inimigo do roster tem POSE declarada, e a âncora não depende da
> resolução (o mesmo ponto da arte em qualquer janela).
>
> Roda via: love . test_one test_enemy_pose

## L25-27 (em `M.run`, junto a `t:truthy("boss depois da cutscene luta DENTRO do castelo",`)

> ===================================================================
> 1. Cenário por tipo de node
> ===================================================================

## L39-45 (em `M.run`, junto a `local Config = require("src.core.Config")`)

> ===================================================================
> 2. Linha de chão das cenas de interior
> ===================================================================
> v11: varre TODOS os atos da campanha, não os 3 que tinham arte quando
> o teste nasceu. O ato novo sem salão (ou com salão sem âncora) passa a
> FALHAR aqui em vez de aparecer na cara do dono — foi exatamente assim
> que os atos 4-6 ficaram reusando o cenário do ato 1 sem ninguém ver.

## L57-59 (em `M.run`, junto a `t:truthy(key .. " ancora na laje (yr=" .. tostring(a.yr) .. ")",`)

> Toda laje destes salões mora na metade de baixo da arte; acima
> disso é parede (o caso do hall 2) e abaixo de 0.95 some atrás do
> HUD. Fora dessa faixa é bug de dado, não de gosto.

## L64-66 (em `M.run`, junto a `do`)

> Cada ato tem o SEU salão: dois atos apontando pro mesmo PNG é o defeito
> que o dono pegou jogando ("o cenário do boss de alguns atos está igual
> o do primeiro ato"). Comparação por conteúdo, não por nome de arquivo.

## L83-85 (em `M.run`, junto a `t:truthy("hall 2 ancora MAIS BAIXO que o hall 1 (laje mais baixa na arte)",`)

> O hall do ato 2 é o do defeito: a laje dele é MAIS BAIXA que a dos
> irmãos. Se alguém "uniformizar" os três valores, o chefe volta a
> flutuar — este assert existe pra isso.

## L90-91 (em `M.run`, junto a `do`)

> Âncora independe da resolução: mesmo ponto da ARTE em qualquer
> janela (o cover-fit corta na vertical em telas largas).

## L108-110 (em `M.run`, junto a `local nodeTypes = { "battle", "elite", "mini_boss", "boss" }`)

> ===================================================================
> 3. Pose de todo inimigo do roster
> ===================================================================

## L124-125 (em `seen`, junto a `local dir = "assets/sprites/characters/enemies"`)

> Arte nova sem pose declarada é o caminho de volta pro defeito: o
> sprite entra no jogo, cai no default grounded e ninguém percebe.

## L149-151 (em `seen`, junto a `do`)

> ===================================================================
> 4. reducedMotion: tira o BALANCO, nunca a ALTURA
> ===================================================================

## L165 (em `_G.gameSettings`, junto a `_G.gameSettings = { reducedMotion = false }`)

> com movimento: oscila, mas nunca encosta no chao nem foge da faixa

## L180-184 (em `_G.gameSettings`, junto a `local apoiados = 0`)

> quem pisa nao se mexe, com ou sem reducedMotion.
> O exemplo era `tower_lich`, que virou FLUTUANTE por decisao de
> design (Set/2026, ver o comentario dele em enemy_poses). Trocado
> por um apoiado que nao esta em disputa — e a assercao agora varre
> TODOS os grounded, pra nao quebrar de novo quando um mudar de lado.

## L200-204 (em `_G.gameSettings`, junto a `local ART = "assets/sprites/characters/enemies"`)

> ===================================================================
> 5. A ARTE do clip, nao so o dado da pose (Set/2026, 2a leva do dono:
> "o pezinho dele precisa ficar inclinado para baixo. A capa tambem
> precisa ficar mexendo um pouquinho, coisas sutis")
> ===================================================================

## L207-210 (em `_G.gameSettings`, junto a `local function padDoClip(id, clip)`)

> Margem transparente abaixo do conteudo do 1o frame de um clip. E
> exatamente o que `EnemyRenderer.clipMetrics` chama de `pad`, e o que
> posiciona o sprite na tela. Varre de baixo pra cima e para na 1a
> linha com conteudo — barato o bastante pra rodar em 21 inimigos.

## L226-236 (em `padDoClip`, junto a `do`)

> (a) O PE DO CONTEUDO tem que cair no mesmo lugar em idle/hurt/death.
>
> `clipMetrics` mede o pad do 1o frame DE CADA CLIP e o usa pra
> posicionar o sprite. Se so um clip for regerado, o monstro PULA na
> vertical ao levar dano ou ao morrer. Foi o defeito que quase entrou
> nesta leva: corrigir o pe so no idle deixava idle=1 e hurt=4, ou seja
> ~7px de pulo na tela a cada golpe recebido.
>
> `attack` fica FORA de proposito: esses clips vem com o canvas cru do
> PixelLab (176-256px, margem gorda) e o proprio EnemyRenderer conta
> com isso — a escala sai sempre do idle.

## L252-254 (em `padDoClip`, junto a `t:truthy(id .. ": idle nao encosta na borda de baixo",`)

> (b) Conteudo encostando na ultima linha do canvas =
> arte CORTADA. Aconteceu duas vezes ao desenhar o bico
> da bota do lich: a ponta ficou sem fechar.

## L264-273 (em `padDoClip`, junto a `do`)

> (c) Quem flutua tem PANO, e pano se mexe. O idle do lich era
> silhueta parada: media do deslocamento da borda entre frames = 1px,
> e o que sobrava era chuvisco de regeracao, nao balanco. Foi
> exatamente a queixa ("a capa precisa ficar mexendo um pouquinho").
>
> A metrica soma tres deslocamentos da SILHUETA entre os frames do
> idle: o extremo direito do corpo e a barra de cada aba da capa.
> Medido nesta sessao: arte antiga = 3, arte nova = 7. O teto existe
> porque a outra metade do pedido foi "coisas sutis, bem pequenas" —
> capa esvoacando seria tao errado quanto capa parada.

## L309-310 (em `opaco`, junto a `local function barra(x0r, x1r)`)

> barra (ponto mais baixo) de cada aba da capa, em fracoes da
> largura pra nao cravar pixel de um canvas especifico

## L328-331 (em `barra`, junto a `do`)

> (d) REGRA DO APOIO (Out/2026, "os ratos parecem flutuar"): o chao e a
> linha mais baixa com coluna opaca GROSSA, nao o pixel mais baixo. Um
> corpo 20x20 com um rabo de 2px pendurado 6px abaixo pisa na base do
> CORPO; e o override groundRow dos ratos vale (rabo grosso deitado).

## L348 (em `barra`, junto a `local unknown = EnemyPoses.get("nao_existe_no_roster")`)

> get() normaliza e nunca devolve nil (fallback anunciado, nao mudo).

