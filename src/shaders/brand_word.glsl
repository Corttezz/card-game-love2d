extern Image goldMask;
extern vec2 texSize;
extern vec2 origin;
extern number sweepP;
extern number whiteMix;
extern number boost;

vec3 sweepCol(vec3 c, float s) {
    if (s >= 0.0 && s < 3.0) return vec3(1.0, 0.9725, 0.8863);
    if ((s >= 3.0 && s < 7.0) || (s >= -3.0 && s < 0.0)) return c * 0.5 + vec3(1.0, 0.9255, 0.7059) * 0.5;
    if ((s >= 7.0 && s < 9.0) || (s >= -5.0 && s < -3.0)) return min(vec3(1.0), c * 1.12 + 10.0 / 255.0);
    return c;
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 p = Texel(tex, tc);
    vec3 c = p.rgb;
    if (Texel(goldMask, tc).a > 0.5) {
        c = mix(c, vec3(1.0, 0.9725, 0.8863), whiteMix);
        c = min(vec3(1.0), c * (1.0 + 0.15 * boost) + boost * 18.0 / 255.0);
        vec2 px = floor(tc * texSize) + origin;
        c = sweepCol(c, px.x + px.y * 0.55 - sweepP);
    }
    return vec4(c, p.a) * color;
}
