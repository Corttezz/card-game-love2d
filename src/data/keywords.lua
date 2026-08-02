-- src/data/keywords.lua
-- Glossário de keywords (F5 do gameplay-overhaul-v1): detectadas na
-- descrição da carta e explicadas no tooltip (CardInfoDisplay) — resolve
-- "orbs jamais explicados" e ensina as regras novas (bloqueio zera,
-- exaurir remove da corrida). Ordem = prioridade (máx 3 por tooltip).

return {
    -- ===== ORBES: verbete POR ELEMENTO (feedback Jul/2026: "explicacao
    -- apenas da orbe que tem relacao com a carta, nao de todas"). Todos no
    -- group="orb": o primeiro que casar EXCLUI os demais do grupo — carta
    -- de Fogo explica so o orbe de Fogo; o generico e fallback pra cartas
    -- de orbe sem elemento (Evocar, Dualcast). Semantica canonica:
    -- EffectSystem.orbPulseValue/orbEvokeValue (pulso no fim do SEU turno,
    -- evocar = efeito cheio).
    { match = { "raio", "lightning" }, name = "Orbe de Raio", group = "orb",
      requires = { "orbe", "orb", "canaliza", "evoca", "channel", "evoke", "valor" },
      text = "Canalizado, PULSA dano no inimigo no fim do seu turno; evocar descarrega o valor cheio." },
    { match = { "gelo", "frost", "ice" }, name = "Orbe de Gelo", group = "orb",
      requires = { "orbe", "orb", "canaliza", "evoca", "channel", "evoke", "valor" },
      text = "Canalizado, PULSA armadura no fim do seu turno; evocar da a armadura cheia." },
    { match = { "fogo", "fire" }, name = "Orbe de Fogo", group = "orb",
      requires = { "orbe", "orb", "canaliza", "evoca", "channel", "evoke", "valor" },
      text = "Canalizado, PULSA dano leve por turno; evocar causa o dano cheio + queimadura." },
    { match = { "sagrado", "holy" }, name = "Orbe Sagrado", group = "orb",
      requires = { "orbe", "orb", "canaliza", "evoca", "channel", "evoke", "valor" },
      text = "Canalizado, PULSA cura leve por turno; evocar cura o valor cheio." },
    { match = { "sombra", "dark", "shadow" }, name = "Orbe de Sombra", group = "orb",
      requires = { "orbe", "orb", "canaliza", "evoca", "channel", "evoke", "valor" },
      text = "Canalizado, CRESCE +2 por turno; evocar dispara em DOBRO." },
    { match = { "orbe", "canaliza", "evoca", "orb", "channel", "evoke", "valor" }, name = "Orbes", group = "orb",
      text = "Vai pra fileira de orbes (3 slots) e PULSA no fim do seu turno (numero no orbe). Evocar dispara o efeito cheio. Detalhes: passe o mouse na fileira." },
    { match = { "exaurir", "exhaust" }, name = "Exaurir",
      text = "Uso unico POR BATALHA: sai do baralho ate a proxima." },
    { match = { "veneno", "poison" }, name = "Veneno",
      text = "Dano por turno igual aos stacks (acumulaveis)." },
    { match = { "vulneravel", "vulnerable" }, name = "Vulneravel",
      text = "Alvo recebe +50% de dano." },
    { match = { "fraco", "weak" }, name = "Fraco",
      text = "Alvo causa -25% de dano." },
    -- Rebalance v2 (Jul/2026): "retencao" adicionado — desc nova do Escudo Templario usa o termo
    { match = { "reter", "retencao", "mantida", "retain" }, name = "Reter",
      text = "Nao e descartada no fim do turno." },
    { match = { "inato", "innate" }, name = "Inato",
      text = "Sempre comeca na sua mao no inicio da batalha." },
    { match = { "bloqueio", "armadura", "block", "armor" }, name = "Bloqueio",
      text = "Absorve dano. Zera no inicio do seu turno. Maximo 30 (+10 por ato)." },
    { match = { "foco", "focus" }, name = "Foco",
      text = "+1 de potencia por ponto em cada pulso e evocacao de orbe, nesta batalha." },
    { match = { "forca", "strength" }, name = "Forca",
      text = "+1 de dano por ponto, nesta batalha." },
    { match = { "destreza", "dexterity" }, name = "Destreza",
      text = "+1 de bloqueio por ponto, nesta batalha." },
}
