import os, sys, subprocess, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
E = importlib.import_module(os.environ.get('TDZ_EDL', 'edl'))

WT = r'E:\dev\projects\card-game-trailer-zero'
LOVEC = r'C:\Program Files\LOVE\lovec.exe'
WORK = os.path.join(E.OUT, 'work', 'crt')
SRC = os.path.join(E.OUT, 'zero_semcrt.mp4')
DST = os.path.join(E.OUT, 'zero_crt.mkv')
CHUNK = 600
TV_SKIP = getattr(E, 'TV_SKIP', 66)


def main():
    os.makedirs(WORK, exist_ok=True)
    total = int(round(E.DUR * E.FPS))
    parts = []
    for start in range(0, total, CHUNK):
        n = min(CHUNK, total - start)
        part = os.path.join(WORK, f'p_{start:05d}.mkv')
        parts.append(part)
        if os.path.exists(part):
            continue
        fr = os.path.join(WORK, 'frames')
        shutil.rmtree(fr, ignore_errors=True); os.makedirs(fr)
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', SRC, '-vf', f'select=between(n\\,{start}\\,{start + n - 1})', '-vsync', '0',
                        '-start_number', str(start + 1), '-compression_level', '1', os.path.join(fr, '%05d.png')], check=True)
        env = dict(os.environ, CARDGAME_HEADLESS='1', CARDGAME_IDENTITY='card-game-trailer-v9', CRT_IN=fr, CRT_OUT=part,
                   CRT_FIRST=str(start + 1), CRT_SKIP=str(start + TV_SKIP), CRT_POWERON='1.8', CRT_SEED='11')
        r = subprocess.run([LOVEC, '.', 'test_one', 'trailer_crt_post'], cwd=WT, env=env, capture_output=True, text=True)
        print(r.stdout.strip().splitlines()[-1] if r.stdout.strip() else r.stderr[-400:])
        shutil.rmtree(fr, ignore_errors=True)
    lst = os.path.join(WORK, 'lista.txt')
    open(lst, 'w').write(''.join(f"file '{p}'\n" for p in parts))
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', lst, '-c', 'copy', DST], check=True)
    print('[ok] CRT', DST)


if __name__ == '__main__':
    main()
