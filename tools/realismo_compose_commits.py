import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1]
BASE = sys.argv[2]

PLAN = [
    ("a_sombra", {
        "src/ui/WorldRoad.lua": [3345, 3347, 3349, 3350, 3386, 3388, 3390, 3399, 3701],
        "src/data/scene_integration.lua": [28],
        "engine/ShadowEngine.lua": "all",
    }),
    ("e_chao", {
        "src/data/scene_integration.lua": [20, 24],
    }),
    ("b_profundidade", {
        "src/data/scene_integration.lua": [25],
        "engine/SceneGrade.lua": "all",
    }),
    ("c_lado_sol", {
        "src/ui/WorldRoad.lua": [24, 26, 287, 3286, 3344],
        "src/data/world_props.lua": "all",
    }),
    ("f_fogueira", {
        "src/ui/WorldRoad.lua": [1191],
        "src/data/scene_integration.lua": [5],
        "engine/LuminaireEngine.lua": [14],
    }),
    ("h_poste", {
        "engine/LuminaireEngine.lua": [11],
    }),
]


def git(*args):
    return subprocess.run(["git"] + list(args), cwd=ROOT, capture_output=True, text=True,
                          encoding="utf-8", errors="surrogateescape").stdout


def head_lines(path):
    return git("show", "%s:%s" % (BASE, path)).split("\n")


def hunks(path):
    out = git("diff", "-U0", BASE, "--", path)
    res = {}
    cur = None
    for line in out.split("\n"):
        m = re.match(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
        if m:
            start = int(m.group(1))
            count = 1 if m.group(2) is None else int(m.group(2))
            cur = {"start": start, "count": count, "new": []}
            res[start] = cur
        elif cur is not None and line.startswith("+"):
            cur["new"].append(line[1:])
        elif cur is not None and line.startswith("-"):
            pass
    return res


def apply(lines, hs, wanted):
    lines = list(lines)
    for start in sorted(wanted, reverse=True):
        h = hs[start]
        if h["count"] == 0:
            at = start
            lines[at:at] = h["new"]
        else:
            lines[start - 1:start - 1 + h["count"]] = h["new"]
    return lines


def main():
    os.makedirs(OUT, exist_ok=True)
    state = {}
    manifest = []
    files = set()
    for _, spec in PLAN:
        files.update(spec.keys())
    for path in files:
        state[path] = {"base": head_lines(path), "hunks": hunks(path), "applied": set()}
        for start in state[path]["hunks"]:
            found = any(spec.get(path) == "all" or (isinstance(spec.get(path), list) and start in spec[path])
                        for _, spec in PLAN)
            if not found:
                raise SystemExit("hunk sem dono: %s @%d" % (path, start))
    for name, spec in PLAN:
        step = {"name": name, "files": {}}
        for path, sel in spec.items():
            st = state[path]
            if sel == "all":
                st["applied"] = set(st["hunks"].keys())
            else:
                st["applied"].update(sel)
            text = "\n".join(apply(st["base"], st["hunks"], st["applied"]))
            dst = os.path.join(OUT, name, path.replace("/", "__"))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "w", encoding="utf-8", newline="\n") as f:
                f.write(text)
            step["files"][path] = dst
        manifest.append(step)
    for path in files:
        final = "\n".join(apply(state[path]["base"], state[path]["hunks"], set(state[path]["hunks"].keys())))
        work = open(os.path.join(ROOT, path), "r", encoding="utf-8", newline="").read().replace("\r\n", "\n")
        if final != work:
            raise SystemExit("composição final difere do working copy: " + path)
    json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
    print("[ok] composição = working copy para %d arquivos; %d passos" % (len(files), len(manifest)))


main()
