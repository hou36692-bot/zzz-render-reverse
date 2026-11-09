using UnityEngine;

/// <summary>Marks a camera that renders ZZZ characters; the shared renderer features run only for marked cameras.</summary>
[RequireComponent(typeof(Camera))]
public sealed class ZZZCharacterCamera : MonoBehaviour
{
    [Tooltip("Apply the captured character grading LUT (source composite PS fbb07bad).")]
    public bool colorGrading = true;
    [Tooltip("Apply the source highlight chain and final segmented highlight response (source PS 6443f79d).")]
    public bool highlights = true;
    [Range(0f, 1f), Tooltip("Target-side scale of the additive highlight contribution; 1 is the source response.")]
    public float highlightStrength = 1f;

    public static bool TryGet(Camera camera, out ZZZCharacterCamera marker)
    {
        marker = null;
        return camera != null && camera.TryGetComponent(out marker) && marker.isActiveAndEnabled;
    }
}
