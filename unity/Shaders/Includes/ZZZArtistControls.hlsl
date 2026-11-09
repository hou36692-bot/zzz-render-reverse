#ifndef ZZZ_ARTIST_CONTROLS_INCLUDED
#define ZZZ_ARTIST_CONTROLS_INCLUDED

// 颜色、曝光与饱和度属于目标美术调节；中性值保留输入颜色，参数沿原材质保存。
float3 ZZZArtColor(float3 color, float3 tint, float exposureStops, float saturation)
{
    if (all(tint == 1.0) && exposureStops == 0.0 && saturation == 1.0)
        return color;
    float3 adjusted = color * tint;
    if (saturation != 1.0)
    {
        float luminance = dot(adjusted, float3(0.212672904, 0.715152204, 0.072175));
        adjusted = lerp(luminance.xxx, adjusted, saturation);
    }
    return max(adjusted, 0.0) * exp2(exposureStops);
}

float3 ZZZArtShadow(float3 originalMultiplier, float3 tint, float strength)
{
    if (all(tint == 1.0) && strength == 1.0)
        return originalMultiplier;
    return lerp(float3(1.0, 1.0, 1.0), originalMultiplier * tint, strength);
}

// 0跟随时钟驱动选择，1使用材质固定光向，2使用场景光；覆盖值不由驱动脚本改写。
bool ZZZArtUsesSceneLight(float runtimeMode, float artistMode)
{
    return artistMode > 1.5 || (artistMode < 0.5 && runtimeMode > 0.5);
}

#endif
