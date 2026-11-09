Shader "Hidden/ZZZ/CharacterOutput"
{
    Properties
    {
        [HideInInspector] _BlitTexture ("角色线性颜色（直通Alpha）", 2D) = "black" {}
        [Header(Highlight Filter)]
        _VwwBrightThreshold ("亮部阈值", Float) = 0.45
        _VwwBrightGain ("亮部增益", Float) = 0.8
        [Header(Source Segmented Response)]
        _VwwSegmentThreshold ("分段响应分界", Float) = 0.3
        _VwwSegmentExponent ("高值幂指数", Float) = 0.333333343
        _VwwSegmentPowScale ("高值缩放", Float) = 1.49380159
        _VwwSegmentOffset ("高值偏移", Float) = 0.7
        _VwwHighlightGain ("高亮响应增益", Float) = 1.3
        [Header(Target Composition Calibration)]
        _VwwHighlightCompositionStrength ("高亮合成强度", Range(0,1)) = 1
        [HideInInspector] _VwwSourceTexelSize ("输入纹素尺寸", Vector) = (0, 0, 0, 0)
        [HideInInspector] _VwwFilterAxisTexel ("滤波轴步长", Vector) = (0, 0, 0, 0)
        [HideInInspector] _VwwAtlasRegion ("图集区域", Vector) = (0, 0, 0, 0)
        [HideInInspector] _VwwBloomTexture ("还原高亮（线性RGB）", 2D) = "black" {}
        [HideInInspector] _VwwMipAtlasTexture ("高亮金字塔图集（线性RGB）", 2D) = "black" {}
        [HideInInspector] _ZZZGradingLut ("角色调色LUT（LogC 32³条带，线性）", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        // 全屏Pass共同状态：覆盖颜色，不写深度；各Pass只声明采样计算。
        Blend One Zero
        Cull Off
        ZWrite Off
        ZTest Always
        ColorMask RGBA
        Stencil { Ref 0 Comp Always Pass Keep Fail Keep ZFail Keep }
        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Includes/ZZZCharacterOutput.hlsl"
        ENDHLSL

        Pass
        {
            Name "NativeRoleCopy2448"
            HLSLPROGRAM
                #pragma target 3.5
                #pragma vertex Vert
                #pragma fragment SourceRoleNormalizeFragment
            ENDHLSL
        }

        Pass
        {
            Name "SourceBrightPrefilter107"
            HLSLPROGRAM
                #pragma target 3.5
                #pragma vertex Vert
                #pragma fragment SourceBrightPrefilterFragment
            ENDHLSL
        }

        Pass
        {
            Name "SourceOptimizedBlur108109"
            HLSLPROGRAM
                #pragma target 3.5
                #pragma vertex Vert
                #pragma fragment SourceOptimizedBlurFragment
            ENDHLSL
        }

        Pass
        {
            Name "SourcePyramidPack110112"
            HLSLPROGRAM
                #pragma target 3.5
                #pragma vertex Vert
                #pragma fragment SourcePyramidPackFragment
            ENDHLSL
        }

        Pass
        {
            Name "SourcePyramidFilterLarge113116"
            HLSLPROGRAM
                #pragma target 3.5
                #pragma vertex Vert
                #pragma fragment SourcePyramidFilterLargeFragment
            ENDHLSL
        }

        Pass
        {
            Name "SourcePyramidFilterMedium114117"
            HLSLPROGRAM
                #pragma target 3.5
                #pragma vertex Vert
                #pragma fragment SourcePyramidFilterMediumFragment
            ENDHLSL
        }

        Pass
        {
            Name "SourcePyramidFilterSmall115118"
            HLSLPROGRAM
                #pragma target 3.5
                #pragma vertex Vert
                #pragma fragment SourcePyramidFilterSmallFragment
            ENDHLSL
        }

        Pass
        {
            Name "SourceWeightedResolve119"
            HLSLPROGRAM
                #pragma target 3.5
                #pragma vertex Vert
                #pragma fragment SourceWeightedResolveFragment
            ENDHLSL
        }

        Pass
        {
            Name "CharacterOutputAdapter"
            HLSLPROGRAM
                #pragma target 3.5
                #pragma vertex Vert
                #pragma fragment CharacterOutputAdapterFragment
            ENDHLSL
        }

        Pass
        {
            Name "CharacterGradingLut"
            HLSLPROGRAM
                #pragma target 3.5
                #pragma vertex Vert
                #pragma fragment CharacterGradingFragment
            ENDHLSL
        }
    }
    Fallback Off
}
