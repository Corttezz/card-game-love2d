extern Image occLm;
extern Image occMask;
extern vec2 maskSize;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 scene = Texel(tex, uv).rgb;
    vec3 body = Texel(occLm, uv).rgb;
    float m = Texel(occMask, sc / maskSize).a;
    return vec4(mix(scene, body, step(0.5, m)), 1.0);
}
