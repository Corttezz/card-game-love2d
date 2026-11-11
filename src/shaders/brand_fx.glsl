extern Image bayer;
extern number cell;
extern vec2 gridOrigin;
extern vec2 center;
extern vec2 bgCenter;
extern vec2 screenN;
extern number bgAmt;
extern vec4 ringA;
extern vec3 colA;
extern vec4 ringB;
extern vec3 colB;

vec4 ring(vec4 outc, vec4 r, vec3 col, vec2 n, float by) {
    if (r.w < 0.5) return outc;
    float dd = length(n - center);
    if (abs(dd - r.x) <= r.y * 0.5 && by < r.z) return vec4(col, 1.0);
    return outc;
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 n = floor((sc - gridOrigin) / cell);
    float by = Texel(bayer, (mod(n, 4.0) + 0.5) / 4.0).r;
    vec4 outc = vec4(0.0);
    if (bgAmt > 0.0) {
        vec2 q = (n - bgCenter) / (screenN * 0.62);
        float lv = clamp(1.0 - length(q), 0.0, 1.0) * 3.2;
        float k = clamp(floor(lv + by - 0.5), 0.0, 3.0);
        vec3 bc = vec3(9.0, 6.0, 10.0);
        if (k > 2.5) bc = vec3(27.0, 16.0, 35.0);
        else if (k > 1.5) bc = vec3(20.0, 12.0, 26.0);
        else if (k > 0.5) bc = vec3(14.0, 9.0, 17.0);
        outc = vec4(bc / 255.0, bgAmt);
    }
    outc = ring(outc, ringA, colA, n, by);
    outc = ring(outc, ringB, colB, n, by);
    return outc * color;
}
