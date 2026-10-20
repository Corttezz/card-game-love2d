#!/usr/bin/env python3
"""Build de RELEASE do Grimoire (Windows primeiro, pronto pra depot Steam).

    python tools/build_release.py                  # build completo + smoke
    python tools/build_release.py --skip-tests     # pula o test_all da copia limpa
    python tools/build_release.py --bytecode       # Lua -> bytecode LuaJIT (so Windows)
    python tools/build_release.py --love-dir "C:/Program Files/LOVE"

O que faz, em ordem (para no primeiro erro, exit code 1):
  1. Lista os arquivos RASTREADOS pelo git (build reproduzivel: o que nao esta
     commitado nao entra) e filtra o que e runtime: conf/main + components/
     engine/ src/ shaders/ assets/ audio/. Fora: tools/, docs/, memory/,
     scratchpads, .md/.py/.sh, video (modulo desligado no conf.lua).
  2. Remove COMENTARIOS de todo .lua com um lexer Lua de verdade (strings
     curtas com escapes, strings longas [[ ]] / [==[ ]==], comentarios longos,
     shebang). As quebras de linha sao PRESERVADAS: a linha N do build e a
     linha N do repositorio, entao crash log do jogador aponta pro fonte.
  3. Prova que o strip nao mudou o programa: o proprio LOVE compila original e
     limpo e compara string.dump(f, true) byte a byte (bytecode sem debug info
     identico = mesma semantica). Qualquer diferenca reprova o build.
  4. (default) Roda `test_all` numa copia limpa que inclui tools/ — a suite
     inteira contra o codigo SEM comentarios.
  5. Escreve build_info.lua (a flag de RELEASE, ver src/core/Release.lua),
     empacota Grimoire.love (mp3/png sem recompressao), funde com love.exe
     (icone via rcedit se disponivel) e monta build/steam/windows/content.
  6. Smoke: boota o EXECUTAVEL fundido com GRIMOIRE_SELFTEST=1 (boot real,
     pula splash, renderiza todas as cartas, abre run das 3 classes, desenha
     o menu) e exige exit 0 + selftest_result.txt "OK".
"""
import argparse
import datetime
import os
import re
import shutil
import subprocess
import sys
import time
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")
GAME_NAME = "Grimoire"
SELFTEST_IDENTITY = "grimoire-selftest"

RUNTIME_ROOT_FILES = {"conf.lua", "main.lua"}
RUNTIME_DIRS = ("components/", "engine/", "src/", "shaders/", "assets/", "audio/")
# .ico: so serve ao rcedit (icone do .exe); a janela usa assets/branding/icon.png.
EXCLUDE_EXT = {".md", ".py", ".sh", ".bat", ".mp4", ".ogv", ".psd", ".aseprite",
               ".ase", ".xcf", ".kra", ".blend", ".bak", ".tmp", ".log", ".ico"}
EXCLUDE_NAMES = {"Thumbs.db", ".DS_Store", "desktop.ini"}
# Diretorios de asset sem nenhuma referencia no codigo (o relatorio do build
# lista candidatos novos a cada execucao). Vazio desde a limpeza de Out/2026,
# que apagou do repo o que estava aqui (tileset act1_catacumbs).
EXCLUDE_PREFIXES = ()
# Arquivos fora do runtime que a SUITE le (so entram na copia de verificacao,
# nunca no pacote): test_achievements confere icones/metadados Steam.
VERIFY_EXTRA_PREFIXES = ("tools/", "steam/achievements/")
# Steamworks (opcional): DLLs que o dono baixa e solta aqui (gitignored).
# Ver memory/release_pipeline.md, secao "Steamworks / luasteam".
STEAM_VENDOR_DIR = os.path.join(ROOT, "vendor", "steam")
STEAM_DLLS = ["luasteam.dll", "steam_api64.dll"]
RCEDIT_VENDOR = os.path.join(ROOT, "tools", "vendor", "rcedit-x64.exe")


def _main_checkout_rcedit():
    try:
        common = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
                                cwd=ROOT, capture_output=True, text=True).stdout.strip()
    except Exception:
        return None
    if not common:
        return None
    cand = os.path.join(os.path.dirname(common), "tools", "vendor", "rcedit-x64.exe")
    return cand if os.path.isfile(cand) else None
# Ja comprimidos: zip STORED (deflate nao ganha nada e so atrasa o load).
STORED_EXT = {".png", ".mp3", ".ogg", ".wav", ".jpg", ".jpeg", ".ttf", ".otf"}
LOVE_RUNTIME = ["love.dll", "lua51.dll", "mpg123.dll", "msvcp120.dll",
                "msvcr120.dll", "OpenAL32.dll", "SDL2.dll"]


def log(msg):
    print(msg, flush=True)


def die(msg):
    log("\n[BUILD FALHOU] " + msg)
    sys.exit(1)


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from luastrip import LuaStripError, strip_lua  # noqa: E402


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
def run(cmd, cwd=None, env=None, timeout=None, capture=True):
    log("  $ " + " ".join(f'"{c}"' if " " in c else c for c in cmd))
    p = subprocess.run(cmd, cwd=cwd, env=env, timeout=timeout,
                       stdout=subprocess.PIPE if capture else None,
                       stderr=subprocess.STDOUT if capture else None,
                       text=True, encoding="utf-8", errors="replace")
    return p.returncode, (p.stdout or "")


def read_version():
    txt = open(os.path.join(ROOT, "src/core/Config.lua"), encoding="utf-8").read()
    m = re.search(r'^Config\.VERSION\s*=\s*"([^"]+)"', txt, re.M)
    if not m:
        die("Config.VERSION nao encontrado em src/core/Config.lua")
    return m.group(1)


def git(*args):
    code, outp = run(["git", "-C", ROOT] + list(args))
    if code != 0:
        die("git falhou: " + outp)
    return outp


def tracked_files():
    files = git("ls-files", "-z").split("\0")
    return [f for f in files if f]


def is_runtime(rel):
    if rel in RUNTIME_ROOT_FILES:
        return True
    if not rel.startswith(RUNTIME_DIRS):
        return False
    base = os.path.basename(rel)
    if base in EXCLUDE_NAMES or ":" in base:
        return False
    if os.path.splitext(base)[1].lower() in EXCLUDE_EXT:
        return False
    if base.upper().startswith("README"):
        return False
    if rel.startswith(EXCLUDE_PREFIXES):
        return False
    return True


def copy_tree(files, dest, strip=True):
    """Copia `files` (relativos ao ROOT) pra dest, stripando .lua.
    Devolve lista de .lua copiados (rel)."""
    if os.path.exists(dest):
        shutil.rmtree(dest)
    luas = []
    for rel in files:
        srcp = os.path.join(ROOT, rel)
        if not os.path.isfile(srcp):
            continue  # removido no working tree e ainda listado
        dstp = os.path.join(dest, rel)
        os.makedirs(os.path.dirname(dstp), exist_ok=True)
        if strip and rel.endswith(".lua"):
            src = open(srcp, encoding="utf-8", newline="").read()
            try:
                stripped = strip_lua(src, rel)
            except LuaStripError as e:
                die(str(e))
            with open(dstp, "w", encoding="utf-8", newline="\n") as f:
                f.write(stripped)
            luas.append(rel)
        else:
            shutil.copy2(srcp, dstp)
    return luas


VALIDATOR_MAIN = r'''
-- Gerado por tools/build_release.py. Compara bytecode (sem debug info) do
-- fonte original e do fonte sem comentarios; opcionalmente grava bytecode.
function love.load(args)
    local manifest = args[1]
    local bad, n = 0, 0
    for line in io.lines(manifest) do
        local orig, stripped, rel, bcout = line:match("^(.-)\t(.-)\t(.-)\t(.*)$")
        if orig then
            n = n + 1
            local function slurp(p)
                local f = assert(io.open(p, "rb")); local d = f:read("*a"); f:close(); return d
            end
            local a, ea = loadstring(slurp(orig), "@" .. rel)
            local b, eb = loadstring(slurp(stripped), "@" .. rel)
            if not a then
                print("ORIGINAL NAO COMPILA " .. rel .. ": " .. tostring(ea)); bad = bad + 1
            elseif not b then
                print("STRIP QUEBROU " .. rel .. ": " .. tostring(eb)); bad = bad + 1
            elseif string.dump(a, true) ~= string.dump(b, true) then
                print("BYTECODE DIFERENTE " .. rel); bad = bad + 1
            elseif bcout ~= "" then
                local f = assert(io.open(bcout, "wb")); f:write(string.dump(b, false)); f:close()
            end
        end
    end
    print(("validator: %d arquivos, %d problemas"):format(n, bad))
    love.event.quit(bad == 0 and 0 or 1)
end
'''


def validate_strip(lovec, luas, stripped_root, bytecode_root=None):
    vdir = os.path.join(BUILD, "_validator")
    os.makedirs(vdir, exist_ok=True)
    open(os.path.join(vdir, "main.lua"), "w", encoding="utf-8").write(VALIDATOR_MAIN)
    open(os.path.join(vdir, "conf.lua"), "w", encoding="utf-8").write(
        'function love.conf(t) t.identity = "grimoire-build-validator" '
        't.window = false t.modules.audio = false t.modules.sound = false '
        't.modules.graphics = false t.modules.window = false end\n')
    manifest = os.path.join(BUILD, "_validator_manifest.txt")
    with open(manifest, "w", encoding="utf-8", newline="\n") as f:
        for rel in luas:
            bc = os.path.join(bytecode_root, rel) if bytecode_root else ""
            f.write("\t".join([os.path.join(ROOT, rel), os.path.join(stripped_root, rel),
                               rel, bc]).replace("\\", "/") + "\n")
    code, outp = run([lovec, vdir, manifest], timeout=600)
    tail = "\n".join(outp.strip().splitlines()[-15:])
    log(tail)
    if code != 0:
        die("validacao do strip falhou (ver acima)")


def zip_dir(src_dir, zip_path):
    if os.path.exists(zip_path):
        os.remove(zip_path)
    with zipfile.ZipFile(zip_path, "w") as z:
        for dirpath, _, files in os.walk(src_dir):
            for fn in sorted(files):
                full = os.path.join(dirpath, fn)
                rel = os.path.relpath(full, src_dir).replace("\\", "/")
                ext = os.path.splitext(fn)[1].lower()
                comp = zipfile.ZIP_STORED if ext in STORED_EXT else zipfile.ZIP_DEFLATED
                zi = zipfile.ZipInfo(rel, date_time=(2026, 1, 1, 0, 0, 0))
                zi.compress_type = comp
                zi.external_attr = 0o644 << 16
                with open(full, "rb") as fh:
                    z.writestr(zi, fh.read(), compress_type=comp, compresslevel=9 if comp == zipfile.ZIP_DEFLATED else None)


def human(nbytes):
    for unit in ("B", "KB", "MB", "GB"):
        if nbytes < 1024:
            return f"{nbytes:.1f} {unit}"
        nbytes /= 1024
    return f"{nbytes:.1f} TB"


def dir_size(path):
    total = 0
    for dp, _, fs in os.walk(path):
        for f in fs:
            total += os.path.getsize(os.path.join(dp, f))
    return total


GENERIC_DIRS = {"assets", "audio", "sprites", "icons", "sfx", "music", "cards",
                "backgrounds", "effects", "frames", "scenes", "characters",
                "enemies", "ui", "patterns", "attack", "defense", "effect", "jokers"}


def unreferenced_report(files):
    """Heuristica: asset cujo nome-base nao aparece em NENHUM .lua de runtime
    nem o diretorio pai (pastas carregadas por scan). So relatorio."""
    corpus = []
    for rel in files:
        if rel.endswith(".lua"):
            try:
                corpus.append(open(os.path.join(ROOT, rel), encoding="utf-8").read())
            except (OSError, UnicodeDecodeError):
                pass
    text = "\n".join(corpus)
    cands = []
    for rel in files:
        if not rel.startswith(("assets/", "audio/")) or rel.endswith(".lua"):
            continue
        stem = os.path.splitext(os.path.basename(rel))[0]
        d = os.path.dirname(rel)
        parent = os.path.basename(d)
        if stem in text or d in text:
            continue
        if parent not in GENERIC_DIRS and len(parent) > 3 and parent in text:
            continue
        cands.append(rel)
    return cands


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="Build de release do Grimoire")
    ap.add_argument("--love-dir", default=os.environ.get("LOVE_DIR", r"C:\Program Files\LOVE"))
    ap.add_argument("--skip-tests", action="store_true", help="nao roda test_all na copia limpa")
    ap.add_argument("--skip-smoke", action="store_true", help="nao boota o executavel")
    ap.add_argument("--bytecode", action="store_true",
                    help="empacota bytecode LuaJIT gerado pelo proprio lovec (so Windows x64)")
    ap.add_argument("--allow-dirty", action="store_true",
                    help="permite build com working tree sujo (o pacote usa o working tree)")
    args = ap.parse_args()

    love_dir = args.love_dir
    lovec = os.path.join(love_dir, "lovec.exe")
    love_exe = os.path.join(love_dir, "love.exe")
    for p in [lovec, love_exe] + [os.path.join(love_dir, d) for d in LOVE_RUNTIME]:
        if not os.path.isfile(p):
            die(f"runtime do LOVE ausente: {p} (use --love-dir)")

    version = read_version()
    commit = git("rev-parse", "--short", "HEAD").strip()
    dirty = git("status", "--porcelain", "--untracked-files=no").strip()
    if dirty and not args.allow_dirty:
        die("working tree com mudancas nao commitadas (commit ou --allow-dirty):\n" + dirty)
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    log(f"== {GAME_NAME} {version} ({commit}{' +dirty' if dirty else ''}) ==")

    os.makedirs(BUILD, exist_ok=True)
    all_files = tracked_files()
    runtime = sorted(f for f in all_files if is_runtime(f))
    log(f"[1/6] {len(runtime)} arquivos de runtime (de {len(all_files)} rastreados)")

    # 2) copia limpa
    stage = os.path.join(BUILD, "stage")
    luas = copy_tree(runtime, stage, strip=True)
    with open(os.path.join(stage, "build_info.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("-- gerado por tools/build_release.py; a presenca deste arquivo = RELEASE\n"
                f'return {{ release = true, version = "{version}", commit = "{commit}'
                f'{"+dirty" if dirty else ""}", date = "{stamp}", bytecode = {str(args.bytecode).lower()} }}\n')
    log(f"[2/6] comentarios removidos de {len(luas)} .lua")

    # 3) prova de equivalencia (+ bytecode opcional, gravado por cima do stage)
    validate_strip(lovec, luas, stage, stage if args.bytecode else None)
    log("[3/6] bytecode original == bytecode limpo em todos os arquivos"
        + (" (pacote em bytecode)" if args.bytecode else ""))

    # 4) suite completa contra o codigo limpo
    if not args.skip_tests:
        verify = os.path.join(BUILD, "verify")
        verify_files = runtime + [f for f in all_files if f.startswith(VERIFY_EXTRA_PREFIXES)
                                  and os.path.splitext(f)[1].lower() not in (".py", ".md", ".sh")]
        copy_tree(verify_files, verify, strip=True)
        env = dict(os.environ, CARDGAME_IDENTITY="card-game-build-verify")
        code, outp = run([lovec, ".", "test_all"], cwd=verify, env=env, timeout=3600)
        summary = [l for l in outp.splitlines() if "suites:" in l or "TUDO VERDE" in l or "FAIL" in l]
        log("\n".join(summary[-12:]))
        if code != 0:
            open(os.path.join(BUILD, "verify_test_all.log"), "w", encoding="utf-8").write(outp)
            die("test_all falhou no codigo sem comentarios (build/verify_test_all.log)")
        shutil.rmtree(verify, ignore_errors=True)
        log("[4/6] test_all verde no codigo sem comentarios")
    else:
        log("[4/6] test_all PULADO (--skip-tests)")

    # 5) pacote
    out_dir = os.path.join(BUILD, "release", version)
    if os.path.exists(out_dir):
        shutil.rmtree(out_dir)
    os.makedirs(out_dir)
    love_file = os.path.join(out_dir, f"{GAME_NAME}.love")
    zip_dir(stage, love_file)

    exe_base = os.path.join(BUILD, "_love_base.exe")
    shutil.copy2(love_exe, exe_base)
    rcedit = (os.environ.get("RCEDIT") or shutil.which("rcedit") or shutil.which("rcedit-x64")
              or (RCEDIT_VENDOR if os.path.isfile(RCEDIT_VENDOR) else None)
              or _main_checkout_rcedit())
    icon = os.path.join(ROOT, "assets", "branding", "icon.ico")
    if rcedit and os.path.isfile(icon):
        code, outp = run([rcedit, exe_base, "--set-icon", icon,
                          "--set-version-string", "ProductName", GAME_NAME,
                          "--set-version-string", "FileDescription", GAME_NAME,
                          "--set-version-string", "OriginalFilename", f"{GAME_NAME}.exe",
                          "--set-file-version", version, "--set-product-version", version])
        if code != 0:
            die("rcedit falhou: " + outp)
        log("  icone/versao do .exe aplicados (rcedit)")
    else:
        log("  [aviso] rcedit nao encontrado: o .exe fica com o icone do LOVE "
            "(baixe rcedit-x64.exe de github.com/electron/rcedit/releases pra "
            "tools/vendor/ ou defina RCEDIT=caminho\\rcedit-x64.exe)")

    win_dir = os.path.join(out_dir, "windows")
    os.makedirs(win_dir)
    exe_path = os.path.join(win_dir, f"{GAME_NAME}.exe")
    with open(exe_path, "wb") as out, open(exe_base, "rb") as a, open(love_file, "rb") as b:
        shutil.copyfileobj(a, out)
        shutil.copyfileobj(b, out)
    os.remove(exe_base)
    for dll in LOVE_RUNTIME:
        shutil.copy2(os.path.join(love_dir, dll), win_dir)
    shutil.copy2(os.path.join(love_dir, "license.txt"), os.path.join(win_dir, "license.txt"))
    notices = os.path.join(ROOT, "dist", "THIRD_PARTY_NOTICES.txt")
    if not os.path.isfile(notices):
        die("dist/THIRD_PARTY_NOTICES.txt ausente (OFL da fonte exige o aviso no pacote)")
    shutil.copy2(notices, win_dir)

    # Steamworks: luasteam + steam_api64 ao lado do exe (require("luasteam")
    # acha a DLL pelo diretorio do executavel). Sem elas o jogo roda igual e o
    # SteamBridge avisa "Steam INATIVA" no log — mas o BUILD tambem avisa alto.
    steam_found = [d for d in STEAM_DLLS if os.path.isfile(os.path.join(STEAM_VENDOR_DIR, d))]
    if len(steam_found) == len(STEAM_DLLS):
        for d in STEAM_DLLS:
            shutil.copy2(os.path.join(STEAM_VENDOR_DIR, d), win_dir)
        log("  Steamworks: luasteam.dll + steam_api64.dll incluidas")
    elif steam_found:
        die("vendor/steam/ incompleto: tem " + ", ".join(steam_found)
            + " mas precisa de " + " + ".join(STEAM_DLLS))
    else:
        log("  " + "!" * 72)
        log("  [AVISO STEAM] vendor/steam/ sem " + " + ".join(STEAM_DLLS) + ":")
        log("  o pacote sai SEM Steamworks (conquistas Steam nao desbloqueiam;")
        log("  o perfil local funciona). Ver memory/release_pipeline.md.")
        log("  " + "!" * 72)

    steam_content = os.path.join(BUILD, "steam", "windows", "content")
    if os.path.exists(steam_content):
        shutil.rmtree(steam_content)
    shutil.copytree(win_dir, steam_content)
    log(f"[5/6] {love_file}\n      {exe_path}\n      {steam_content}")

    # 6) smoke do executavel
    if not args.skip_smoke:
        appdata = os.environ.get("APPDATA") or os.path.expanduser("~")
        sdir = os.path.join(appdata, SELFTEST_IDENTITY)   # fundido: sem o "LOVE/"
        shutil.rmtree(sdir, ignore_errors=True)
        env = dict(os.environ, GRIMOIRE_SELFTEST="1", CARDGAME_IDENTITY=SELFTEST_IDENTITY)
        t0 = time.time()
        try:
            code, _ = run([exe_path], cwd=win_dir, env=env, timeout=180)
        except subprocess.TimeoutExpired:
            die("smoke: executavel nao terminou em 180s (travou?)")
        res_file = os.path.join(sdir, "selftest_result.txt")
        res = open(res_file, encoding="utf-8").read().strip() if os.path.isfile(res_file) else "(sem resultado)"
        crashes = os.path.join(sdir, "crashes")
        log(f"  exit={code} em {time.time() - t0:.1f}s :: {res.splitlines()[0] if res else ''}")
        if code != 0 or not res.startswith("OK"):
            if os.path.isdir(crashes):
                for fn in os.listdir(crashes):
                    log(open(os.path.join(crashes, fn), encoding="utf-8", errors="replace").read()[:4000])
            die("smoke do executavel falhou: " + res[:2000])
        logf = os.path.join(sdir, "logs", "last_session.log")
        if not os.path.isfile(logf):
            die("smoke: release nao gravou logs/last_session.log (print nao foi roteado?)")
        shutil.rmtree(sdir, ignore_errors=True)

        # Caminho de erro do PACOTE: erro induzido -> tela amigavel + crash log.
        env = dict(env, GRIMOIRE_SELFTEST="crash", GRIMOIRE_CRASH_SHOT="1")
        try:
            code, _ = run([exe_path], cwd=win_dir, env=env, timeout=120)
        except subprocess.TimeoutExpired:
            die("smoke crash: tela de erro nao fechou em 120s")
        shot = os.path.join(sdir, "crash_screen.png")
        logs = os.listdir(crashes) if os.path.isdir(crashes) else []
        if code != 1 or not os.path.isfile(shot) or not logs:
            die(f"smoke crash: exit={code} screenshot={os.path.isfile(shot)} crash_logs={len(logs)}")
        shutil.copy2(shot, os.path.join(out_dir, "crash_screen_check.png"))
        shutil.rmtree(sdir, ignore_errors=True)
        log("[6/6] executavel fundido bootou, renderizou o catalogo e abriu as 3 classes; "
            "erro induzido gerou tela amigavel + crash log")
    else:
        log("[6/6] smoke PULADO (--skip-smoke)")

    # relatorio
    cands = unreferenced_report(runtime)
    report = os.path.join(out_dir, "build_report.txt")
    with open(report, "w", encoding="utf-8", newline="\n") as f:
        f.write(f"{GAME_NAME} {version} commit {commit}{' +dirty' if dirty else ''} em {stamp}\n")
        f.write(f"bytecode: {args.bytecode}\n")
        f.write(f".love: {human(os.path.getsize(love_file))}\n")
        f.write(f"windows/: {human(dir_size(win_dir))}\n")
        f.write(f"arquivos de runtime: {len(runtime)} ({len(luas)} .lua)\n\n")
        f.write(f"assets possivelmente sem referencia (heuristica, {len(cands)}):\n")
        for c in cands:
            f.write("  " + c + "\n")
    log(f"\n.love {human(os.path.getsize(love_file))} | windows/ {human(dir_size(win_dir))} "
        f"| {len(cands)} assets candidatos a sem-referencia (ver {report})")
    log("BUILD OK")


if __name__ == "__main__":
    main()
