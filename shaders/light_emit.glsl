extern number levels;
extern number cell;
extern number intensity;
extern number upK;

float bayer4(vec2 sc) {
    int x = int(mod(sc.x, 4.0));
    int y = int(mod(sc.y, 4.0));
    int i = x + y * 4;
    if (i ==  0) return 0.0625;
    if (i ==  1) return 0.5625;
    if (i ==  2) return 0.1875;
    if (i ==  3) return 0.6875;
    if (i ==  4) return 0.8125;
    if (i ==  5) return 0.3125;
    if (i ==  6) return 0.9375;
    if (i ==  7) return 0.4375;
    if (i ==  8) return 0.25;
    if (i ==  9) return 0.75;
    if (i == 10) return 0.125;
    if (i == 11) return 0.625;
    if (i == 12) return 1.0;
    if (i == 13) return 0.5;
    if (i == 14) return 0.875;
    return 0.375;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 p = uv * 2.0 - 1.0;
    if (p.y < 0.0) p.y = p.y * max(upK, 1.0);
    float f = clamp(1.0 - dot(p, p), 0.0, 1.0);
    f = f * f;
    float q = floor(f * levels + bayer4(floor(sc / max(cell, 1.0)))) / levels;
    if (q <= 0.0) discard;
    return vec4(color.rgb * q * intensity, 1.0);
}
