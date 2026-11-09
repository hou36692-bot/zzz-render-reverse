Shader "ZZZ/Character/HairShadowMask"
{
    Properties
    {
                // 以下为 Unity 校准项；源材质没有对应的美术控制属性。
        // 偏移按 3840 x 2160 参考画幅像素计算，范围 -100..100，默认值为 0；左上角为原点，+Y 向下。
        _ArtHairShadowOffsetX ("发影遮罩水平偏移（参考像素）", Range(-100, 100)) = 0
        _ArtHairShadowOffsetY ("发影遮罩垂直偏移（参考像素，+Y 向下）", Range(-100, 100)) = 0
        // 默认值 1 保留现有 Stencil 遮罩；设为 0 时，片元会在写入 Stencil 前丢弃。
        _ArtHairShadowEnabled ("发影遮罩启用", Float) = 1
                // 以下为 MAT_HairShadow_UI 中序列化的值；Clip-space 偏移的单位尚未确认。
        _ClipSpaceXOffset ("源 Clip-space X 偏移", Float) = 0
        _ClipSpaceYOffset ("源 Clip-space Y 偏移", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("源混合源因子", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("源混合目标因子", Float) = 0
        [Toggle] _ZWrite ("源深度写入", Float) = 1
                _StencilRef ("目标 Stencil 参考值", Float) = 1
        _StencilReadMask ("目标 Stencil 读取掩码", Float) = 255
        _StencilWriteMask ("目标 Stencil 写入掩码", Float) = 255
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp ("目标 Stencil 比较", Float) = 8
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass ("目标 Stencil 通过操作", Float) = 2
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("目标剔除", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("目标深度测试", Float) = 4
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
        Pass
        {
            Name "HairShadowStencilMask"
            Tags { "LightMode"="ZZZHairShadowMask" }
            // 此处的 Stencil 消费逻辑和渲染状态为受控重建值，尚未从捕获中恢复。
            Blend [_SrcBlend] [_DstBlend]
            Cull [_Cull]
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            ColorMask 0
            Stencil
            {
                Ref [_StencilRef]
                ReadMask [_StencilReadMask]
                WriteMask [_StencilWriteMask]
                Comp [_StencilComp]
                Pass [_StencilPass]
                Fail Keep
                ZFail Keep
            }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex HairShadowVertex
            #pragma fragment HairShadowFragment
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Includes/ZZZHairShadow.hlsl"
            ENDHLSL
        }
    }
    CustomEditor "ZZZCharacterShaderGUI"
}
