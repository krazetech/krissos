#version 440
// The lock clock's liquid glass (LockClock.qml), one pass. The digits, drawn white, are the
// glass's shape; a blur of them (a smaller mip level) is its height. The blurred wallpaper
// behind is seen through it, bent towards the edges like a lens, lifted and tinted with the
// wallpaper's own colour, and lit from above: a soft band along the top edges, a bright rim,
// a faint shadow inside the bottom. Where the wallpaper is light, a soft dark halo keeps the
// time readable. Compiled to glass.frag.qsb with qsb (qt6-shadertools) when the shell is built.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 pixel;    // one pixel, in texture coordinates
    float bend;    // how far the edges bend the wallpaper, in pixels
    float halo;    // 0 to 1: how much dark halo (more on a light wallpaper)
};
layout(binding = 1) uniform sampler2D shape;     // the digits, white on clear, mipmapped
layout(binding = 2) uniform sampler2D backdrop;  // the blurred wallpaper behind, mipmapped

// The height: the digits blurred, nine taps of a finer mip level, so the bevel is smooth.
float height(vec2 uv) {
    float h = 0.0;
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++)
            h += textureLod(shape, uv + vec2(float(x), float(y)) * pixel * 3.0, 2.0).a;
    return h / 9.0;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float a = texture(shape, uv).a;
    vec2 d = pixel * 3.0;
    // Uphill: into the glyph. g.y > 0 on a top edge, < 0 on a bottom one.
    vec2 g = vec2(height(uv + vec2(d.x, 0.0)) - height(uv - vec2(d.x, 0.0)),
                  height(uv + vec2(0.0, d.y)) - height(uv - vec2(0.0, d.y)));
    float h = height(uv);

    vec3 behind = texture(backdrop, uv - g * pixel * bend).rgb;
    // The wallpaper's colour under the clock (its last mip level), lifted to about 70% light.
    vec3 avg = textureLod(backdrop, vec2(0.5), 12.0).rgb;
    float lum = dot(avg, vec3(0.2126, 0.7152, 0.0722));
    vec3 tint = mix(avg, vec3(1.0), clamp((0.7 - lum) / max(0.001, 1.0 - lum), 0.0, 1.0));
    // Mostly light, so the time reads like white text at a glance, with the wallpaper showing
    // through: frosted glass, not grey metal.
    vec3 glass = mix(mix(behind, vec3(1.0), 0.7), tint, 0.16);

    float top = clamp(g.y * 3.0, 0.0, 1.0) * 0.35;
    float bottom = clamp(-g.y * 3.0, 0.0, 1.0) * 0.1;
    float rim = (1.0 - smoothstep(0.3, 0.7, h)) * 0.5;
    vec3 col = clamp(glass + vec3(top + rim) - vec3(bottom), 0.0, 1.0);

    float dark = halo * 0.25 * smoothstep(0.3, 0.6, lum) * smoothstep(0.0, 0.6, h) * (1.0 - a);
    fragColor = vec4(col * a, a + dark) * qt_Opacity;
}
