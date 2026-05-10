// shaders/polychrome.glsl
// Edition "Polychrome" — hue cycle cromático completo, mais saturado e rápido
// que Holo. Usado em cartas raras especiais (×mult).
//
// Diferença vs Holo:
//   • Holo: bandas iridescentes com specular sweep e shimmer FBM (foil cosmico).
//   • Polychrome: hue rotation suave, mais saturada, sem sparkle/shimmer.
//
// Uniforms:
//   time     (number) — segundos
//   strength (number) — 0..1 (default 0.7)

extern number time;
extern number strength;

vec3 phsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
    vec4 base = Texel(tex, uv);
    if (base.a < 0.02 || strength < 0.01) {
        return base * colour;
    }

    // Hue ondulante: combinação de gradient diagonal + radial.
    vec2 cuv = uv - 0.5;
    float r = length(cuv);
    float hue = fract(uv.x * 0.6 + uv.y * 0.4 + time * 0.22 - r * 0.5);

    vec3 rainbow = phsv2rgb(vec3(hue, 0.95, 1.0));

    // Polychrome substitui mais agressivamente que Holo:
    // áreas coloridas viram totalmente policromáticas, áreas escuras menos.
    float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
    float blend = strength * 0.6 * smoothstep(0.05, 0.4, lum);

    vec3 outRgb = mix(base.rgb, rainbow, blend);

    // Saturation boost geral.
    float avg = (outRgb.r + outRgb.g + outRgb.b) / 3.0;
    outRgb = mix(vec3(avg), outRgb, 1.0 + strength * 0.3);
    outRgb = clamp(outRgb, 0.0, 1.4);

    return vec4(outRgb, base.a) * colour;
}
