extern Image occLm;
extern Image occMask;
extern vec2 maskSize;
extern float erodePx;

float maskAt(vec2 p) {
    return step(0.5, Texel(occMask, p / maskSize).a);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 scene = Texel(tex, uv).rgb;
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
