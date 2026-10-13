-- src/data/boss_cinematics.lua
-- CINEMÁTICAS DE CHEFE — dados puros (sem lógica), lidos por
-- src/ui/BossCinematic.lua.
--
-- Ordem fixada pelo dono (Out/2026): a porta do castelo abre (cerimônia já
-- existente do WorldRoad) → o SALÃO abre VAZIO (chefe ausente, HUD escondido)
-- → a entrada toca DENTRO do salão, com o cenário do próprio salão → nome do
-- chefe → HUD → luta. Na morte: colapso em câmera lenta, luz saindo dos
-- olhos, rajada de penas/corvos, dessaturação breve, o corpo fica no salão e
-- SÓ DEPOIS entram os espólios.
--
-- FORMATO: por chefe (spriteId), `intro` e `death` são LISTAS de passos. Cada
-- passo tem `kind` e `dur` (segundos que o passo ocupa antes do próximo; 0 =
-- dispara e segue). Efeitos com envelope próprio (gust, desat, slowmo)
-- continuam vivos depois que o passo passou — o `dur` é só o COMPASSO da
-- sequência. Tempos em segundos; posições em FRAÇÃO da arte do salão
-- (400×256) quando dizem `u`/`v`, ou em fração da altura do corpo quando dizem
-- `k`.
--
-- Passos de ENTRADA:
--   dark   { to }                 escurece/clareia o salão até `to` (0..1)
--   eyes   { u, v, blinks={t..}, size } dois olhos de brasa abrem no escuro,
--                                 piscam nos instantes da lista, apagam no fim
--   flyby  { from="left"|"right", v, ghosts, arc, land, lights }
--                                 o chefe VARRE o salão de um lado a outro
--                                 (cópias fantasmas atrás = rastro de
--                                 movimento, vento, penas, luminárias tremem);
--                                 `land=true` termina NO palco (pouso);
--                                 `lights` = valor de `dark` ao fim do passo
--   land   { shake, dust, crows } impacto: tremor, poeira, corvos espantados,
--                                 o chefe passa a ser desenhado pelo jogo
--   title  { }                    cartão com nome + epíteto (i18n
--                                 boss_cinematics.<id>.*)
--   hud    { }                    HUD/mão voltam (fim da entrada)
--
--   land   também aceita: `ring` (ice/frost/lava/spores/petal: cores da
--          onda de choque), `particle` (feather/shard/ember/spore/petal) +
--          `burst` (quantas), `sound` (impacto), `clip` (one-shot no palco;
--          default "land"), `crows` (0 = sem corvos nem penas assentando)
--
-- Passos de ENTRADA por ELEMENTO (os outros 5 chefes, Out/2026):
--   runes      { n }                      runas no chão acendem uma a uma;
--                                         o círculo fecha e fica até o `land`
--   rise       { clip, storm }            chefe SOBE do piso (recorte na linha
--                                         do chão, fagulhas do elemento, loop
--                                         `storm`); termina visível no palco
--   door_burst { u, v, debris, shake, lights }  portão do fundo estoura
--   firewall   { v, h, hold }             cortina de chamas em bandas; `hold`
--                                         = quanto fica depois do passo
--   chains     { }                        as correntes do salão (`bonds` do
--                                         chefe) nascem FROUXAS: ele entra
--                                         arrastando e elas esticam no `land`;
--                                         na luta arrebentam por `breakAt`
--   walk_in    { clip, stomp, sound }     chefe cresce do fundo (backY) até o
--                                         palco; `stomp` = tremor por passo
--   whiteout   { peak }                   nevasca (5 degraus, teto 0.8)
--   silhouette { clip, far, strike, strikeClip, hitDelay }
--                                         vulto preto SÓLIDO com borda fria
--                                         dentro do branco: longe e pequeno
--                                         (`far`), cresce andando; em `strike`
--                                         bate o cajado ainda em silhueta
--   land.clip=false / land.hit=false      sem clip / sem impacto de tela
--   settle     { }                        nevasca cai; chefe visível
--   heartbeat  { rate, boost, hold }      pulses do salão aceleram + vinheta
--   roots      { n, u, v }                raízes rastejam do ponto (u,v)
--              { n, from="walls", grasp } ...ou descem das bocas pintadas do
--                                         salão (InteriorFX rootMouths) e
--                                         AGARRAM o corpo; retraem no `land`
--   assemble   { block }                  o corpo se MONTA de blocos do próprio
--                                         sprite puxados do chão, pés → cabeça
--   land.cracks = true                    o chão racha em volta do pé
--   eclipse    { u, v, to }               disco cobre a abertura + coroa
--   descend    { clip, u, v, backlit, lights }  chefe desce de (u,v) ao palco
--   RAINHA v2 (chefe final, frente rainha-eclipse, Out/2026):
--   omen       { to, steps }              pressentimento: a luz do vão morre
--                                         em degraus, o eclipse vira íris, a
--                                         coroa sangra, cinzas caem
--   unveil     { clip, u, v }             manifestação: olhos demais no escuro,
--                                         silhueta em casulo que se abre em
--                                         contraluz, sombra maior que ela
--   coronation { clip, cadence }          cartão único: letras uma a uma com
--                                         sino, halos quebrados, stinger
--
-- Passos de MORTE:
--   slowmo { scale, release }     EnemyRenderer em câmera lenta por `dur`,
--                                 volta ao normal em `release` s
--   burst  { n|feathers, crows, particle, sound }  rajada a partir do corpo
--   desat  { peak, rise, fall }   dessaturação da cena: sobe em `rise`,
--                                 segura, cai em `fall`
--   lava   { }                    poça de lava cresce sob o corpo (tirano)
--   crumble { delay, roots, block } raízes agarram e soltam; o corpo desaba
--                                 em pedaços que viram monte e esporos (colosso)
--   dawn   { u, v }               luz morna volta na abertura (rainha)
--   hold   { }                    o corpo fica no salão; espólios esperam
--
-- Todo chefe tem `palette` (body/glow/ember/flash/ghost/rim/particle/
-- particle2): névoa, brilhos, flash e partículas usam ela. O runner avisa
-- `kind` desconhecido e segue (fallback silencioso é proibido). Chefe SEM
-- roteiro aqui ganha a entrada genérica (BossCinematic.GENERIC).
--
-- `reduced` = versão curta pra reducedMotion (mesma linguagem, sem varrer).

return {
    -- ATO 1 — Rei da Carniça: corvo-rei que paira. Olhos de brasa acendem
    -- no vão âmbar atrás do trono (pulses[1] do salão 1: x 182..218,
    -- y 78..178 da arte), três passagens em rasante, pouso no palco.
    carrion_king = {
        -- v3 (dono, ao vivo): olhos maiores que abrem devagar e acompanham,
        -- passagens cada vez mais PERTO (longe → colada na câmera → pouso),
        -- clips PixelLab `dive`/`land`/`roar` quando instalados, som em tudo.
        intro = {
            { kind = "dark",  dur = 0.45, to = 0.86 },
            { kind = "eyes",  dur = 2.60, u = 0.50, v = 0.40,
              blinks = { 1.00, 1.75 }, size = 0.052, track = true },
            { kind = "flyby", dur = 0.46, from = "right", v = 0.36,
              ghosts = 4, arc = 0.04, scale = 0.80, caw = true },
            { kind = "flyby", dur = 0.38, from = "left",  v = 0.58,
              ghosts = 6, arc = -0.03, scale = 1.55 },
            { kind = "flyby", dur = 0.72, from = "right", v = 0.44,
              ghosts = 3, land = true, lights = 0.22 },
            { kind = "land",  dur = 0.60, shake = 16, dust = 18, crows = 7, clip = "land" },
            { kind = "title", dur = 2.40, clip = "roar" },
            { kind = "hud",   dur = 0 },
        },
        -- reducedMotion: olhos (uma piscada), um rasante curto que pousa,
        -- impacto sem tremor forte, cartão mais curto.
        introReduced = {
            { kind = "dark",  dur = 0.30, to = 0.80 },
            { kind = "eyes",  dur = 1.20, u = 0.50, v = 0.40,
              blinks = { 0.70 }, size = 0.052, track = false },
            { kind = "flyby", dur = 0.45, from = "right", v = 0.46,
              ghosts = 0, land = true, lights = 0.15 },
            { kind = "land",  dur = 0.40, shake = 5, dust = 8, crows = 3 },
            { kind = "title", dur = 1.60 },
            { kind = "hud",   dur = 0 },
        },
        death = {
            { kind = "burst",  dur = 0,    feathers = 24, crows = 5 },
            { kind = "desat",  dur = 0,    peak = 0.72, rise = 0.45, fall = 1.40 },
            { kind = "slowmo", dur = 1.60, scale = 0.32, release = 0.35 },
            { kind = "hold",   dur = 1.20 },
        },
        deathReduced = {
            { kind = "burst",  dur = 0,    feathers = 10, crows = 2 },
            { kind = "desat",  dur = 0,    peak = 0.55, rise = 0.30, fall = 0.80 },
            { kind = "hold",   dur = 0.90 },
        },
    },

    -- ATO 2 — Lich da Torre (flutua): o salão GELA. O círculo rúnico do
    -- chão acende runa por runa (névoa branco-azul sobe), e o lich SOBE do
    -- piso dentro de uma tempestade de geada, cajado por último (clip
    -- `rise`), recortado na linha do chão. Impacto = o círculo completa +
    -- onda de gelo. Morte: se desfaz em geada (lascas) e esfria a cena.
    tower_lich = {
        palette = {
            body = { 0.08, 0.12, 0.26 }, glow = { 0.45, 0.80, 1.00 }, ember = { 0.82, 0.95, 1.00 },
            flash = { 0.70, 0.88, 1.00 }, ghost = { 0.50, 0.70, 1.00 }, rim = { 0.60, 0.85, 1.00 },
            particle = { 0.55, 0.70, 0.86 }, particle2 = { 0.86, 0.96, 1.00 },
        },
        intro = {
            { kind = "dark",  dur = 0.80, to = 0.86 },
            { kind = "runes", dur = 1.60, n = 5 },
            { kind = "rise",  dur = 1.40, from = "floor", storm = "bossFrostStorm", clip = "rise" },
            { kind = "land",  dur = 0.55, shake = 8, dust = 6, crows = 0, ring = "ice",
              particle = "shard", burst = 16, sound = "bossIceCrackle" },
            { kind = "title", dur = 2.20, clip = "roar" },
            { kind = "hud",   dur = 0 },
        },
        introReduced = {
            { kind = "dark",  dur = 0.30, to = 0.80 },
            { kind = "runes", dur = 0.80, n = 5 },
            { kind = "rise",  dur = 0.70, from = "floor", clip = "rise" },
            { kind = "land",  dur = 0.40, shake = 3, dust = 3, crows = 0, ring = "ice",
              particle = "shard", burst = 6, sound = "bossIceCrackle" },
            { kind = "title", dur = 1.50 },
            { kind = "hud",   dur = 0 },
        },
        death = {
            { kind = "burst",  dur = 0,    n = 30, particle = "shard", sound = "bossFrostShatter" },
            { kind = "desat",  dur = 0,    peak = 0.60, rise = 0.40, fall = 1.20 },
            { kind = "slowmo", dur = 1.40, scale = 0.35, release = 0.35 },
            { kind = "hold",   dur = 1.10 },
        },
        deathReduced = {
            { kind = "burst",  dur = 0,    n = 12, particle = "shard", sound = "bossFrostShatter" },
            { kind = "desat",  dur = 0,    peak = 0.45, rise = 0.30, fall = 0.80 },
            { kind = "hold",   dur = 0.90 },
        },
    },

    -- ATO 3 — Tirano do Abismo (pisa): o portão-caveira do fundo ESTOURA
    -- (lascas, brasas, flash), uma PAREDE DE FOGO INFERNAL sobe atrás do
    -- palco, correntes caem das paredes e ele ATRAVESSA o fogo andando (clip
    -- `stride`, cresce do fundo até o palco, o chão treme a cada passo).
    -- Impacto = pisada: tremor forte, onda de lava. Morte: afunda na lava
    -- (poça de brasa cresce sob o corpo, bolhas, câmera lenta quente).
    abyss_tyrant = {
        palette = {
            body = { 0.16, 0.06, 0.04 }, glow = { 1.00, 0.45, 0.12 }, ember = { 1.00, 0.72, 0.25 },
            flash = { 1.00, 0.55, 0.20 }, ghost = { 0.90, 0.40, 0.20 }, rim = { 1.00, 0.50, 0.20 },
            particle = { 0.35, 0.12, 0.06 }, particle2 = { 1.00, 0.60, 0.20 },
        },
        -- CORRENTES DO SALÃO (v2, Out/2026; dono: "as correntes saem do céu,
        -- poderiam ser parte da fase, ligadas a ele"): cada corrente vai de
        -- uma âncora PINTADA do castle_hall_3 (InteriorFX.HALLS[3].chainAnchors)
        -- a um ponto do corpo dele (grip = fração do canvas do sprite: pulsos
        -- e pescoço). Ele entra arrastando, elas esticam no pouso; na luta
        -- arrebentam uma a uma nos limiares de vida (`breakAt`; "enraged" =
        -- o ENFURECIDO de 30% que o jogo já tem) e, todas rompidas, ele está
        -- solto. Só leitura: nenhum número de dano/vida muda.
        bonds = {
            { anchor = "pillarL", grip = { 0.19, 0.73 }, breakAt = 0.72, front = true },
            { anchor = "pillarR", grip = { 0.81, 0.73 }, breakAt = 0.52, front = true },
            { anchor = "hornL",   grip = { 0.47, 0.34 }, breakAt = 0.38, front = false },
            { anchor = "hornR",   grip = { 0.53, 0.34 }, breakAt = "enraged", front = false },
        },
        intro = {
            { kind = "dark",       dur = 0.70, to = 0.86 },
            { kind = "door_burst", dur = 0.50, u = 0.50, v = 0.46, debris = 18, shake = 18, lights = 0.40 },
            { kind = "firewall",   dur = 1.20, v = 0.58, h = 0.34, hold = 2.30 },
            { kind = "chains",     dur = 0.20 },
            { kind = "walk_in",    dur = 1.80, from = "back", clip = "stride", stomp = 0.55 },
            { kind = "land",       dur = 0.60, shake = 18, dust = 18, crows = 0, ring = "lava",
              particle = "ember", burst = 20 },
            { kind = "title",      dur = 2.30, clip = "roar" },
            { kind = "hud",        dur = 0 },
        },
        introReduced = {
            { kind = "dark",       dur = 0.30, to = 0.80 },
            { kind = "door_burst", dur = 0.40, u = 0.50, v = 0.46, debris = 6, shake = 5, lights = 0.40 },
            { kind = "firewall",   dur = 0.60, v = 0.58, h = 0.30, hold = 1.00 },
            { kind = "chains",     dur = 0.10 },
            { kind = "walk_in",    dur = 0.90, from = "back", clip = "stride" },
            { kind = "land",       dur = 0.40, shake = 4, dust = 6, crows = 0, ring = "lava",
              particle = "ember", burst = 8 },
            { kind = "title",      dur = 1.50 },
            { kind = "hud",        dur = 0 },
        },
        death = {
            { kind = "burst",  dur = 0,    n = 24, particle = "ember", sound = "bossLavaImplosion" },
            { kind = "lava",   dur = 0 },
            { kind = "desat",  dur = 0,    peak = 0.45, rise = 0.50, fall = 1.20 },
            { kind = "slowmo", dur = 1.50, scale = 0.35, release = 0.35 },
            { kind = "hold",   dur = 1.20 },
        },
        deathReduced = {
            { kind = "burst",  dur = 0,    n = 10, particle = "ember", sound = "bossLavaImplosion" },
            { kind = "lava",   dur = 0 },
            { kind = "desat",  dur = 0,    peak = 0.35, rise = 0.30, fall = 0.80 },
            { kind = "hold",   dur = 0.90 },
        },
    },

    -- ATO 4 — Monarca do Inverno (pisa): NEVASCA. O salão vira branco em
    -- 3 degraus de dither, o vento uiva, os braseiros azuis quase apagam; a
    -- silhueta escura do monarca aparece DENTRO do branco, cada vez mais
    -- nítida, e a nevasca assenta revelando ele já no palco. Impacto = o
    -- cajado bate no chão (clip `roar`): cristais erguem do piso, onda de
    -- geada. Morte: estilhaça em cristais.
    winter_monarch = {
        palette = {
            body = { 0.10, 0.16, 0.28 }, glow = { 0.55, 0.80, 1.00 }, ember = { 0.85, 0.95, 1.00 },
            flash = { 0.88, 0.95, 1.00 }, ghost = { 0.60, 0.80, 1.00 }, rim = { 0.70, 0.90, 1.00 },
            particle = { 0.60, 0.75, 0.90 }, particle2 = { 0.92, 0.97, 1.00 },
        },
        -- v2 (Out/2026, dono: "a silhueta na nevasca poderia durar mais e
        -- ficar mais marcada"): a fase de silhueta vai de 1,2 s pra 3,8 s —
        -- vulto preto SÓLIDO com borda fria de 1 px, longe e pequeno no
        -- branco (`far`), cresce andando (clip `walk`), o cajado bate uma
        -- vez AINDA em silhueta (`strike` + clip `roar`: flash frio, onda de
        -- geada, lascas) e só então a neve assenta e a cor entra (`settle`).
        -- O `land` que vem depois é a revelação (sem segundo golpe: clip e
        -- impacto de tela desligados).
        intro = {
            { kind = "dark",       dur = 0.30, to = 0.50 },
            { kind = "whiteout",   dur = 1.40, peak = 0.90 },
            { kind = "silhouette", dur = 3.80, clip = "walk", far = 0.38,
              strike = 2.75, strikeClip = "roar", hitDelay = 0.35 },
            { kind = "settle",     dur = 0.90 },
            { kind = "land",       dur = 0.55, shake = 5, dust = 6, crows = 0, ring = "frost",
              clip = false, hit = false, particle = "shard", burst = 8, sound = "bossIceCrackle" },
            { kind = "title",      dur = 2.20 },
            { kind = "hud",        dur = 0 },
        },
        introReduced = {
            { kind = "dark",       dur = 0.30, to = 0.45 },
            { kind = "whiteout",   dur = 0.80, peak = 0.70 },
            { kind = "silhouette", dur = 1.50, clip = "walk", far = 0.5,
              strike = 1.00, strikeClip = "roar", hitDelay = 0.25 },
            { kind = "settle",     dur = 0.50 },
            { kind = "land",       dur = 0.40, shake = 3, dust = 4, crows = 0, ring = "frost",
              clip = false, hit = false, particle = "shard", burst = 6, sound = "bossIceCrackle" },
            { kind = "title",      dur = 1.50 },
            { kind = "hud",        dur = 0 },
        },
        death = {
            { kind = "burst",  dur = 0,    n = 34, particle = "shard", sound = "bossFrostShatter" },
            { kind = "desat",  dur = 0,    peak = 0.65, rise = 0.40, fall = 1.20 },
            { kind = "slowmo", dur = 1.40, scale = 0.35, release = 0.35 },
            { kind = "hold",   dur = 1.10 },
        },
        deathReduced = {
            { kind = "burst",  dur = 0,    n = 12, particle = "shard", sound = "bossFrostShatter" },
            { kind = "desat",  dur = 0,    peak = 0.45, rise = 0.30, fall = 0.80 },
            { kind = "hold",   dur = 0.90 },
        },
    },

    -- ATO 5 — Colosso Pútrido (pisa). v2 (Out/2026, dono: "do nada
    -- surgindo, não fez sentido"): o SALÃO É ELE. O coração de raízes do
    -- fundo acelera (pulses do salão 5 + vinheta por batida), raízes descem
    -- das PAREDES e do teto (`roots from=walls`, bocas em InteriorFX.HALLS[5]
    -- .rootMouths) e agarram o palco; ossos e entulho do chão são puxados e
    -- se juntam formando a silhueta DE BAIXO PRA CIMA (`assemble`: blocos
    -- do próprio sprite, pés → tronco → cabeça); as raízes se retraem, ele
    -- ergue a cabeça (clip `roar` no `land`) e o chão racha em volta
    -- (`land.cracks`). Morte = o processo ao contrário (`crumble`): raízes
    -- agarram e soltam, o corpo desaba em pedaços e esporos.
    rot_colossus = {
        palette = {
            body = { 0.08, 0.14, 0.08 }, glow = { 0.45, 0.85, 0.35 }, ember = { 0.80, 0.95, 0.45 },
            flash = { 0.55, 0.85, 0.35 }, ghost = { 0.40, 0.70, 0.30 }, rim = { 0.50, 0.90, 0.40 },
            particle = { 0.25, 0.40, 0.18 }, particle2 = { 0.65, 0.90, 0.45 },
        },
        intro = {
            { kind = "dark",      dur = 0.60, to = 0.70 },
            { kind = "heartbeat", dur = 1.60, rate = 2.4, boost = 2.2, hold = 4.2 },
            { kind = "roots",     dur = 1.10, n = 7, from = "walls", grasp = true },
            { kind = "assemble",  dur = 2.60, block = 5 },
            { kind = "land",      dur = 0.70, shake = 16, dust = 20, crows = 0, ring = "spores",
              particle = "spore", burst = 22, clip = "roar", cracks = true,
              sound = "colossusCrack" },
            { kind = "title",     dur = 2.30, clip = false },
            { kind = "hud",       dur = 0 },
        },
        introReduced = {
            { kind = "dark",      dur = 0.30, to = 0.60 },
            { kind = "heartbeat", dur = 0.80, rate = 2.4, boost = 1.8, hold = 1.4 },
            { kind = "roots",     dur = 0.50, n = 5, from = "walls", grasp = true },
            { kind = "assemble",  dur = 1.20, block = 6 },
            { kind = "land",      dur = 0.40, shake = 4, dust = 6, crows = 0, ring = "spores",
              particle = "spore", burst = 8, clip = "roar", cracks = true,
              sound = "colossusCrack" },
            { kind = "title",     dur = 1.50, clip = false },
            { kind = "hud",       dur = 0 },
        },
        -- morte: sem slowmo do EnemyRenderer — o desabamento em pedaços É a
        -- câmera lenta (o chefe real fica escondido e volta sob o monte)
        death = {
            { kind = "desat",   dur = 0,    peak = 0.50, rise = 0.45, fall = 1.30 },
            { kind = "burst",   dur = 0,    n = 14, particle = "spore", sound = "bossSporeCollapse" },
            { kind = "crumble", dur = 3.00, delay = 0.70, roots = 6, block = 5 },
            { kind = "hold",    dur = 1.10 },
        },
        deathReduced = {
            { kind = "desat",   dur = 0,    peak = 0.35, rise = 0.30, fall = 0.80 },
            { kind = "burst",   dur = 0,    n = 8, particle = "spore", sound = "bossSporeCollapse" },
            { kind = "crumble", dur = 1.60, delay = 0.30, roots = 4, block = 6 },
            { kind = "hold",    dur = 0.90 },
        },
    },

    -- ATO 6 — Rainha do Eclipse (flutua), o CHEFE FINAL — v2 (Out/2026,
    -- frente rainha-eclipse; dono: "algo mais macabro, mais estiloso,
    -- entradas mais marcantes"). Três atos próprios, ~14 s:
    --   1. PRESSENTIMENTO (`omen`): o salão muda antes de ela existir — a luz
    --      do vão morre em 4 degraus (tique por degrau, silêncio entre eles),
    --      o eclipse pintado vira uma ÍRIS que olha o jogador, a coroa sangra,
    --      cinzas começam a cair, névoa magenta.
    --   2. MANIFESTAÇÃO (`unveil` + `descend`): olhos demais acendem no escuro
    --      do vão, a silhueta em casulo de asas (clip `unveil`) se abre em
    --      contraluz com a sombra no mármore maior que ela e um halo quebrado;
    --      o `descend` a traz ao palco (silhueta → cor cheia).
    --   3. COROAÇÃO (`coronation`): cartão único — letras uma a uma com sino,
    --      halos quebrados ladeando, stinger coral na última letra.
    -- LUTA: BossCinematic observa a fase do kit (src/data/enemies.lua, nunca
    -- alterado) e fecha o eclipse do salão 6 (InteriorFX.setEclipse) + halo
    -- quebrado nela. MORTE: cinzas que sobem, `dawn` v2 (a luz chega em
    -- degraus pelo vão, o disco abre num crescente, o mármore acende) e a
    -- voz dela se apagando (`bossEclipseFade`); o corpo fica no salão.
    -- Música própria: `musicBossEclipse` (MusicDirector, só no salão dela).
    eclipse_queen = {
        palette = {
            body = { 0.14, 0.04, 0.18 }, glow = { 0.85, 0.25, 0.75 }, ember = { 1.00, 0.55, 0.85 },
            flash = { 0.95, 0.45, 0.90 }, ghost = { 0.70, 0.30, 0.80 }, rim = { 1.00, 0.50, 0.90 },
            particle = { 0.55, 0.15, 0.45 }, particle2 = { 1.00, 0.60, 0.85 },
        },
        intro = {
            { kind = "dark",       dur = 0.60, to = 0.45 },
            { kind = "omen",       dur = 3.60, to = 0.82, steps = 4 },
            { kind = "unveil",     dur = 3.20, u = 0.50, v = 0.30, clip = "unveil" },
            { kind = "descend",    dur = 1.70, from = "opening", u = 0.50, v = 0.30, backlit = true,
              clip = "descend", lights = 0.30 },
            { kind = "land",       dur = 0.60, shake = 9, dust = 0, crows = 0, ring = "petal",
              particle = "petal", burst = 22, sound = "bossFeathersSettle" },
            { kind = "coronation", dur = 4.40, clip = "crown", cadence = 0.085 },
            { kind = "hud",        dur = 0 },
        },
        -- reducedMotion: os três atos continuam (toda a informação), curtos:
        -- degraus sem íris móvel, casulo sem tremor, letras em cascata rápida.
        introReduced = {
            { kind = "dark",       dur = 0.30, to = 0.45 },
            { kind = "omen",       dur = 1.40, to = 0.80, steps = 4 },
            { kind = "unveil",     dur = 1.20, u = 0.50, v = 0.30, clip = "unveil" },
            { kind = "descend",    dur = 0.80, from = "opening", u = 0.50, v = 0.30, backlit = true,
              clip = "descend", lights = 0.30 },
            { kind = "land",       dur = 0.40, shake = 3, dust = 0, crows = 0, ring = "petal",
              particle = "petal", burst = 6, sound = "bossFeathersSettle" },
            { kind = "coronation", dur = 2.60, clip = "crown" },
            { kind = "hud",        dur = 0 },
        },
        death = {
            { kind = "burst",  dur = 0,    n = 34, particle = "ash", sound = "bossEclipseBreak" },
            { kind = "dawn",   dur = 0,    u = 0.50, v = 0.227 },
            { kind = "desat",  dur = 0,    peak = 0.55, rise = 0.45, fall = 1.40 },
            { kind = "slowmo", dur = 1.70, scale = 0.32, release = 0.35 },
            { kind = "hold",   dur = 1.80 },
        },
        deathReduced = {
            { kind = "burst",  dur = 0,    n = 14, particle = "ash", sound = "bossEclipseBreak" },
            { kind = "dawn",   dur = 0,    u = 0.50, v = 0.227 },
            { kind = "desat",  dur = 0,    peak = 0.40, rise = 0.30, fall = 0.80 },
            { kind = "hold",   dur = 1.10 },
        },
    },
}
