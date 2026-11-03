set -e
cd "E:/dev/projects/card-game-trailer"
B=build/trailer
V=${1:-main}
n=grimoire_trailer_c13; SHOPV=1
[ "$V" = semloja ] && n=grimoire_trailer_c13_semloja && SHOPV=0
if [ "${SKIP_RENDER:-0}" != 1 ]; then
  TRAILER_SRC="$APPDATA/LOVE/card-game-trailer-c11/trailer" TRAILER_CUT=trailer_c13_cut C13_SHOP=$SHOPV TRAILER_NO_LOUDNORM=1 TRAILER_NO_REVIEW=1 TRAILER_STEM=$B/${n}_music.f32 python tools/trailer_v3.py
  mv -f $B/$n.mp4 $B/${n}_raw.mp4
fi
ffmpeg -v error -y -i $B/${n}_raw.mp4 -vn -c:a pcm_f32le $B/${n}_raw.wav
lim="aresample=192000,alimiter=limit=0.85:attack=1:release=60:level=disabled,aresample=48000"
meas() { ffmpeg -nostats -i "$1" -af ebur128=peak=true -f null - 2>&1 | grep -E "^\s+I:" | tail -1 | awk '{print $2}'; }
I0=$(meas $B/${n}_raw.wav)
G=$(python -c "print(round(-14.0-($I0),2))")
for k in 1 2 3; do
  ffmpeg -v error -y -i $B/${n}_raw.wav -af "volume=${G}dB,$lim" -c:a pcm_f32le $B/${n}_fin.wav
  I=$(meas $B/${n}_fin.wav)
  G=$(python -c "print(round($G+(-14.0-($I)),2))")
  echo "pass $k I=$I next G=$G"
done
ffmpeg -v error -y -i $B/${n}_raw.wav -af "volume=${G}dB,$lim" -c:a pcm_f32le $B/${n}_fin.wav
echo "$G" > $B/${n}_gain.txt
ffmpeg -v error -y -i $B/${n}_raw.mp4 -i $B/${n}_fin.wav -map 0:v -map 1:a -c:v copy -c:a aac -b:a 320k -movflags +faststart $B/$n.mp4
ffmpeg -v error -y -i $B/$n.mp4 -vf "scale=1280:720:flags=lanczos" -c:v libx264 -preset slow -crf 14 -pix_fmt yuv420p -tune animation -c:a copy -movflags +faststart $B/${n}_720p.mp4
rm -f "${B:?}/${n}_raw.wav" "${B:?}/${n}_fin.wav"
echo "[ok] $V gain $G"
