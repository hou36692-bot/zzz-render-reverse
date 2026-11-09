using UnityEngine;
using UnityEngine.Rendering;

/// <summary>Uses the shared ZZZ character URP asset only while its scene is loaded, restoring the previous project settings.</summary>
public sealed class ZZZRenderPipelineBinding : MonoBehaviour
{
    [Tooltip("Project-owned URP asset with the shared ZZZ character renderer. Template assets are not modified.")]
    public RenderPipelineAsset pipeline;

    private RenderPipelineAsset previousDefault;
    private RenderPipelineAsset previousQuality;
    private bool applied;

    private void OnEnable()
    {
        if (pipeline == null || applied)
            return;
        previousDefault = GraphicsSettings.defaultRenderPipeline;
        previousQuality = QualitySettings.renderPipeline;
        GraphicsSettings.defaultRenderPipeline = pipeline;
        QualitySettings.renderPipeline = pipeline;
        applied = true;
    }

    private void OnDisable()
    {
        if (!applied)
            return;
        // Preserve another scene/user change made after this component activated.
        if (GraphicsSettings.defaultRenderPipeline == pipeline)
            GraphicsSettings.defaultRenderPipeline = previousDefault;
        if (QualitySettings.renderPipeline == pipeline)
            QualitySettings.renderPipeline = previousQuality;
        applied = false;
    }
}
