extern number t;
extern vec2 moon_center;
extern number moon_radius;
extern vec2 art_off;
extern number art_scale;
extern number sky_limit;

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 sc) {
    vec4 px = Texel(tex, uv);

    number lum = dot(px.rgb, vec3(0.35, 0.5, 0.15));
    number hi = smoothstep(0.60, 0.85, lum);

    number dm = length(sc - moon_center) / max(moon_radius, 1.0);
    number outside_moon = smoothstep(0.95, 1.30, dm);

    vec2 ap = floor((sc - art_off) / max(art_scale, 0.001));
    number sky = 1.0 - smoothstep(sky_limit - 6.0, sky_limit + 2.0, ap.y);

    number ph = fract(sin(dot(ap, vec2(12.9898, 78.233))) * 43758.5453);
    number tw = 0.5 + 0.5 * sin(t * (1.2 + 2.6 * ph) + ph * 6.2831);

    vec3 add = px.rgb * (hi * outside_moon * sky * tw * 0.9);
    return vec4(add, 1.0) * colour;
}
