// shaders/boot_warp.glsl — deformação de SUCÇÃO da entrada (v4, Jul/2026).
// Warpa a imagem-base (câmara de pedra) em torno do centro: giro (swirl) +
// contração (pinch) que cresce perto do miolo. Assim o PRÓPRIO fundo parece
// ser sugado/rodado pra dentro do buraco — animação suave, sem flicker (é só
// distorção de UV de UMA imagem estável). Dirigido por `intensity` 0..1.
//
// `t` deve ser um tempo LIMITADO (splashTime 0..~4), não love.timer.getTime()
// (grande demais → o centro enrola infinito e vira borrão).

extern number intensity;   // 0..1 (quanto o buraco está aberto)
extern number t;           // tempo do splash (bounded)

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 c = vec2(0.5, 0.5);
    vec2 d = uv - c;
    float r = length(d);
    float maxR = 0.72;
    float frac = clamp(1.0 - r / maxR, 0.0, 1.0);
    float f2 = frac * frac;                 // concentra o efeito no miolo

    // SWIRL: só perto do centro (f2), cresce com intensity e gira devagar no tempo.
    float twist = f2 * (intensity * 2.6 + t * intensity * 0.5);
    float s = sin(twist);
    float co = cos(twist);
    vec2 rd = vec2(d.x * co - d.y * s, d.x * s + d.y * co);

    // PINCH: amostra mais longe do centro perto do miolo → a imagem CONTRAI
    // pra dentro (sensação de sucção).
    float pinch = 1.0 + intensity * 0.55 * f2;
    rd *= pinch;

    vec2 nuv = c + rd;
    return Texel(tex, clamp(nuv, 0.0, 1.0)) * color;
}
