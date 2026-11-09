using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;

/// <summary>Optional clock that drives time-based material inputs such as Matcap UV scrolling.</summary>
public interface IZZZDisplayClock
{
    double DisplayTimeSeconds { get; }
}

/// <summary>
/// 共享角色输入：把动画后的头部轴、光照来源与展示时钟写到角色实际材质槽。
/// 头部骨骼的轴向约定随骨架导入而不同，属于角色适配；通过 faceAxis 映射到 Face/Eye Shader 使用的源头部基。
/// </summary>
[ExecuteAlways]
[DefaultExecutionOrder(12000)]
public sealed class ZZZCharacterInputs : MonoBehaviour
{
    public enum LightingMode { CapturedFrame01, UnityScene }
    public enum BoneAxis { Right, Up, Forward, NegativeRight, NegativeUp, NegativeForward }

    [Tooltip("可选展示时钟（实现 IZZZDisplayClock）；为空时使用 Time.timeSinceLevelLoad。")]
    [FormerlySerializedAs("baseline")] public MonoBehaviour displayClock;
    [Tooltip("动画后的头部骨骼（如 Bip001 Head）。")]
    public Transform head;
    [Tooltip("接收输入的角色 Renderer；为空时自动收集子层级。")]
    public Renderer[] consumers;
    [Tooltip("CapturedFrame01 使用材质中的源帧光照；UnityScene 使用当前 URP 主光。")]
    public LightingMode lightingMode = LightingMode.UnityScene;

    [Header("头部骨骼到源头部基的映射（角色骨架适配）")]
    public BoneAxis faceAxisX = BoneAxis.Right;
    public BoneAxis faceAxisY = BoneAxis.Up;
    public BoneAxis faceAxisZ = BoneAxis.Forward;

    private static readonly int DisplayTimeSeconds = Shader.PropertyToID("_DisplayTimeSeconds");
    private static readonly int UseSceneLighting = Shader.PropertyToID("_UseSceneLighting");
    private static readonly int FaceAxisXWS = Shader.PropertyToID("_FaceAxisXWS");
    private static readonly int FaceAxisYWS = Shader.PropertyToID("_FaceAxisYWS");
    private static readonly int FaceAxisZWS = Shader.PropertyToID("_FaceAxisZWS");
    private static readonly int HeadPositionWS = Shader.PropertyToID("_HeadPositionWS");
    private MaterialPropertyBlock properties;

    private void OnEnable()
    {
        RenderPipelineManager.beginCameraRendering += BeforeCamera;
        ApplyInputs();
    }

    private void OnDisable()
    {
        RenderPipelineManager.beginCameraRendering -= BeforeCamera;
    }

    private void LateUpdate() => ApplyInputs();

    private void BeforeCamera(ScriptableRenderContext context, Camera camera)
    {
        if (camera != null && (camera.cullingMask & (1 << gameObject.layer)) != 0)
            ApplyInputs();
    }

    [ContextMenu("Lighting / Captured Frame01")]
    public void UseCapturedLighting()
    {
        lightingMode = LightingMode.CapturedFrame01;
        ApplyInputs();
    }

    [ContextMenu("Lighting / Unity Scene")]
    public void UseUnityLighting()
    {
        lightingMode = LightingMode.UnityScene;
        ApplyInputs();
    }

    // 取骨骼世界矩阵的列向量而非Transform.right/up/forward：角色根节点用负缩放纠正导入镜像时，
    // 旋转无法表达反射，只有矩阵列能给出与镜像后几何一致的头部基。
    public Vector3 Axis(BoneAxis axis)
    {
        Matrix4x4 m = head.localToWorldMatrix;
        Vector3 right = ((Vector3)m.GetColumn(0)).normalized;
        Vector3 up = ((Vector3)m.GetColumn(1)).normalized;
        Vector3 forward = ((Vector3)m.GetColumn(2)).normalized;
        switch (axis)
        {
            case BoneAxis.Right: return right;
            case BoneAxis.Up: return up;
            case BoneAxis.Forward: return forward;
            case BoneAxis.NegativeRight: return -right;
            case BoneAxis.NegativeUp: return -up;
            default: return -forward;
        }
    }

    private double ClockSeconds()
    {
        if (displayClock is IZZZDisplayClock clock)
            return clock.DisplayTimeSeconds;
        return Application.isPlaying ? Time.timeSinceLevelLoad : 0.0;
    }

    public void ApplyInputs()
    {
        if (head == null)
            return;
        if (consumers == null || consumers.Length == 0)
            consumers = GetComponentsInChildren<Renderer>(true);
        properties ??= new MaterialPropertyBlock();
        Vector3 axisX = Axis(faceAxisX), axisY = Axis(faceAxisY), axisZ = Axis(faceAxisZ);
        Vector3 headPosition = head.position;
        float time = (float)ClockSeconds();
        float sceneLighting = lightingMode == LightingMode.UnityScene ? 1f : 0f;
        foreach (Renderer consumer in consumers)
        {
            if (consumer == null)
                continue;
            for (int index = 0; index < consumer.sharedMaterials.Length; index++)
            {
                consumer.GetPropertyBlock(properties, index);
                properties.SetFloat(DisplayTimeSeconds, time);
                properties.SetFloat(UseSceneLighting, sceneLighting);
                properties.SetVector(FaceAxisXWS, new Vector4(axisX.x, axisX.y, axisX.z, 0f));
                properties.SetVector(FaceAxisYWS, new Vector4(axisY.x, axisY.y, axisY.z, 0f));
                properties.SetVector(FaceAxisZWS, new Vector4(axisZ.x, axisZ.y, axisZ.z, 0f));
                properties.SetVector(HeadPositionWS, new Vector4(headPosition.x, headPosition.y, headPosition.z, 1f));
                consumer.SetPropertyBlock(properties, index);
                properties.Clear();
            }
        }
    }
}
