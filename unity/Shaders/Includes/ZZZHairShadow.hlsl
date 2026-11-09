#ifndef ZZZ_HAIR_SHADOW_INCLUDED
#define ZZZ_HAIR_SHADOW_INCLUDED

// 保持现有材质 CBUFFER 字段顺序和 float 精度。
CBUFFER_START(UnityPerMaterial)
float _ClipSpaceXOffset;       // 沿用源属性名的裁剪空间输入；源单位尚未确认。
float _ClipSpaceYOffset;       // 沿用源属性名的裁剪空间输入；源单位尚未确认。
float _ArtHairShadowOffsetX;   // 目标侧美术偏移，单位为 3840x2160 参考画幅像素。
float _ArtHairShadowOffsetY;   // 目标侧美术偏移，单位为参考画幅像素；正值向下移动。
float _ArtHairShadowEnabled;   // 默认开启的 Stencil 遮罩开关；关闭时在执行 Stencil 操作前丢弃片元。
CBUFFER_END

struct HairShadowAttributes
{
    float3 positionOS : POSITION; // 网格顶点的物体空间位置。
};

struct HairShadowVaryings
{
    float4 positionCS : SV_POSITION; // 光栅化阶段使用的齐次裁剪空间位置。
};

// 发影遮罩几何：先保留源裁剪空间位移，再应用目标侧参考像素校准。
HairShadowVaryings HairShadowVertex(HairShadowAttributes input)
{
    HairShadowVaryings output;
    output.positionCS = TransformObjectToHClip(input.positionOS);
    output.positionCS.xy += float2(_ClipSpaceXOffset, _ClipSpaceYOffset) * output.positionCS.w;
    output.positionCS.xy += float2(
        _ArtHairShadowOffsetX / 3840.0,
        -_ArtHairShadowOffsetY / 2160.0) * (2.0 * output.positionCS.w);
    return output;
}

// 发影只写 Stencil；ShaderLab ColorMask 0 禁止颜色写入。
float4 HairShadowFragment(HairShadowVaryings input) : SV_Target
{
    clip(_ArtHairShadowEnabled - 0.5);
    return 0.0;
}

#endif