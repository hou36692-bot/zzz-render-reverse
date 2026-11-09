Shader "ZZZ/Character/Face"
{
    Properties
    {
        // 颜色图RGB在线性域参与乘色；控制图R/G决定边界与过渡，均保留原材质采样偏移。
        [Header(Material Inputs)]
        _MainTex ("面部主色图（sRGB）", 2D) = "white" {}
        _LightTex ("脸部控制图（线性R/G）", 2D) = "white" {}
        _Color ("主色乘色", Color) = (1,1,1,1)
        _SourceMipBias ("Mip 采样偏移", Float) = -2
        // 白色→浅色→暗色三段；区域由顶点色B编码选择，不对应三个材质槽。
        [Header(Tone Palette)]
        _ShallowColor ("区域0浅色", Color) = (1,0.9607844,0.9490196,1)
        _ShadowColor ("区域0暗色／发影乘色", Color) = (0.9450981,0.8509805,0.8509805,1)
        _FaceShallowColor1 ("区域1浅色", Color) = (0.890005529,0.890005529,0.890005529,1)
        _FaceShallowColor2 ("区域2浅色", Color) = (0.603827417,0.603827417,0.603827417,1)
        _FaceShadowColor1 ("区域1暗色", Color) = (0.787412345,0.787412345,0.787412345,1)
        _FaceShadowColor2 ("区域2暗色", Color) = (0.318546832,0.318546832,0.318546832,1)
        _FaceBandWidths ("区域0/1/2过渡宽度（XYZ）", Vector) = (0.05,0.05,0.1,0)
        // 这三轴由动画后的头部骨骼实时更新；默认是单位基，不是捕获帧矩阵。
        [HideInInspector] _FaceAxisXWS ("面部X轴（世界）", Vector) = (1,0,0,0)
        [HideInInspector] _FaceAxisYWS ("面部Y轴（世界）", Vector) = (0,1,0,0)
        [HideInInspector] _FaceAxisZWS ("面部Z轴（世界）", Vector) = (0,0,1,0)
        [Header(Lighting)]
        // 捕获模式使用以下源光照记录；场景模式使用URP主光，环境来源可选Profile或场景SH。
        _LightDirection ("源主光方向（朝向光源，世界空间）", Vector) = (0.494292885,0.712461531,-0.498069525,0)
        _SourceLightColor ("源主光颜色", Color) = (1,1,1,1)
        _AmbientColor ("环境颜色（源cb0[2]）", Color) = (0.0467248037,0.0705322102,0.0943396091,1)
        [Enum(Profile,0,SceneSH,1)] _SceneAmbientMode ("场景光照时的环境来源", Float) = 0
        [HideInInspector] _UseSceneLighting ("运行时场景光照开关", Float) = 1
        [Enum(FollowDriver,0,Captured,1,Scene,2)] _ArtLightingMode ("光照输入（0=跟随，1=捕获，2=场景）", Float) = 0
        _ResponseScale ("色调响应系数（源0.96）", Float) = 0.96
        [Toggle] _DistancePalette ("视距色板（Feature）", Float) = 1
        [Header(Artist Controls)]
        _ArtTint ("综合乘色", Color) = (1,1,1,1)
        _ArtExposure ("曝光（档）", Range(-4,4)) = 0
        _ArtSaturation ("饱和度", Range(0,2)) = 1
        _ArtShadowTint ("发影色调", Color) = (1,1,1,1)
        _ArtShadowStrength ("发影强度", Range(0,2)) = 1
        // 发影依赖当前生产链的模板写入与重绘；保留材质状态，不改共享RendererFeature。
        [Header(Render State)]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("源混合因子", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("目标混合因子", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("剔除模式", Float) = 2
        [Toggle] _ZWrite ("写入深度", Float) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("深度比较", Float) = 4
        _StencilRef ("表面模板参考值", Float) = 128
        _StencilRefShadow ("发影模板参考值", Float) = 132
        _StencilReadMask ("表面模板读取掩码", Float) = 1
        _StencilWriteMask ("表面模板写入掩码", Float) = 255
        _StencilWriteMaskShadow ("发影模板比较掩码", Float) = 128
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp ("表面模板比较", Float) = 8
    }
    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Includes/ZZZFace.hlsl"
    ENDHLSL
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
        Pass
        {
            Name "ZZZFaceSurface"
            Tags { "LightMode"="UniversalForward" }
            Blend [_SrcBlend] [_DstBlend]
            Cull [_Cull]
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            ColorMask RGBA
            Stencil
            {
                Ref [_StencilRef]
                ReadMask [_StencilReadMask]
                WriteMask [_StencilWriteMask]
                Comp [_StencilComp]
                Pass Replace
                Fail Keep
                ZFail Keep
            }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex ZZZFaceVertex
            #pragma fragment ZZZFaceFragment
            // 当前Renderer使用Forward+；删此变体会使主光输入变化，不能当作无用开关。
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            ENDHLSL
        }
        Pass
        {
            Name "ZZZFaceShadow"
            Tags { "LightMode"="ZZZFaceShadow" }
            // 只在发影模板命中、深度相等时给已写颜色乘阴影色；不是第二次绘制主色。
            Blend DstColor Zero
            Cull [_Cull]
            ZWrite Off
            ZTest Equal
            ColorMask RGB
            Stencil
            {
                Ref [_StencilRefShadow]
                ReadMask [_StencilWriteMaskShadow]
                WriteMask 0
                Comp Equal
                Pass Keep
                Fail Keep
                ZFail Keep
            }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex ZZZFaceVertex
            #pragma fragment ZZZFaceShadowFragment
            ENDHLSL
        }
    }
    CustomEditor "ZZZCharacterShaderGUI"
}
