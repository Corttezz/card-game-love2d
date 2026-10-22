def _no_white(im, i):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and min(r, g, b) > 222 and max(r, g, b) - min(r, g, b) < 30:
                px[x, y] = (255, 196, 92, a)
    return im


def _shut_eyes(im, i):
    px = im.load()
    for y in range(32, 60):
        for x in range(44, 85):
            r, g, b, a = px[x, y]
            if a and r > 110 and g > 0.35 * r and b < 100:
                px[x, y] = (58, 16, 20, a)
    return im


FIXUPS = {
    "abyss_watcher/form": _shut_eyes,
    "wicker_effigy/awaken": _no_white,
    "wicker_effigy/roar": _no_white,
}

STILL_SUFFIX = ("Same creature, same pixel art style, same pixel scale, same outline weight, same palette and "
                "shading, same canvas, front view facing the viewer, feet or lowest part near the bottom of the "
                "canvas. Only the pose changes. Transparent background, nothing else in the image.")

ANIM_SUFFIX = (" Palette, colors, proportions, face and every body part stay unchanged in every frame. "
               "Nothing new appears, no text, background stays empty and transparent.")

PMM = "animate_image_pixminimax"

STILLS = {
    "wicker_effigy/blaze": dict(desc=(
        "Change the pose: the woven wicker giant raises BOTH long woven arms high above its head, twig claws "
        "spread open, antlered stag skull tilted up as if roaring, the fire in the ribcage chest roars into a "
        "big bright flame, the two shoulder fires flare into tall flames licking upward, small sparks around. "
        "The wicker body stays dark brown wood, only the fires and eyes give orange and red light, never gold.")),
    "storm_griffin/dive": dict(desc=(
        "Change the pose: the griffin dives down toward the viewer head first, both wings swept back and "
        "folded tight against the body, both lion legs and eagle talons pulled up and tucked under the "
        "belly, talons curled closed, tail streaming behind, body tilted forward, beak open.")),
    "storm_griffin/flare": dict(desc=(
        "Change the pose: the griffin brakes in mid air to land, both wings flared wide open and spread out to "
        "the sides, crackling cyan lightning along the wing edges, the body upright, both eagle legs swung down "
        "and reaching forward toward the ground with the talons spread wide open, the hind legs dangling down, "
        "beak open screeching.")),
    "storm_griffin/crouch": dict(desc=(
        "Change the pose: the griffin has just landed hard in a deep low crouch, chest low near the ground, "
        "knees deeply bent, eagle talons spread and gripping the ground, wings half open and lowered out to "
        "the sides, head low and forward, beak open.")),
    "abyss_watcher/unfurl": dict(desc=(
        "Change the pose: ALL the eyes are closed shut, dark eyelids with no glow at all, and the long curtain "
        "of tentacles spreads wide outward to both sides like an opening fan, tentacle tips curling.")),
    "ice_wyrm/rear": dict(desc=(
        "Change the pose: the ice wyrm rears up tall, neck stretched high and head thrown back, jaws wide open "
        "roaring, a strong long blast of white and pale cyan frost breath streaming from the jaws, the small "
        "frost wings flared wide open, the coils still on the ground.")),
    "ice_wyrm/coil": dict(desc=(
        "Change the pose: the ice wyrm is coiled low and tight, the neck pulled down and the head held low "
        "just above the coils, snarling with the jaws half open, the small frost wings folded flat against "
        "the back, the spine spikes bristling, ready to strike.")),
    "ice_wyrm/dormant": dict(desc=(
        "Change the pose: the ice wyrm lies dormant curled up in a tight low spiral of coils on the ground, "
        "the head tucked down and resting on the coils with the eye closed, the small frost wings folded flat, "
        "frost covering the scales, no breath.")),
    "spore_mother/cluster": dict(desc=(
        "Change the pose: the fungal matriarch squats down so low that she looks like a giant mushroom "
        "growing from the ground: the huge cap rests low near the ground covering everything, the body, arms "
        "and legs tucked and hidden under the cap, only the bottom of the cap and a few roots and small "
        "mushrooms visible, the eyes closed, the gills dim.")),
    "spore_mother/spread": dict(desc=(
        "Change the pose: the fungal matriarch spreads both mossy clawed arms wide open to the sides, the big "
        "cap tilted slightly back, the gills under the cap glowing bright green, a burst of glowing green "
        "spore dots puffing out from under the cap.")),
    "fallen_angel/cocoon": dict(desc=(
        "Change the pose: the fallen angel wraps both huge black feathered wings closed around its body in "
        "front of it like a cloak, the wings meet in the middle and hide the armor and the sword, only the "
        "pale head with long grey hair and the broken halo visible above the wings, feet pointed down "
        "below the wings, floating.")),
    "fallen_angel/kneel": dict(desc=(
        "Change the pose: the fallen angel has landed kneeling on one knee, the other foot planted, head "
        "bowed, both hands on the hilt of the long dark sword planted point-down in the ground in front, "
        "the huge black wings spread wide open and low out to the sides, a few black feathers falling.")),
    "storm_harpy/fly": dict(desc=(
        "Change the pose: the harpy is flying, both huge dark wings raised high mid wingbeat, body leaning "
        "forward, both scaly bird legs pulled up and tucked under the belly with the black talons curled "
        "closed, hooked claws of the hands held forward, white hair streaming back.")),
    "dusk_bat/fly": dict(desc=(
        "Change the pose: the giant bat flies with both wings raised up high above its back in a narrow V, "
        "the wingtips pointing up and staying well inside the frame, narrower than now, the small clawed feet "
        "pulled up and tucked tight under the belly, ears back, body centered.")),
    "glacier_knight/strideA": dict(desc=(
        "Change the pose: the ice knight takes a heavy step forward toward the viewer, the LEFT armored leg "
        "lifted and stepping forward with the knee bent, the right leg planted behind, the body leaning "
        "forward with the weight shifting, the frost greatsword held low swinging with the stride, thin pale "
        "frost mist streaming off the shoulders.")),
    "glacier_knight/strideB": dict(desc=(
        "Change the pose: the ice knight takes a heavy step forward toward the viewer, the RIGHT armored leg "
        "lifted and stepping forward with the knee bent, the left leg planted behind, the body leaning "
        "forward with the weight shifting, the frost greatsword held low swinging with the stride, thin pale "
        "frost mist streaming off the shoulders.")),
    "frost_troll/sit": dict(desc=(
        "Change the pose: the huge snow troll sits on the ground resting at the roadside, legs crossed in "
        "front of it, the big body slumped and hunched forward, the long arms resting on its knees with the "
        "fists hanging down, head drooping low and eyes half closed as if dozing.")),
    "mire_hag/cackle": dict(desc=(
        "Change the pose: the swamp witch throws one empty hand high up over her head with the fingers spread "
        "as if conjuring, the other hand clutching her cloak, the head thrown back cackling with the mouth wide "
        "open, the cloak flaring out, the wide pointed hat keeping its exact shape.")),
    "dullahan/raise": dict(desc=(
        "Change the pose: the headless knight holds its own helmeted head up beside its shoulder at the "
        "height of the neck flame, the left arm bent with the elbow out, the head well below the top of the "
        "canvas, the head's violet eyes blazing bright and the visor jaw open wide laughing, "
        "the dark red cape billowing out wide behind, the curved blade held low in the right hand.")),
    "blood_duke/bats": dict(desc=(
        "Replace the vampire with a swirling column of many small black bats with red eyes and wisps of "
        "blood red mist, roughly the same height and shape as the count, no person visible, only bats and "
        "red mist, same pixel scale and palette.")),
    "blood_duke/flourish": dict(desc=(
        "Change the pose: the vampire count sweeps his black cape with red lining wide open with one raised "
        "arm, the cape spread like a bat wing, the other white gloved hand at his chest, chin raised, red eyes "
        "glowing, a few small black bats flying off the cape edge.")),
}

ANIMS = {
    "wicker_effigy/awaken": dict(first="derive:unlit", last="still:blaze", tool=PMM, action=(
        "the dark dead wicker giant slowly comes alive: first a few embers glow and fall from its body, then a "
        "spark catches deep inside the chest and a flame grows in the ribcage, the shoulder fires ignite, the "
        "eyes light up, then the fire roars higher and the arms lift higher and higher until both are raised "
        "high above the head in a full blaze; the wicker stays dark brown wood, only the fires give light")),
    "wicker_effigy/roar": dict(first="still:blaze", last="idle", tool=PMM, action=(
        "roars with both arms raised high and the flames at their peak, the skull shakes, sparks burst from "
        "the shoulders, then the arms swing down slowly to its sides and the fires shrink back to the small "
        "chest flame and two shoulder flames, settling into its standing stance")),
    "storm_griffin/swoop": dict(first="still:dive", last="still:flare", action=(
        "dives down with wings tucked tight and legs tucked under the belly, then throws both wings wide open "
        "to brake, cyan lightning crackling along the feathers, the legs swing down from under the belly and "
        "reach forward with the talons opening")),
    "storm_griffin/land": dict(first="still:flare", last="still:crouch", action=(
        "the talons hit the ground and both legs bend deep absorbing the impact, the body drops low, the wings "
        "beat down once and half fold, feathers ruffle")),
    "storm_griffin/rear": dict(first="still:crouch", last="idle", action=(
        "rears up tall from the crouch, wings thrown high and wide with bright cyan lightning crackling, head "
        "thrown back screeching with the beak wide open, then drops back down onto its talons and settles into "
        "its stance with the wings raised")),
    "abyss_watcher/form": dict(first="derive:dark@still:unfurl", last="still:unfurl", tool=PMM, action=(
        "the dark shapeless shadow blot slowly gains its dark crimson colour a little more in every frame, "
        "the tentacles writhe, curl and uncurl and spread outward to both sides one after another; the eyes "
        "NEVER open in this clip, every eye stays shut and dark with no glow in every frame")),
    "abyss_watcher/gaze": dict(first="still:unfurl", last="idle", action=(
        "the eyes open one by one: the small side eyes open first glowing deep orange, one after another, the "
        "big central eye opens last, wide and glowing deep orange; the eyes are orange and red, never white, "
        "never yellow; the tentacles slowly draw back in and hang down")),
    "ice_wyrm/emerge": dict(first="still:dormant", last="still:coil", action=(
        "wakes and bursts out of its frozen sleep: the frost on the scales cracks and ice chunks fly off, the "
        "head jerks up, the eye opens glowing, the coils heave and tighten, ending coiled low and tight, "
        "snarling")),
    "ice_wyrm/rear": dict(first="still:coil", last="still:rear", action=(
        "rises spiralling: the neck uncoils and stretches higher and higher, the head lifts and throws back, "
        "the frost wings snap open wide, the jaws open wide and the frost breath begins to blast out")),
    "ice_wyrm/roar": dict(first="still:rear", last="idle", action=(
        "roars with a long blast of frost breath, the head shaking, the wings beating once, then lowers its "
        "neck and settles its coils into its stance, breathing a small cloud of frost")),
    "spore_mother/emerge": dict(first="still:cluster", last="still:spread", action=(
        "the giant mushroom swells and bulges, the cap edge splits, then she pushes up from under the cap, "
        "unfolding her body and legs and rising tall, shedding glowing green spores, until she stands with "
        "both arms spread wide")),
    "spore_mother/spread": dict(first="still:spread", last="idle", action=(
        "glowing green spores puff out from under the cap and drift down, the arms slowly lower to her sides, "
        "the cap settles back, settling into her stance")),
    "fallen_angel/descend": dict(first="still:cocoon", last="idle", action=(
        "descends slowly wrapped in its closed wings, feet pointed down, then the wings unfold and open wide "
        "out to the sides, black feathers falling, the armor and sword revealed")),
    "fallen_angel/land": dict(first="idle", last="still:kneel", action=(
        "lands: the legs reach down, the feet touch the ground, the knees bend and it drops onto one knee "
        "absorbing the impact, the sword point strikes the ground, the wings sweep down low, feathers fall")),
    "fallen_angel/rise": dict(first="still:kneel", last="idle", action=(
        "rises slowly from one knee to stand tall, head lifting, pulling the sword up, the wings lifting back "
        "up and wide, settling into its standing stance")),
    "storm_harpy/swoop": dict(first="still:fly", last="still:fly", frames=12, action=(
        "flies in place with two full powerful wingbeats, the wings sweep down and up, the body bobs up and "
        "down with each beat, the tucked legs sway under the belly with each beat, the white hair streams")),
    "storm_harpy/land": dict(first="still:fly", last="idle", action=(
        "comes in to land: the legs drop down and extend, the talons spread wide, the feet touch down, the "
        "knees bend deep absorbing the impact, the wings beat down and settle, ending in its crouched stance")),
    "dusk_bat/swoop": dict(first="still:fly", last="still:fly", frames=12, action=(
        "flies in place with two full wingbeats: the wings sweep down and up in a narrow V, the wingtips "
        "never reach further out to the sides than in the first frame, the body bobs with each beat, the "
        "tucked little feet sway under the belly with each beat")),
    "dusk_bat/land": dict(first="still:fly", last="idle", action=(
        "brakes to a hover: the wings beat down, the wingtips never reaching further out to the sides than in "
        "the last frame, the little clawed feet drop down and spread, the "
        "body swings back and settles into its hovering stance")),
    "spectral_knight/form": dict(first="derive:mist", last="idle", tool=PMM, action=(
        "the whole dark silhouette brightens evenly a little more in every frame, every part of the knight, "
        "helm, horns, shield, sword and mist, condenses together at the same time, nothing pops in, nothing "
        "flashes white, the body stays still")),
    "glacier_knight/walk#a": dict(first="idle", last="still:strideA", frames=4, action=(
        "steps heavily forward onto the left foot, the armor plates jolt, ice crackles under the boot, pale "
        "frost mist streams off the armour")),
    "glacier_knight/walk#b": dict(first="still:strideA", last="still:strideB", frames=4, action=(
        "the weight rolls over the planted left foot and the right leg swings forward and plants heavily, "
        "ice crackling under the boot, the greatsword swinging, frost mist streaming off the armour")),
    "glacier_knight/walk#c": dict(first="still:strideB", last="idle", frames=4, action=(
        "drags the left leg up beside the right and stops heavily, ice crackling, the greatsword settling "
        "low in front, frost mist drifting off the armour")),
    "glacier_knight/form": dict(first="derive:mist", last="idle", tool=PMM, action=(
        "the dark silhouette condenses out of freezing fog: the whole figure brightens evenly to pale icy "
        "blue a little more in every frame, frost forms over the armour plates, all parts appear together, "
        "the icy flame wisps ignite last, the body stays still")),
    "frost_troll/stand": dict(first="still:sit", last="idle", action=(
        "wakes up: the head lifts, it pushes itself up off the ground with both huge fists, rises to its full "
        "height, stretches the long arms wide and out, throws its head back and roars with the jaw open, then "
        "lowers the arms and leans forward with the fists resting on the ground in its stance")),
    "frost_troll/walk": dict(first="idle", end="idle", action=(
        "heavy lumbering walk toward the viewer in place, two full strides: each huge foot lifts high and "
        "stomps down, the body sways side to side and bobs, the long arms swing and the knuckles drag and "
        "plant on the ground with each step like a gorilla, the shaggy fur bounces, the shoulder ice shards "
        "rock")),
    "mire_hag/cackle#a": dict(first="idle", last="still:cackle", frames=6, action=(
        "throws one empty hand high up over her head, the head tilting back, the mouth opening wide in a "
        "cackle, the cloak flaring")),
    "mire_hag/cackle#b": dict(first="still:cackle", last="idle", frames=6, action=(
        "cackles with the shoulders shaking, then lowers the hand and settles into her stance")),
    "dullahan/laugh#a": dict(first="idle", last="still:raise", frames=6, action=(
        "lifts its own helmeted head high up with the left arm, the head's eyes igniting brighter, the visor "
        "jaw opening, the cape billowing out")),
    "dullahan/laugh#b": dict(first="still:raise", last="idle", frames=6, action=(
        "the raised head laughs with the jaw clattering open and shut, then the arm lowers the head back to "
        "chest height and the cape settles")),
    "blood_duke/form#a": dict(first="still:bats", last="still:flourish", frames=8, action=(
        "the swirling bats and red mist spiral inward and condense into the vampire count, the last bats "
        "merging into the sweeping cape")),
    "blood_duke/form#b": dict(first="still:flourish", last="idle", frames=4, action=(
        "the cape sweeps closed around him with a flourish and he settles into his stance")),
    "wicker_effigy/awaken#b": dict(first="tools/preview_out/entradas_arte/mini/tries/wicker_effigy_awaken_t2/9.png",
                                   last="still:blaze", tool=PMM, frames=4, action=(
        "the fire roars up: both long woven arms lift straight up close to the body, never spreading out "
        "sideways, slowly higher and higher until raised high above the head, the shoulder flames grow tall, the chest flame swells, the skull tilts up")),
    "wicker_effigy/roar#b": dict(first="tools/preview_out/entradas_arte/mini/tries/wicker_effigy_roar_t2/2.png",
                                 last="idle", tool=PMM, frames=8, action=(
        "after the roar both raised arms come down slowly straight in front of the body, a little lower in "
        "every frame, never spreading out sideways, down to its sides, while the big flames shrink back a little in every frame to the small chest flame and two "
        "shoulder flames, the skull tilts back down, settling into its stance")),
}
