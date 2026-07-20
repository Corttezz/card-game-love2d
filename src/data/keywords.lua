-- src/data/keywords.lua
-- Glossário de keywords (F5 do gameplay-overhaul-v1): detectadas na
-- descrição da carta e explicadas no tooltip (CardInfoDisplay) — resolve
-- "orbs jamais explicados" e ensina as regras novas (bloqueio zera,
-- exaurir remove da corrida). Ordem = prioridade (máx 3 por tooltip).

return {
    { match = { "orbe", "canaliza", "evoca", "orb", "channel", "evoke" }, name = "Orbes",
      text = "3 slots. Pulsam todo turno (metade do efeito) e Evocar dispara o efeito cheio: Raio=dano, Gelo=armadura, Fogo=dano+queima, Sombra=cresce, evoca x2. Slot cheio evoca o mais antigo." },
    { match = { "exaurir", "exhaust" }, name = "Exaurir",
      text = "Uso unico POR BATALHA: sai do baralho ate a proxima." },
    { match = { "veneno", "poison" }, name = "Veneno",
      text = "Dano por turno igual aos stacks (acumulaveis)." },
    { match = { "vulneravel", "vulnerable" }, name = "Vulneravel",
      text = "Alvo recebe +50% de dano." },
    { match = { "fraco", "weak" }, name = "Fraco",
      text = "Alvo causa -25% de dano." },
    { match = { "reter", "mantida", "retain" }, name = "Reter",
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
