Shader "ZZZ/Character/Surface"
{
    Properties
    {
                _ArtTint ("角色综合色调（Surface RGB；默认白色中性）", Color) = (1,1,1,1)
        _ArtExposure ("角色曝光（stops；范围 -4 至 4）", Range(-4,4)) = 0
        _ArtSaturation ("角色饱和度（范围 0 至 2）", Range(0,2)) = 1
        _ArtShadowTint ("阴影色调（Surface RGB；默认白色中性）", Color) = (1,1,1,1)
        _ArtShadowStrength ("阴影强度（范围 0 至 2）", Range(0,2)) = 1
        _ArtSpecularStrength ("高光强度（适用 Surface；范围 0 至 2）", Range(0,2)) = 1
        _ArtMatcapStrength ("Matcap 强度（适用 Surface；范围 0 至 2）", Range(0,2)) = 1
        _ArtEmissionStrength ("发光强度（适用 Surface；范围 0 至 2）", Range(0,2)) = 1
        [Enum(FollowDriver,0,Captured,1,Scene,2)] _ArtLightingMode ("光照输入（0=跟随，1=捕获，2=场景）", Float) = 0

                _MainTex ("基础颜色贴图（Surface；sRGB RGB 使用，A 未用）", 2D) = "white" {}
        _NormalControl ("法线与色调控制图（Surface；Linear RG=法线 XY、B=tone、A 未用）", 2D) = "gray" {}
        _MaterialControl ("材质控制图（Surface；Linear R=区域、G=金属、B=高光遮罩、A 未用）", 2D) = "black" {}
        _AuxiliaryControl ("辅助控制图（Surface；Linear R=折射、G=粗糙度、B=Matcap/发光、A 未用）", 2D) = "black" {}
        _BaseColor ("基础颜色乘数（Surface；RGB 使用，A 未用）", Color) = (1,1,1,1)
        _NormalStrength ("法线强度", Float) = 1
        _MetalStrength ("金属度强度", Float) = 1
        _RoughnessStrength ("粗糙度强度", Float) = 1
        _BandWidth ("色阶过渡宽度", Range(0.00001,0.5)) = 0.05
        _SpecularStrength ("高光强度", Float) = 0.1
        _EmissionEnabled ("发光开关（大于 0.5 启用）", Float) = 1
        _EmissionRemap ("Matcap/发光遮罩重映射（大于 0.5 启用）", Float) = 1
        _TextureMipBias ("表面贴图 Mip 偏置", Float) = -2
        [Toggle] _TextureVFlip ("贴图V翻转（解码PNG导入链）", Float) = 1

                _Shadow0 ("区域 0 浅阴影色（Surface；RGB 使用，A 未用）", Color) = (0.465587646,0.496251494,0.817612767,1)
        _Shadow1 ("区域 1 浅阴影色（Surface；RGB 使用，A 未用）", Color) = (0.458144158,0.426719159,0.690340936,1)
        _Shadow2 ("区域 2 浅阴影色（Surface；RGB 使用，A 未用）", Color) = (0.399879128,0.479779124,1,1)
        _Shadow3 ("区域 3 浅阴影色（Surface；RGB 使用，A 未用）", Color) = (0.745404363,0.663981318,0.663981318,1)
        _Shadow4 ("区域 4 浅阴影色（Surface；RGB 使用，A 未用）", Color) = (0.519338429,0.535206974,0.656266451,1)
        _Dark0 ("区域 0 深阴影色（Surface；RGB 使用，A 未用）", Color) = (0.425069422,0.371261537,0.817612767,1)
        _Dark1 ("区域 1 深阴影色（Surface；RGB 使用，A 未用）", Color) = (0.340877861,0.21760045,0.445306182,1)
        _Dark2 ("区域 2 深阴影色（Surface；RGB 使用，A 未用）", Color) = (0.132860959,0.0975873843,0.603827417,1)
        _Dark3 ("区域 3 深阴影色（Surface；RGB 使用，A 未用）", Color) = (0.600443065,0.43425703,0.600443065,1)
        _Dark4 ("区域 4 深阴影色（Surface；RGB 使用，A 未用）", Color) = (0.373130202,0.320461571,0.529900014,1)
        _Specular0 ("区域 0 高光颜色（Surface；RGB 使用，A 未用）", Color) = (0.674528301,0.820794046,1,1)
        _Specular1 ("区域 1 高光颜色（Surface；RGB 使用，A 未用）", Color) = (0.356844097,0.364195973,0.933962286,1)
        _Specular2 ("区域 2 高光颜色（Surface；RGB 使用，A 未用）", Color) = (0.749019623,0.749019623,0.749019623,1)
        _Specular3 ("区域 3 高光颜色（Surface；RGB 使用，A 未用）", Color) = (0.990566015,0.507028282,0.443885714,1)
        _Specular4 ("区域 4 高光颜色（Surface；RGB 使用，A 未用）", Color) = (1,1,1,1)
        _Emission0 ("区域 0 发光颜色（Surface；RGB 使用，A 未用）", Color) = (0.6,0.6,0.6,1)
        _Emission1 ("区域 1 发光颜色（Surface；RGB 使用，A 未用）", Color) = (0.735849023,0.735849023,0.735849023,1)
        _Emission2 ("区域 2 发光颜色（Surface；RGB 使用，A 未用）", Color) = (0.754716992,0.754716992,0.754716992,1)
        _Emission3 ("区域 3 发光颜色（Surface；RGB 使用，A 未用）", Color) = (0.830188692,0.830188692,0.830188692,1)
        _Emission4 ("区域 4 发光颜色（Surface；RGB 使用，A 未用）", Color) = (0,0,0,1)
        _RegionSpecular ("区域 0-3 高光增益（Vector XYZW 对应区域；无物理单位）", Vector) = (0.01,0.013,0.078,0.051)
        _RegionSpecular4 ("区域 4 高光增益（无物理单位）", Float) = 0.01

                [Toggle] _UseSceneLighting ("强制使用场景光照（运行时可覆盖）", Float) = 0
        _LightDirection ("捕获主光方向（世界空间）", Vector) = (0.494292885,0.712461531,-0.498069525,0)
        _AlternateLightDirection ("捕获备选光方向（世界空间）", Vector) = (0.54590261,-0.263838917,-0.795222878,0)
        _SourceLightColor ("捕获主光颜色", Color) = (1,1,1,1)
        _AmbientColor ("环境颜色（源角色光照记录）", Color) = (0.0467248037,0.0705322102,0.0943396091,1)
        [Enum(Profile,0,SceneSH,1)] _SceneAmbientMode ("场景光照时的环境来源", Float) = 0

                _MatcapArray ("Matcap 源纹理数组（Surface；采样 RGBA，A 参与覆盖率）", 2DArray) = "" {}
        _MatcapUVTransform0 ("区域 0 Matcap UV 变换（XY 缩放 / ZW 偏移；UV 无单位）", Vector) = (5,5,0,0)
        _MatcapUVTransform1 ("区域 1 Matcap UV 变换（XY 缩放 / ZW 偏移；UV 无单位）", Vector) = (5,5,0,0)
        _MatcapUVTransform2 ("区域 2 Matcap UV 变换（XY 缩放 / ZW 偏移；UV 无单位）", Vector) = (5,5,0,0)
        _MatcapUVTransform3 ("区域 3 Matcap UV 变换（XY 缩放 / ZW 偏移；UV 无单位）", Vector) = (5,5,0,0)
        _MatcapUVTransform4 ("区域 4 Matcap UV 变换（XY 缩放 / ZW 偏移；UV 无单位）", Vector) = (5,5,0,0)
        _MatcapParameters0 ("区域 0 Matcap 参数（slice / RGB 增益 / alpha 增益 / U 速率 UV/s）", Vector) = (100,1,1,0)
        _MatcapParameters1 ("区域 1 Matcap 参数（slice / RGB 增益 / alpha 增益 / U 速率 UV/s）", Vector) = (100,1,1,0)
        _MatcapParameters2 ("区域 2 Matcap 参数（slice / RGB 增益 / alpha 增益 / U 速率 UV/s）", Vector) = (100,1,1,0)
        _MatcapParameters3 ("区域 3 Matcap 参数（slice / RGB 增益 / alpha 增益 / U 速率 UV/s）", Vector) = (100,1,1,0)
        _MatcapParameters4 ("区域 4 Matcap 参数（slice / RGB 增益 / alpha 增益 / U 速率 UV/s）", Vector) = (100,1,1,0)
        _MatcapOptions0 ("区域 0 Matcap 选项（V 速率 UV/s / 混合模式 / 折射开关 / 折射比例）", Vector) = (0,0,0,0.5)
        _MatcapOptions1 ("区域 1 Matcap 选项（V 速率 UV/s / 混合模式 / 折射开关 / 折射比例）", Vector) = (0,0,0,0.5)
        _MatcapOptions2 ("区域 2 Matcap 选项（V 速率 UV/s / 混合模式 / 折射开关 / 折射比例）", Vector) = (0,0,0,0.5)
        _MatcapOptions3 ("区域 3 Matcap 选项（V 速率 UV/s / 混合模式 / 折射开关 / 折射比例）", Vector) = (0,0,0,0.5)
        _MatcapOptions4 ("区域 4 Matcap 选项（V 速率 UV/s / 混合模式 / 折射开关 / 折射比例）", Vector) = (0,0,0,0.5)
        _MatcapTint0 ("区域 0 Matcap 染色（Surface RGB 使用，A 未用）", Color) = (1,1,1,1)
        _MatcapTint1 ("区域 1 Matcap 染色（Surface RGB 使用，A 未用）", Color) = (1,1,1,1)
        _MatcapTint2 ("区域 2 Matcap 染色（Surface RGB 使用，A 未用）", Color) = (1,1,1,1)
        _MatcapTint3 ("区域 3 Matcap 染色（Surface RGB 使用，A 未用）", Color) = (1,1,1,1)
        _MatcapTint4 ("区域 4 Matcap 染色（Surface RGB 使用，A 未用）", Color) = (1,1,1,1)
        _MatcapEnabled ("源 Matcap 分支（Surface；值小于 0.5 时旁路）", Float) = 1
        _DisplayTimeSeconds ("展示运行时间（秒；Matcap UV 动画输入）", Float) = 1.95

                _SurfaceExposure ("目标表面曝光（stops；输出阶段）", Range(-4,4)) = 0
        _Opacity ("目标覆盖率（Surface 输出 Alpha；源不透明分支对应 1）", Range(0,1)) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("剔除模式", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("混合源因子", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("混合目标因子", Float) = 0
        [Toggle] _ZWrite ("深度写入（ZWrite state）", Float) = 1

    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
        Pass
        {
            Name "Surface"
            Tags { "LightMode"="UniversalForwardOnly" }
            // 保留双面材质状态；片元正反面信号控制法线方向。
            Blend [_SrcBlend] [_DstBlend]
            Cull [_Cull]
            ZWrite [_ZWrite]
            ZTest LEqual
            ColorMask RGBA
            Stencil { Ref 0 Comp Always Pass Keep Fail Keep ZFail Keep }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex SurfaceVertex
            #pragma fragment SurfaceFragment
            // 当前URP提供的光照变体，保留Forward+与实际阴影输入。
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Includes/ZZZSceneLighting.hlsl"
            #include "Includes/ZZZArtistControls.hlsl"
            #include "Includes/ZZZSurface.hlsl"
            ENDHLSL
        }
    }
    CustomEditor "ZZZCharacterShaderGUI"
}
