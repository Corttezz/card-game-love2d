extern number time;
extern number mid_flash;

vec4 effect(vec4 colour, Image texture, vec2 tc, vec2 sc) {
    if (mid_flash <= 0.001) discard;

    vec2 res = love_ScreenSize.xy;
    vec2 uv = (sc - 0.5 * res) / max(res.x, res.y);
    float r = length(uv);

    float ring = 0.0;
    if (time > 0.0) {
        float ringR = clamp(time * 0.55, 0.0, 0.9);
        float thick = 0.18;
        ring = smoothstep(ringR + thick, ringR, r) * (1.0 - smoothstep(ringR + 2.0 * thick, ringR + thick, r));
        ring *= 0.5;
    }

    float center = 1.0 - smoothstep(0.0, 0.7, r);

    float a = mid_flash * (0.55 + 0.45 * center) + ring * mid_flash;
    a = clamp(a, 0.0, 1.0);

    return vec4(1.0, 1.0, 1.0, a);
}
