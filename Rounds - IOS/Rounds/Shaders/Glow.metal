#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Home backdrop: three soft colour fields drifting over the background colour.
// Each field is a Gaussian falloff around a moving centre; fields blend additively
// in linear-ish space, then a touch of blue-noise-style grain breaks up banding.

static float hash(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

static float field(float2 uv, float2 centre, float radius) {
    float2 d = uv - centre;
    return exp(-dot(d, d) / (radius * radius));
}

[[ stitchable ]] half4 glowField(float2 position, half4 currentColor,
                                 float2 size, float time,
                                 half4 colorA, half4 colorB, half4 colorC,
                                 half4 background, float intensity, float speed) {
    // Normalise to width so fields stay round on any aspect ratio.
    float2 uv = position / size.x;
    float aspect = size.y / size.x;

    // All three fields ride one infinity loop (lemniscate of Gerono: x = cos t, y = sin t · cos t)
    // across the top of the screen, spaced a third of a loop apart. One loop ≈ 10s at speed 1.
    float s = time * speed * 0.63;
    float2 loopCentre = float2(0.5, 0.16 * aspect);
    float2 loopSize   = float2(0.38, 0.22 * aspect);
    float third = 2.0943951;   // 2π / 3
    float ta = s, tb = s + third, tc = s + 2.0 * third;
    float2 a = loopCentre + loopSize * float2(cos(ta), sin(ta) * cos(ta));
    float2 b = loopCentre + loopSize * float2(cos(tb), sin(tb) * cos(tb));
    float2 c = loopCentre + loopSize * float2(cos(tc), sin(tc) * cos(tc));

    // Fields breathe: each radius swells and shrinks ~15%.
    float fa = field(uv, a, 0.42 * (1.0 + 0.15 * sin(s * 0.83)));
    float fb = field(uv, b, 0.40 * (1.0 + 0.15 * sin(s * 0.97 + 1.0)));
    float fc = field(uv, c, 0.38 * (1.0 + 0.15 * sin(s * 0.71 + 2.0)));

    // Glow lives in the top of the screen only; the lower half stays the plain background.
    float y = uv.y / aspect;                       // 0 at top, 1 at bottom
    float topMask = 1.0 - smoothstep(0.28, 0.52, y);
    fa *= topMask; fb *= topMask; fc *= topMask;

    float3 col = float3(background.rgb);
    col = mix(col, float3(colorA.rgb), clamp(fa * intensity, 0.0, 1.0));
    col = mix(col, float3(colorB.rgb), clamp(fb * intensity, 0.0, 1.0));
    col = mix(col, float3(colorC.rgb), clamp(fc * intensity, 0.0, 1.0));

    // ±0.5/255 grain: invisible as texture, removes gradient banding.
    col += (hash(position + fract(time)) - 0.5) / 255.0;

    return half4(half3(col), 1.0);
}
