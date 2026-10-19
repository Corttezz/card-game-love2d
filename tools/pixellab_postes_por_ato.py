import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_landmarks_diorama as L

ROOT = L.ROOT
L.OUT = os.path.join(ROOT, "tools/preview_out/postes_por_ato/pixellab")
L.RAW = os.path.join(L.OUT, "raw")
L.CAND = os.path.join(L.OUT, "cand")
L.JOBS = os.path.join(L.OUT, "jobs.json")

POST = (" The post is narrow: its foot is only as wide as the post itself plus at most two small stones or "
        "roots, never a wide spreading base. The light is at the top: the lantern or flame is small, at "
        "most one fifth of the total height. Tall and slender, about as tall as a man.")

L.SPECS = {
    "ma_post": ("marsh_landmark_shop.png", 40, 84, "moon_r",
        "a roadside lamp post of a haunted swamp: one crooked post of old rotten dark wood, green moss "
        "patches clinging to it and one or two thin strands of hanging moss, a short crooked wooden arm "
        "near the top with a small brace, and hanging from the arm on a short chain a SMALL square "
        "lantern of dark iron with greenish glass and a pale green flame inside. The post goes straight "
        "into the mud with two or three small roots and one tiny mushroom at the foot." + POST),
    "hi_post": ("highlands_landmark_shop.png", 36, 92, "moon_r",
        "a slender roadside lamp post of a cold moonlit highland road: a tall thin square column of "
        "stacked grey-blue cut stone blocks, only a little wider than a man's arm, a small dark iron "
        "bracket bolted near the top holding a small iron cage with a cold blue flame inside, a simple "
        "square stone footing barely wider than the column, a few lichen spots on the stones." + POST),
    "hi_post2": ("highlands_landmark_shop.png", 32, 96, "moon_r",
        "a slender roadside lamp post of a cold moonlit highland road: a short square plinth of grey-blue "
        "cut stone blocks at the bottom, only a quarter of the height, and rising from it a thin dark "
        "wrought iron pole with a small curled iron arm at the top, and hanging from the arm a SMALL iron "
        "lantern with a cold blue flame behind the glass. Very thin and tall, the iron pole is two or "
        "three pixels wide, a few lichen spots on the stones." + POST),
    "hi_post3": ("highlands_landmark_shop.png", 40, 96, "moon_r",
        "a sturdy roadside lamp post of a cold moonlit highland road. At the bottom a carved square "
        "pedestal of grey-blue cut stone with visible thickness: a pale moonlit top face, a lit right "
        "face and a darker left face, chiselled block seams and a moulded cap, about one quarter of the "
        "height. Rising from it a clearly readable wrought iron pole four to five pixels thick, its "
        "right edge catching pale blue moonlight and its left edge dark. Near the top a bold iron "
        "bracket arm with a curled scroll and a diagonal brace sticks out to the right, and from its "
        "tip a short chain holds a small iron lantern whose glass is filled with a bright cold BLUE "
        "flame, the brightest pixels of the sprite. The arm, chain and lantern are clearly connected, "
        "nothing floats." + POST),
}

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "queue":
        L.queue(sys.argv[3:], sys.argv[2])
    elif cmd == "poll":
        L.poll()
    elif cmd == "process":
        L.process()
    elif cmd == "sheet":
        L.sheet(sys.argv[2])
