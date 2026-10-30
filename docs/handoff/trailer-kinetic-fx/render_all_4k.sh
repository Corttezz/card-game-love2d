K=/e/dev/_orquestracao/skills-externas/kinetic-film
PY=$K/venv/Scripts/python.exe
T=/e/dev/projects/card-game-trailer/build/trailer
M=/e/dev/projects/card-game-love2d/tools/trailer_kinetic_metrics.py
run() {
  film=$1; edl=$2; beats=$3; dest=$4; review=$5; fin=$6
  cd $K/$film || exit 1
  s=$(date +%s)
  $PY kscripts/layer.py . 4 > out/render4k.log 2>&1 && $PY kscripts/mixdown.py . >> out/render4k.log && $PY kscripts/compose.py . --res 4k >> out/render4k.log 2>&1 || { echo "$film RENDER FAIL"; return 1; }
  e=$(date +%s); echo "$film RENDER4K_SECONDS $((e-s))" | tee -a out/render4k.log
  rm -rf out/final4k
  $PY /c/Users/corte/.claude/skills/scenario-kinetic-film/scripts/finish.py . --video out/video_4k.mp4 --audio out/mix.wav --no-vertical --dest out/final4k > out/finish4k.log 2>&1
  cp out/final4k/${fin}_4k60.mp4 $T/$dest.mp4 && cp out/final4k/${fin}_1080p60.mp4 $T/${dest}_1080p.mp4 || { echo "$film COPY FAIL"; return 1; }
  mkdir -p $T/kinetic/$review
  $PY -I $M $T/$dest.mp4 --edl $T/kinetic/$edl --beats $T/music/$beats --trim 0 --spec spec.js --sources out/mix_sources.json --layer out/layer --json $T/kinetic/$review/metrics.json --sheet $T/kinetic/$review/contact_sheet.jpg > out/metrics4k.log 2>&1
  echo "$film DONE"
}
run grimoire_a A_edl.json boss-abyss_tyrant_beats.json grimoire_kinetic_hook30 A_review grimoire-kinetic-hook30
run grimoire_b B_edl.json boss-carrion_king_beats.json grimoire_kinetic_new B_review grimoire-kinetic-new
run grimoire_c C2_edl.json boss-carrion_king_beats.json grimoire_trailer_v9_kinetic v9_review grimoire-trailer-v9-kinetic
echo ALL_DONE
