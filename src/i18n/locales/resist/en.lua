return {
    header = "Resistances",
    type = {
        physical = "Physical",
        fire = "Fire",
        ice = "Ice",
        lightning = "Lightning",
        dark = "Shadow",
        arcane = "Arcane",
        poison = "Poison",
    },
    title = {
        immune = "Immune to {type}",
        resist = "Resists {type}",
        weak = "Weak to {type}",
    },
    desc = {
        immune = "{type} damage does nothing to this creature.",
        resist = "Takes only half of {type} damage.",
        weak = "Takes 50% more {type} damage.",
    },
    float = {
        immune = "IMMUNE",
        resist = "RESISTS",
        weak = "WEAKNESS!",
    },
    status_note = {
        poison_immune = "Poison still sticks, but its ticks deal no damage.",
        poison_resist = "Each poison tick deals only half.",
        poison_weak = "Each poison tick deals 50% more.",
        fire_immune = "Burn deals no damage either.",
        fire_resist = "Burn deals only half.",
        fire_weak = "Burn deals 50% more.",
    },
}
