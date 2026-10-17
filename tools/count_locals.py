import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "src/ui/WorldRoad.lua"
n = 0
for line in open(path, encoding="utf-8").read().split("\n"):
    if re.match(r"^local\s+function\s", line):
        n += 1
        continue
    m = re.match(r"^local\s+([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)", line)
    if m:
        n += len(m.group(1).split(","))
print(path, "file-scope local slots:", n)
