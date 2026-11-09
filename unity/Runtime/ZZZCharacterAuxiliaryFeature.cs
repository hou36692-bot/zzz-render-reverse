using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RendererUtils;
using UnityEngine.Rendering.Universal;

/// <summary>
/// Shared ZZZ character auxiliary layers: source-mesh outline, hair-shadow stencil mask and face shadow redraw,
/// ordered before the character output chain. Runs only for cameras that render ZZZ characters.
/// </summary>
public sealed class ZZZCharacterAuxiliaryFeature : ScriptableRendererFeature
{
    [Tooltip("Preview the auxiliary layers in Scene View for scenes that contain a ZZZCharacterCamera.")]
    [SerializeField] private bool previewInSceneView = true;
    [Tooltip("Legacy camera names accepted without a ZZZCharacterCamera marker.")]
    [SerializeField] private string[] legacyCameraNames = { "VivianM2Camera" };

    private AuxiliaryPass outlinePass;
    private AuxiliaryPass hairMaskPass;
    private AuxiliaryPass faceShadowPass;

    public override void Create()
    {
        outlinePass = new AuxiliaryPass("ZZZOutline", "ZZZ Character / Source Outline");
        hairMaskPass = new AuxiliaryPass("ZZZHairShadowMask", "ZZZ Character / Hair Shadow Mask");
        faceShadowPass = new AuxiliaryPass("ZZZFaceShadow", "ZZZ Character / Face Shadow Redraw");
    }

    public static bool IsCharacterCamera(Camera camera, string[] legacyNames)
    {
        if (camera == null)
            return false;
        if (ZZZCharacterCamera.TryGet(camera, out _))
            return true;
        if (legacyNames != null)
            foreach (var name in legacyNames)
                if (camera.name == name)
                    return true;
        return false;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var cameraData = renderingData.cameraData;
        bool run = cameraData.cameraType == CameraType.Game && IsCharacterCamera(cameraData.camera, legacyCameraNames);
#if UNITY_EDITOR
        if (!run && previewInSceneView && cameraData.cameraType == CameraType.SceneView)
            run = Object.FindAnyObjectByType<ZZZCharacterCamera>() != null;
#endif
        if (!run)
            return;
        renderer.EnqueuePass(outlinePass);
        renderer.EnqueuePass(hairMaskPass);
        renderer.EnqueuePass(faceShadowPass);
    }

    private sealed class AuxiliaryPass : ScriptableRenderPass
    {
        private readonly ShaderTagId shaderTag;
        private readonly string label;

        private sealed class PassData
        {
            public RendererListHandle rendererList;
        }

        public AuxiliaryPass(string tag, string label)
        {
            shaderTag = new ShaderTagId(tag);
            this.label = label;
            renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        }

        public override void RecordRenderGraph(RenderGraph graph, ContextContainer frameData)
        {
            var cameraData = frameData.Get<UniversalCameraData>();
            var renderingData = frameData.Get<UniversalRenderingData>();
            var resources = frameData.Get<UniversalResourceData>();
            var descriptor = new RendererListDesc(shaderTag, renderingData.cullResults, cameraData.camera)
            {
                renderQueueRange = RenderQueueRange.all,
                sortingCriteria = SortingCriteria.CommonOpaque,
                layerMask = cameraData.camera.cullingMask,
                rendererConfiguration = PerObjectData.None
            };
            var rendererList = graph.CreateRendererList(descriptor);
            using (var builder = graph.AddRasterRenderPass<PassData>(label, out var data))
            {
                data.rendererList = rendererList;
                builder.UseRendererList(rendererList);
                // Multiplicative face redraw reads existing color; stencil operations preserve depth outside their masks.
                builder.SetRenderAttachment(resources.activeColorTexture, 0, AccessFlags.ReadWrite);
                builder.SetRenderAttachmentDepth(resources.activeDepthTexture, AccessFlags.ReadWrite);
                builder.AllowPassCulling(false);
                builder.SetRenderFunc((PassData passData, RasterGraphContext context) =>
                    context.cmd.DrawRendererList(passData.rendererList));
            }
        }
    }
}
