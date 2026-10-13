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
-- Passos de MORTE:
--   slowmo { scale, release }     EnemyRenderer em câmera lenta por `dur`,
--                                 volta ao normal em `release` s
--   burst  { feathers, crows }    rajada a partir do corpo
--   desat  { peak, rise, fall }   dessaturação da cena: sobe em `rise`,
--                                 segura, cai em `fall`
--   hold   { }                    o corpo fica no salão; espólios esperam
--
-- Chefes APOIADOS (atos 3, 4, 5) pedem outra entrada (porta estourando,
-- subir do chão) — o formato aceita `kind`s novos; o runner avisa por
-- `kind` desconhecido e segue (fallback silencioso é proibido). Hoje só o
-- rei-carniça tem roteiro; chefe sem entrada aqui luta como antes.
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
        intro = {
            { kind = "dark",       dur = 0.70, to = 0.86 },
            { kind = "door_burst", dur = 0.50, u = 0.50, v = 0.46, debris = 18, shake = 18, lights = 0.40 },
            { kind = "firewall",   dur = 1.20, v = 0.58, h = 0.34, hold = 2.30 },
            { kind = "chains",     dur = 0.20, n = 4 },
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
        intro = {
            { kind = "dark",       dur = 0.30, to = 0.50 },
            { kind = "whiteout",   dur = 1.60, peak = 0.90 },
            { kind = "silhouette", dur = 1.20, clip = "walk" },
            { kind = "settle",     dur = 0.80 },
            { kind = "land",       dur = 0.60, shake = 10, dust = 8, crows = 0, ring = "frost",
              clip = "roar", particle = "shard", burst = 16, sound = "bossIceCrackle" },
            { kind = "title",      dur = 2.20 },
            { kind = "hud",        dur = 0 },
        },
        introReduced = {
            { kind = "dark",       dur = 0.30, to = 0.45 },
            { kind = "whiteout",   dur = 0.80, peak = 0.70 },
            { kind = "settle",     dur = 0.50 },
            { kind = "land",       dur = 0.40, shake = 3, dust = 4, crows = 0, ring = "frost",
              clip = "roar", particle = "shard", burst = 6, sound = "bossIceCrackle" },
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

    -- ATO 5 — Colosso Pútrido (pisa): o coração de raízes do fundo BATE
    -- mais forte e mais rápido (pulses do salão 5 + vinheta na cor por
    -- batida), raízes rastejam da boca do túnel pelo chão, e o colosso
    -- EMERGE do túnel (clip `emerge`) vindo do fundo até o palco, arrastando
    -- os pés (chão treme a cada passo). Impacto = último passo: esporos
    -- explodem. Morte: desaba e vira esporos (flutuam).
    rot_colossus = {
        palette = {
            body = { 0.08, 0.14, 0.08 }, glow = { 0.45, 0.85, 0.35 }, ember = { 0.80, 0.95, 0.45 },
            flash = { 0.55, 0.85, 0.35 }, ghost = { 0.40, 0.70, 0.30 }, rim = { 0.50, 0.90, 0.40 },
            particle = { 0.25, 0.40, 0.18 }, particle2 = { 0.65, 0.90, 0.45 },
        },
        intro = {
            { kind = "dark",      dur = 0.60, to = 0.70 },
            { kind = "heartbeat", dur = 1.80, rate = 2.4, boost = 2.2, hold = 2.6 },
            { kind = "roots",     dur = 1.20, n = 6, u = 0.50, v = 0.62 },
            { kind = "walk_in",   dur = 2.00, from = "back", clip = "emerge", stomp = 0.50,
              sound = "bossEmergeTear" },
            { kind = "land",      dur = 0.60, shake = 16, dust = 20, crows = 0, ring = "spores",
              particle = "spore", burst = 22 },
            { kind = "title",     dur = 2.30, clip = "roar" },
            { kind = "hud",       dur = 0 },
        },
        introReduced = {
            { kind = "dark",      dur = 0.30, to = 0.60 },
            { kind = "heartbeat", dur = 0.80, rate = 2.4, boost = 1.8 },
            { kind = "walk_in",   dur = 0.90, from = "back", clip = "emerge", sound = "bossEmergeTear" },
            { kind = "land",      dur = 0.40, shake = 4, dust = 6, crows = 0, ring = "spores",
              particle = "spore", burst = 8 },
            { kind = "title",     dur = 1.50 },
            { kind = "hud",       dur = 0 },
        },
        death = {
            { kind = "burst",  dur = 0,    n = 30, particle = "spore", sound = "bossSporeCollapse" },
            { kind = "desat",  dur = 0,    peak = 0.50, rise = 0.45, fall = 1.30 },
            { kind = "slowmo", dur = 1.50, scale = 0.35, release = 0.35 },
            { kind = "hold",   dur = 1.20 },
        },
        deathReduced = {
            { kind = "burst",  dur = 0,    n = 12, particle = "spore", sound = "bossSporeCollapse" },
            { kind = "desat",  dur = 0,    peak = 0.35, rise = 0.30, fall = 0.80 },
            { kind = "hold",   dur = 0.90 },
        },
    },
}
