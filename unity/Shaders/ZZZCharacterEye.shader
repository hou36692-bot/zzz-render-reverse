Shader "ZZZ/Character/Eye"
{
    Properties
    {
        // 主图RGB为sRGB固有色，A为覆盖；Eye_E为Linear 16×16表，按顶点COLOR.r点读取。
        _MainTex ("眼部主图（sRGB RGB，A覆盖）", 2D) = "white" {}
        _EyeColorMap ("眼色表（16×16 Linear）", 2D) = "white" {}
        _LightTex ("明暗控制图（Linear R边界／G宽度）", 2D) = "white" {}
        _Color ("眼部颜色乘数", Color) = (1,1,1,1)
        _ShallowColor ("浅色乘数", Color) = (1,1,1,1)
        _ShadowColor ("暗色乘数", Color) = (1,1,1,1)
        _Bandwidth ("归一化角度过渡宽度", Float) = 0.1
        _SourceMipBias ("Mip 采样偏移", Float) = 0
        _ResponseScale ("色调响应系数（源0.96）", Float) = 0.96
        [Toggle] _PowerResponse ("亮度幂响应（Feature）", Float) = 1
        [Toggle] _DistancePalette ("视距色板（Feature）", Float) = 1

        _LightDirection ("源主光方向（朝向光源，世界空间）", Vector) = (0.494292885,0.712461531,-0.498069525,0)
        _SourceLightColor ("源主光颜色", Color) = (1,1,1,1)
        _AmbientColor ("环境颜色", Color) = (0.0467248037,0.0705322102,0.0943396091,1)
        [Enum(Profile,0,SceneSH,1)] _SceneAmbientMode ("场景光照时的环境来源", Float) = 0
        [HideInInspector] _UseSceneLighting ("运行时场景光照开关", Float) = 1
        [Enum(FollowDriver,0,Captured,1,Scene,2)] _ArtLightingMode ("光照输入（0=跟随，1=捕获，2=场景）", Float) = 0

        _ArtTint ("美术颜色染色", Color) = (1,1,1,1)
        _ArtExposure ("美术曝光（档）", Range(-4,4)) = 0
        _ArtSaturation ("美术饱和度", Range(0,2)) = 1

        [HideInInspector] _FaceAxisXWS ("源头部X轴（世界）", Vector) = (1,0,0,0)
        [HideInInspector] _FaceAxisYWS ("源头部Y轴（世界）", Vector) = (0,1,0,0)
        [HideInInspector] _FaceAxisZWS ("源头部Z轴（世界）", Vector) = (0,0,1,0)
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" }
        Pass
        {
            Name "ZZZEyeLayer"
            Tags { "LightMode"="UniversalForwardOnly" }
            // 源眼PS输出预乘RGB；目标Alpha采用覆盖over，避免重复预乘。
            Blend One OneMinusSrcAlpha, One OneMinusSrcAlpha
            Cull Back
            ZWrite Off
            ZTest LEqual
            ColorMask RGBA
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex ZZZEyeVertex
            #pragma fragment ZZZEyeFragment
            // Forward+渲染器下缺少该变体时主光输入为零，不能当作无用开关删除。
            #pragma multi_compile _ _FORWARD_PLUS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Includes/ZZZEye.hlsl"
            ENDHLSL
        }
    }
    CustomEditor "ZZZCharacterShaderGUI"
}
