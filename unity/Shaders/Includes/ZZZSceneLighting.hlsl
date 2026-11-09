#ifndef ZZZ_SCENE_LIGHTING_INCLUDED
#define ZZZ_SCENE_LIGHTING_INCLUDED

// Unity场景光照适配：实际主光、阴影、环境和额外灯；不宣称恢复源游戏光缓冲。
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// URP提供世界方向、颜色/强度、距离/聚光衰减及当前可用阴影图。
Light ZZZGetSceneMainLight(float3 positionWS)
{
    return GetMainLight(TransformWorldToShadowCoord(positionWS), positionWS, half4(1,1,1,1));
}

float3 ZZZLightRadiance(Light light)
{
    return light.color * light.distanceAttenuation * light.shadowAttenuation;
}

// 环境项：源帧角色光照记录里是一组常量环境色（两角色捕获相同）。
// sceneAmbientMode=0 使用材质Profile中的环境色，1 使用场景SH，避免天空盒环境把角色整体抬亮。
float3 ZZZAmbient(float3 normalWS, float3 profileAmbient, float sceneAmbientMode)
{
    return sceneAmbientMode > 0.5 ? max(SampleSH(normalWS), 0.0) : profileAmbient;
}

float3 ZZZAdditionalDiffuse(float3 positionWS, float3 normalWS, float4 positionCS)
{
    InputData inputData = (InputData)0;
    inputData.positionWS = positionWS;
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(positionCS);
    float3 additional = 0.0;
#if defined(_ADDITIONAL_LIGHTS)
#if USE_FORWARD_PLUS
    UNITY_LOOP for (uint lightIndex = 0u; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); ++lightIndex)
    {
        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK
        Light light = GetAdditionalLight(lightIndex, positionWS, half4(1,1,1,1));
        additional += ZZZLightRadiance(light) * saturate(dot(normalWS, light.direction));
    }
#endif
    uint lightCount = GetAdditionalLightsCount();
    LIGHT_LOOP_BEGIN(lightCount)
        Light light = GetAdditionalLight(lightIndex, positionWS, half4(1,1,1,1));
        additional += ZZZLightRadiance(light) * saturate(dot(normalWS, light.direction));
    LIGHT_LOOP_END
#endif
    return additional;
}

float3 ZZZSceneDiffuseIrradiance(float3 positionWS, float3 normalWS, float4 positionCS, float3 profileAmbient, float sceneAmbientMode)
{
    normalWS = normalize(normalWS);
    Light mainLight = ZZZGetSceneMainLight(positionWS);
    return ZZZAmbient(normalWS, profileAmbient, sceneAmbientMode) +
        ZZZLightRadiance(mainLight) * saturate(dot(normalWS, mainLight.direction)) +
        ZZZAdditionalDiffuse(positionWS, normalWS, positionCS);
}

#endif
