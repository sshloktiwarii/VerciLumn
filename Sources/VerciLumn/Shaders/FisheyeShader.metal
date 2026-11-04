#include <metal_stdlib>
using namespace metal;

// 1. Metal Compute Kernel for direct texture pipelines
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

// 2. Stitchable Shader for SwiftUI (macOS 14+ distortionEffect)
[[ stitchable ]] float2 fisheyeDistortionEffect(float2 position, float2 center, float radius, float strength) {
    float2 delta = position - center;
    float dist = length(delta);
    if (dist < radius && radius > 0.0001) {
        float percent = dist / radius;
        float distortion = pow(percent, max(strength, 0.001f));
        return center + normalize(delta) * distortion * radius;
    }
    return position;
}
