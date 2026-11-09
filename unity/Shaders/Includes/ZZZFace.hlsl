#ifndef ZZZ_FACE_INCLUDED
#define ZZZ_FACE_INCLUDED

// 共享脸部模型（两角色源帧共用脸部PS 3969ce67）：
// 顶点控制位→头部相对灯向角度→控制图R/G边界→白/浅/暗三段色调→视距色板→0.96×色调×光色+环境色→美术调节。
// Stencil发影由第二个Pass独立乘色。头部基由ZZZCharacterInputs按角色骨架映射写入。
#include "ZZZArtistControls.hlsl"
#include "ZZZFaceMath.hlsl"

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);
TEXTURE2D(_LightTex);
SAMPLER(sampler_LightTex);

CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST;
    float4 _LightTex_ST;
    float4 _Color;
    float4 _ShallowColor;
    float4 _ShadowColor;
    float4 _FaceShallowColor1;
    float4 _FaceShallowColor2;
    float4 _FaceShadowColor1;
    float4 _FaceShadowColor2;
    float4 _FaceBandWidths;
    float4 _FaceAxisXWS;
    float4 _FaceAxisYWS;
    float4 _FaceAxisZWS;
    float _SourceMipBias;
    float4 _ArtTint;
    float _ArtExposure;
    float _ArtSaturation;
    float4 _ArtShadowTint;
    float _ArtShadowStrength;
    float4 _LightDirection;
    float4 _SourceLightColor;
    float4 _AmbientColor;
    float _SceneAmbientMode;
    float _UseSceneLighting;
    float _ArtLightingMode;
    float _ResponseScale;
    float _DistancePalette;
CBUFFER_END

struct ZZZFaceAttributes
{
    float3 positionOS : POSITION;
    float4 color : COLOR;
    float2 uv0 : TEXCOORD0;
    float2 uv3 : TEXCOORD3;
};

struct ZZZFaceVaryings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float2 uv0 : TEXCOORD1;
    float2 diffuseUV : TEXCOORD2;
    float directionSelector : TEXCOORD3;
    float toneRegionSelector : TEXCOORD4;
    float2 alternateUV : TEXCOORD5;
};

// 顶点色B存编码：bit4选择控制图R；低两位0/1/2或3选择色板0/1/2。
// 先解码再插值，像素按.8/.6阈值选择；不能用材质槽编号替代区域。
ZZZFaceVaryings ZZZFaceVertex(ZZZFaceAttributes input)
{
    ZZZFaceVaryings output;
    VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS);
    uint packedFaceControl = (uint)(saturate(input.color.b) * 255.0 + 0.5);
    output.positionCS = positionInputs.positionCS;
    output.positionWS = positionInputs.positionWS;
    output.uv0 = input.uv0;
    output.diffuseUV = TRANSFORM_TEX(input.uv0, _MainTex);
    output.directionSelector = (packedFaceControl & 16u) != 0u ? 16.0 : 0.0;
    output.toneRegionSelector = 0.9 - 0.2 * (packedFaceControl & 3u);
    output.alternateUV = input.uv3;
    return output;
}

// 控制图采样：bit4取镜像图R，否则取UV4左右回退；G优先取镜像图，越界取模型UV图。
float3 ZZZFaceTone(ZZZFaceVaryings input, float angle)
{
    float4 angleSample = SAMPLE_TEXTURE2D_BIAS(_LightTex, sampler_LightTex, ZZZFaceAngleUV(angle, input.uv0) * _LightTex_ST.xy + _LightTex_ST.zw, _SourceMipBias);
    float4 modelSample = SAMPLE_TEXTURE2D_BIAS(_LightTex, sampler_LightTex, input.uv0 * _LightTex_ST.xy + _LightTex_ST.zw, _SourceMipBias);
    float selectedR = input.directionSelector > 0.5 ? saturate(angleSample.r) : (angle > 0.0 ? input.alternateUV.y : input.alternateUV.x);
    float angleGreen = saturate(angleSample.g);
    float selectedG = angleGreen > 0.4 && angleGreen < 0.95 ? angleGreen : saturate(modelSample.g);
    float bandwidth = ZZZFaceRegionScalar(input.toneRegionSelector, _FaceBandWidths.x, _FaceBandWidths.y, _FaceBandWidths.z);
    float3 weights = ZZZFaceToneWeights(selectedR, selectedG, angle, bandwidth);
    float3 shallow = ZZZFaceRegionColor(input.toneRegionSelector, _ShallowColor.rgb, _FaceShallowColor1.rgb, _FaceShallowColor2.rgb);
    float3 shadow = ZZZFaceRegionColor(input.toneRegionSelector, _ShadowColor.rgb, _FaceShadowColor1.rgb, _FaceShadowColor2.rgb);
    if (_DistancePalette > 0.5)
    {
        float distanceToView = length(GetCurrentViewPosition() - input.positionWS);
        shallow = ZZZFaceDistancePalette(shallow, distanceToView);
        shadow = ZZZFaceDistancePalette(shadow, distanceToView);
    }
    return weights.x + shallow * weights.y + shadow * weights.z;
}

half4 ZZZFaceFragment(ZZZFaceVaryings input) : SV_Target
{
    // 光照来源：捕获模式使用材质中的源光向/光色，场景模式使用URP主光（含距离与阴影衰减）。
    float3 lightDirection = _LightDirection.xyz;
    float3 lightColor = _SourceLightColor.rgb;
    float3 ambient = _AmbientColor.rgb;
    if (ZZZArtUsesSceneLight(_UseSceneLighting, _ArtLightingMode))
    {
        Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS), input.positionWS, half4(1.0, 1.0, 1.0, 1.0));
        lightDirection = mainLight.direction;
        lightColor = mainLight.color * mainLight.distanceAttenuation * mainLight.shadowAttenuation;
        ambient = _SceneAmbientMode > 0.5 ? max(SampleSH(-normalize(_FaceAxisYWS.xyz)), 0.0) : _AmbientColor.rgb;
    }
    float angle = ZZZFaceLightAngle(lightDirection, _FaceAxisXWS.xyz, _FaceAxisYWS.xyz, _FaceAxisZWS.xyz);
    // 主色RGB已由sRGB采样解码；颜色相乘在线性域进行，最后不重复gamma。
    float3 baseColor = SAMPLE_TEXTURE2D_BIAS(_MainTex, sampler_MainTex, input.diffuseUV, _SourceMipBias).rgb * _Color.rgb;
    // 源输出：albedo×(0.96×色调×光色)+环境色×albedo。
    float3 faceColor = baseColor * (_ResponseScale * ZZZFaceTone(input, angle) * lightColor + ambient);
    faceColor = ZZZArtColor(faceColor, _ArtTint.rgb, _ArtExposure, _ArtSaturation);
    return half4(faceColor, 1.0);
}

half4 ZZZFaceShadowFragment(ZZZFaceVaryings input) : SV_Target
{
    // 返回乘数，由第二Pass的Blend DstColor Zero作用到既有颜色，不重复主光/主图。
    float3 shadowColor = ZZZArtShadow(_ShadowColor.rgb, _ArtShadowTint.rgb, _ArtShadowStrength);
    return half4(shadowColor, 1.0);
}

#endif
