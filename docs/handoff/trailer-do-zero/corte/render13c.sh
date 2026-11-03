set -e
cd "E:/dev/projects/card-game-trailer"
B=build/trailer
n=grimoire_trailer_c13c
python "E:/dev/projects/card-game-love2d/docs/handoff/trailer-do-zero/corte/build13c_audio.py"
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
if [ "${NO720:-0}" != 1 ]; then
  ffmpeg -v error -y -i $B/$n.mp4 -vf "scale=1280:720:flags=lanczos" -c:v libx264 -preset slow -crf 14 -pix_fmt yuv420p -tune animation -c:a copy -movflags +faststart $B/${n}_720p.mp4
fi
rm -f "${B:?}/${n}_raw.wav" "${B:?}/${n}_fin.wav"
echo "[ok] c13c gain $G"
