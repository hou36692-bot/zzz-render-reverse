using UnityEngine;

/// <summary>
/// 描边跟随体：与源Renderer共用骨架与网格的外壳Renderer，跟随其显隐并复制面部Morph权重。
/// 描边几何由共享Outline Shader按源描边VS扩张，不烘焙或修改源网格。
/// </summary>
[ExecuteAlways]
[DefaultExecutionOrder(13000)]
public sealed class ZZZOutlineFollower : MonoBehaviour
{
    public SkinnedMeshRenderer source;
    private SkinnedMeshRenderer target;

    private void OnEnable()
    {
        target = GetComponent<SkinnedMeshRenderer>();
        if (source == null && transform.parent != null)
            source = transform.parent.GetComponent<SkinnedMeshRenderer>();
    }

    private void LateUpdate()
    {
        if (source == null || target == null)
            return;
        target.enabled = source.enabled;
        if (source.sharedMesh != target.sharedMesh)
            return;
        for (int i = 0; i < source.sharedMesh.blendShapeCount; i++)
            target.SetBlendShapeWeight(i, source.GetBlendShapeWeight(i));
    }
}
