using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

namespace ZZZ.Rendering
{
    /// <summary>
    /// Shared ZZZ character output chain, reconstructed from the identical post shaders of both captured frames:
    /// LogC 32^3 grading LUT (composite PS fbb07bad), highlight extraction / separable and pyramid filters
    /// (source draws 107-119 of the Vivian frame, 130-142 of the Qianxia frame) and the final segmented
    /// highlight response (PS 6443f79d). Intermediate sizes scale with the camera target like the source.
    /// </summary>
    public sealed class ZZZCharacterOutputFeature : ScriptableRendererFeature
    {
        private const string ShaderName = "Hidden/ZZZ/CharacterOutput";
        private const float SourceHeight = 1368f;

        [SerializeField] private Shader m_OutputShader = null;
        [Tooltip("Captured character grading LUT (1024x32 LogC strip, linear). Leave empty to skip grading.")]
        public Texture2D gradingLut;
        [Header("Target Composition Calibration")]
        [Tooltip("Highlight strength for legacy cameras without a ZZZCharacterCamera marker. 1 is the source response.")]
        [Range(0f, 1f)] public float highlightCompositionStrength = 1f;
        [Tooltip("Legacy camera names accepted without a ZZZCharacterCamera marker.")]
        [SerializeField] private string[] legacyCameraNames = { "VivianM2Camera" };

        private Material m_RuntimeMaterial;
        private OutputPass m_Pass;

        public override void Create()
        {
            CoreUtils.Destroy(m_RuntimeMaterial);
            m_RuntimeMaterial = null;
            m_Pass = new OutputPass
            {
                renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing,
                requiresIntermediateTexture = true
            };

            Shader shader = m_OutputShader != null ? m_OutputShader : Shader.Find(ShaderName);
            if (shader == null)
            {
                Debug.LogError($"{nameof(ZZZCharacterOutputFeature)}: shader '{ShaderName}' was not found.", this);
                return;
            }
            m_RuntimeMaterial = CoreUtils.CreateEngineMaterial(shader);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            Camera camera = renderingData.cameraData.camera;
            if (m_RuntimeMaterial == null || renderingData.cameraData.cameraType != CameraType.Game ||
                !ZZZCharacterAuxiliaryFeature.IsCharacterCamera(camera, legacyCameraNames))
                return;

            bool grading = gradingLut != null, highlights = true; float strength = highlightCompositionStrength;
            if (ZZZCharacterCamera.TryGet(camera, out var marker))
            {
                grading &= marker.colorGrading;
                highlights = marker.highlights;
                strength = marker.highlightStrength;
            }
            if (!grading && !highlights)
                return;
            m_Pass.Setup(m_RuntimeMaterial, gradingLut, grading, highlights, Mathf.Clamp01(strength));
            renderer.EnqueuePass(m_Pass);
        }

        protected override void Dispose(bool disposing)
        {
            CoreUtils.Destroy(m_RuntimeMaterial);
            m_RuntimeMaterial = null;
        }

        private sealed class OutputPass : ScriptableRenderPass
        {
            // Highlight extraction threshold / gain from the source bright-pass constants (CB0[1].x/y).
            private const float BrightThreshold = 0.45f;
            private const float BrightGain = 0.8f;
            private const int PassBrightExtract = 1, PassBlur = 2, PassPack = 3, PassLarge = 4, PassMedium = 5,
                PassSmall = 6, PassResolve = 7, PassHighlightComposite = 8, PassGrade = 9;

            private static readonly int BlitTextureId = Shader.PropertyToID("_BlitTexture");
            private static readonly int BlitScaleBiasId = Shader.PropertyToID("_BlitScaleBias");
            private static readonly int BloomTextureId = Shader.PropertyToID("_VwwBloomTexture");
            private static readonly int AtlasTextureId = Shader.PropertyToID("_VwwMipAtlasTexture");
            private static readonly int GradingLutId = Shader.PropertyToID("_ZZZGradingLut");
            private static readonly int SourceTexelSizeId = Shader.PropertyToID("_VwwSourceTexelSize");
            private static readonly int FilterAxisTexelId = Shader.PropertyToID("_VwwFilterAxisTexel");
            private static readonly int AtlasRegionId = Shader.PropertyToID("_VwwAtlasRegion");
            private static readonly int BrightThresholdId = Shader.PropertyToID("_VwwBrightThreshold");
            private static readonly int BrightGainId = Shader.PropertyToID("_VwwBrightGain");
            private static readonly int HighlightCompositionStrengthId = Shader.PropertyToID("_VwwHighlightCompositionStrength");

            private static readonly Vector4 BigRegion = new Vector4(0f, 0.472049713f, 1f, 0.527950287f);
            private static readonly Vector4 MidRegion = new Vector4(0f, 0.149068296f, 0.588235319f, 0.310559005f);
            private static readonly Vector4 SmallRegion = new Vector4(0f, 0.0124223828f, 0.235294119f, 0.124223605f);

            private Material m_Material;
            private Texture2D m_Lut;
            private bool m_Grading, m_Highlights;
            private float m_Strength;

            private sealed class PassData
            {
                public TextureHandle source, secondary;
                public Material material;
                public Texture lut;
                public Vector4 sourceTexelSize, filterAxisTexel, atlasRegion;
                public int secondaryTextureId, shaderPass;
                public bool hasSecondary;
                public float strength;
            }

            public void Setup(Material material, Texture2D lut, bool grading, bool highlights, float strength)
            {
                m_Material = material; m_Lut = lut; m_Grading = grading; m_Highlights = highlights; m_Strength = strength;
            }

            public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
            {
                UniversalResourceData resources = frameData.Get<UniversalResourceData>();
                TextureHandle source = resources.activeColorTexture;
                if (!source.IsValid())
                    return;
                if (resources.isActiveTargetBackBuffer)
                {
                    Debug.LogError("ZZZ character output needs an intermediate camera color texture; skipping back-buffer input.");
                    return;
                }

                TextureDesc sourceDescriptor = renderGraph.GetTextureDesc(source);
                int w = sourceDescriptor.width, h = sourceDescriptor.height;
                Vector4 sourceTexel = new Vector4(1f / w, 1f / h, w, h);
                TextureDesc fullDescriptor = sourceDescriptor;
                fullDescriptor.depthBufferBits = DepthBits.None;
                fullDescriptor.msaaSamples = MSAASamples.None;
                fullDescriptor.clearBuffer = false;

                TextureHandle graded = source;
                if (m_Grading)
                {
                    fullDescriptor.name = "ZZZ Character Graded";
                    graded = renderGraph.CreateTexture(fullDescriptor);
                    AddPass(renderGraph, "ZZZ Character / Grading LUT (fbb07bad)", source, graded, PassGrade, sourceTexel, Vector4.zero, Vector4.zero);
                }

                TextureHandle output = graded;
                if (m_Highlights)
                {
                    float scale = h / SourceHeight, aspect = (float)w / h;
                    int brightH = Mathf.Max(1, Mathf.RoundToInt(192f * scale)), brightW = Mathf.Max(1, Mathf.CeilToInt(brightH * aspect));
                    int atlasH = Mathf.Max(1, Mathf.RoundToInt(161f * scale)), atlasW = Mathf.Max(1, Mathf.CeilToInt(85f * scale * aspect));
                    int resolveW = Mathf.Max(1, Mathf.CeilToInt(w * 0.35f)), resolveH = Mathf.Max(1, Mathf.CeilToInt(h * 0.35f));

                    TextureDesc brightDescriptor = MakeColorDescriptor(sourceDescriptor, brightW, brightH, "ZZZ Character Bright Field");
                    TextureHandle bright = renderGraph.CreateTexture(brightDescriptor);
                    TextureHandle blurX = renderGraph.CreateTexture(brightDescriptor);
                    TextureHandle blurY = renderGraph.CreateTexture(brightDescriptor);
                    TextureDesc atlasDescriptor = MakeColorDescriptor(sourceDescriptor, atlasW, atlasH, "ZZZ Character Highlight Pyramid Atlas");
                    TextureHandle atlasPacked = renderGraph.CreateTexture(atlasDescriptor);
                    TextureHandle atlasX1 = renderGraph.CreateTexture(atlasDescriptor);
                    TextureHandle atlasX2 = renderGraph.CreateTexture(atlasDescriptor);
                    TextureHandle atlasX3 = renderGraph.CreateTexture(atlasDescriptor);
                    TextureHandle atlasY1 = renderGraph.CreateTexture(atlasDescriptor);
                    TextureHandle atlasY2 = renderGraph.CreateTexture(atlasDescriptor);
                    TextureHandle atlasFiltered = renderGraph.CreateTexture(atlasDescriptor);
                    TextureHandle resolved = renderGraph.CreateTexture(MakeColorDescriptor(sourceDescriptor, resolveW, resolveH, "ZZZ Character Highlight Resolve"));
                    fullDescriptor.name = "ZZZ Character Output";
                    output = renderGraph.CreateTexture(fullDescriptor);

                    Vector4 atlasTexel = new Vector4(1f / atlasW, 1f / atlasH, atlasW, atlasH);
                    AddPass(renderGraph, "ZZZ Character / Bright Extraction", graded, bright, PassBrightExtract, sourceTexel, Vector4.zero, Vector4.zero);
                    AddPass(renderGraph, "ZZZ Character / Filter X", bright, blurX, PassBlur, sourceTexel, new Vector4(1f / brightW, 0f, 0f, 0f), Vector4.zero);
                    AddPass(renderGraph, "ZZZ Character / Filter Y", blurX, blurY, PassBlur, sourceTexel, new Vector4(0f, 1f / brightH, 0f, 0f), Vector4.zero);
                    AddPass(renderGraph, "ZZZ Character / Pack Highlight Pyramid", blurY, atlasPacked, PassPack,
                        new Vector4(1f / brightW, 1f / brightH, brightW, brightH), Vector4.zero, Vector4.zero);
                    AddPass(renderGraph, "ZZZ Character / Pyramid X Large", atlasPacked, atlasX1, PassLarge, atlasTexel, new Vector4(1f / atlasW, 0, 0, 0), BigRegion);
                    AddPass(renderGraph, "ZZZ Character / Pyramid X Medium", atlasX1, atlasX2, PassMedium, atlasTexel, new Vector4(1f / atlasW, 0, 0, 0), MidRegion);
                    AddPass(renderGraph, "ZZZ Character / Pyramid X Small", atlasX2, atlasX3, PassSmall, atlasTexel, new Vector4(1f / atlasW, 0, 0, 0), SmallRegion);
                    AddPass(renderGraph, "ZZZ Character / Pyramid Y Large", atlasX3, atlasY1, PassLarge, atlasTexel, new Vector4(0, 1f / atlasH, 0, 0), BigRegion);
                    AddPass(renderGraph, "ZZZ Character / Pyramid Y Medium", atlasY1, atlasY2, PassMedium, atlasTexel, new Vector4(0, 1f / atlasH, 0, 0), MidRegion);
                    AddPass(renderGraph, "ZZZ Character / Pyramid Y Small", atlasY2, atlasFiltered, PassSmall, atlasTexel, new Vector4(0, 1f / atlasH, 0, 0), SmallRegion);
                    AddPass(renderGraph, "ZZZ Character / Weighted Highlight Resolve", blurY, resolved, PassResolve, sourceTexel,
                        Vector4.zero, Vector4.zero, atlasFiltered, AtlasTextureId);
                    AddPass(renderGraph, "ZZZ Character / Highlight Composite (6443f79d)", graded, output, PassHighlightComposite, sourceTexel,
                        Vector4.zero, Vector4.zero, resolved, BloomTextureId);
                }
                resources.cameraColor = output;
            }

            private static TextureDesc MakeColorDescriptor(TextureDesc source, int width, int height, string name)
            {
                source.name = name;
                source.width = width;
                source.height = height;
                source.colorFormat = GraphicsFormat.B10G11R11_UFloatPack32;
                source.depthBufferBits = DepthBits.None;
                source.msaaSamples = MSAASamples.None;
                source.clearBuffer = false;
                source.filterMode = FilterMode.Bilinear;
                source.wrapMode = TextureWrapMode.Clamp;
                source.useDynamicScale = false;
                source.useDynamicScaleExplicit = true;
                source.useMipMap = false;
                source.autoGenerateMips = false;
                return source;
            }

            private void AddPass(RenderGraph graph, string passName, TextureHandle source, TextureHandle destination, int shaderPass,
                Vector4 sourceTexelSize, Vector4 filterAxisTexel, Vector4 atlasRegion, TextureHandle secondary = default, int secondaryTextureId = 0)
            {
                using (var builder = graph.AddRasterRenderPass<PassData>(passName, out PassData data))
                {
                    data.source = source;
                    data.secondary = secondary;
                    data.material = m_Material;
                    data.lut = m_Lut;
                    data.shaderPass = shaderPass;
                    data.sourceTexelSize = sourceTexelSize;
                    data.filterAxisTexel = filterAxisTexel;
                    data.atlasRegion = atlasRegion;
                    data.hasSecondary = secondary.IsValid();
                    data.secondaryTextureId = secondaryTextureId;
                    data.strength = m_Strength;

                    builder.UseTexture(source, AccessFlags.Read);
                    if (data.hasSecondary)
                        builder.UseTexture(secondary, AccessFlags.Read);
                    builder.SetRenderAttachment(destination, 0, AccessFlags.Write);
                    builder.SetRenderFunc((PassData passData, RasterGraphContext context) => ExecutePass(passData, context));
                }
            }

            private static void ExecutePass(PassData data, RasterGraphContext context)
            {
                MaterialPropertyBlock properties = context.renderGraphPool.GetTempMaterialPropertyBlock();
                properties.SetTexture(BlitTextureId, data.source);
                properties.SetVector(BlitScaleBiasId, new Vector4(1f, 1f, 0f, 0f));
                properties.SetVector(SourceTexelSizeId, data.sourceTexelSize);
                properties.SetVector(FilterAxisTexelId, data.filterAxisTexel);
                properties.SetVector(AtlasRegionId, data.atlasRegion);
                properties.SetFloat(BrightThresholdId, BrightThreshold);
                properties.SetFloat(BrightGainId, BrightGain);
                properties.SetFloat(HighlightCompositionStrengthId, data.strength);
                if (data.lut != null)
                    properties.SetTexture(GradingLutId, data.lut);
                if (data.hasSecondary)
                    properties.SetTexture(data.secondaryTextureId, data.secondary);
                context.cmd.DrawProcedural(Matrix4x4.identity, data.material, data.shaderPass, MeshTopology.Triangles, 3, 1, properties);
            }
        }
    }
}
