extern number levels;
extern number cell;
extern number intensity;
extern number upK;

float hash12(vec2 q) {
    return fract(sin(dot(q, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 p = uv * 2.0 - 1.0;
    if (p.y < 0.0) p.y = p.y * max(upK, 1.0);
    float d2 = dot(p, p);
    if (d2 >= 1.0) discard;
    float a = atan(p.y, p.x + 1e-5);
    float w = 1.0 + 0.10 * (0.55 + 0.25 * sin(3.0 * a + 1.3) + 0.12 * sin(5.0 * a + 4.1) + 0.08 * sin(9.0 * a + 2.2));
    float f = clamp(1.0 - d2 * w * w, 0.0, 1.0);
    f = f * f * intensity;
    float n = (hash12(floor(sc / max(cell, 1.0))) - 0.5) / max(levels, 1.0);
    float q = f + n * step(0.0005, f);
    if (q <= 0.0) discard;
    return vec4(color.rgb * q, 1.0);
}
