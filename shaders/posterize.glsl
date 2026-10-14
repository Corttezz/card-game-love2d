extern number levels;
extern number block;

float bayer2(float x, float y) {
    return (3.0 * y + (2.0 - 4.0 * y) * x) / 4.0;
}

float bayer4(vec2 p) {
    vec2 q = floor(p / max(block, 1.0));
    float x0 = mod(q.x, 2.0), y0 = mod(q.y, 2.0);
    float x1 = mod(floor(q.x / 2.0), 2.0), y1 = mod(floor(q.y / 2.0), 2.0);
    return (bayer2(x0, y0) * 4.0 + bayer2(x1, y1)) / 4.0;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 c = Texel(tex, uv);
    float d = bayer4(sc) - 0.5;
    float L = max(levels, 1.0);
    c.rgb = floor(c.rgb * L + d + 0.5) / L;
    c.a   = floor(c.a   * L + d + 0.5) / L;
    return c * color;
}
