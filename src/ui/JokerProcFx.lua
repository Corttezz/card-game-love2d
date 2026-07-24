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

    -- Anima a instância ATUAL do slot, não a referência capturada no impacto:
    -- rebuildJokerSlots recria instâncias (coleção+bancada) e animar o objeto
    -- órfão = joker parado na tela ("não se move" — bug Jul/2026).
    local joker = proc.joker
    local g = _G.game
    if g and g.jokerSlots and proc.slotIndex and g.jokerSlots[proc.slotIndex] then
        joker = g.jokerSlots[proc.slotIndex]
    end

    -- 1) PULINHO do joker (feel v2/v3.1): sobe com o lado direito levantando
    -- (rotação anti-horária) + CRESCE (swell) — "levantar de tamanho e dar
    -- uma mexidinha" (dono). Amplo e longo pra ler mesmo no meio do combate.
    if joker then
        -- v3.2: envelope chunky do hop/swell (estala-segura-cai-quica).
        if joker.hop_up then joker:hop_up(26, 0.45) end
        if joker.swell_up then joker:swell_up(0.30, 0.45) end
        if joker.juice_up then joker:juice_up(0.5, -0.22) end
    end
    -- DEBUG FEEL (temporário): prova em jogo real de que o tick achou e
    -- kickou a instância desenhada.
    pcall(love.filesystem.append, "feel_debug.log",
        ("[FEEL] JOKER-TICK slot=%s inst=%s viaLookup=%s hop_amt=%s\n"):format(
            tostring(proc.slotIndex), tostring(joker ~= nil),
            tostring(joker ~= proc.joker),
            tostring(joker and joker.juice and joker.juice.hop_amt)))

    -- 2) Som: ASSINATURA do joker se existir (audio/sfx/joker-sig/<id>.mp3,
    -- registrada como jokerSig_<id> no main.lua) — cada lendário soa como ele
    -- mesmo. Fallback: jokerTick genérico. Pitch sobe na cadeia nos dois casos.
    local sig = joker and joker.id and ("jokerSig_" .. joker.id)
    if sig and Sfx.has(sig) then
        Sfx.playWithVariation(sig, 1.0 + (ordinal - 1) * 0.05, 0.02)
    else
        Sfx.playWithVariation("jokerTick", 1.0 + (ordinal - 1) * 0.08, 0.03)
    end

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
