extern Image softLm;
extern Image occLm;
extern Image occMask;
extern vec2 maskSize;
extern float erodePx;
extern float coverOn;
extern vec2 lmSize;

float maskAt(vec2 p) {
    return step(0.5, Texel(occMask, p / maskSize).a);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 sn = Texel(softLm, (floor(uv * lmSize) + 0.5) / lmSize).rgb;
    vec3 soft = Texel(softLm, uv).rgb * step(0.001, max(sn.r, max(sn.g, sn.b)));
    vec3 scene = min(Texel(tex, uv).rgb + soft, vec3(1.0));
    if (coverOn < 0.5) return vec4(scene, 1.0);
    vec3 body = Texel(occLm, uv).rgb;
    float r = erodePx;
    float m = maskAt(sc);
    m = min(m, maskAt(sc + vec2(r, 0.0)));
    m = min(m, maskAt(sc + vec2(-r, 0.0)));
    m = min(m, maskAt(sc + vec2(0.0, r)));
    m = min(m, maskAt(sc + vec2(0.0, -r)));
    m = min(m, maskAt(sc + vec2(r, r)));
    m = min(m, maskAt(sc + vec2(-r, r)));
    m = min(m, maskAt(sc + vec2(r, -r)));
    m = min(m, maskAt(sc + vec2(-r, -r)));
    return vec4(mix(scene, body, m), 1.0);
}
