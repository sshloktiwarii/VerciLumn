#include <metal_stdlib>
using namespace metal;

// 1. Metal Compute Kernel for direct offscreen texture pipelines
kernel void fisheyeDistortion(texture2d<float, access::read> inTexture [[texture(0)]],
                             texture2d<float, access::write> outTexture [[texture(1)]],
                             constant float2 &center [[buffer(0)]],
                             constant float &radius [[buffer(1)]],
                             constant float &strength [[buffer(2)]],
                             uint2 gid [[thread_position_in_grid]]) {
    
    float2 size = float2(inTexture.get_width(), inTexture.get_height());
    if (gid.x >= uint(size.x) || gid.y >= uint(size.y)) {
        return;
    }
    
    float2 uv = float2(gid) / size;
    float2 delta = uv - center;
    float dist = length(delta);
    
    if (dist < radius && radius > 0.0001) {
        float percent = dist / radius;
        float distortion = pow(percent, strength);
        float2 distortedUV = center + normalize(delta) * distortion * radius;
        uint2 readCoords = uint2(clamp(distortedUV * size, float2(0.0), size - 1.0));
        outTexture.write(inTexture.read(readCoords), gid);
    } else {
        outTexture.write(inTexture.read(gid), gid);
    }
}

// 2. Stitchable Distortion Shader for SwiftUI (macOS 14+ .distortionEffect)
// Convex spherical lens magnification centered on active word
[[ stitchable ]] float2 fisheyeDistortionEffect(float2 position, float2 center, float radius, float strength) {
    float2 delta = position - center;
    float dist = length(delta);
    if (dist < radius && radius > 0.0001f) {
        float percent = dist / radius;
        // Smooth spherical bulging
        float distortion = pow(percent, max(strength, 0.001f));
        return center + normalize(delta) * distortion * radius;
    }
    return position;
}

// 3. Stitchable Color Effect for Fluid Aurora (macOS 14+ .colorEffect)
[[ stitchable ]] half4 fluidAuroraColor(float2 position, half4 inColor, float time, float bass, half4 primaryColor, half4 secondaryColor) {
    float2 uv = position * 0.002f;
    
    float wave1 = sin(uv.x * 2.5f + time * 0.8f) * cos(uv.y * 1.8f - time * 0.5f);
    float wave2 = sin(uv.y * 3.0f + time * 1.2f + wave1 * 2.0f);
    float wave3 = cos((uv.x + uv.y) * 2.0f - time * 0.9f) * sin(uv.x * 4.0f);
    
    float intensity = clamp((wave1 + wave2 + wave3) * 0.33f + 0.5f + (bass * 0.35f), 0.0f, 1.0f);
    
    half4 blendColor = mix(primaryColor, secondaryColor, half(intensity));
    half alpha = half(clamp(intensity * 0.65f + (bass * 0.25f), 0.0f, 0.95f));
    return half4(blendColor.rgb * alpha, alpha);
}
