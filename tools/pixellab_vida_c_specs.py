IDLE_SUFFIX = (" Seamless idle loop: the last frame flows back into the first. Same creature, same size, same position "
               "on the canvas, same colors and outline in every frame. Glowing eyes keep glowing in every frame. "
               "Nothing new appears: no particles, no smoke clouds, no new objects, nothing leaves the frame.")
FIDGET_SUFFIX = (" Starts and ends in exactly the first pose. Same creature, same size, same colors and outline in every "
                 "frame. Glowing eyes keep glowing unless the eyes close. Nothing new appears: no particles, no "
                 "clouds, no new objects, nothing leaves the frame.")
PLANTED = " Feet stay planted on the ground in every frame."

ACT = {}

C = {}


def creature(eid, act, keep, idle, fidgets, grounded=True, boss=False, idle_frames=14):
    ACT[eid] = act
    C[eid] = {"keep": keep, "idle": idle, "fidgets": fidgets, "grounded": grounded, "boss": boss,
              "idle_frames": idle_frames}


creature("bog_ghoul", 5,
         "hunched grey-green ghoul, bald head, glowing green eyes, moss and weed strands hanging from the shoulders, "
         "torn brown loincloth, long clawed arms",
         "it stays deeply hunched with the head low and thick moss clumps on the high shoulders in every frame; slow heavy breathing: the chest and shoulders rise and fall a little, the hunched back sways a little, the moss and weed "
         "strands on the shoulders sway, the torn loincloth flaps gently, the clawed fingers twitch",
         {"fidget_twitch": ("the head jerks sharply to one side, the neck cracks, then the head snaps back; the arms "
                            "jolt once", 10),
          "fidget_sniff": ("the head lifts and turns slightly to the left sniffing the air, the shoulders rise, then it "
                           "lowers the head back down", 10),
          "fidget_claw": ("the long clawed fingers of both hands curl into fists and slowly open again, the arms tense",
                          8)})

creature("plague_toad", 5,
         "huge olive-brown toad sitting, glowing yellow-green pustules on the back and body, yellow-green drool from the "
         "mouth, big round eyes",
         "the throat and belly swell and shrink with slow breathing, the yellow-green pustules pulse brighter and "
         "dimmer, the drool strands sway and stretch, the body stays seated",
         {"fidget_blink": ("both big eyes blink: the eyelids close and open again, everything else still", 6),
          "fidget_croak": ("the throat inflates into a big round pale sac below the mouth, then deflates back, the body "
                           "shakes once", 10),
          "fidget_shift": ("it lifts one front foot a little, sets it down, and the heavy body settles with a wobble",
                           8)})

creature("leech_horror", 5,
         "hulking mass of olive-green leeches and worms in a humanoid shape, a big round toothed mouth in the head, two "
         "smaller toothed mouths on the shoulders, clawed hands",
         "the leech worms of the body writhe and slide slowly over each other, the round toothed mouths pulse open and "
         "closed, the dangling slime strands on the arms sway, the body breathes",
         {"fidget_gape": ("the big round mouth in the head opens wider showing the ring of teeth, holds, then closes "
                          "back", 10),
          "fidget_writhe": ("all the leeches on the torso and arms squirm strongly for a moment, the body shudders, then "
                            "settles", 10)})

creature("mire_hag", 5,
         "swamp witch, wide green witch hat with bones, long pale grey-green hair, glowing violet eyes, dark green and "
         "black tattered cape, yellow sash, bone charms, brown boots",
         "she breathes slowly, the long pale hair drifts, the tattered cape hem and the yellow sash sway, the bone "
         "charms dangle and swing, the hat brim bobs a little, hands twitch",
         {"fidget_look": ("she turns her head slowly to the left, then to the right, eyes narrowing, then back to the "
                          "front", 10),
          "fidget_hunch": ("she hunches her shoulders and leans forward a little, fingers curling like claws, then "
                           "straightens back up", 10),
          "fidget_hat": ("the wide hat brim droops and wobbles, the hair whips once as she shakes her head", 8)})

creature("croc_warrior", 5,
         "crocodile warrior standing, long spear in the right hand, round turtle-shell shield, orange feathers on the "
         "shoulder and spear, bone and skull belt, torn loincloth, long tail",
         "slow breathing: the chest rises, the long tail tip sways side to side, the orange feathers on the shoulder and "
         "the spear flutter, the torn loincloth sways, the spear stays in the hand",
         {"fidget_snap": ("the long jaws open wide showing the teeth and snap shut, the head jerks", 8),
          "fidget_spear": ("it lifts the spear a little and plants the butt of the spear back on the ground, the "
                           "feathers swing", 8),
          "fidget_tail": ("the long tail lashes to the side and curls back, the body shifts weight", 10)})

creature("spore_mother", 5,
         "giant mushroom creature, big dark red spotted mushroom cap, glowing green gills dripping under the cap, dark "
         "shadow face with green eyes, olive root body, root legs, small pale mushrooms on the arms",
         "the big mushroom cap rises and sinks slowly with breathing, the glowing green drips under the cap stretch and "
         "sway, the small mushrooms on the arms bob, the root arms sway, the root legs stay planted",
         {"fidget_puff": ("the mushroom cap swells and lifts, the green gills glow brighter, then the cap sinks back "
                          "with a shudder", 10),
          "fidget_tilt": ("the mushroom cap tilts slowly to one side and back like a head turning, the arms sway", 10),
          "fidget_roots": ("the root fingers of both hands curl and uncurl, the root legs flex", 8)})

creature("rot_colossus", 5,
         "huge green rotting colossus with antler branches on its head, glowing cyan eyes, two big bones across the "
         "chest on a strap, massive shoulders, tusked open jaw, brown loincloth",
         "",
         {"fidget_snort": ("the head turns slightly to the side and the open jaw snorts, the shoulders heave, then back",
                           10),
          "fidget_flex": ("the massive arms flex: the fists clench and the shoulders roll forward, then relax", 10),
          "fidget_shake": ("it shakes the head, the antler branches sway, then the head settles", 8)},
         boss=True)

creature("dusk_shade", 6,
         "hooded wraith in a dark violet robe, pale glowing eyes in the hood, wispy pale purple flames rising around the "
         "shoulders and hands, tattered robe hem, hovering",
         "the wispy purple flames flicker and curl upward, the tattered robe hem ripples, the hands drift a little, the "
         "hood sways",
         {"fidget_flare": ("the purple flames around the shoulders flare taller for a moment and sink back", 10),
          "fidget_look": ("the hooded head tilts to the left, then to the right, then back to the front", 10),
          "fidget_claw": ("the pale hands curl the fingers like claws and open again", 8)},
         grounded=False)

creature("dusk_bat", 6,
         "giant dark bat, big dark purple wings with crimson membrane, red eyes, white fangs, big ears, small claws "
         "below",
         "the big wings beat slowly up and down in a hovering flap, the ears twitch, the small feet dangle and swing, "
         "the wings never open wider than in the first frame",
         {"fidget_screech": ("the mouth opens wide showing the fangs in a screech, the ears fold back, then it closes",
                             8),
          "fidget_ears": ("the big ears twitch and the head tilts to one side and back", 8)},
         grounded=False)

creature("grave_thrall", 6,
         "undead skeleton warrior, bone skull with glowing violet eyes, rusty brown plate armor, chainmail, big rusty "
         "tower shield on the left, short sword in the right hand, torn purple banner cloth at the waist",
         "slight creaky breathing sway: the shoulders rise and fall, the torn purple banner cloth at the waist ripples "
         "and swings, the skull jaw hangs and moves a little, the sword tip sways",
         {"fidget_jaw": ("the skull jaw drops open and chatters twice, then closes", 8),
          "fidget_shield": ("it raises the tower shield a little and lowers it back, the armor shifts", 10),
          "fidget_tilt": ("the skull tilts to the side with a creak and straightens back", 8)})

creature("blood_duke", 6,
         "vampire lord, slicked dark hair, pale face, glowing red eyes, tall red collar, long black cape with crimson "
         "lining and gold trim, crimson vest, white gloves, black boots",
         "slow aristocratic breathing, the long black cape hangs closed and only its hem ripples gently, the cape never "
         "spreads wider than in the first frame, the red eyes keep glowing, the tall "
         "collar shifts, the gloved fingers twitch",
         {"fidget_fangs": ("he smirks: the mouth opens a little showing the fangs, then closes", 8),
          "fidget_cape": ("a gust: the black cape billows out a little at the bottom and settles back", 10),
          "fidget_gloves": ("he flexes the white gloved fingers of both hands slowly and relaxes", 8)})

creature("dullahan", 6,
         "headless knight in dark crimson armor, violet flame burning from the neck, holding its own helmeted head "
         "wreathed in violet flame in the left hand, curved sword in the right hand, long dark red cape",
         "the violet flame on the neck and the violet flame on the held head flicker and dance upward, the long red "
         "cape sways, the curved sword sways a little, slow breathing",
         {"fidget_raise": ("it lifts the held flaming head a little higher as if looking around, then lowers it back",
                           10),
          "fidget_sword": ("it turns the curved sword in the hand, the blade swings slightly and returns", 8),
          "fidget_flare": ("the violet neck flame flares up tall for a moment and shrinks back", 8)})

creature("fallen_angel", 6,
         "fallen angel, huge black feathered wings, broken golden halo above the head, pale face with white eyes, dark "
         "silver armor, long purple robe, long dark sword in the right hand pointing down",
         "the huge black wings breathe: the feathers ripple and the wing tips lift and sink slowly, the purple robe hem "
         "sways, the broken halo shimmers, slow breathing, the wings never open wider than in the first frame",
         {"fidget_ruffle": ("the black wing feathers ruffle and shake, then smooth down", 10),
          "fidget_bow": ("the head bows down slowly, then lifts back up", 10),
          "fidget_sword": ("the hand tightens on the sword and shifts it, the blade swings a little and returns", 8)})

creature("eclipse_queen", 6,
         "pale vampire queen, huge purple bat-wing cloak, dark crown, glowing magenta eyes, silver armor on the chest, "
         "long black gown with stars",
         "",
         {"fidget_shiver": ("the huge purple bat wings shiver and fold in a little, then open back", 10),
          "fidget_tilt": ("she tilts the head with the crown slowly to the side and back, the hands lift a little", 10)},
         grounded=False, boss=True)

LIMBS = {
    "bog_ghoul": "the long clawed arms", "plague_toad": "the front legs", "leech_horror": "the clawed arms",
    "mire_hag": "the hands", "croc_warrior": "the spear and the shield", "spore_mother": "the root arms",
    "rot_colossus": "the massive arms", "dusk_shade": "the pale hands", "dusk_bat": "the wings",
    "grave_thrall": "the sword and the tower shield", "blood_duke": "the gloved hands",
    "dullahan": "the curved sword and the held head", "fallen_angel": "the sword and the wings",
    "eclipse_queen": "the hands and the wing cloak",
}

STATE_TEXT = {
    "state_poison": ("poisoned and sick: it hunches a little, the body sways weakly and shudders, it coughs once "
                     "with the head dipping forward, {limbs} hang loose, then it recovers to the first pose", 10),
    "state_weak": ("weakened and exhausted: the shoulders droop, the head hangs lower, {limbs} sag down, slow "
                   "heavy tired breathing, then it lifts back to the first pose", 10),
    "state_enraged": ("enraged: the body tenses and leans forward aggressively, snarling, fast heavy breathing, "
                      "{limbs} tense and clench, it trembles with fury, then returns to the first pose", 10),
}

for _eid, _limbs in LIMBS.items():
    for _k, (_t, _n) in STATE_TEXT.items():
        C[_eid]["fidgets"].setdefault(_k, (_t.format(limbs=_limbs), _n))
