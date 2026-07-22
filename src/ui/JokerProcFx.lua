-- src/ui/JokerProcFx.lua
-- FX de "proc" de joker estilo Balatro (game feel v1, Jul/2026): quando uma
-- carta jogada dispara um joker ativo, o SLOT dele reage — juice na carta do
-- joker, popup flutuante com a contribuição ("×2", "+3", "+4 HP") e um tick
-- sonoro curto com pitch crescente na cadeia (1º joker grave, 3º agudo).
--
-- Quem AGENDA os ticks em sequência é o CombatSequence (via EventManager,
-- espaçados por PROC_TICK). Este módulo só executa UM tick.
--
-- proc = { slotIndex = i, joker = <instância>, label = "×2", kind = "mult" }
--
-- Headless-safe: Sfx é no-op; posição do slot vem por pcall no GameplayScene
-- (não carregado em tools) — sem tela, só o juice no objeto acontece.

local Sfx = require("src.systems.Sfx")

local JokerProcFx = {}

-- Executa o tick visual/sonoro do proc `ordinal`-ésimo da cadeia.
function JokerProcFx.tick(proc, ordinal)
    if not proc then return end
    ordinal = ordinal or 1

    -- 1) Juice na carta do joker (o slot "pula" — relevo do Balatro).
    local joker = proc.joker
    if joker and joker.juice_up then
        joker:juice_up(0.6, 0.2)
    end

    -- 2) Tick sonoro: pitch sobe a cada joker da cadeia (cascata satisfatória).
    Sfx.playWithVariation("jokerTick", 1.0 + (ordinal - 1) * 0.08, 0.03)

    -- 3) Popup + faísca no slot (precisa da geometria da cena de gameplay).
    local ok, GameplayScene = pcall(require, "src.scenes.GameplayScene")
    if not ok or not GameplayScene.jokerSlotCenter then return end
    local x, y = GameplayScene.jokerSlotCenter(proc.slotIndex or 1)
    if not x then return end

    local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
    if okFT then
        FloatingText.spawn(proc.label or "!", x, y - 12, {
            kind = proc.kind or "mult",
            fontSize = 16,
            lift = 30,
            hold = 0.4,
        })
    end

    local okPS, ParticleSystem = pcall(require, "src.systems.ParticleSystem")
    if okPS and ParticleSystem.Presets then
        ParticleSystem.Presets.JOKER_ACTIVATED(x, y)
    end
end

return JokerProcFx
