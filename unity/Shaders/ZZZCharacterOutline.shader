Shader "ZZZ/Character/Outline"
{
    Properties
    {
                // Unity 调整项；色调为白色、倍率为 1 时保持捕获基准。
        _ArtOutlineTint ("描边色调", Color) = (1,1,1,1)
        _ArtOutlineWidth ("描边宽度倍率", Range(0,2)) = 1
        _ArtOutlineStrength ("描边强度倍率", Range(0,2)) = 1
        [Enum(FollowDisplay,0,CapturedFrame,1,UnityScene,2)] _ArtLightingMode ("光照来源", Float) = 0
                _MainTex ("源漫反射（sRGB RGB）", 2D) = "white" {}
        _MaterialControl ("源材质区域（Linear R）", 2D) = "black" {}
        _OutlineColor ("源区域0描边色", Color) = (1,1,1,1)
        _OutlineColor1 ("源区域1描边色", Color) = (1,1,1,1)
        _OutlineColor2 ("源区域2描边色", Color) = (1,1,1,1)
        _OutlineColor3 ("源区域3描边色", Color) = (1,1,1,1)
        _OutlineColor4 ("源区域4描边色", Color) = (1,1,1,1)
        _TextureMipBias ("源纹理 Mip 偏置", Float) = -2
        [Toggle] _TextureVFlip ("贴图V翻转（解码PNG导入链）", Float) = 1
        _SourceMetalStrength ("源金属响应倍率", Float) = 1
        _LightDirection ("Frame01 主光方向（WS）", Vector) = (0.494292885,0.712461531,-0.498069525,0)
        _AlternateLightDirection ("Frame01 备用光方向（WS）", Vector) = (0.54590261,-0.263838917,-0.795222878,0)
        _SourceLightColor ("Frame01 结构化主光颜色", Color) = (1,1,1,1)
        _AmbientColor ("Frame01 环境色", Color) = (0.0467248037,0.0705322102,0.0943396091,1)
        _OutlineLightTint ("Frame01 描边全局色调", Color) = (0.776000023,0.75999999,0.800000012,1)
        [Toggle] _UseSceneLighting ("使用 Unity 场景光照", Float) = 0
        [Enum(Profile,0,SceneSH,1)] _SceneAmbientMode ("场景光照时的环境来源", Float) = 0
        [Toggle] _RegionFromVertex ("分区取自顶点编码（脸部描边Feature）", Float) = 0
        _Frame01ProjectionScale ("Frame01 CB0[96].y 投影比例", Float) = 4.7046299
        _Frame01ViewportCorrection ("Frame01 CB0[88] 视口修正", Vector) = (0,540,0,0)
        _Frame01WidthScale ("Frame01 CB3[125].z 宽度比例", Float) = 1
        _Frame01ProjectionOffsetScale ("Frame01 CB3[116].z 投影偏移比例", Float) = 1
        _Frame01DepthOffsetScale ("Frame01 CB3[105].y 深度偏移比例", Float) = 0.01
        // 当前导入网格没有 TEXCOORD4；关闭辅助锚点时使用当前顶点位置。
        [Toggle] _UseTEXCOORD4ProjectionAnchor ("捕获辅助投影位置可用", Float) = 0
                [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("源混合源因子", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("源混合目标因子", Float) = 0
        [Toggle] _ZWrite ("目标描边深度写入", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("目标描边剔除", Float) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("目标深度测试", Float) = 4
        _StencilRef ("捕获 Stencil 参考值", Float) = 144
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp ("目标 Stencil 比较", Float) = 8
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass ("目标 Stencil 通过操作", Float) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
        Pass
        {
            Name "CharacterOutlineFXDeferred"
            Tags { "LightMode"="ZZZOutline" }
            // Draw64–70 的源状态对象内容未取得；保留可编辑的序列化状态值。
            Blend [_SrcBlend] [_DstBlend]
            Cull [_Cull]
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            ColorMask RGBA
            Stencil
            {
                Ref [_StencilRef]
                Comp [_StencilComp]
                Pass [_StencilPass]
                Fail Keep
                ZFail Keep
            }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex ZZZOutlineVertex
            #pragma fragment ZZZOutlineFragment
            // Forward+渲染器下缺少该变体时主光输入为零。
            #pragma multi_compile _ _FORWARD_PLUS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Includes/ZZZSceneLighting.hlsl"
            #include "Includes/ZZZOutline.hlsl"
            ENDHLSL
        }
    }
    CustomEditor "ZZZCharacterShaderGUI"
}
