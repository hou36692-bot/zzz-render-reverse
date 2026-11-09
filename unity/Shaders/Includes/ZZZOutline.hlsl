#ifndef ZZZ_OUTLINE_INCLUDED
#define ZZZ_OUTLINE_INCLUDED

#include "ZZZArtistControls.hlsl"

// 材质常量沿用现有 UnityPerMaterial 字段顺序和 float 精度。
CBUFFER_START(UnityPerMaterial)
float4 _OutlineColor;
float4 _OutlineColor1, _OutlineColor2, _OutlineColor3, _OutlineColor4;
float4 _MainTex_ST;
float _TextureMipBias;
float _SourceMetalStrength;
float4 _LightDirection, _AlternateLightDirection, _SourceLightColor, _AmbientColor, _OutlineLightTint;
float _UseSceneLighting;
float _Frame01ProjectionScale;
float4 _Frame01ViewportCorrection;
float _Frame01WidthScale;
float _Frame01ProjectionOffsetScale;
float _Frame01DepthOffsetScale;
float _UseTEXCOORD4ProjectionAnchor;
float _SrcBlend;
float _DstBlend;
float _ZWrite;
float _Cull;
float _ZTest;
float _StencilRef;
float _StencilComp;
float _StencilPass;
float4 _ArtOutlineTint;
float _ArtOutlineWidth;
float _ArtOutlineStrength;
float _ArtLightingMode;
float _RegionFromVertex;
float _TextureVFlip;
float _SceneAmbientMode;
CBUFFER_END

TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
TEXTURE2D(_MaterialControl); SAMPLER(sampler_MaterialControl);

// 顶点输入沿用原 TEXCOORD 布局和精度；UV1 携带带符号的平滑法线 XY。
struct ZZZOutlineAttributes
{
    float3 positionOS : POSITION;                 // 源顶点的物体空间位置。
    float3 normalOS : NORMAL;                     // 用于着色的物体空间法线。
    float4 tangentOS : TANGENT;                   // 物体空间切线及其左右手方向。
    float4 vertexColor : COLOR;                   // R 控制描边宽度；G 提供带符号的深度信号；B 编码光向选择标记。
    float2 uv0 : TEXCOORD0;                       // 源纹理与材质控制图使用的 UV；顶点入口会翻转图像的 V 方向。
    float2 uv1SmoothNormal : TEXCOORD1;           // 切线空间平滑法线的带符号 XY；不重映射，也不翻转。
    float4 projectionPositionTEXCOORD4 : TEXCOORD4; // 可选的源投影锚点；当前导入网格不含此通道。
};

// 插值器语义和字段顺序沿用精简前的描边 Pass。
struct ZZZOutlineVaryings
{
    float4 positionCS : SV_POSITION;              // 已投影并按描边宽度扩张的裁剪空间位置。
    float2 uv0 : TEXCOORD0;                        // 已翻转的材质控制图与漫反射图 UV。
    float4 vertexColor : TEXCOORD2;                // 插值后的源顶点信号。
    float3 smoothNormalWS : TEXCOORD3;             // 描边光照使用的世界空间法线。
    float alternateLight : TEXCOORD4;              // 从顶点色 B 提取并插值的光向选择标记。
    float vertexRegion : TEXCOORD5;                // 脸部描边：顶点色B低两位解码的色板选择值（.9/.7/.5/.3）。
};

// 直接读取 DXBC v5.xy：UV1 已是带符号的切线空间 XY，不从 0–1 重映射。
float3 DecodeSmoothNormalFromUV1(float2 uv1, float3 normalOS, float4 tangentOS)
{
    float2 normalXY = uv1;
    float normalZ = sqrt(1.0 - min(dot(normalXY, normalXY), 1.0));
    float3 tangent = normalize(tangentOS.xyz);
    float3 normal = normalize(normalOS);
    float3 bitangent = cross(normal, tangent) * tangentOS.w;
    return normalize(tangent * normalXY.x + bitangent * normalXY.y + normal * normalZ);
}

// 顶点数据：COLOR.r 控制宽度，UV1 提供带符号平滑法线 XY；宽度单位为视空间单位。
// 保持 VS3dc9820 的运算顺序与常量，包括 CB0[88].y/.w 修正。
float SourceOutlineWidth(float projectedDepth, float vertexColorRed)
{
    float3 depthBands = saturate(
        projectedDepth * float3(10.0, 1.0, 0.5) + float3(0.0, -0.1, -1.05));
    float width = depthBands.x * 0.00105;
    float segment = -depthBands.x * 0.00105 + 0.005;
    width = depthBands.y * segment + width;
    segment = -width + 0.0035;
    width = depthBands.z * segment + width;
    segment = _Frame01ViewportCorrection.y * 0.005 - width;
    width = _Frame01ViewportCorrection.w * segment + width;
    return width * vertexColorRed * _Frame01WidthScale * _ArtOutlineWidth;
}

// DXBC CB1[28].x 控制是否将 TEXCOORD4.xyz 用作投影辅助位置。
// 描边生成：沿重建的平滑法线扩张，并叠加顶点深度信号。
float4 ProjectSourceOutlinePosition(ZZZOutlineAttributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    float3 positionVS = mul(UNITY_MATRIX_V, float4(positionWS, 1.0)).xyz;
    float3 projectionPositionOS = lerp(
        input.positionOS,
        input.projectionPositionTEXCOORD4.xyz,
        step(0.5, _UseTEXCOORD4ProjectionAnchor));
    float3 projectionPositionWS = TransformObjectToWorld(projectionPositionOS);
    float3 projectionPositionVS = mul(UNITY_MATRIX_V, float4(projectionPositionWS, 1.0)).xyz;
    float projectedDepth = -projectionPositionVS.z / max(_Frame01ProjectionScale, 0.00001);
    float outlineWidth = SourceOutlineWidth(projectedDepth, input.vertexColor.r)
        * _Frame01ProjectionOffsetScale;

    float3 normalOS = DecodeSmoothNormalFromUV1(
        input.uv1SmoothNormal, input.normalOS, input.tangentOS);
    float3 normalWS = TransformObjectToWorldNormal(normalOS);
    float3 normalVS = mul((float3x3)UNITY_MATRIX_V, normalWS);
    float2 projectedNormal = normalVS.xy;
    projectedNormal *= rsqrt(max(dot(projectedNormal, projectedNormal), 0.000000000001));
    positionVS.xy += projectedNormal * outlineWidth;

    // COLOR.g 是捕获到的带符号深度信号；DXBC 中性值为 0.502。
    float depthSignal = (input.vertexColor.g - 0.502) * _Frame01DepthOffsetScale;
    float3 viewDirection = normalize(positionVS);
    positionVS += viewDirection * depthSignal;
    return mul(UNITY_MATRIX_P, float4(positionVS, 1.0));
}

ZZZOutlineVaryings ZZZOutlineVertex(ZZZOutlineAttributes input)
{
    ZZZOutlineVaryings output;
    output.positionCS = ProjectSourceOutlinePosition(input);
    // PNG 图像行相对源模型 UV 倒置；UV1 中的平滑法线数据不翻转。
    output.uv0 = float2(input.uv0.x, _TextureVFlip > 0.5 ? 1.0 - input.uv0.y : input.uv0.y);
    output.vertexColor = input.vertexColor;
    output.smoothNormalWS = TransformObjectToWorldNormal(
        DecodeSmoothNormalFromUV1(input.uv1SmoothNormal, input.normalOS, input.tangentOS));
    // 源描边片元着色器按源顶点着色器从顶点色提取并插值的低位选择光向。
    uint vertexFlags = (uint)(input.vertexColor.b * 255.0);
    output.alternateLight = (vertexFlags >> 5) & 1u;
    uint packedFace = (uint)(saturate(input.vertexColor.b) * 255.0 + 0.5);
    output.vertexRegion = 0.9 - 0.2 * (packedFace & 3u);
    return output;
}

// 捕获的片元着色器将漫反射与金属响应转为 HSV，压缩 V 值后叠加区域描边色。
float3 OutlineRGBToHSV(float3 color)
{
    float4 constants = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 first = color.g >= color.b ?
        float4(color.gb, constants.xy) : float4(color.bg, constants.wz);
    float4 second = color.r >= first.x ?
        float4(color.r, first.yzx) : float4(first.xyw, color.r);
    float difference = second.x - min(second.w, second.y);
    return float3(abs(second.z + (second.w - second.y) / (6.0 * difference + 0.0001)),
        difference / (second.x + 0.0001), second.x);
}
float3 OutlineHSVToRGB(float3 hsv)
{
    float3 hue = saturate(abs(frac(hsv.x + float3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0);
    return hsv.z * lerp(float3(1.0,1.0,1.0), hue, hsv.y);
}
// 保持源片元响应顺序：压缩 HSV 明度、选择光向，再合成环境光与直射光。
// HSV 颜色响应：压缩明度，再按所选光向和区域颜色计算描边。
float3 EvaluateOutlineLightingResponse(
    float3 diffuse,
    float2 materialControl,
    float4 regionColor,
    ZZZOutlineVaryings input)
{
    float3 hsv = OutlineRGBToHSV(saturate(1.0 + regionColor.a * (diffuse * (1.0 - materialControl.g * _SourceMetalStrength) - 1.0)));
    float response = 0.8 - 0.2 * (1.0 + hsv.z - hsv.y);
    float3 direction = normalize(input.alternateLight > 0.5 ? _AlternateLightDirection.xyz : _LightDirection.xyz);
    float3 sourceLightColor = min(_SourceLightColor.rgb, 1.0);
    float3 ambientColor = _AmbientColor.rgb;
    if (ZZZArtUsesSceneLight(_UseSceneLighting, _ArtLightingMode))
    {
        // Unity 场景光照属于目标侧适配；捕获中的阴影与 Stencil 消费关系尚未验证。
        Light sceneLight = GetMainLight();
        if (dot(sceneLight.direction, sceneLight.direction) > 0.000001)
            direction = normalize(sceneLight.direction);
        sourceLightColor = sceneLight.color * sceneLight.distanceAttenuation;
        ambientColor = ZZZAmbient(normalize(input.smoothNormalWS), _AmbientColor.rgb, _SceneAmbientMode);
    }
    float lightResponse = saturate((dot(direction, normalize(input.smoothNormalWS)) - 0.28) * 10.000001);
    hsv.z *= response * (0.5 + 0.5 * lightResponse);
    float3 outlineColor = OutlineHSVToRGB(hsv) * regionColor.rgb;
    return outlineColor * (ambientColor + _OutlineLightTint.rgb * sourceLightColor);
}

// 片元阶段：采样源控制图，选择对应区域色，再计算源响应和美术调整。
float4 ZZZOutlineFragment(ZZZOutlineVaryings input) : SV_Target
{
    float2 materialControl = SAMPLE_TEXTURE2D_BIAS(_MaterialControl, sampler_MaterialControl, input.uv0, _TextureMipBias).rg;
    // 身体描边按材质控制图R分区；脸部描边（源PS dcab6417）按顶点编码分区。
    float region = _RegionFromVertex > 0.5 ? input.vertexRegion : materialControl.r;
    float4 color = region < 0.8 ? _OutlineColor1 : _OutlineColor;
    color = region < 0.6 ? _OutlineColor2 : color;
    color = region < 0.4 ? _OutlineColor3 : color;
    color = region < 0.2 ? _OutlineColor4 : color;
    float3 diffuse = SAMPLE_TEXTURE2D_BIAS(_MainTex, sampler_MainTex, input.uv0, _TextureMipBias).rgb;
    float3 lightingColor = EvaluateOutlineLightingResponse(diffuse, materialControl, color, input);
    return float4(lightingColor * _ArtOutlineTint.rgb * _ArtOutlineStrength, color.a);
}

#endif
