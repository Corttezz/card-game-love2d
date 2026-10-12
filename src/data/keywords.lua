-- src/data/keywords.lua
-- Glossário de keywords (F5 do gameplay-overhaul-v1): detectadas na
-- descrição da carta e explicadas no tooltip (CardInfoDisplay) — resolve
-- "orbs jamais explicados" e ensina as regras novas (bloqueio zera,
-- exaurir remove da batalha). Ordem = prioridade (máx 3 por tooltip).
--
-- Out/2026: o glossário era PORTUGUÊS em todos os idiomas (nome/texto
-- cravados aqui). Agora este arquivo guarda só a ESTRUTURA — id, grupo e as
-- palavras que disparam o verbete, POR LOCALE, do jeito que aparecem na
-- descrição TRADUZIDA (minúsculas, com acento). Nome e texto exibidos vêm do
-- i18n: `keyword.<id>.name` / `keyword.<id>.text` nos 5 locales.
-- Trava: love . test_one test_locale_accents (cada verbete casa a própria
-- carta-exemplo em cada idioma).

-- Contexto de orbe: "fogo" sozinho não é orbe de Fogo — a descrição precisa
-- falar de canalizar/evocar/orbe/valor junto.
local ORB_CTX = {
    pt_BR = { "orbe", "canaliza", "evoca", "valor" },
    en    = { "orb", "channel", "evoke", "value" },
    es    = { "orbe", "canaliza", "evoca", "valor" },
    fr    = { "orbe", "canalise", "évoque", "valeur" },
    de    = { "orb", "kanalisiere", "löse", "wert" },
}

return {
    -- ===== ORBES: verbete POR ELEMENTO (feedback Jul/2026: "explicacao
    -- apenas da orbe que tem relacao com a carta, nao de todas"). Todos no
    -- group="orb": o primeiro que casar EXCLUI os demais do grupo — carta
    -- de Fogo explica so o orbe de Fogo; o generico e fallback pra cartas
    -- de orbe sem elemento (Evocar, Dualcast). Semantica canonica:
    -- EffectSystem.orbPulseValue/orbEvokeValue (pulso no fim do SEU turno,
    -- evocar = efeito cheio).
    { id = "orb_lightning", group = "orb", requires = ORB_CTX,
      match = { pt_BR = { "raio" }, en = { "lightning" }, es = { "rayo" },
                fr = { "foudre" }, de = { "blitz" } } },
    { id = "orb_ice", group = "orb", requires = ORB_CTX,
      match = { pt_BR = { "gelo" }, en = { "ice", "frost" }, es = { "hielo" },
                fr = { "glace" }, de = { "eis" } } },
    { id = "orb_fire", group = "orb", requires = ORB_CTX,
      match = { pt_BR = { "fogo" }, en = { "fire" }, es = { "fuego" },
                fr = { "feu" }, de = { "feuer" } } },
    { id = "orb_holy", group = "orb", requires = ORB_CTX,
      match = { pt_BR = { "sagrado" }, en = { "holy" }, es = { "sagrado" },
                fr = { "sacré" }, de = { "heilig" } } },
    { id = "orb_dark", group = "orb", requires = ORB_CTX,
      match = { pt_BR = { "sombra" }, en = { "shadow", "dark" }, es = { "sombra" },
                fr = { "ombre" }, de = { "schatten" } } },
    { id = "orb", group = "orb", match = ORB_CTX },
    { id = "exhaust",
      match = { pt_BR = { "exaurir" }, en = { "exhaust" }, es = { "agotar" },
                fr = { "épuiser" }, de = { "erschöpfen" } } },
    { id = "poison",
      match = { pt_BR = { "veneno" }, en = { "poison" }, es = { "veneno" },
                fr = { "poison" }, de = { "gift" } } },
    { id = "vulnerable",
      match = { pt_BR = { "vulnerável" }, en = { "vulnerable" }, es = { "vulnerable" },
                fr = { "vulnérable" }, de = { "verwundbar" } } },
    { id = "weak",
      match = { pt_BR = { "fraco" }, en = { "weak" }, es = { "débil" },
                fr = { "faible" }, de = { "schwach" } } },
    -- Rebalance v2 (Jul/2026): "retenção" — desc do Escudo Templário usa o termo
    { id = "retain",
      match = { pt_BR = { "reter", "retenção", "mantida" }, en = { "retain" },
                es = { "retención", "retener" }, fr = { "conservation" },
                de = { "behalten" } } },
    { id = "innate",
      match = { pt_BR = { "inato" }, en = { "innate" }, es = { "innato" },
                fr = { "inné" }, de = { "angeboren" } } },
    { id = "block",
      match = { pt_BR = { "bloqueio", "armadura" }, en = { "block", "armor" },
                es = { "bloqueo", "armadura" }, fr = { "blocage", "armure" },
                de = { "block", "rüstung" } } },
    { id = "focus",
      match = { pt_BR = { "foco" }, en = { "focus" }, es = { "foco" },
                fr = { "focus" }, de = { "fokus" } } },
    { id = "strength",
      match = { pt_BR = { "força" }, en = { "strength" }, es = { "fuerza" },
                fr = { "force" }, de = { "stärke" } } },
    { id = "dexterity",
      match = { pt_BR = { "destreza" }, en = { "dexterity" }, es = { "destreza" },
                fr = { "dextérité" }, de = { "geschicklichkeit" } } },
}
