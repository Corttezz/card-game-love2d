extern number T;
extern Image pal;
extern number trevScale;
extern vec2 texSize;
extern vec2 origin;
extern number sweepP;
extern number pxScale;
extern number tRay0;
extern number tRayStep;
extern number tCharge;
extern number tFlash;

vec3 palAt(float row, float idx) {
    return Texel(pal, vec2((idx + 0.5) / 7.0, (row + 0.5) / 4.0)).rgb;
}

vec3 sweepCol(vec3 c, float s) {
    if (s >= 0.0 && s < 3.0) return vec3(1.0, 0.9725, 0.8863);
    if ((s >= 3.0 && s < 7.0) || (s >= -3.0 && s < 0.0)) return c * 0.5 + vec3(1.0, 0.9255, 0.7059) * 0.5;
    if ((s >= 7.0 && s < 9.0) || (s >= -5.0 && s < -3.0)) return min(vec3(1.0), c * 1.12 + 10.0 / 255.0);
    return c;
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 d = Texel(tex, tc);
    if (d.a < 0.002) return vec4(0.0);
    float idx = floor(d.r * 255.0 + 0.5);
    float g = floor(d.g * 255.0 + 0.5);
    float hub = step(15.5, g);
    float cls = g - 16.0 * hub;
    float b = d.b;
    float a = T - d.a * trevScale;
    if (a < 0.0) return vec4(0.0);
    float lit = 0.0;
    if (cls > 0.5 && cls < 8.5) {
        float ak = T - (tRay0 + (cls - 1.0) * tRayStep) - b * 0.10;
        lit = ak >= 0.11 ? 1.0 : (ak >= 0.045 ? 2.0 : (ak >= 0.0 ? 3.0 : 0.0));
    } else if (cls > 8.5) {
        float ar = T - tCharge - b * 0.22;
        lit = ar >= 0.045 ? 1.0 : (ar >= 0.016 ? 2.0 : (ar >= 0.0 ? 3.0 : 0.0));
    }
    if (hub > 0.5) {
        float ah = T - (tCharge + 0.2);
        if (ah >= 0.06) lit = 1.0;
        else if (ah >= 0.0) lit = 3.0;
    }
    vec3 c = palAt(lit, idx);
    float fl = T - tFlash;
    if (fl >= 0.0 && fl < 0.36) {
        c = palAt(fl < 0.14 ? 3.0 : 2.0, idx);
    }
    if (a < 0.05) c = palAt(3.0, max(idx, 5.0));
    else if (a < 0.13) c = palAt(2.0, idx);
    if (idx > 2.5) {
        vec2 px = floor(tc * texSize) * pxScale + origin;
        c = sweepCol(c, px.x + px.y * 0.55 - sweepP);
    }
    return vec4(c, 1.0) * color;
}
