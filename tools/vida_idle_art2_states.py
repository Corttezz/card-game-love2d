STATE_TAIL = (" A seamless loop that starts and ends exactly in its idle pose, stays in place, feet planted. "
              "Same palette, size and proportions, eyes keep glowing, nothing new appears, no particles, no halo, no color change.")

STATE_FPS = {"state_poison": 8, "state_weak": 7, "state_enraged": 11}

STATE_WORDS = {
    "ember_imp": ("lava imp", "its claws drag on the ground", "the flame mane flares higher, fangs bared"),
    "hellhound": ("two-headed hellhound", "both heads hang low and the tail droops", "both heads snarl with hackles up and the flame manes flare higher"),
    "abyss_acolyte": ("hooded acolyte", "the grimoire sinks lower and its flame shrinks", "the raised claw clenches and the grimoire flame flares higher"),
    "obsidian_sentinel": ("armored sentinel", "the gauntlets hang heavy and the helmet bows", "the fists clench and the helmet lowers forward menacingly"),
    "pit_brute": ("horned demon", "it leans its weight heavily on the hammer handle", "it grips the hammer hard, shoulders bunched, fangs bared"),
    "abyss_watcher": ("floating many-eyed creature", "the tentacles hang limp and the bell sags lower", "the tentacles writhe faster and all eyes widen"),
    "abyss_tyrant": ("demon lord", "the clawed hands hang lower and the horned head bows", "the claws flex open, shoulders rise and the skull head juts forward"),
    "frost_wight": ("skeletal wight", "the bony hands hang limp and the hood bows", "the bony fingers curl into claws and the hooded head juts forward"),
    "frost_wolf": ("frost wolf", "the head hangs low and the tail droops", "the hackles rise, the lips pull back over the fangs and the head lowers to strike"),
    "rime_shaman": ("goblin shaman", "it leans on the totem staff and the raised hand drops", "the raised hand claws the air and it bares its teeth"),
    "glacier_knight": ("ice knight", "the greatsword tip sinks and the helmet bows", "the greatsword lifts a little and the helmet lowers forward"),
    "frost_troll": ("snow troll", "the head hangs and the huge arms sag", "the tusks bare, the shoulders bunch up and the fists press into the ground"),
    "ice_wyrm": ("ice wyrm", "the neck sags lower and the wings fold limp", "the neck coils back to strike, jaws wide, wings flared"),
    "winter_monarch": ("ice king", "it leans on its staff and the crowned head bows", "the free hand clenches, the staff grips tight and the skull head juts forward"),
}

HEAD = {
    "ember_imp": (0.45, 0.15), "hellhound": (0.30, 0.20), "abyss_acolyte": (0.53, 0.10),
    "obsidian_sentinel": (0.49, 0.22), "pit_brute": (0.51, 0.15), "abyss_watcher": (0.50, 0.15),
    "abyss_tyrant": (0.49, 0.15), "frost_wight": (0.45, 0.12), "frost_wolf": (0.30, 0.18),
    "rime_shaman": (0.50, 0.25), "glacier_knight": (0.49, 0.22), "frost_troll": (0.62, 0.20),
    "ice_wyrm": (0.70, 0.12), "winter_monarch": (0.45, 0.12),
}


def state_action(eid, clip):
    who, weak, rage = STATE_WORDS[eid]
    if clip == "state_poison":
        return (f"poisoned and sick: the {who} hunches a little and draws in, shudders, coughs once in the middle of the loop, "
                f"the head droops and lifts again, breathing ragged and uneven")
    if clip == "state_weak":
        return (f"weakened and exhausted: the {who} droops and sags lower, {weak}, slow heavy tired breathing, it sways slightly")
    return (f"enraged: the {who} tenses and leans forward aggressively, {rage}, quick angry breaths, trembling with fury")


def attach(specs):
    for eid in specs:
        specs[eid]["states"] = {c: dict(frames=10, fps=STATE_FPS[c], action=state_action(eid, c)) for c in STATE_FPS}
    return specs
