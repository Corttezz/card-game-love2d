extern vec2 mouse;
extern number hover;
extern number time;
extern vec2 cardSize;
extern number quadOn;
extern vec3 hRow0;
extern vec3 hRow1;
extern vec3 hRow2;
extern number silhouette;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec2 uv = vertex_position.xy / cardSize;
    vec2 centered = uv - vec2(0.5);

    float proj = dot(centered, mouse);

    float pressAmount = -proj * hover * 0.12;

    float wobble = sin(time * 2.0 + centered.x * 4.0) * 0.005 * hover
                 + cos(time * 1.7 + centered.y * 4.0) * 0.005 * hover;

    vec2 disp = centered * cardSize * (pressAmount + wobble);
    if (quadOn > 0.5) disp *= (1.0 - uv.y);
    vec2 warped = vertex_position.xy + disp;

    if (quadOn > 0.5) {
        vec3 q = vec3(warped / cardSize, 1.0);
        float w = dot(hRow2, q);
        warped = vec2(dot(hRow0, q), dot(hRow1, q)) / w;
    }

    return transform_projection * vec4(warped, vertex_position.zw);
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
    vec4 t = Texel(tex, uv);
    if (silhouette > 0.5) return vec4(color.rgb, color.a * step(0.5, t.a));
    return t * color;
}
#endif
