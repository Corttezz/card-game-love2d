-- src/data/intent_fog.lua
-- ============================================================================
-- NÉVOA DE INTENÇÃO — quanto o clima do bioma esconde do intent do inimigo
-- ============================================================================
-- DADO PURO (sem lógica). Quem lê: src/systems/IntentVisibility.lua.
--
-- Ideia do dono (Out/2026): nos biomas do fim da jornada a nevasca / a bruma
-- do crepúsculo ESCONDE parte do que o inimigo anuncia. O jogador continua
-- vendo o TIPO do golpe (ataque, defesa, fortalecer) mas não o NÚMERO; com a
-- névoa mais fechada nem o tipo. O intent continua CONGELADO no anúncio
-- (CLAUDE.md §6): a névoa só muda o que o HUD mostra, nunca o golpe.
--
-- Chave = id do bioma em src/data/biomes.lua. Bioma ausente = céu limpo
-- (atos 1-3 ficam exatamente como eram). Tudo aqui é afinável.
--
--   base    densidade da névoa no 1º andar do bioma (0..1)
--   peak    densidade na porta do castelo (a MESMA curva do clima na tela:
--           WeatherEngine.intensityFor(progress) — densidade sobe conforme
--           a estrada chega ao castelo, como a neve engrossa)
--   heavy   fração dos turnos escondidos em que até o TIPO some ("?")
--   hall    densidade fixa dentro do salão do chefe (bruma do interior)
--   color   cor do véu desenhado sobre o intent (tinta do bioma)
--
-- A rolagem é POR TURNO, no anúncio do intent, no stream "misc" do Rng:
--   r < densidade        → turno encoberto (type_only, ou hidden se r < densidade × heavy)
--   senão                → clareira: o número aparece inteiro
-- O stream "misc" é de propósito: usar "enemy" deslocaria a sequência de
-- golpes dos atos 4-6 em toda seed já medida pelo piloto.
-- ============================================================================

return {
    biomes = {
        -- Ato 4 — Geleira: nevasca. É o bioma que motivou a mecânica.
        frost = { base = 0.35, peak = 0.80, heavy = 0.40, hall = 0.55,
                  color = { 0.86, 0.92, 1.00 } },
        -- Ato 6 — Crepúsculo: bruma violeta, mais rala que a neve.
        dusk  = { base = 0.25, peak = 0.60, heavy = 0.25, hall = 0.45,
                  color = { 0.58, 0.46, 0.66 } },
    },

    -- Quanto a névoa oculta EMPURRA o clima na tela (WeatherEngine): o
    -- estado decide e o mundo acompanha — assim a nevasca fecha quando o
    -- número some e abre na clareira, e a seed continua reproduzindo a luta
    -- (o relógio do clima é visual, não entra na regra).
    worldBoost = { type_only = 0.45, hidden = 0.75 },
}
