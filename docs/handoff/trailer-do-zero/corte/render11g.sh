set -e
cd "E:/dev/projects/card-game-trailer"
B=build/trailer
for v in tirano rei; do
  n=grimoire_trailer_c11g; [ $v = rei ] && n=grimoire_trailer_c11g_rei
  TRAILER_SRC="$APPDATA/LOVE/card-game-trailer-c11/trailer" TRAILER_CUT=trailer_c11g_cut C11_MUSIC=$v TRAILER_NO_LOUDNORM=1 python tools/trailer_v3.py
  j=$(ffmpeg -nostats -i $B/$n.mp4 -af loudnorm=I=-14:TP=-1.0:LRA=20:print_format=json -f null - 2>&1 | sed -n '/{/,/}/p')
  set -- $(echo "$j" | python -c "import sys,json;d=json.load(sys.stdin);print(d['input_i'],d['input_tp'],d['input_lra'],d['input_thresh'],d['target_offset'])")
  ffmpeg -v error -y -i $B/$n.mp4 -c:v copy -af "loudnorm=I=-14:TP=-1.0:LRA=20:measured_I=$1:measured_TP=$2:measured_LRA=$3:measured_thresh=$4:offset=$5:linear=true" -ar 48000 -c:a aac -b:a 320k -movflags +faststart $B/tmp_$n.mp4
  mv -f $B/tmp_$n.mp4 $B/$n.mp4
  I=$(ffmpeg -nostats -i $B/$n.mp4 -af ebur128 -f null - 2>&1 | grep -E "^\s+I:" | tail -1 | awk '{print $2}')
  G=$(python -c "print(round(-14.0-($I),2))")
  ffmpeg -v error -y -i $B/$n.mp4 -c:v copy -af "volume=${G}dB" -c:a aac -b:a 320k -movflags +faststart $B/tmp_$n.mp4
  mv -f $B/tmp_$n.mp4 $B/$n.mp4
  echo "gain $n $I -> $G"
  ffmpeg -v error -y -i $B/$n.mp4 -vf "scale=1280:720:flags=lanczos" -c:v libx264 -preset slow -crf 14 -pix_fmt yuv420p -tune animation -c:a copy -movflags +faststart $B/${n}_720p.mp4
  for x in $n ${n}_720p; do ffmpeg -v error -y -i $B/$x.mp4 -c:v copy -af "aresample=192000,alimiter=limit=0.85:attack=1:release=50:level=disabled,aresample=48000" -c:a aac -b:a 320k -movflags +faststart $B/tmp_$x.mp4 && mv -f $B/tmp_$x.mp4 $B/$x.mp4; done
  echo "[ok] $v"
done
echo DONE
