import sys, os, json, subprocess, shutil
sys.path.insert(0, r'C:\Users\corte\.claude\skills\scenario-kinetic-film\scripts')
from filmserver import serve
film = os.path.abspath(sys.argv[1])
workers = int(sys.argv[2]) if len(sys.argv) > 2 else 4
only = sys.argv[3:] if len(sys.argv) > 3 else None
here = os.path.dirname(os.path.abspath(__file__))
url, srv = serve(film)
env = {**os.environ, 'FILM_URL': url}
info = json.loads(subprocess.run(['node', r'C:\Users\corte\.claude\skills\scenario-kinetic-film\scripts\info.mjs'], env=env, cwd=film, capture_output=True, text=True, check=True).stdout)
total = round(info['dur'] * info['fps'])
out = os.path.join(film, 'out', 'layer')
if not only:
    shutil.rmtree(out, ignore_errors=True)
os.makedirs(out, exist_ok=True)
step = -(-total // workers)
ranges = [(i * step, min(total, (i + 1) * step)) for i in range(workers)]
if only:
    ranges = [tuple(map(int, r.split(':'))) for r in only]
jobs = [subprocess.Popen(['node', os.path.join(here, 'render_layer.mjs'), out, str(a), str(b)], env=env, cwd=film) for a, b in ranges]
bad = [j for j in jobs if j.wait() != 0]
srv.shutdown()
print(f'{total} frames, {len(os.listdir(out))} with ink, {"FAIL" if bad else "ok"}')
sys.exit(1 if bad else 0)
