#ifndef ZZZ_CHARACTER_OUTPUT_INCLUDED
#define ZZZ_CHARACTER_OUTPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
// 输出链：调色LUT→亮部提取→可分离滤波→三尺度图集→加权还原→分段响应与合成。两角色源帧共用这些后处理Shader。
// 参数由RenderGraph每个Pass独立写入，保持原布局；不移到材质CBUFFER。
TEXTURE2D_X(_VwwBloomTexture);
TEXTURE2D_X(_VwwMipAtlasTexture);
TEXTURE2D(_ZZZGradingLut);

float4 _VwwSourceTexelSize;
float4 _VwwFilterAxisTexel;
float4 _VwwAtlasRegion;
float _VwwBrightThreshold;
float _VwwBrightGain;
float _VwwSegmentThreshold;
float _VwwSegmentExponent;
float _VwwSegmentPowScale;
float _VwwSegmentOffset;
float _VwwHighlightGain;
float _VwwHighlightCompositionStrength;

static const float4 ZZZBigRegion = float4(0.0, 0.472049713, 1.0, 0.527950287);
static const float4 ZZZMidRegion = float4(0.0, 0.149068296, 0.588235319, 0.310559005);
static const float4 ZZZSmallRegion = float4(0.0, 0.0124223828, 0.235294119, 0.124223605);
// 角色颜色按目标尺寸双线性直通，格式负责颜色域转换。
float4 SourceRoleNormalizeFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    return SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord);
}
// 四个对角采样平均，再按阈值截亮；阈值和增益由Feature提供。
float4 SourceBrightPrefilterFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float2 texel = _VwwSourceTexelSize.xy;
    float4 sample00 = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord + float2( texel.x,  texel.y));
    float4 sample01 = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord + float2( texel.x, -texel.y));
    float4 sample10 = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord + float2(-texel.x, -texel.y));
    float4 sample11 = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord + float2(-texel.x,  texel.y));
    float4 average = (sample00 + sample01 + sample10 + sample11) * 0.25;
    return float4(max(average.rgb - _VwwBrightThreshold, 0.0) * _VwwBrightGain, average.a);
}
// 单轴六tap滤波，偏移与权重保持原次序；X/Y两遍由Feature控制。
float4 SourceOptimizedBlurFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float2 stepUv = _VwwFilterAxisTexel.xy;
    float4 sum = 0.0;
    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord - 2.222628 * stepUv) * 0.133484393;
    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord - 4.095285 * stepUv) * 0.00570466183;
    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord + 1.320767 * stepUv) * 0.501892;
    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord - 0.437803 * stepUv) * 0.323496908;
    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord + 5.0 * stepUv) * 0.000543567527;
    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord + 3.147974 * stepUv) * 0.0348784700;
    return sum;
}
// 图集采样限制在当前tile内部，避免滤波跨入其它尺度。
float2 ClampToAtlasTile(float2 uv, float4 region)
{
    float2 halfTexel = 0.5 * _VwwSourceTexelSize.xy;
    return clamp(uv, region.xy + halfTexel, region.xy + region.zw - halfTexel);
}

float4 AtlasTap(float2 uv, float offset, float4 region)
{
    return SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp,
        ClampToAtlasTile(uv + offset * _VwwFilterAxisTexel.xy, region));
}

// 三个尺度使用不同半径/核权重；保留有贡献的真实核，不擅自归一化。
float4 FilterAtlasLarge(float2 uv)
{
    float4 atlasRegion = _VwwAtlasRegion;
    float4 weightedColorSum = 0.0;
    weightedColorSum += AtlasTap(uv, -5.227498, atlasRegion) * 0.0151298102;
    weightedColorSum += AtlasTap(uv, -7.158820, atlasRegion) * 0.000964867824;
    weightedColorSum += AtlasTap(uv, -3.314762, atlasRegion) * 0.100958303;
    weightedColorSum += AtlasTap(uv, -1.417412, atlasRegion) * 0.288900;
    weightedColorSum += AtlasTap(uv,  0.472244591, atlasRegion) * 0.356403589;
    weightedColorSum += AtlasTap(uv,  2.364548, atlasRegion) * 0.189770803;
    weightedColorSum += AtlasTap(uv,  4.268898, atlasRegion) * 0.0434656292;
    weightedColorSum += AtlasTap(uv,  6.190808, atlasRegion) * 0.00425362587;
    weightedColorSum += AtlasTap(uv,  8.0, atlasRegion) * 0.000153239904;
    return weightedColorSum;
}

float4 FilterAtlasMedium(float2 uv)
{
    float4 atlasRegion = _VwwAtlasRegion;
    float4 weightedColorSum = 0.0;
    weightedColorSum += AtlasTap(uv, -12.293380, atlasRegion) * 0.000947096676;
    weightedColorSum += AtlasTap(uv, -14.265090, atlasRegion) * 0.000146320002;
    weightedColorSum += AtlasTap(uv, -10.323360, atlasRegion) * 0.00464627193;
    weightedColorSum += AtlasTap(uv, -8.354863, atlasRegion) * 0.0172795802;
    weightedColorSum += AtlasTap(uv, -6.387677, atlasRegion) * 0.0487266295;
    weightedColorSum += AtlasTap(uv, -4.421542, atlasRegion) * 0.104202203;
    weightedColorSum += AtlasTap(uv, -2.456162, atlasRegion) * 0.169012904;
    weightedColorSum += AtlasTap(uv, -0.491210788, atlasRegion) * 0.207937;
    weightedColorSum += AtlasTap(uv,  1.473654, atlasRegion) * 0.194056496;
    weightedColorSum += AtlasTap(uv,  3.438778, atlasRegion) * 0.137373805;
    weightedColorSum += AtlasTap(uv,  5.404496, atlasRegion) * 0.0737620592;
    weightedColorSum += AtlasTap(uv,  7.371121, atlasRegion) * 0.0300378799;
    weightedColorSum += AtlasTap(uv,  9.338933, atlasRegion) * 0.00927573629;
    weightedColorSum += AtlasTap(uv, 11.308170, atlasRegion) * 0.00217165402;
    weightedColorSum += AtlasTap(uv, 13.279020, atlasRegion) * 0.000385392312;
    weightedColorSum += AtlasTap(uv, 15.0, atlasRegion) * 0.0000387885193;
    return weightedColorSum;
}

float4 FilterAtlasSmall(float2 uv)
{
    float4 atlasRegion = _VwwAtlasRegion;
    float4 weightedColorSum = 0.0;
    weightedColorSum += AtlasTap(uv, -16.322439, atlasRegion) * 0.000393386610;
    weightedColorSum += AtlasTap(uv, -18.303101, atlasRegion) * 0.0000828053671;
    weightedColorSum += AtlasTap(uv, -12.362960, atlasRegion) * 0.00520150177;
    weightedColorSum += AtlasTap(uv, -14.342410, atlasRegion) * 0.00156375498;
    weightedColorSum += AtlasTap(uv, -8.405515, atlasRegion) * 0.0337260291;
    weightedColorSum += AtlasTap(uv, -10.384010, atlasRegion) * 0.0144784302;
    weightedColorSum += AtlasTap(uv, -4.449542, atlasRegion) * 0.107267298;
    weightedColorSum += AtlasTap(uv, -6.427385, atlasRegion) * 0.0657470524;
    weightedColorSum += AtlasTap(uv, -0.494374692, atlasRegion) * 0.167387903;
    weightedColorSum += AtlasTap(uv, -2.471902, atlasRegion) * 0.146469697;
    weightedColorSum += AtlasTap(uv,  1.483130, atlasRegion) * 0.160102695;
    weightedColorSum += AtlasTap(uv,  3.460702, atlasRegion) * 0.128165394;
    weightedColorSum += AtlasTap(uv,  5.438433, atlasRegion) * 0.0858689398;
    weightedColorSum += AtlasTap(uv,  7.416409, atlasRegion) * 0.0481489189;
    weightedColorSum += AtlasTap(uv,  9.394713, atlasRegion) * 0.0225949194;
    weightedColorSum += AtlasTap(uv, 11.373420, atlasRegion) * 0.00887349620;
    weightedColorSum += AtlasTap(uv, 13.352620, atlasRegion) * 0.00291622407;
    weightedColorSum += AtlasTap(uv, 15.332350, atlasRegion) * 0.000801990274;
    weightedColorSum += AtlasTap(uv, 17.312691, atlasRegion) * 0.000184551303;
    weightedColorSum += AtlasTap(uv, 19.0, atlasRegion) * 0.0000250982393;
    return weightedColorSum;
}

// 仅更新指定图集区域，区域外直通，以保留其他尺度的内容。
float4 FilterAtlasRegion(Varyings input, float4 region, int kernel)
{
    float2 uv = input.texcoord;
    bool inside = uv.x >= region.x && uv.x <= region.x + region.z &&
                  uv.y >= region.y && uv.y <= region.y + region.w;
    if (!inside)
        return SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv);

    if (kernel == 0) return FilterAtlasLarge(uv);
    if (kernel == 1) return FilterAtlasMedium(uv);
    return FilterAtlasSmall(uv);
}

float4 SourcePyramidFilterLargeFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    return FilterAtlasRegion(input, _VwwAtlasRegion, 0);
}
float4 SourcePyramidFilterMediumFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    return FilterAtlasRegion(input, _VwwAtlasRegion, 1);
}
float4 SourcePyramidFilterSmallFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    return FilterAtlasRegion(input, _VwwAtlasRegion, 2);
}
// 四tap下采样至图集tile，localUV将tile坐标还原成输入UV。
float4 DownsampleBrightTile(float2 atlasUv, float4 region)
{
    float2 localUv = saturate((atlasUv - region.xy) / region.zw);
    float2 texel = _VwwSourceTexelSize.xy * float2(0.96, 0.25);
    float4 sum = 0.0;
    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, localUv + texel);
    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, localUv + float2(texel.x, -texel.y));
    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, localUv - texel);
    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, localUv + float2(-texel.x, texel.y));
    return sum * 0.25;
}

float4 SourcePyramidPackFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float2 uv = input.texcoord;
    if (uv.x <= ZZZBigRegion.x + ZZZBigRegion.z && uv.y >= ZZZBigRegion.y && uv.y <= ZZZBigRegion.y + ZZZBigRegion.w)
        return DownsampleBrightTile(uv, ZZZBigRegion);
    if (uv.x <= ZZZMidRegion.x + ZZZMidRegion.z && uv.y >= ZZZMidRegion.y && uv.y <= ZZZMidRegion.y + ZZZMidRegion.w)
        return DownsampleBrightTile(uv, ZZZMidRegion);
    if (uv.x <= ZZZSmallRegion.x + ZZZSmallRegion.z && uv.y >= ZZZSmallRegion.y && uv.y <= ZZZSmallRegion.y + ZZZSmallRegion.w)
        return DownsampleBrightTile(uv, ZZZSmallRegion);
    return 0.0;
}
// 原亮部与三尺度图集按0.3/0.3/0.26/0.15合成；总权重不强制为1。
float4 SourceWeightedResolveFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float2 uv = input.texcoord;
    float4 bright = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv);
    float4 big = SAMPLE_TEXTURE2D_X(_VwwMipAtlasTexture, sampler_LinearClamp,
        uv * float2(1.0, 0.527950287) + float2(0.0, 0.472049713));
    float4 middle = SAMPLE_TEXTURE2D_X(_VwwMipAtlasTexture, sampler_LinearClamp,
        uv * float2(0.588235319, 0.310559005) + float2(0.0, 0.149068296));
    float4 small = SAMPLE_TEXTURE2D_X(_VwwMipAtlasTexture, sampler_LinearClamp,
        uv * float2(0.235294119, 0.124223605) + float2(0.0, 0.0124223828));
    return bright * 0.3 + big * 0.3 + middle * 0.26 + small * 0.15;
}
// 低于分界值保持线性，高值走幂响应；系数保持当前模型，不是显示gamma。
float3 ZZZHighlightResponse(float3 highlight)
{
    float3 powered = exp(log(abs(highlight)) * _VwwSegmentExponent) * _VwwSegmentPowScale - _VwwSegmentOffset;
    float3 segmented = lerp(highlight, powered, step(_VwwSegmentThreshold, highlight));
    return segmented * _VwwHighlightGain;
}
// 高亮按目标强度加到颜色上，保留输入Alpha，最后饱和到[0,1]。
float4 CharacterOutputAdapterFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float4 source = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord);
    float3 resolvedHighlights = SAMPLE_TEXTURE2D_X(_VwwBloomTexture, sampler_LinearClamp, input.texcoord).rgb;
    return float4(saturate(source.rgb + ZZZHighlightResponse(resolvedHighlights) * _VwwHighlightCompositionStrength), source.a);
}

// 源合成PS fbb07bad：线性颜色经LogC编码后查32³条带LUT（1024×32，蓝通道选切片并在相邻切片间插值）。
// LUT本身是源运行时生成的调色结果，作为共享Profile数据；这里只还原编码与采样方式。
float3 ZZZLogCEncode(float3 linearColor)
{
    return saturate(log2(linearColor * 5.555556 + 0.047996) * 0.0734997839 + 0.386036);
}

float3 ZZZApplyGradingLut(float3 linearColor)
{
    float3 coordinate = ZZZLogCEncode(max(linearColor, 0.0)) * 31.0;
    float slice = floor(coordinate.b);
    float2 uv = float2((coordinate.r + 0.5) / 1024.0 + slice / 32.0, (coordinate.g + 0.5) / 32.0);
    float3 lower = SAMPLE_TEXTURE2D_LOD(_ZZZGradingLut, sampler_LinearClamp, uv, 0).rgb;
    float3 upper = SAMPLE_TEXTURE2D_LOD(_ZZZGradingLut, sampler_LinearClamp, uv + float2(1.0 / 32.0, 0.0), 0).rgb;
    return lerp(lower, upper, coordinate.b - slice);
}

// Alpha保持角色覆盖，供后续合成使用；源目标Alpha为1，不代表角色层覆盖。
float4 CharacterGradingFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float4 source = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord);
    return float4(ZZZApplyGradingLut(source.rgb), source.a);
}

#endif
