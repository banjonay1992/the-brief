#include <metal_stdlib>
using namespace metal;

// Water-surface displacement: a drop lands at `origin` and a damped wave
// travels outward, gently offsetting whatever it passes under.
[[ stitchable ]] float2 calmRipple(
    float2 position,
    float2 origin,
    float time,
    float amplitude,
    float frequency,
    float decay,
    float speed
) {
    float dist = length(position - origin);
    float delay = dist / speed;
    float t = max(0.0, time - delay);
    float falloff = exp(-decay * t) * exp(-0.0016 * dist);
    float offsetAmount = amplitude * sin(frequency * t) * falloff;
    float2 direction = dist > 0.5 ? (position - origin) / dist : float2(0.0, 0.0);
    return position + offsetAmount * direction;
}
