extern number time;
extern number strength;
extern number kind;
extern number anim;
extern vec2 cardSize;

float bayer2(vec2 p) {
    float i = mod(p.x, 2.0) + mod(p.y, 2.0) * 2.0;
    if (i == 0.0) return 0.125;
    if (i == 1.0) return 0.625;
    if (i == 2.0) return 0.875;
    return 0.375;
}

float nearEdge(Image tex, vec2 uv, vec2 ts, float d) {
    float a = 1.0;
    a = min(a, Texel(tex, uv + vec2( d, 0.0) * ts).a);
    a = min(a, Texel(tex, uv + vec2(-d, 0.0) * ts).a);
    a = min(a, Texel(tex, uv + vec2(0.0,  d) * ts).a);
    a = min(a, Texel(tex, uv + vec2(0.0, -d) * ts).a);
    return (a < 0.5) ? 1.0 : 0.0;
}

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
    vec4 base = Texel(tex, uv);
    if (base.a < 0.02 || strength < 0.005) {
        return base * colour;
    }
    vec2 ts = 1.0 / cardSize;
    vec2 px = floor(uv * cardSize);

    float frame = 0.0;
    if (nearEdge(tex, uv, ts, 6.0) > 0.5) frame = 1.0;
    else if (nearEdge(tex, uv, ts, 9.0) > 0.5) frame = 0.5;

    float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
    float hi = (frame <= 0.0 && lum > 0.74) ? 0.7 : 0.0;

    float band = 0.0;
    if (anim > 0.001) {
        float span = cardSize.x + cardSize.y * 0.5 + 60.0;
        float pos = mod(time * 34.0, span) - 30.0;
        float d = (px.x + floor(px.y * 0.5)) - pos;
        float ad = abs(d);
        if (ad < 2.0) band = 1.0;
        else if (ad < 4.0) band = 0.5;
        else if (d < 0.0 && ad < 10.0) {
            float k = 1.0 - (ad - 4.0) / 6.0;
            if (k > bayer2(px)) band = 0.3;
        }
    }

    float amt = strength * (frame * 0.6 + max(frame, hi) * band * anim * 1.2);
    if (amt <= 0.0) return base * colour;

    vec3 tint = (kind < 0.5) ? vec3(0.78, 0.88, 1.0) : vec3(1.0, 0.86, 0.50);
    if (kind > 0.5 && band > 0.0) {
        float h = mod(floor((px.x + px.y * 0.5) / 6.0), 3.0);
        tint = (h == 0.0) ? vec3(1.0, 0.85, 0.45)
             : (h == 1.0) ? vec3(1.0, 0.62, 0.72) : vec3(0.58, 0.95, 0.90);
    }
    vec3 outRgb = min(base.rgb + tint * amt, vec3(1.0));
    return vec4(outRgb, base.a) * colour;
}
