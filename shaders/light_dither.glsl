extern number wobbleK;
extern number gain;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 p = uv * 2.0 - 1.0;
    float d2 = dot(p, p);
    if (d2 >= 1.0) discard;
    float wf = step(0.5, color.a);
    float seed = (color.a - 0.5 * wf) / 0.49 * 71.0;
    float wobble = wf * wobbleK;
    float a = atan(p.y, p.x + 1e-5);
    float w = 1.0 + wobble * (0.55 + 0.25 * sin(3.0 * a + seed)
        + 0.12 * sin(5.0 * a + seed * 1.7) + 0.08 * sin(9.0 * a + seed * 2.3));
    float i = clamp(1.0 - d2 * w * w, 0.0, 1.0);
    i = i * i * gain;
    if (i <= 0.0) discard;
    return vec4(color.rgb * i, 1.0);
}
