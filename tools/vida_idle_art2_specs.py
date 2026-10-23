IDLE_TAIL = (" Stays in place, same pose, feet planted. Subtle seamless loop, last frame flows into the first. "
             "Same palette, size and silhouette every frame, eyes keep glowing, nothing new appears, no particles, no halo.")

FIDGET_TAIL = (" Starts and ends in its idle pose, stays in place, feet planted. "
               "Same palette, size and proportions, eyes keep glowing unless closed by the action, nothing new appears, no particles, no halo.")

FLOAT_TAIL = (" Floats in place, same pose. Subtle seamless loop, last frame flows into the first. "
              "Same palette, size and silhouette every frame, eyes keep glowing, nothing new appears, no particles, no halo.")

SPECS = {
    "ember_imp": dict(act=3, eyes=[4, 5], idle=dict(frames=16, fps=10, action=(
        "idle breathing loop of a crouching lava imp: the flame mane on its head flickers and licks upward in tongues of fire that change shape every frame, "
        "the curled tail sways slowly and its flame tip flickers, chest heaves with quick impish breaths, shoulders rise and fall. "
        "The mouth stays closed in its grin, nothing comes out of the mouth, no breath, no smoke, no puff. "
        "The black body and the thin orange lava seams keep exactly their colors in every frame, no flashing, no white, only the fire moves")),
        fidgets=dict(
            fidget_tailflick=dict(frames=10, fps=12, weight=3, action=(
                "the imp flicks its tail: the long curled tail whips to the side and snaps back, the flame tip trailing and flaring, then the tail curls back into place")),
            fidget_cackle=dict(frames=10, fps=11, weight=2, action=(
                "the imp cackles: head tilts back a little, the fanged grin widens, shoulders bounce twice with laughter, flame mane flares up, then it settles")),
            fidget_look=dict(frames=10, fps=9, weight=2, action=(
                "the imp glances sideways: its head turns a little to its left, the glowing eyes looking that way, then turns a little to its right, then back to the front")),
        ),
        gap=[2.5, 6.0], fx=[
            dict(kind="embers", xr=0.47, yr=0.08, rate=1.2, spread=0.18, dir="up"),
            dict(kind="embers", xr=0.86, yr=0.10, rate=0.6, spread=0.06, dir="up"),
            dict(kind="ash", xr=0.50, yr=0.20, rate=0.5, spread=0.40, dir="up"),
        ]),
    "hellhound": dict(act=3, eyes=[0, 1], idle=dict(frames=16, fps=10, action=(
        "idle panting loop of a two-headed hellhound standing four-legged: both heads pant with jaws working slightly, the burning flame manes on both heads and along the back roil and lick upward, "
        "the flame on the tail tip flickers and the tail sways, the ribcage rises and falls with heavy breaths, the lava cracks keep their color")),
        fidgets=dict(
            fidget_snarl=dict(frames=10, fps=11, weight=3, action=(
                "both heads snarl: the two heads pull back the lips and snap their jaws once toward the front, manes flaring, then settle back")),
            fidget_sniff=dict(frames=12, fps=10, weight=2, action=(
                "the left head lowers and sniffs the ground, nostrils twitching, while the right head keeps watching, then the left head rises back up")),
            fidget_shake=dict(frames=10, fps=12, weight=1, action=(
                "the hellhound shakes its heads quickly side to side like a dog shaking off water, flame manes whipping, then stands still again")),
        ),
        gap=[2.5, 6.0], fx=[
            dict(kind="embers", xr=0.30, yr=0.06, rate=1.2, spread=0.30, dir="up"),
            dict(kind="embers", xr=0.90, yr=0.10, rate=0.6, spread=0.05, dir="up"),
            dict(kind="smoke", xr=0.16, yr=0.40, rate=0.5, spread=0.05, dir="up"),
        ]),
    "abyss_acolyte": dict(act=3, eyes=[0, 1], idle=dict(frames=16, fps=9, action=(
        "idle loop of a hooded acolyte standing: the flame on the open grimoire flickers and dances every frame, the ragged robe hem and the tattered sleeves sway gently, "
        "the chains around its body swing a little, the hood dips with a slow breath, the raised clawed hand curls its fingers slowly, the two eyes in the hood glow steadily")),
        fidgets=dict(
            fidget_pages=dict(frames=10, fps=10, weight=3, action=(
                "the pages of the open grimoire flip by themselves, two pages turning over while the flame on the book flares, the acolyte looks down at the book, then looks up again")),
            fidget_beckon=dict(frames=10, fps=10, weight=2, action=(
                "the raised left clawed hand slowly beckons: the fingers curl in and open again, the hand lowers a little and rises back")),
            fidget_chains=dict(frames=10, fps=11, weight=1, action=(
                "the acolyte shrugs its shoulders and the chains around its body rattle and swing, robe hem swishing, then everything settles")),
        ),
        gap=[3.0, 7.0], fx=[
            dict(kind="embers", xr=0.24, yr=0.12, rate=1.0, spread=0.08, dir="up"),
            dict(kind="smoke", xr=0.24, yr=0.14, rate=0.4, spread=0.05, dir="up"),
            dict(kind="ash", xr=0.50, yr=0.80, rate=0.4, spread=0.50, dir="up"),
        ]),
    "obsidian_sentinel": dict(act=3, eyes=[4, 5], idle=dict(frames=16, fps=8, action=(
        "idle loop of a heavy armored sentinel standing guard: the glowing lava seams on the obsidian armor keep exactly their color and brightness, "
        "the dark cape behind it ripples at its ragged glowing hem, chest plate rises with a slow heavy breath, the visor slit glows")),
        fidgets=dict(
            fidget_look=dict(frames=12, fps=9, weight=2, action=(
                "the sentinel turns its helmet slowly to its left as if scanning, holds, then turns back to the front")),
            fidget_flex=dict(frames=10, fps=10, weight=2, action=(
                "the sentinel clenches both gauntlet fists at its sides, then relaxes the hands, the armor colors stay the same")),
            fidget_gust=dict(frames=10, fps=11, weight=1, action=(
                "a gust of hot wind: the cape and the tabard flap to the side and settle back, the sentinel does not move")),
        ),
        gap=[3.5, 8.0], fx=[
            dict(kind="embers", xr=0.34, yr=0.40, rate=0.8, spread=0.35, dir="up"),
            dict(kind="smoke", xr=0.34, yr=0.30, rate=0.4, spread=0.30, dir="up"),
        ]),
    "pit_brute": dict(act=3, eyes=[0, 1], idle=dict(frames=16, fps=8, action=(
        "idle loop of a hulking horned demon leaning on its sledgehammer: the huge chest and shoulders heave with slow heavy breaths, "
        "the loincloth sways a little, the head bobs slightly, the hands stay on the hammer handle. The lava cracks, horns and hammer keep exactly their colors and brightness in every frame, no glowing, no gold, no yellow")),
        fidgets=dict(
            fidget_snort=dict(frames=10, fps=10, weight=3, action=(
                "the demon snorts: the head jerks up a little, the nostrils flare and the lips curl to show the fangs, the shoulders rise, then it settles")),
            fidget_regrip=dict(frames=10, fps=10, weight=2, action=(
                "the demon lifts its hands slightly off the hammer handle, flexes the fingers and grips the handle again, the hammer head stays on the ground")),
            fidget_roll=dict(frames=12, fps=10, weight=1, action=(
                "the demon rolls its massive shoulders and cracks its neck to one side, then back to its stance")),
        ),
        gap=[3.0, 7.0], fx=[
            dict(kind="embers", xr=0.50, yr=0.38, rate=0.8, spread=0.45, dir="up"),
            dict(kind="smoke", xr=0.51, yr=0.24, rate=0.4, spread=0.05, dir="up"),
        ]),
    "abyss_watcher": dict(act=3, eyes=[0, 1, 2], float=True, idle=dict(frames=16, fps=9, action=(
        "idle loop of a floating jellyfish-like abyss creature: the long curtain of tentacles undulates in slow waves that travel down from the bell to the tips, "
        "the tentacle tips curl and sway, the flesh bell swells and contracts gently like breathing, the cluster of glowing orange eyes stays lit with the same color")),
        fidgets=dict(
            fidget_blink=dict(frames=6, fps=12, weight=3, action=(
                "the eyes blink: the eyelids of all the glowing orange eyes close and open once, the large central eye last")),
            fidget_dart=dict(frames=10, fps=10, weight=2, action=(
                "all the pupils of the eyes dart to the left, then to the right, then back to the center")),
            fidget_curl=dict(frames=12, fps=10, weight=2, action=(
                "the tentacles slowly curl up toward the bell like a fist and then uncurl and hang down again")),
        ),
        gap=[2.5, 6.0], fx=[
            dict(kind="drips", xr=0.48, yr=0.95, rate=0.6, spread=0.50, dir="down"),
            dict(kind="embers", xr=0.50, yr=0.08, rate=0.4, spread=0.50, dir="up"),
        ]),
    "abyss_tyrant": dict(act=3, boss=True, eyes=[0, 1], idle=None,
        fidgets=dict(
            fidget_flex=dict(frames=12, fps=10, weight=2, action=(
                "the demon lord flexes its huge clawed hands, the claws curling and opening, the glowing lava seams on the arms flaring, then relaxes")),
            fidget_glare=dict(frames=10, fps=9, weight=2, action=(
                "the horned skull head tilts down slightly and the glowing yellow eyes glare toward the viewer, then the head returns, colors stay the same")),
            fidget_cape=dict(frames=12, fps=10, weight=1, action=(
                "a hot gust: the ragged grey-green cape billows outward on both sides and falls back, the demon stays still")),
        ),
        gap=[3.0, 7.0], fx=[
            dict(kind="embers", xr=0.50, yr=0.55, rate=0.8, spread=0.50, dir="up"),
        ]),
    "frost_wight": dict(act=4, eyes=[0, 1], idle=dict(frames=16, fps=8, action=(
        "idle loop of a hooded skeletal wight standing: the tattered icy robe strips and the hood fringe flutter softly in a cold wind, "
        "the hanging icicle rags sway, the shoulders rise and fall with a slow breath, the frost-blue eyes inside the hood glow steadily")),
        fidgets=dict(
            fidget_tilt=dict(frames=10, fps=9, weight=2, action=(
                "the wight tilts its hooded skull head slowly to one side as if listening, then straightens")),
            fidget_claws=dict(frames=10, fps=10, weight=2, action=(
                "the bony fingers of both hands twitch and curl into claws, then relax and hang again")),
            fidget_gust=dict(frames=12, fps=11, weight=1, action=(
                "an icy gust: all the tattered robe strips and the hood edge whip to the side and slowly settle back")),
        ),
        gap=[3.0, 7.0], fx=[
            dict(kind="frost", xr=0.38, yr=0.50, rate=0.8, spread=0.40, dir="down"),
            dict(kind="mist", xr=0.38, yr=0.92, rate=0.6, spread=0.50, dir="side"),
        ]),
    "frost_wolf": dict(act=4, eyes=[0, 1], idle=dict(frames=16, fps=9, action=(
        "idle loop of a gaunt frost wolf standing on four legs: it pants with the jaw slightly open, the frosty breath wisp at the mouth puffs and fades in rhythm, "
        "the shaggy fur on the neck and back ruffles in the wind, the icicles under the jaw and chest sway, the ribcage rises and falls, the tail sways slowly")),
        fidgets=dict(
            fidget_sniff=dict(frames=10, fps=10, weight=2, action=(
                "the wolf lowers its head and sniffs the air, nostrils twitching, then raises its head again")),
            fidget_shake=dict(frames=10, fps=12, weight=2, action=(
                "the wolf shakes its head and neck fur quickly like shaking off snow, fur and icicles flying back and forth, then stands still")),
            fidget_snarl=dict(frames=10, fps=11, weight=2, action=(
                "the wolf snarls: the lips pull back, the fangs show wider, the head lowers a little and the hackles rise, then it relaxes")),
        ),
        gap=[2.5, 6.0], fx=[
            dict(kind="frost", xr=0.12, yr=0.46, rate=1.0, spread=0.05, dir="side"),
            dict(kind="mist", xr=0.45, yr=0.95, rate=0.5, spread=0.50, dir="side"),
        ]),
    "rime_shaman": dict(act=4, eyes=[0, 1], idle=dict(frames=16, fps=9, action=(
        "idle loop of a hunched goblin shaman holding a totem staff: the white fur pelt cloak ruffles in a cold wind, the fur trim strips sway, "
        "the ice crystal on top of the staff stays the same, the raised hand curls and opens its fingers slowly, the shoulders rise and fall with breathing, the bone necklace swings a little")),
        fidgets=dict(
            fidget_tap=dict(frames=10, fps=10, weight=2, action=(
                "the shaman lifts the totem staff a little and taps it down on the ground, then holds it upright again")),
            fidget_mutter=dict(frames=10, fps=10, weight=2, action=(
                "the shaman mutters a chant: the head bobs, the mouth moves, the raised hand makes a small circling gesture, then stops")),
            fidget_look=dict(frames=12, fps=9, weight=1, action=(
                "the shaman glances suspiciously to its left, then to its right, then back to the front")),
        ),
        gap=[2.5, 6.0], fx=[
            dict(kind="glint", xr=0.82, yr=0.12, rate=0.8, spread=0.05),
            dict(kind="frost", xr=0.82, yr=0.16, rate=0.6, spread=0.08, dir="down"),
            dict(kind="mist", xr=0.45, yr=0.95, rate=0.4, spread=0.45, dir="side"),
        ]),
    "glacier_knight": dict(act=4, eyes=[0], idle=dict(frames=16, fps=8, action=(
        "idle loop of a heavy ice knight standing with a greatsword held low: the icy flame wisps on the shoulders and the sword tip curl and waver upward every frame, "
        "the chest plate rises with a slow breath, the blue glow in the visor slit stays lit")),
        fidgets=dict(
            fidget_grip=dict(frames=10, fps=10, weight=2, action=(
                "the knight tightens its grip on the greatsword, raising the blade a little and lowering it back")),
            fidget_look=dict(frames=12, fps=9, weight=2, action=(
                "the knight turns its helmet slowly to its left, holds, then back to the front")),
            fidget_shrug=dict(frames=10, fps=10, weight=1, action=(
                "the knight rolls its armored shoulders, the icy flame wisps on the shoulders flaring up, then settles")),
        ),
        gap=[3.5, 8.0], fx=[
            dict(kind="frost", xr=0.25, yr=0.20, rate=0.6, spread=0.06, dir="up"),
            dict(kind="frost", xr=0.62, yr=0.20, rate=0.6, spread=0.06, dir="up"),
            dict(kind="mist", xr=0.40, yr=0.94, rate=0.5, spread=0.50, dir="side"),
        ]),
    "frost_troll": dict(act=4, eyes=[0, 1], idle=dict(frames=16, fps=8, action=(
        "idle loop of a massive hulking snow troll on its knuckles: the huge chest and shoulders heave with slow heavy breaths, the shaggy white fur on the arms and back ruffles in the wind, "
        "the beard sways, the long arms shift weight a little, the fists stay on the ground")),
        fidgets=dict(
            fidget_snort=dict(frames=10, fps=10, weight=3, action=(
                "the troll snorts: the head jerks up, the nostrils flare, the tusked mouth opens a little, the shoulders rise, then it settles")),
            fidget_scratch=dict(frames=12, fps=10, weight=2, action=(
                "the troll lifts its right hand off the ground, scratches its beard with the big fingers, then puts the fist back on the ground")),
            fidget_look=dict(frames=12, fps=9, weight=1, action=(
                "the troll turns its head slowly to its left, then back to the front")),
        ),
        gap=[3.0, 7.0], fx=[
            dict(kind="frost", xr=0.64, yr=0.36, rate=0.6, spread=0.05, dir="side"),
            dict(kind="mist", xr=0.50, yr=0.95, rate=0.5, spread=0.50, dir="side"),
        ]),
    "ice_wyrm": dict(act=4, eyes=[0], idle=dict(frames=16, fps=9, action=(
        "idle loop of a coiled ice wyrm: the upright neck sways slowly in its S curve, the open jaws breathe frost in a rhythmic puff, "
        "the small frost wings flutter, the spine spikes shift with the breathing, the glowing cyan eye stays lit, the coils on the ground stay still")),
        fidgets=dict(
            fidget_hiss=dict(frames=10, fps=11, weight=3, action=(
                "the wyrm hisses: the head pulls back, the jaws open wider showing the fangs, the frills flare, then it settles")),
            fidget_wings=dict(frames=12, fps=10, weight=2, action=(
                "the wyrm stretches its small frost wings open wide and folds them back")),
            fidget_look=dict(frames=12, fps=9, weight=1, action=(
                "the wyrm turns its head slowly toward the viewer, then back to the side")),
        ),
        gap=[2.5, 6.0], fx=[
            dict(kind="frost", xr=0.86, yr=0.22, rate=1.0, spread=0.06, dir="side"),
            dict(kind="mist", xr=0.50, yr=0.92, rate=0.5, spread=0.50, dir="side"),
        ]),
    "winter_monarch": dict(act=4, boss=True, eyes=[2, 3], idle=None,
        fidgets=dict(
            fidget_orb=dict(frames=12, fps=10, weight=2, action=(
                "the ice king lifts the staff slightly, then lowers the staff back, the gem keeps its color")),
            fidget_cape=dict(frames=12, fps=10, weight=2, action=(
                "a freezing gust: the long ice cape billows out to the side and falls back, the king stays still")),
            fidget_glare=dict(frames=10, fps=9, weight=1, action=(
                "the crowned skull head turns slightly toward the viewer, the eyes glare, then it returns")),
        ),
        gap=[3.0, 7.0], fx=[
            dict(kind="glint", xr=0.16, yr=0.17, rate=0.8, spread=0.05),
            dict(kind="frost", xr=0.50, yr=0.40, rate=0.8, spread=0.50, dir="down"),
        ]),
}

FIXUPS = {
    ("ember_imp", "idle", 3): [("unflame", (0, 44, 40, 58))],
    ("abyss_watcher", "idle", 1): [("transplant", (34, 24, 82, 58))],
    ("glacier_knight", "idle", 1): [("transplant", (31, 28, 48, 40))],
    ("obsidian_sentinel", "fidget_look", 2): [("unflame", (28, 0, 72, 22))],
}
