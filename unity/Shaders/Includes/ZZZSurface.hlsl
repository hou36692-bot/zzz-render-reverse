#ifndef ZZZ_SURFACE_INCLUDED
#define ZZZ_SURFACE_INCLUDED

// 主线：控制图/TBN法线→五区域七色阶→Matcap/高光/发光→主光与环境→美术调节。
// 两角色源帧共用该表面PS（a24c103a；头发变体050d63a2无Matcap数组）。角色差异只在材质Profile。
TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
TEXTURE2D(_NormalControl); SAMPLER(sampler_NormalControl);
TEXTURE2D(_MaterialControl); SAMPLER(sampler_MaterialControl);
TEXTURE2D(_AuxiliaryControl); SAMPLER(sampler_AuxiliaryControl);
TEXTURE2D_ARRAY(_MatcapArray); SAMPLER(sampler_MatcapArray);
CBUFFER_START(UnityPerMaterial)
float4 _MainTex_ST, _BaseColor;
float4 _LightDirection, _AlternateLightDirection, _SourceLightColor, _AmbientColor;
float4 _Shadow0, _Shadow1, _Shadow2, _Shadow3, _Shadow4;
float4 _Dark0, _Dark1, _Dark2, _Dark3, _Dark4;
float4 _Specular0, _Specular1, _Specular2, _Specular3, _Specular4;
float4 _Emission0, _Emission1, _Emission2, _Emission3, _Emission4;
float4 _RegionSpecular;
float4 _MatcapParameters0, _MatcapParameters1, _MatcapParameters2, _MatcapParameters3, _MatcapParameters4;
float4 _MatcapUVTransform0, _MatcapUVTransform1, _MatcapUVTransform2, _MatcapUVTransform3, _MatcapUVTransform4;
float4 _MatcapOptions0, _MatcapOptions1, _MatcapOptions2, _MatcapOptions3, _MatcapOptions4;
float4 _MatcapTint0, _MatcapTint1, _MatcapTint2, _MatcapTint3, _MatcapTint4;
float _NormalStrength, _MetalStrength, _RoughnessStrength, _BandWidth;
float _SpecularStrength, _EmissionEnabled, _EmissionRemap, _RegionSpecular4;
float _MatcapEnabled, _SurfaceExposure;
float _Opacity, _Cull, _SrcBlend, _DstBlend, _ZWrite;
float _TextureMipBias;
float _DisplayTimeSeconds;
float _UseSceneLighting;
float _ArtExposure, _ArtSaturation, _ArtShadowStrength;
float _ArtSpecularStrength, _ArtMatcapStrength, _ArtEmissionStrength, _ArtLightingMode;
float _TextureVFlip, _SceneAmbientMode;
float4 _ArtTint, _ArtShadowTint;
CBUFFER_END
// 顶点输入准备
struct SurfaceAttributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float4 vertexControl : COLOR;
    float2 primaryUV : TEXCOORD0;
    float2 backFaceUV : TEXCOORD3;
};
struct SurfaceVaryings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float4 tangentWS : TEXCOORD2;
    float4 surfaceUV : TEXCOORD3;
    float4 vertexControl : TEXCOORD4;
    float alternateLight : TEXCOORD5;
};
struct SurfaceSignals
{
    float3 diffuse;
    float3 normalWS;
    float3 lightDirectionWS;
    float3 viewDirectionWS;
    float region;
    float metal;
    float roughness;
    float specularMask;
    float toneBias;
    float emissionMask;
    float matcapMask;
    float matcapRefractionMask;
    float vertexToneMask;
    float alternateLight;
    float2 modelUV;
};
float DecodeAlternateLightVertexFlag(float colorBlue)
{
    uint packedColor = (uint)(colorBlue * 255.0 + 0.5);
    return (packedColor >> 5) & 1u;
}
SurfaceVaryings SurfaceVertex(SurfaceAttributes input)
{
    SurfaceVaryings output;
    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    output.tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz),
        input.tangentOS.w * GetOddNegativeScale());
    output.surfaceUV = float4(TRANSFORM_TEX(input.primaryUV, _MainTex), input.backFaceUV);
    output.vertexControl = input.vertexControl;
    output.alternateLight = DecodeAlternateLightVertexFlag(input.vertexControl.b);
    return output;
}
// 控制法线与切线基底
float3 DecodeControlNormal(float3 encodedNormal)
{
    float2 normalXY = (saturate(encodedNormal.xy) * 2.0 - 1.004) * _NormalStrength;
    return float3(normalXY, sqrt(1.0 - min(dot(normalXY, normalXY), 1.0)));
}
float3 SurfaceNormalFromBasis(SurfaceVaryings input, float2 uv, float3 normalTS, float faceSign)
{
    float3 normalWS = normalize(input.normalWS);
    float3 tangentWS = input.tangentWS.xyz;
    float3 bitangentWS;
    if (dot(tangentWS, tangentWS) > 0.000001 && abs(input.tangentWS.w) > 0.1)
    {
        tangentWS = normalize(tangentWS);
        bitangentWS = cross(normalWS, tangentWS) * input.tangentWS.w;
    }
    else
    {
        float3 positionDx = ddx(input.positionWS), positionDy = ddy(input.positionWS);
        float2 uvDx = ddx(uv), uvDy = ddy(uv);
        float3 perpendicularDy = cross(positionDy, normalWS);
        float3 perpendicularDx = cross(normalWS, positionDx);
        tangentWS = perpendicularDy * uvDx.x + perpendicularDx * uvDy.x;
        bitangentWS = perpendicularDy * uvDx.y + perpendicularDx * uvDy.y;
        float scale = rsqrt(max(max(dot(tangentWS, tangentWS), dot(bitangentWS, bitangentWS)), 0.000001));
        tangentWS *= scale;
        bitangentWS *= scale;
    }
    return normalize(normalTS.x * tangentWS + normalTS.y * bitangentWS + normalTS.z * faceSign * normalWS);
}
// 贴图采样与信号解码
float2 SourceTextureUV(float2 meshUV)
{
    // 导入链不同：解码PNG的V与源相反时置1；直接导入源纹理流时置0。
    return float2(meshUV.x, _TextureVFlip > 0.5 ? 1.0 - meshUV.y : meshUV.y);
}
SurfaceSignals ReadSurfaceSignals(SurfaceVaryings input, float faceSign)
{
    SurfaceSignals output;
    float2 meshUV = faceSign < 0.0 && _Cull < 0.5 ? input.surfaceUV.zw : input.surfaceUV.xy;
    float2 uv = SourceTextureUV(meshUV);
    float4 materialControl = saturate(SAMPLE_TEXTURE2D_BIAS(_MaterialControl, sampler_MaterialControl, uv, _TextureMipBias));
    float4 auxiliaryControl = saturate(SAMPLE_TEXTURE2D_BIAS(_AuxiliaryControl, sampler_AuxiliaryControl, uv, _TextureMipBias));
    float3 normalControl = saturate(SAMPLE_TEXTURE2D_BIAS(_NormalControl, sampler_NormalControl, uv, _TextureMipBias).rgb);
    float3 normalTS = DecodeControlNormal(normalControl);
    output.diffuse = SAMPLE_TEXTURE2D_BIAS(_MainTex, sampler_MainTex, uv, _TextureMipBias).rgb * _BaseColor.rgb;
    output.modelUV = meshUV;
    output.normalWS = SurfaceNormalFromBasis(input, meshUV, normalTS, faceSign);
    output.region = materialControl.r;
    output.metal = materialControl.g * _MetalStrength;
    output.specularMask = materialControl.b;
    output.toneBias = (normalControl.b * 2.0 - 1.0) * 2.0;
    output.roughness = auxiliaryControl.g * _RoughnessStrength;
    output.matcapRefractionMask = auxiliaryControl.r;
    float matcapMask = auxiliaryControl.b;
    if (_EmissionEnabled > 0.5 && _EmissionRemap > 0.5)
        matcapMask = matcapMask <= 0.2 ? min(matcapMask * 5.1, 1.0) : 0.0;
    output.matcapMask = _EmissionRemap > 0.5 ? matcapMask : 1.0;
    output.emissionMask = _EmissionRemap > 0.5 ? max((auxiliaryControl.b - 0.2) * 1.25, 0.0) : auxiliaryControl.b;
    output.alternateLight = input.alternateLight;
    output.vertexToneMask = output.alternateLight > 0.5 ? 0.0 : input.vertexControl.a;
    output.lightDirectionWS = normalize(output.alternateLight > 0.5 ? _AlternateLightDirection.xyz : _LightDirection.xyz);
    output.viewDirectionWS = normalize(GetCameraPositionWS() - input.positionWS);
    return output;
}
// 区域选择与七阶明暗
float3 RegionColor(float region, float3 color0, float3 color1, float3 color2, float3 color3, float3 color4)
{
    float3 result = region < 0.8 ? color1 : color0;
    result = region < 0.6 ? color2 : result;
    result = region < 0.4 ? color3 : result;
    return region < 0.2 ? color4 : result;
}
float RegionScalar(float region, float4 values, float value4)
{
    float result = region < 0.8 ? values.y : values.x;
    result = region < 0.6 ? values.z : result;
    result = region < 0.4 ? values.w : result;
    return region < 0.2 ? value4 : result;
}
float3 SevenBandSurfaceResponse(SurfaceSignals surface, float3 lightColor, float3 dark, float3 shadow)
{
    // 法线点积加顶点控制的垂直修正，再加控制图B偏移，决定当前色调位置。
    float normalLight = dot(surface.normalWS, surface.lightDirectionWS);
    float adjusted = (normalLight + 1.0) * saturate(surface.normalWS.y + 1.5 -
        min(surface.lightDirectionWS.y * 3.0, 1.0) * 0.5) - 1.0;
    float tone = lerp(normalLight, adjusted, surface.vertexToneMask) + surface.toneBias;
    float width = max(_BandWidth, 0.00001);
    float denominator = 2.0 - width * 3.0;
    float3 ramp = float3(tone * 3.0 + 3.0, tone * 3.0 - width * 1.5 + 1.0,
        tone * 3.0 - width * 4.5 - 1.0) / denominator;
    float3 inverseRamp = 1.0 - ramp;
    float3 boundaries = float3((tone + 0.3333) / width + 0.5,
        (tone - 0.3333) / width + 0.5, (tone - 0.3333) / width - 0.5);
    float3 inverseBoundaries = 1.0 - boundaries;
    // 宽区间和窄过渡取min形成七个贡献；这里的色阶不是七个解剖部位。
    float darkWeight = saturate(inverseRamp.x);
    float shadowWeight = saturate(min(ramp.x, inverseBoundaries.x));
    float transitionWeight = saturate(min(inverseRamp.y, boundaries.x));
    float midWeight = saturate(min(boundaries.y, inverseBoundaries.z));
    float litTransitionWeight = saturate(min(ramp.y, inverseBoundaries.y));
    float litWeight = saturate(min(inverseRamp.z, boundaries.z));
    float brightWeight = saturate(ramp.z);
    float3 response = darkWeight * float3(0.776000023,0.75999999,0.800000012) * dark;
    response += shadowWeight * float3(0.800000012,0.720000029,0.748387098) * shadow;
    response += transitionWeight * float3(1,0.949999988,0.966000021) * shadow;
    response += midWeight * float3(1,0.985000014,0.920000017);
    response += litTransitionWeight * float3(1,0.875,0.850000024);
    response += litWeight * float3(0.702528715,0.674117684,0.749019623);
    response += brightWeight * float3(1,0.949999988,0.966000021);
    return response * lightColor;
}
// 五区域阴影色
void ResolveSurfaceRegionColors(SurfaceSignals surface, out float3 resolvedDark, out float3 resolvedShadow)
{
    float3 dark = RegionColor(surface.region, _Dark0.rgb, _Dark1.rgb, _Dark2.rgb, _Dark3.rgb, _Dark4.rgb);
    float3 shadow = RegionColor(surface.region, _Shadow0.rgb, _Shadow1.rgb, _Shadow2.rgb, _Shadow3.rgb, _Shadow4.rgb);
    if (abs(_ArtShadowStrength - 1.0) > 0.000001 ||
        any(abs(_ArtShadowTint.rgb - float3(1.0, 1.0, 1.0)) > 0.000001))
    {
        dark = ZZZArtShadow(dark, _ArtShadowTint.rgb, _ArtShadowStrength);
        shadow = ZZZArtShadow(shadow, _ArtShadowTint.rgb, _ArtShadowStrength);
    }
    resolvedDark = dark;
    resolvedShadow = shadow;
}
// Matcap array 采样与混合
float3 ApplySourceMatcap(SurfaceSignals surface)
{
    // 各区域选择数组切片、UV变换与混合模式；视空间法线产生基础Matcap坐标。
    float4 parameters = surface.region >= 0.8 ? _MatcapParameters0 :
        surface.region >= 0.6 ? _MatcapParameters1 :
        surface.region >= 0.4 ? _MatcapParameters2 :
        surface.region >= 0.2 ? _MatcapParameters3 : _MatcapParameters4;
    float4 options = surface.region >= 0.8 ? _MatcapOptions0 :
        surface.region >= 0.6 ? _MatcapOptions1 :
        surface.region >= 0.4 ? _MatcapOptions2 :
        surface.region >= 0.2 ? _MatcapOptions3 : _MatcapOptions4;
    float4 uvTransform = surface.region >= 0.8 ? _MatcapUVTransform0 :
        surface.region >= 0.6 ? _MatcapUVTransform1 :
        surface.region >= 0.4 ? _MatcapUVTransform2 :
        surface.region >= 0.2 ? _MatcapUVTransform3 : _MatcapUVTransform4;
    float3 tint = RegionColor(surface.region, _MatcapTint0.rgb, _MatcapTint1.rgb,
        _MatcapTint2.rgb, _MatcapTint3.rgb, _MatcapTint4.rgb);
    if (_MatcapEnabled < 0.5 || parameters.x >= 50.0) return surface.diffuse;
    float3 normalVS = mul((float3x3)UNITY_MATRIX_V, surface.normalWS);
    float2 matcapUV = normalVS.xy * 0.5 + 0.5;
    if (options.z > 0.5)
    {
        float2 baseUV = surface.modelUV * uvTransform.xy + uvTransform.zw;
        matcapUV = baseUV + surface.matcapRefractionMask * options.w * matcapUV;
    }
    matcapUV += _DisplayTimeSeconds * float2(parameters.w, options.x);
    float4 sample = SAMPLE_TEXTURE2D_ARRAY(_MatcapArray, sampler_MatcapArray, matcapUV, parameters.x);
    float3 matcap = sample.rgb * tint;
    float weight = saturate(surface.matcapMask * sample.a * parameters.z);
    if (options.y < 0.5)
        return lerp(surface.diffuse, matcap * parameters.y, weight);
    if (options.y < 1.5)
        return surface.diffuse + matcap * parameters.y * weight;
    float3 overlay = saturate((matcap - 0.5) * parameters.y + matcap);
    overlay = lerp(float3(0.5,0.5,0.5), overlay, weight);
    float3 multiplied = 2.0 * surface.diffuse * overlay;
    float3 screened = 1.0 - 2.0 * (1.0 - surface.diffuse) * (1.0 - overlay);
    return lerp(multiplied, screened, step(0.5, surface.diffuse));
}

float3 SurfaceDiffuseWithMatcap(SurfaceSignals surface)
{
    float3 diffuse = ApplySourceMatcap(surface);
    if (abs(_ArtMatcapStrength - 1.0) > 0.000001)
        diffuse = lerp(surface.diffuse, diffuse, _ArtMatcapStrength);
    return diffuse;
}
// 高光响应
float3 SourceSurfaceSpecular(SurfaceSignals surface, float3 diffuse)
{
    // 粗糙度控制高光峰形，N/H、L/H控制方向响应；材质遮罩与区域颜色限定贡献。
    float roughnessSquared = pow(1.0 - surface.roughness, 2.0);
    float roughnessFourth = roughnessSquared * roughnessSquared;
    float3 halfDirection = normalize(surface.viewDirectionWS + surface.lightDirectionWS);
    float normalHalf = saturate(dot(surface.normalWS, halfDirection) * 0.75 + 0.25);
    float lightHalf = max(pow(saturate(dot(surface.lightDirectionWS, halfDirection) * 0.75 + 0.25), 2.0), 0.1);
    float denominator = pow(normalHalf * normalHalf * (roughnessFourth - 1.0) + 1.00001, 2.0);
    float highlight = roughnessFourth / max((roughnessSquared * 4.0 + 2.0) * lightHalf * denominator, 0.00001);
    highlight = saturate(highlight - surface.roughness) *
        saturate(dot(surface.normalWS, surface.lightDirectionWS) * 0.75 + 0.25) / max(roughnessSquared, 0.00001);
    float strength = RegionScalar(surface.region, _RegionSpecular, _RegionSpecular4);
    float3 specularColor = RegionColor(surface.region, _Specular0.rgb, _Specular1.rgb,
        _Specular2.rgb, _Specular3.rgb, _Specular4.rgb);
    float3 reflectance = lerp(float3(0.04,0.04,0.04), diffuse, surface.metal);
    return specularColor * reflectance * surface.specularMask * _SpecularStrength * saturate(highlight * strength * 10.0) * 100.0;
}

// 场景光照输入
#include "ZZZSceneLighting.hlsl"
// 捕获与场景光照分支
float3 EvaluateSurfaceLighting(inout SurfaceSignals surface, SurfaceVaryings input, float3 diffuse, float3 dark, float3 shadow)
{
    // 场景路径使用实际URP主光/阴影/SH；固定方向路径保留已使用的材质输入。
    float3 output;
    bool useSceneLighting = ZZZArtUsesSceneLight(_UseSceneLighting, _ArtLightingMode);
    if (useSceneLighting)
    {
        Light mainLight = ZZZGetSceneMainLight(input.positionWS);
        surface.lightDirectionWS = dot(mainLight.direction, mainLight.direction) > 0.000001 ?
            normalize(mainLight.direction) : float3(0,1,0);
        float3 radiance = ZZZLightRadiance(mainLight);
        float3 ambient = ZZZAmbient(surface.normalWS, _AmbientColor.rgb, _SceneAmbientMode);
        output = diffuse * (1.0 - surface.metal) * 0.96 * SevenBandSurfaceResponse(surface, radiance, dark, shadow);
        float3 specular = SourceSurfaceSpecular(surface, diffuse);
        if (abs(_ArtSpecularStrength - 1.0) > 0.000001) specular *= _ArtSpecularStrength;
        output += diffuse * ambient + specular * radiance;
        output += diffuse * ZZZAdditionalDiffuse(input.positionWS, surface.normalWS, input.positionCS);
    }
    else
    {
        float3 capturedLightColor = _SourceLightColor.rgb;
        output = diffuse * (1.0 - surface.metal) * 0.96 *
            SevenBandSurfaceResponse(surface, capturedLightColor, dark, shadow);
        float3 specular = SourceSurfaceSpecular(surface, diffuse);
        if (abs(_ArtSpecularStrength - 1.0) > 0.000001) specular *= _ArtSpecularStrength;
        output += diffuse * _AmbientColor.rgb + specular;
    }
    return output;
}
// 发光叠加
void AddSurfaceEmission(SurfaceSignals surface, float3 diffuse, inout float3 output)
{
    float3 emissionColor = RegionColor(surface.region, _Emission0.rgb, _Emission1.rgb,
        _Emission2.rgb, _Emission3.rgb, _Emission4.rgb);
    float emissionStrength = abs(_ArtEmissionStrength - 1.0) > 0.000001 ? _ArtEmissionStrength : 1.0;
    output += diffuse * emissionColor * surface.emissionMask * _EmissionEnabled * emissionStrength;
}
// 表面片元合成
float4 SurfaceFragment(SurfaceVaryings input, FRONT_FACE_TYPE frontFace : FRONT_FACE_SEMANTIC) : SV_Target
{
    // 正反面UV和法线解码后才求材质响应；不要靠统一曝光替代前面各模块计算。
    SurfaceSignals surface = ReadSurfaceSignals(input, IS_FRONT_VFACE(frontFace, 1.0, -1.0));
    float3 diffuse = SurfaceDiffuseWithMatcap(surface);

    float3 dark;
    float3 shadow;
    ResolveSurfaceRegionColors(surface, dark, shadow);

    float3 output = EvaluateSurfaceLighting(surface, input, diffuse, dark, shadow);

    AddSurfaceEmission(surface, diffuse, output);

    if (abs(_ArtExposure) > 0.000001 || abs(_ArtSaturation - 1.0) > 0.000001 ||
        any(abs(_ArtTint.rgb - float3(1.0, 1.0, 1.0)) > 0.000001))
        output = ZZZArtColor(output, _ArtTint.rgb, _ArtExposure, _ArtSaturation);
    return float4(max(output, 0.0) * exp2(_SurfaceExposure), _Opacity);
}

#endif
