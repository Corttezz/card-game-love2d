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
}
