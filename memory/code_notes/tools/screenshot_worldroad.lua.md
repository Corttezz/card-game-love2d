---
name: code_notes/tools/screenshot_worldroad.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_worldroad.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_worldroad.lua`

Origem: `tools/screenshot_worldroad.lua` em `7dbdb60d` (33 de 52 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local M = {}`)

> tools/screenshot_worldroad.lua
> Captura o WorldRoad (mundo rolante) nos 3 biomas, empilhados verticalmente,
> pra validação visual. Roda via: love . screenshot_worldroad
> Saída: worldroad_screenshot.png no save dir.

## L11-12 (em `M`, junto a `local function overlays(x, y, w, h)`)

> LightEngine v1: overlays (composite multiply + fork marks) — mesma ordem
> do GameplayScene. Helper local pra manter os modos legíveis.

## L26-27 (em `M.run`, junto a `if mode and mode:match("^day_") then`)

> prefixos F6.1: "day_" = andar 1 (dia), "mid_" = meio do ato.
> Default = 1 (anoitecer/boss — mood cheio, o look validado).

## L36-37 (em `M.run`, junto a `if mode and mode:match("^dark_") then`)

> prefixo "dark_": cenário BEM escuro (revisão de emissivos/olhos —
> ambiente a 55% do noturno; é onde luz mal posicionada aparece)

## L50-52 (em `M.run`, junto a `local biomeOverride = nil`)

> prefixo "b<N>_": força o BIOMA/ATO do modo (fork etc. nasciam sempre
> no bioma 1). Necessário pra validar arte de lugar POR ATO — a mesma
> encruzilhada no chão de gelo, de pântano, de abismo.

## L64-65 (em `M.run`, junto a `local SceneBackground = require("src.ui.SceneBackground")`)

> Interior de castelo (BOSS): SceneBackground + chefe do ato.
> "interior2" = hall/chefe do ato 2 (tower_lich) etc.

## L92-93 (em `M.run`, junto a `local topBarH = 80`)

> FIM DE TRECHO: castelo grande com o portão visível (validação da
> curva de aproximação v5). camZ a 92% do segmento. "gate3" = bioma 3.

## L99-100 (em `M.run`, junto a `WorldRoad._camZ = segLen * 1.0`)

> v10.2: máximo NATURAL da caminhada (sem boost de câmera) —
> calibra CASTLE_APPROACH pra caber sem cortar/sair da esfera

## L104-106 (em `M.run`, junto a `WorldRoad._blend = nil`)

> mata o blend residual do setBiome (paleta pura, igual ao modo
> endless) e passa o MESMO bioma no draw — o 1 hardcoded criava
> blend invertido fields→bioma que a mountains_front do v5.8 expôs

## L114-116 (em `M.run`, junto a `local topBarH = 80`)

> v10.4: castelo num PROGRESS específico (grow50 = 50%) pra provar
> crescimento MONOTÔNICO (sem encolher ao aproximar). segBase=0,
> camZ = SEGMENT_LEN * (NN/100). Bioma fixo 1 (fields).

## L131-132 (em `M.run`, junto a `local topBarH = 80`)

> v10: CERIMÔNIA DA PORTA congelada no meio (fase door, ~0.7) —
> valida frames da porta + boost do clamp em cena. "entry3" = bioma 3

## L152-156 (em `WorldRoad._entry`, junto a `local topBarH = os.getenv("STORE_NOTOPBAR") == "1" and 0 or 80`)

> A ENCRUZILHADA (v5): estrada bifurcada com 3 marcos + hover no 2.
> "fork2" captura o MEIO da convergência (braço escolhido virando
> a estrada central).
> STORE_NOTOPBAR=1: mundo em tela cheia (screenshot de loja; a faixa
> da top bar ficava preta sem o componente desenhado)

## L160 (em `WorldRoad._entry`, junto a `WorldRoad._blend = nil`)

> paleta PURA do bioma pedido

## L163-169 (em `WorldRoad._entry`, junto a `require("src.i18n.I18n").init()`)

> showFork trava em 3 braços (regra do jogo, não mexo nela), e são 5
> tipos de lugar: "forkb" mostra os outros dois pra conferência.
> "forkmini": o marco PRÓPRIO do mini-chefe (Out/2026) entre a
> batalha e o elite, pra conferir que os três leem diferente.
> rótulos pelo i18n (mesma fonte do jogo: MapManager.labelFor/
> descFor) — cravados em PT a captura saía em português em
> qualquer idioma (screenshots da loja: tools/store_art.py)

## L182-183 (em `out`, junto a `for _ = 1, 20 do`)

> alguns frames pra animIn assentar + registrar markBoxes (precisa
> de draw pra calcular as hitboxes)

## L190-193 (em `out`, junto a `if mode == "forkhover" and WorldRoad._fork then`)

> "forkhover": a LOJA com o mouse em cima — é o único jeito de ver a
> porta ABERTA (anim de estado indexada por _hoverK). Não dá pra
> forjar via f.hover: o update RECALCULA hover pelo mouse real a cada
> tick e o progresso decairia. Crava o progresso no fim, direto.

## L200-202 (em `out`, junto a `local fadeTicks = mode and tonumber(mode:match("^forkfade(%d+)$"))`)

> "forkfade<N>": escolhe o braço DO MEIO e captura N ticks (1/30 s)
> depois — o sumiço dos braços não escolhidos. Trava visual do bug
> "rastro liso sem grama onde os braços estavam" (Out/2026).

## L241-243 (em `out`, junto a `local topBarH = 80`)

> v9.7: CENÁRIO INTERATIVO — varre cliques fora dos marcos
> (árvores/postes/cercas/nuvens) e captura ~0.17s depois, no meio
> da mexidinha (pêndulo + folhinhas + squash de nuvem + rajada)

## L282-284 (em `out`, junto a `local EnemyRenderer = require("src.ui.EnemyRenderer")`)

> Reproduz a chegada no bioma 6 vindo do 5: blend de crossfade
> ATIVO + viagem + encounter (condição real de gameplay que os
> modos estáticos não exercitam)

## L305-309 (em `out`, junto a `local panelH = math.floor(height / 3)`)

> TROCA DE ATO (v10.3): 3 painéis do MESMO mundo — ANTES, no MEIO
> do cross-dissolve e DEPOIS. Valida o bug do dono ("ao trocar de
> ato, as antigas árvores do ato anterior começam aparecendo, só
> saem depois"): no painel 3 não pode sobrar nenhuma árvore/poste
> do bioma 1 (fields = árvore folhosa) no cenário do bioma 2.

## L320-321 (em `out`, junto a `WorldRoad.setBiome(2)`)

> painel 2: ~0.6s depois da troca — longe já virou bioma 2, perto
> ainda esvaindo (o escalonamento por profundidade em ação)

## L337-339 (em `out`, junto a `local topBarH = 80`)

> SEQUÊNCIA TEMPORAL (v7.4.x): 24 frames consecutivos com câmera
> PARADA — análise numérica de ondas/bandas coerentes no gramado
> (diff por linha frame a frame localiza artefato de movimento)

## L346-348 (em `out`, junto a `for _ = 1, 90 do`)

> warmup COM draw: o cache de fileiras (e o broto de entrada) só
> existe quando desenha — sem isso a captura mede o broto, não o
> regime (lição: a 1ª análise mediu a animação de entrada)

## L368-370 (em `out`, junto a `local LuminaireEngine = require("engine.LuminaireEngine")`)

> v9.1: PROVA do fogo animado das luminárias — converte os props
> do bioma em luminárias (ciclo pelo catálogo) e salva 2 instantes
> (lum_a/lum_b.png); diff das duas mostra SÓ chama/lâmpada mexendo

## L413-415 (em `kinds`, junto a `local topBarH = 80`)

> BENCHMARK de CPU (v7.4): 200 frames de VIAGEM simulada (camZ
> avançando = pior caso do tapete de grama). Mede update+draw sem
> present (CPU puro; GPU com 7k sprites pequenos é trivial).

## L443-444 (em `kinds`, junto a `local topBarH = 80`)

> VALIDAÇÃO DE VENTO (v7.1): mesmo bioma em 2 instantes (Δ1.1s) —
> diff das capturas prova que as lâminas do GrassField balançam.

## L470-472 (em `kinds`, junto a `local topBarH = 80`)

> TODOS os 6 biomas em UM processo (protocolo anti-wedge do driver:
> 1 contexto GL, não 6 — ver memory nvidia-driver-love-crash).
> Salva worldroad_full1.png .. worldroad_full6.png no save dir.

## L496-497 (em `kinds`, junto a `local topBarH = 80`)

> Um bioma em tela cheia (proporção real de gameplay, com topbar fake)
> "full" = bioma 1; "full5" = bioma 5, etc.

## L511-514 (em `kinds`, junto a `local bio = tonumber(mode:match("%d")) or 1`)

> v9.2: MARGEM TOTAL de postes — a beira do caminho INTEIRA (perto
> até a crista) forrada de postes nos dois lados, pra VALIDAR cada
> posição possível (flip do braço, glow, sombra, sumir na dobra).
> Sem monstro: foco na cobertura da margem. "postgate3" = bioma 3.

## L521-522 (em `kinds`, junto a `WorldRoad._props = {}`)

> força SÓ postes, DENSO: um par a cada 0.7 unidade, de perto (rel
> ~0.5) até além da crista (emersão) — cobre a margem inteira

## L540-541 (em `WorldRoad._props`, junto a `local bio = tonumber(mode:match("^enemy(%d)_"))`)

> Monstro PLANTADO na estrada do bioma: "enemy4_winter_monarch"
> (valida roster endless no cenário certo, com HUD desligado)

## L565 (em `WorldRoad._props`, junto a `local cx, cy = WorldRoad.getRoadAnchor(WorldRoad.BATTLE_REL,`)

> v9.2: inimigo via callback do painter (props próximos na frente)

## L586-587 (em `WorldRoad._props`, junto a `for _ = 1, 70 do`)

> avança até ~65% da viagem (inimigo já emergiu da crista e cresce).
> draw a cada tick pra _heroScreenPos existir e a poeira spawnar.

