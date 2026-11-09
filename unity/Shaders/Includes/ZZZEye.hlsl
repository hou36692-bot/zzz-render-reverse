#ifndef ZZZ_EYE_INCLUDED
#define ZZZ_EYE_INCLUDED

// 共享眼部层（两角色源帧共用眼PS 720a454f，与脸部PS同族）：
// COLOR.r索引16×16 Eye_E→主图×眼色→亮度幂响应→脸部同款角度明暗→0.96×响应×光色+环境→预乘覆盖输出。
#include "ZZZArtistControls.hlsl"
#include "ZZZFaceMath.hlsl"

TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
TEXTURE2D(_LightTex); SAMPLER(sampler_LightTex);
Texture2D<float4> _EyeColorMap;

CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST, _LightTex_ST, _Color, _ShallowColor, _ShadowColor;
    float4 _FaceAxisXWS, _FaceAxisYWS, _FaceAxisZWS;
    float4 _LightDirection, _SourceLightColor, _AmbientColor;
    float4 _ArtTint;
    float _Bandwidth, _SourceMipBias, _ResponseScale, _DistancePalette, _PowerResponse;
    float _SceneAmbientMode, _UseSceneLighting, _ArtLightingMode, _ArtExposure, _ArtSaturation;
CBUFFER_END

struct ZZZEyeAttributes
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 color : COLOR;
    float2 uv0 : TEXCOORD0;
    float2 uv3 : TEXCOORD3;
};

struct ZZZEyeVaryings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float2 uv0 : TEXCOORD2;
    float2 controls : TEXCOORD3;   // x: bit4方向选择；y: 保留
    float2 alternateUV : TEXCOORD4;
    float4 eyeTint : TEXCOORD5;    // 顶点查表后插值，不能在像素端重新解码COLOR.r。
};

// COLOR.r不是可见红色：乘255截断，低4位为列、高4位倒序为行；RGB×2，Alpha不变。
float4 ZZZEyeLoadTint(float encodedRed)
{
    uint code = (uint)(encodedRed * 255.0);
    return _EyeColorMap.Load(int3(code & 15u, 15u - (code >> 4u), 0)) * float4(2.0, 2.0, 2.0, 1.0);
}

ZZZEyeVaryings ZZZEyeVertex(ZZZEyeAttributes input)
{
    ZZZEyeVaryings output;
    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    output.uv0 = input.uv0;
    uint packed = (uint)(input.color.b * 255.0 + 0.5);
    output.controls = float2((packed & 16u) != 0u ? 1.0 : 0.0, 0.0);
    output.alternateUV = input.uv3;
    output.eyeTint = ZZZEyeLoadTint(input.color.r);
    return output;
}

// 亮度幂响应：暗侧指数随固有色亮度增大，朝向光源时指数趋近1。
float3 ZZZEyePowerResponse(float3 albedo, float3 interpolatedNormal, float3 direction)
{
    float3 normal = normalize(interpolatedNormal);
    float normalizedProjection = dot(direction, normal);
    float rawProjection = dot(direction, interpolatedNormal);
    float correction = saturate(1.0 - 3.0 * (rawProjection - normalizedProjection));
    correction = min(2.0 * correction * sqrt(correction), 1.0);
    float influence = lerp(saturate(normalizedProjection), normalizedProjection * 0.5 + 0.5, 0.5 * correction);
    float exponent = lerp(dot(albedo, float3(0.29, 0.60, 0.11)) * 0.2875 + 1.4375, 1.0, influence);
    float maximum = max(albedo.r, max(albedo.g, albedo.b));
    float3 bounded = maximum > 1.0 ? albedo / maximum : albedo;
    float3 powered = pow(max(bounded, 0.0), exponent);
    return lerp(0.5 * (albedo + powered), powered, saturate(rawProjection));
}

float4 ZZZEyeFragment(ZZZEyeVaryings input) : SV_Target
{
    float3 lightDirection = _LightDirection.xyz;
    float3 lightColor = _SourceLightColor.rgb;
    float3 ambient = _AmbientColor.rgb;
    if (ZZZArtUsesSceneLight(_UseSceneLighting, _ArtLightingMode))
    {
        Light mainLight = GetMainLight();
        lightDirection = mainLight.direction;
        lightColor = mainLight.color * mainLight.distanceAttenuation;
        ambient = _SceneAmbientMode > 0.5 ? max(SampleSH(normalize(input.normalWS)), 0.0) : _AmbientColor.rgb;
    }
    float angle = ZZZFaceLightAngle(lightDirection, _FaceAxisXWS.xyz, _FaceAxisYWS.xyz, _FaceAxisZWS.xyz);
    float4 ordinary = SAMPLE_TEXTURE2D_BIAS(_LightTex, sampler_LightTex, input.uv0 * _LightTex_ST.xy + _LightTex_ST.zw, _SourceMipBias);
    float4 mirrored = SAMPLE_TEXTURE2D_BIAS(_LightTex, sampler_LightTex, ZZZFaceAngleUV(angle, input.uv0) * _LightTex_ST.xy + _LightTex_ST.zw, _SourceMipBias);
    float red = input.controls.x > 0.5 ? saturate(mirrored.r) : (angle > 0.0 ? input.alternateUV.y : input.alternateUV.x);
    float green = mirrored.g > 0.4 && mirrored.g < 0.95 ? saturate(mirrored.g) : saturate(ordinary.g);
    float3 weights = ZZZFaceToneWeights(red, green, angle, _Bandwidth);
    float3 shallow = _ShallowColor.rgb, shadow = _ShadowColor.rgb;
    if (_DistancePalette > 0.5)
    {
        float distanceToView = length(GetCurrentViewPosition() - input.positionWS);
        shallow = ZZZFaceDistancePalette(shallow, distanceToView);
        shadow = ZZZFaceDistancePalette(shadow, distanceToView);
    }
    float3 tone = weights.x + shallow * weights.y + shadow * weights.z;
    float4 main = SAMPLE_TEXTURE2D_BIAS(_MainTex, sampler_MainTex, input.uv0 * _MainTex_ST.xy + _MainTex_ST.zw, _SourceMipBias);
    float3 albedo = main.rgb * _Color.rgb * input.eyeTint.rgb;
    if (_PowerResponse > 0.5)
        albedo = ZZZEyePowerResponse(albedo, input.normalWS, normalize(lightDirection));
    float3 color = albedo * (_ResponseScale * tone * lightColor + ambient);
    color = ZZZArtColor(color, _ArtTint.rgb, _ArtExposure, _ArtSaturation);
    // 眼色Alpha与主图Alpha相乘得到覆盖，只在输出端预乘一次。
    float coverage = main.a * input.eyeTint.a;
    return float4(color * coverage, coverage);
}

#endif
