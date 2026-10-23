ACTS = {
    1: ["cursed_scarecrow", "hollow_farmer", "plague_rats", "harvest_reaper",
        "blight_bull", "wicker_effigy", "carrion_king"],
    2: ["moon_gargoyle", "ram_cultist", "storm_harpy", "rune_golem",
        "spectral_knight", "storm_griffin", "tower_lich"],
}

SUFFIX = (" The camera never moves and the creature stays in the same place at the same size."
          " Every frame keeps the exact same palette, pixel size, proportions and silhouette size,"
          " the glowing eyes stay lit and equally bright in every frame,"
          " nothing new appears, no particles, no sparkles, no smoke clouds, no glow halo."
          " The last frame returns exactly to the first frame pose.")

IDLE = (" This is a calm standing idle loop: the motion is small, smooth and continuous,"
        " never a jump; the feet stay planted on the ground exactly where they are")

SPECS = {
    "cursed_scarecrow": dict(
        keep=("ragged brown hood with grey feathers on top, thick yellow straw collar and straw "
              "shoulder tufts, glowing orange ember eyes, stitched wide grin with teeth, patched "
              "brown coat with a red belt, long arms ending in oversized hooked claw hands, "
              "dark trousers and red shoes"),
        idle=dict(frames=12, action=(
            "a living scarecrow breathing slowly and heavily, shoulders rising and sinking, "
            "the straw collar and the straw tufts on the shoulders bristle and sway in a light "
            "wind, the grey feathers on the hood flutter, the torn coat hem and sleeve rags "
            "sway, the long arms hang and swing very slightly, claw fingers twitch" + IDLE)),
        fidgets={
            "fidget_tilt": dict(frames=10, action=(
                "tilts its head slowly and creepily far to one side like a curious puppet, holds "
                "it, then snaps it back upright, straw collar rustling")),
            "fidget_claws": dict(frames=10, action=(
                "flexes both claw hands: the hooked fingers curl in tight and spread open again "
                "twice, arms lift a little, then hang down again")),
            "fidget_gust": dict(frames=10, action=(
                "a gust of wind blows from the left: the straw collar, the shoulder straw, the "
                "hood feathers and the coat rags all bend and stream to the right, the body "
                "leans a little, then everything settles back")),
        },
    ),
    "hollow_farmer": dict(
        keep=("wide frayed straw hat, gaunt grey undead face with glowing orange ember eyes, "
              "patched brown coat and torn grey apron, hunched pose, grey hands, rusty wooden "
              "pitchfork held upright in its left hand on the right side of the image"),
        idle=dict(frames=12, action=(
            "an undead farmer breathing in a slow tired rhythm, hunched shoulders rising and "
            "falling, the head lolls very slightly, the frayed straw hat brim and the torn apron "
            "strips sway in the wind, the loose empty hand dangles and sways, the pitchfork stays "
            "upright in its grip" + IDLE)),
        fidgets={
            "fidget_grip": dict(frames=10, action=(
                "shifts its grip on the pitchfork: lifts the pitchfork a little and taps its "
                "butt back on the ground, fingers tightening, then stands still")),
            "fidget_look": dict(frames=12, action=(
                "slowly turns its head to look to its left, then to its right, then back to the "
                "front, the hat brim following the head")),
            "fidget_twitch": dict(frames=8, action=(
                "an undead neck twitch: the head jerks sideways twice, the shoulders shudder, "
                "then it settles back to its hunched stance")),
        },
    ),
    "plague_rats": dict(
        keep=("pile of five brown-grey plague rats stacked on top of each other, bald pink tails, "
              "small red beady eyes, yellow pustules on their fur, bared yellow teeth"),
        idle=dict(frames=12, action=(
            "the pile of rats is alive: each rat's body rises and falls with quick small "
            "breaths, the pink tails swish and curl slowly, noses and whiskers twitch, ears flick, "
            "the rats shift a tiny bit against each other but the pile keeps its shape" + IDLE)),
        fidgets={
            "fidget_sniff": dict(frames=10, action=(
                "the top rat lifts its head high, sniffing the air with its nose twitching, "
                "looks around, then lowers its head back to its place on the pile")),
            "fidget_squirm": dict(frames=10, action=(
                "the whole pile squirms: rats wriggle and push against each other, tails lash, "
                "then they settle back into the same pile")),
            "fidget_hiss": dict(frames=8, action=(
                "the front rats open their mouths wide and hiss, showing their yellow teeth, "
                "heads pushed forward, then close their mouths again")),
        },
    ),
    "harvest_reaper": dict(
        keep=("dark green hood around a pale skull face with glowing orange eyes, golden "
              "wheat-straw bundles on both shoulders, dark robe with a red belt, a long scythe "
              "with a curved grey blade held upright in its right hand, loose wheat stalks "
              "floating around its feet"),
        idle=dict(frames=12, action=(
            "a silent reaper standing still and breathing slowly, the golden wheat straw on its "
            "shoulders sways in the wind, the hood edge and the ragged robe hem sway, the loose "
            "wheat stalks around its feet drift and turn slowly in the wind, the scythe stays "
            "upright and still" + IDLE)),
        fidgets={
            "fidget_scythe": dict(frames=10, action=(
                "grips the scythe tighter and turns it slightly so the blade tilts toward us and "
                "back, the hand shifting on the shaft")),
            "fidget_tilt": dict(frames=10, action=(
                "slowly tilts its hooded skull head down and to one side, staring, then raises it "
                "back")),
            "fidget_gust": dict(frames=10, action=(
                "a gust of wind: the wheat straw on its shoulders, the hood and the robe hem "
                "stream sideways and the floating wheat stalks swirl around it, then everything "
                "settles back")),
        },
    ),
    "blight_bull": dict(
        keep=("huge dark grey-brown rotting bull seen from the front, long pale curved horns, "
              "glowing orange eyes, exposed ribs on its flanks, golden wheat stalks tangled on "
              "its back, a bone in its mouth, four hooves on the ground"),
        idle=dict(frames=12, action=(
            "a huge bull breathing deep and heavy: the ribcage and flanks swell and sink, the "
            "big head bobs very slightly with each breath, the wheat stalks on its back sway in "
            "the wind, the tail swishes slowly" + IDLE)),
        fidgets={
            "fidget_snort": dict(frames=10, action=(
                "lowers its head a little and snorts hard, nostrils flaring, the head jerks up "
                "with the snort, then returns")),
            "fidget_paw": dict(frames=12, action=(
                "paws the ground with one front hoof: lifts the hoof and scrapes it back along "
                "the ground twice, head lowered, then plants it back where it was")),
            "fidget_shake": dict(frames=10, action=(
                "shakes its head side to side, the long horns swinging, the wheat stalks on its "
                "back bouncing, then holds still")),
        },
    ),
    "wicker_effigy": dict(
        keep=("towering giant woven from dark brown wicker branches, pale stag skull head with "
              "large branching antlers and small glowing orange eyes, orange fire burning in its "
              "woven chest, small orange flames on both shoulders, long woven arms with twig "
              "claws. The wicker stays dark brown wood, never gold, never bright"),
        idle=dict(frames=12, action=(
            "a wicker giant standing still: only the three fires move, the flames on both "
            "shoulders and the fire in the chest flicker and dance, licking up and shrinking; "
            "the woven chest rises and falls very slightly with a slow breath, the twig claws "
            "creak a little" + IDLE)),
        fidgets={
            "fidget_flare": dict(frames=10, action=(
                "the fire in its chest and on its shoulders flares up taller for a moment, then "
                "dies back down to its normal small size; the wicker stays dark brown")),
            "fidget_turn": dict(frames=12, action=(
                "slowly turns its stag skull head to one side and back, the antlers turning "
                "with it, the fires flickering")),
            "fidget_creak": dict(frames=10, action=(
                "flexes its long woven arms: the twig claws curl and spread, the arms lift a "
                "little and creak, then hang again")),
        },
    ),
    "carrion_king": dict(
        keep=("raven-headed king with a black feathered head and a long grey beak, glowing "
              "orange eyes, a golden spiked crown with blue gems, large dark blue-violet "
              "feathered wings, orange ribcage on a purple tunic with a golden glowing gem in "
              "the chest, purple tattered loincloth, golden bracers, orange bird talons"),
        idle=None,
        fidgets={
            "fidget_caw": dict(frames=10, action=(
                "a silent caw seen from the front: the raven head lifts a little and the grey "
                "beak parts slightly, upper beak up and lower beak down showing a small orange "
                "mouth, the beak keeps its grey color and its short length and never covers the "
                "face or the crown, then the beak closes and the head settles")),
            "fidget_tilt": dict(frames=8, action=(
                "a quick bird head tilt: the raven head jerks sideways, holds, then jerks back, "
                "the crown staying on the head")),
            "fidget_ruffle": dict(frames=10, action=(
                "ruffles its feathers: the wings shake and the feathers puff out and settle back "
                "flat")),
        },
    ),
    "moon_gargoyle": dict(
        keep=("crouched grey-lavender stone gargoyle with large bat wings raised high, pointed "
              "ears with pink insides, glowing purple eyes, small horns, stone claws on the "
              "ground"),
        idle=dict(frames=12, action=(
            "a living stone gargoyle crouched and breathing slowly, its chest and shoulders "
            "rising and falling, the bat wing membranes tremble and the wings flex a little at "
            "the joints, the pointed ears twitch, the eyes keep glowing purple" + IDLE)),
        fidgets={
            "fidget_wings": dict(frames=12, action=(
                "stretches its bat wings open a little wider and higher, membranes tight, then "
                "folds them back to their starting position")),
            "fidget_look": dict(frames=10, action=(
                "turns its head to look to one side, then to the other, then back to the front")),
            "fidget_snarl": dict(frames=8, action=(
                "bares its stone fangs in a snarl, lips pulled back, head lowered a little, then "
                "relaxes")),
        },
    ),
    "ram_cultist": dict(
        keep=("pale ram skull mask with big curled brown horns, dark grey hooded wool robes, "
              "faded purple sash, bone charms on the chest, bronze censer on a chain held low "
              "in its right hand on the left side of the image trailing a thin violet smoke "
              "wisp, left hand raised open"),
        idle=dict(frames=12, action=(
            "a cultist standing in prayer, breathing slowly, the bronze censer swings gently "
            "back and forth on its chain, the thin violet smoke wisp above it waves and curls, "
            "the robe sleeves and the purple sash sway, the raised open hand's fingers move "
            "slowly as if chanting" + IDLE)),
        fidgets={
            "fidget_censer": dict(frames=12, action=(
                "swings the censer a little wider on its chain, the censer keeps its dark violet "
                "glass bulb and bronze base and never turns white or pale, the thin smoke wisp "
                "stays violet and trails behind it, then the censer settles back to hanging")),
            "fidget_chant": dict(frames=10, action=(
                "bows its ram skull head while the raised hand makes a slow chanting gesture, "
                "fingers curling, then raises its head again")),
            "fidget_tilt": dict(frames=8, action=(
                "tilts the ram skull head slowly to one side, staring, then back")),
        },
    ),
    "storm_harpy": dict(
        keep=("monstrous harpy with a withered dark slate-grey feathered body, wild white hair, "
              "gaunt grey beaked face, huge dark grey feather wings spread wide, long hooked "
              "claws held forward, crouched on scaly bird legs with black talons"),
        idle=dict(frames=12, action=(
            "a crouched harpy breathing, the huge spread wings flex slowly up and down a little "
            "at the shoulders, the long wing feathers ripple, the wild white hair whips in the "
            "wind, the claws twitch" + IDLE)),
        fidgets={
            "fidget_shriek": dict(frames=10, action=(
                "thrusts its head forward and opens its beak in a shriek, hair flying, then "
                "pulls back")),
            "fidget_flap": dict(frames=12, action=(
                "gives one big slow flap of both wings, up and down, without leaving the "
                "ground, then holds them spread as before")),
            "fidget_twitch": dict(frames=8, action=(
                "a jerky bird-like look: the head snaps to one side, then the other, then back "
                "to the front")),
        },
    ),
    "rune_golem": dict(
        keep=("bulky dark grey stone golem with glowing magenta-purple rune lines and rune marks "
              "on its armor plates, massive stone fists, heavy legs, small head with a purple "
              "rune on the forehead"),
        idle=dict(frames=12, action=(
            "a stone golem standing heavy and breathing very slowly, the massive shoulders rise "
            "and sink a little, the glowing purple runes pulse brighter and dimmer in a slow "
            "wave, the fists hang heavy" + IDLE)),
        fidgets={
            "fidget_runes": dict(frames=10, action=(
                "the magenta-purple rune lines pulse a little brighter one after another from the "
                "chest outward to the arms, they always stay magenta-purple, never white, never "
                "silver, the grey stone stays the same grey, then the runes dim back to normal")),
            "fidget_fists": dict(frames=10, action=(
                "clenches its massive stone fists and lifts them slightly, grinding, then "
                "relaxes them")),
            "fidget_look": dict(frames=10, action=(
                "turns its small head slowly to one side and back, the heavy shoulders turning a "
                "little with it")),
        },
    ),
    "spectral_knight": dict(
        keep=("ghostly knight in pale grey-violet plate armor, horned helm with two violet eye "
              "lights, torn dark cloth skirt, huge tall rectangular grey tower shield with a "
              "faded sword crest standing at its left side on the right of the image, longsword "
              "with a violet glowing blade held diagonally across its body, wisps of pale ghost "
              "mist around the shield and feet"),
        idle=dict(frames=12, action=(
            "a ghost knight standing guard and breathing slowly, the pale ghost mist wisps "
            "around the shield and the feet curl and drift, the torn cloth skirt sways, the "
            "violet sword blade glow pulses softly, the shield stays planted" + IDLE)),
        fidgets={
            "fidget_sword": dict(frames=10, action=(
                "shifts its grip on the longsword: the hands tighten and the blade tilts a few "
                "degrees up and back down, the blade keeps its exact violet color and thin shape, "
                "no flash, no glow burst, no white, no motion blur, then it returns to the same "
                "diagonal position")),
            "fidget_helm": dict(frames=10, action=(
                "turns its horned helm slowly to one side and back, the violet eye lights "
                "following")),
            "fidget_mist": dict(frames=10, action=(
                "the ghost mist around it swells and swirls up around the shield and legs, then "
                "sinks back down")),
        },
    ),
    "storm_griffin": dict(
        keep=("griffin with slate-grey eagle head and open hooked golden beak, huge slate-grey "
              "feathered wings raised high, thin cyan lightning sparks along the wings, "
              "slate-grey feathered chest, lion hind legs and a lion tail, eagle talons on the "
              "ground"),
        idle=dict(frames=12, action=(
            "a griffin standing and breathing, the chest swells and sinks, the raised wings "
            "flex slowly and the long feathers ripple in the wind, the lion tail swishes, the "
            "beak stays open panting; the few thin cyan lightning lines on the wings stay thin "
            "one-pixel cyan lines, never white, never thick blocks, never more of them" + IDLE)),
        fidgets={
            "fidget_screech": dict(frames=10, action=(
                "throws its eagle head forward and screeches with the beak wide open, the "
                "feathers on the neck bristle, then pulls the head back; only the head, neck and "
                "wing feathers move, the few thin cyan lightning lines stay thin one-pixel lines, "
                "no lightning burst, no thick bolts, no white")),
            "fidget_flap": dict(frames=12, action=(
                "gives one powerful flap of its raised wings, down and back up, staying on the "
                "ground, then holds them raised as before")),
            "fidget_look": dict(frames=8, action=(
                "a sharp raptor look: the eagle head snaps to one side, holds, snaps to the "
                "other, then back to the front")),
        },
    ),
    "tower_lich": dict(
        keep=("lich with a pale skull face and glowing cyan eyes, tall silver-blue spiked crown, "
              "pale blue-white hooded robe and large flowing cape, glowing pale blue orb on a "
              "curved wooden staff in its right hand on the left of the image, cyan gem on the "
              "chest, skeletal left hand, brown boots"),
        idle=None,
        fidgets={
            "fidget_orb": dict(frames=10, action=(
                "lifts the staff a few pixels and the orb's inner swirl turns slowly; only the "
                "orb changes, a little brighter pale blue, it never turns white, the lich's body, "
                "face and crown never light up, no glow, no halo; then the staff lowers back")),
            "fidget_tilt": dict(frames=10, action=(
                "tilts its crowned skull head slowly to one side, staring, then back")),
            "fidget_hand": dict(frames=10, action=(
                "the skeletal left hand lifts and its bony fingers curl and spread in a slow "
                "spellcasting gesture, then lowers back")),
        },
    ),
}

STATE_TEXT = {
    "state_poison": ("is poisoned and sick, a looping state: it hunches over, the body sags and "
                     "shudders, it coughs and retches weakly once in the middle, then straightens "
                     "a little, breathing labored, {d}"),
    "state_weak": ("is weakened and exhausted, a looping state: the body droops lower, the "
                   "shoulders sag, the head hangs, {d}, it breathes slowly and heavily with "
                   "tired sways"),
    "state_enraged": ("is enraged, a looping state: the body tenses and leans forward "
                      "aggressively, it snarls with fast angry breaths pumping the shoulders, {d}"),
}

STATE_DETAIL = {
    "cursed_scarecrow": ("the claw hands hang limp", "the claws drop down limp and the straw collar droops",
                         "the claws spread wide and twitch, straw bristling"),
    "hollow_farmer": ("the free hand clutches its belly", "the pitchfork leans and sags in its loosening grip",
                      "it grips the pitchfork hard and shakes it"),
    "plague_rats": ("the rats tremble and one rat gags", "the rats slump flat against each other, tails limp",
                    "the rats raise their heads and hiss, tails lashing"),
    "harvest_reaper": ("the skull head bows", "the scythe tilts and sags lower in its grip",
                       "it grips the scythe tight and leans in, wheat straw bristling"),
    "blight_bull": ("the head drops low and it wheezes", "the head and horns hang low, the legs stay planted",
                    "the head lowers to charge, nostrils flaring, it stamps a front hoof"),
    "wicker_effigy": ("the three orange fires shrink and sputter low, the wicker stays dark brown, no white, no smoke, no sparks","the fires burn low and the arms hang heavy",
                      "the fires blaze higher and the twig claws flex; the wicker stays dark brown"),
    "carrion_king": ("the beak hangs open", "the wings droop down and the crowned head sags",
                     "the wings flare out and the beak opens in a silent scream"),
    "moon_gargoyle": ("the wings tremble and fold a little", "the wings droop and the ears flatten",
                      "the wings flare, the ears pin back and it bares its fangs"),
    "ram_cultist": ("the raised hand clutches its chest", "the raised hand lowers and the censer hangs still",
                    "the raised hand clenches into a fist and the censer swings hard"),
    "storm_harpy": ("the wings tremble and sag", "the spread wings droop down and the hair falls limp",
                    "the wings flare wide, the claws spread and the hair whips"),
    "rune_golem": ("the runes flicker unevenly", "the fists sag low and the runes dim",
                   "the fists clench and rise and the runes burn brighter"),
    "spectral_knight": ("the sword point dips", "the sword lowers toward the ground, the shield stays planted",
                        "it raises the sword higher and leans behind the shield, eye lights flaring"),
    "storm_griffin": ("the beak hangs open and the wings tremble", "the raised wings droop and the head lowers",
                      "the wings flare high, the lightning sparks crackle stronger"),
    "tower_lich": ("the skeletal hand clutches the chest", "the staff tilts and the head bows, the orb dims a little",
                   "it raises the staff, the orb blazes and the cape billows"),
}

for _eid, _d in STATE_DETAIL.items():
    SPECS[_eid]["states"] = {
        k: dict(frames=10, action="The creature " + STATE_TEXT[k].format(d=_d[i])
                + ", then it returns to the first frame pose")
        for i, k in enumerate(("state_poison", "state_weak", "state_enraged"))
    }

FX = {
    "cursed_scarecrow": [],
    "hollow_farmer": [dict(kind="flies", xr=0.50, yr=0.45, rate=0.5, spread=0.30)],
    "plague_rats": [dict(kind="flies", xr=0.50, yr=0.35, rate=0.8, spread=0.45)],
    "harvest_reaper": [dict(kind="glint", xr=0.45, yr=0.12, rate=0.5, spread=0.25)],
    "blight_bull": [dict(kind="smoke", xr=0.48, yr=0.55, rate=0.6, spread=0.08, tint=(0.80, 0.76, 0.70)),
                    dict(kind="flies", xr=0.50, yr=0.40, rate=0.4, spread=0.40)],
    "wicker_effigy": [dict(kind="embers", xr=0.32, yr=0.34, rate=0.8, spread=0.05),
                      dict(kind="embers", xr=0.68, yr=0.34, rate=0.8, spread=0.05),
                      dict(kind="embers", xr=0.50, yr=0.55, rate=0.6, spread=0.06)],
    "carrion_king": [],
    "moon_gargoyle": [],
    "ram_cultist": [dict(kind="smoke", xr=0.22, yr=0.68, rate=0.8, spread=0.04,
                         tint=(0.70, 0.60, 0.85), dir="up")],
    "storm_harpy": [dict(kind="glint", xr=0.50, yr=0.30, rate=0.3, spread=0.80, tint=(0.75, 0.92, 1.00))],
    "rune_golem": [dict(kind="ash", xr=0.45, yr=0.50, rate=0.3, spread=0.40, dir="down")],
    "spectral_knight": [dict(kind="mist", xr=0.50, yr=0.95, rate=0.8, spread=0.50)],
    "storm_griffin": [dict(kind="glint", xr=0.77, yr=0.12, rate=0.6, spread=0.06, tint=(0.55, 0.93, 0.95)),
                      dict(kind="glint", xr=0.22, yr=0.66, rate=0.6, spread=0.06, tint=(0.55, 0.93, 0.95))],
    "tower_lich": [],
}

BOSSES = ("carrion_king", "tower_lich")

STATE_FX = {}
