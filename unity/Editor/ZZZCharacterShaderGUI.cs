using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class ZZZCharacterShaderGUI : ShaderGUI
{
    private const string ResetLabel = "重置美术调节（不改源数据）";
    private static bool s_ShowMaterialInputs;
    private static bool s_ShowAdvanced;

    private static readonly ArtistGroup[] ArtistGroups =
    {
        new ArtistGroup("基础颜色", new ArtistField[]
        {
            new ArtistField("_ArtTint", "角色综合色", "作用于当前着色器支持的表面颜色。默认白色为中性，不额外偏色。"),
            new ArtistField("_ArtExposure", "曝光（stops）", "作用于当前着色器支持的角色模块；默认 0 为中性。"),
            new ArtistField("_ArtSaturation", "饱和度", "范围：0–2；默认 1 为中性。")
        }),
        new ArtistGroup("阴影", new ArtistField[]
        {
            new ArtistField("_ArtShadowTint", "阴影色调", "默认白色为中性，不额外染色。"),
            new ArtistField("_ArtShadowStrength", "阴影强度", "范围：0–2；默认 1 为中性。")
        }),
        new ArtistGroup("光照模式", new ArtistField[]
        {
            new ArtistField("_ArtLightingMode", "模式", "0 跟随展示，1 使用源帧输入，2 使用场景光照。默认 0。")
        }),
        new ArtistGroup("反射", new ArtistField[]
        {
            new ArtistField("_ArtSpecularStrength", "高光强度", "适用于 Surface / Eye。范围：0–2；默认 1 为中性。"),
            new ArtistField("_ArtMatcapStrength", "Matcap 强度", "适用于 Surface。范围：0–2；默认 1 为中性。")
        }),
        new ArtistGroup("Emission", new ArtistField[]
        {
            new ArtistField("_ArtEmissionStrength", "发光强度", "适用于 Surface。范围：0–2；默认 1 为中性。Bloom 与全角色高亮合成由 RendererFeature 处理，不是单材质参数。")
        }),
        new ArtistGroup("轮廓", new ArtistField[]
        {
            new ArtistField("_ArtOutlineTint", "描边颜色", "默认白色为中性，不额外染色。"),
            new ArtistField("_ArtOutlineWidth", "描边宽度", "范围：0–2 倍基准宽度；默认 1 保持基准。"),
            new ArtistField("_ArtOutlineStrength", "描边强度", "范围：0–2；默认 1 为中性。")
        })
    };

    private static readonly ArtistField[] HairShadowFields =
    {
        new ArtistField("_ArtHairShadowEnabled", "启用发影遮罩", "只控制发影遮罩开关。"),
        new ArtistField("_ArtHairShadowOffsetX", "水平偏移（参考像素）", "左上为原点，+X 向右；按 3840 × 2160 参考画幅换算。"),
        new ArtistField("_ArtHairShadowOffsetY", "垂直偏移（参考像素，+Y 向下）", "左上为原点；按 3840 × 2160 参考画幅换算。")
    };

    private static readonly string[] ArtistPropertyNames =
    {
        "_ArtTint", "_ArtExposure", "_ArtSaturation", "_ArtShadowTint", "_ArtShadowStrength",
        "_ArtSpecularStrength", "_ArtMatcapStrength", "_ArtEmissionStrength", "_ArtLightingMode",
        "_ArtOutlineTint", "_ArtOutlineWidth", "_ArtOutlineStrength", "_ArtHairShadowEnabled",
        "_ArtHairShadowOffsetX", "_ArtHairShadowOffsetY"
    };
    private static readonly string[] RuntimePropertyNames =
    {
        "_UseSceneLighting", "_FaceAxisXWS", "_FaceAxisYWS", "_FaceAxisZWS", "_FaceShadowPointWS", "_DisplayTimeSeconds"
    };
    private static readonly string[] ResetWhite = { "_ArtTint", "_ArtShadowTint", "_ArtOutlineTint" };
    private static readonly string[] ResetOne =
    {
        "_ArtSaturation", "_ArtShadowStrength", "_ArtSpecularStrength", "_ArtMatcapStrength",
        "_ArtEmissionStrength", "_ArtOutlineWidth", "_ArtOutlineStrength", "_ArtHairShadowEnabled"
    };
    private static readonly string[] ResetZero =
    {
        "_ArtExposure", "_ArtLightingMode", "_ArtHairShadowOffsetX", "_ArtHairShadowOffsetY"
    };

    // 只组织已有材质属性；不改 Shader 声明、默认值或运行时行为。
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        EditorGUILayout.LabelField("薇薇安｜美术调节", EditorStyles.boldLabel);
        if (Find(properties, "_ArtHairShadowOffsetX") != null)
        {
            EditorGUILayout.HelpBox("此材质只生成遮罩，不输出颜色；发影颜色和强度由 Face 阴影消费者控制。", MessageType.Info);
            DrawArtistGroup(materialEditor, properties, "发影遮罩", HairShadowFields);
        }
        else
        {
            foreach (ArtistGroup group in ArtistGroups)
                DrawArtistGroup(materialEditor, properties, group.Title, group.Fields);
        }

        if (HasArtistProperty(properties) && GUILayout.Button(new GUIContent(ResetLabel, "仅重置当前 Shader 存在的 _Art 参数到白色、0 或 1；不修改源参数。")))
            ResetArtistProperties(materialEditor);

        DrawMaterialInputs(materialEditor, properties);
        DrawAdvanced(materialEditor, properties);
    }

    private static void DrawArtistGroup(MaterialEditor editor, MaterialProperty[] properties, string title, ArtistField[] fields)
    {
        bool hasField = false;
        foreach (ArtistField field in fields) hasField |= Find(properties, field.Name) != null;
        if (!hasField) return;

        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        EditorGUILayout.LabelField(title, EditorStyles.boldLabel);
        foreach (ArtistField field in fields)
        {
            MaterialProperty property = Find(properties, field.Name);
            if (property != null) editor.ShaderProperty(property, new GUIContent(field.Label, field.Tooltip));
        }
        EditorGUILayout.EndVertical();
    }

    private static void DrawArtistGroup(MaterialEditor editor, MaterialProperty[] properties, ArtistGroup group)
    {
        DrawArtistGroup(editor, properties, group.Title, group.Fields);
    }

    private static void DrawMaterialInputs(MaterialEditor editor, MaterialProperty[] properties)
    {
        bool hasTexture = false;
        foreach (MaterialProperty property in properties)
            hasTexture |= property.type == MaterialProperty.PropType.Texture && !IsArtistProperty(property.name);
        if (!hasTexture) return;

        s_ShowMaterialInputs = EditorGUILayout.Foldout(s_ShowMaterialInputs, "材质输入（贴图/颜色空间）", true);
        if (!s_ShowMaterialInputs) return;
        foreach (MaterialProperty property in properties)
            if (property.type == MaterialProperty.PropType.Texture && !IsArtistProperty(property.name))
                editor.ShaderProperty(property, new GUIContent(property.displayName, "保留 Shader 原始贴图名称、颜色空间与通道说明。"));
    }

    private static void DrawAdvanced(MaterialEditor editor, MaterialProperty[] properties)
    {
        s_ShowAdvanced = EditorGUILayout.Foldout(s_ShowAdvanced, "高级源数据 / 渲染状态", true);
        if (!s_ShowAdvanced) return;

        DrawRuntimeProperties(editor, properties);
        var source = new List<MaterialProperty>();
        var compatibility = new List<MaterialProperty>();
        var renderState = new List<MaterialProperty>();
        foreach (MaterialProperty property in properties)
        {
            if (IsArtistProperty(property.name) || IsRuntimeProperty(property.name) || property.type == MaterialProperty.PropType.Texture)
                continue;
            if (IsRenderState(property.name)) renderState.Add(property);
            else if (IsMarkedUnused(property.displayName)) compatibility.Add(property);
            else source.Add(property);
        }

        DrawPropertyGroup(editor, "源参数（含 HideInInspector 字段）", source,
            "原始 Shader 属性；保留原名称、类型与控件。修改会改变该材质源参数。");
        DrawPropertyGroup(editor, "兼容字段（Shader 标注未消费）", compatibility,
            "Shader 显示名标注兼容保留、未消费或当前主路径不采样；不作为常用美术调节项。");
        DrawPropertyGroup(editor, "渲染状态", renderState,
            "仅显示 Shader 暴露的材质属性；不模拟或改写 Pass / Renderer 设置。");
        EditorGUILayout.HelpBox("Pass 与 Renderer 固定状态不属于材质属性；此 Inspector 不提供伪控件。", MessageType.None);
    }

    private static void DrawRuntimeProperties(MaterialEditor editor, MaterialProperty[] properties)
    {
        bool hasRuntime = false;
        foreach (string name in RuntimePropertyNames) hasRuntime |= Find(properties, name) != null;
        if (!hasRuntime) return;

        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        EditorGUILayout.LabelField("运行时驱动｜只读", EditorStyles.boldLabel);
        EditorGUI.BeginDisabledGroup(true);
        foreach (string name in RuntimePropertyNames)
        {
            MaterialProperty property = Find(properties, name);
            if (property != null) editor.ShaderProperty(property, new GUIContent(RuntimeLabel(name), "由展示运行时驱动；此处只读。"));
        }
        EditorGUI.EndDisabledGroup();
        EditorGUILayout.EndVertical();
    }

    private static void DrawPropertyGroup(MaterialEditor editor, string title, List<MaterialProperty> fields, string tooltip)
    {
        if (fields.Count == 0) return;
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        EditorGUILayout.LabelField(title, EditorStyles.boldLabel);
        foreach (MaterialProperty property in fields)
            editor.ShaderProperty(property, new GUIContent(property.displayName, tooltip));
        EditorGUILayout.EndVertical();
    }

    private static void ResetArtistProperties(MaterialEditor editor)
    {
        var materials = new List<Material>();
        foreach (Object target in editor.targets)
            if (target is Material material && HasArtistProperty(material)) materials.Add(material);
        if (materials.Count == 0) return;

        Undo.RecordObjects(materials.ToArray(), ResetLabel);
        foreach (Material material in materials)
        {
            foreach (string name in ResetWhite)
                if (material.HasProperty(name)) material.SetColor(name, Color.white);
            foreach (string name in ResetOne)
                if (material.HasProperty(name)) material.SetFloat(name, 1f);
            foreach (string name in ResetZero)
                if (material.HasProperty(name)) material.SetFloat(name, 0f);
            EditorUtility.SetDirty(material);
        }
        editor.Repaint();
    }

    private static bool HasArtistProperty(Material material)
    {
        foreach (string name in ArtistPropertyNames) if (material.HasProperty(name)) return true;
        return false;
    }

    private static bool HasArtistProperty(MaterialProperty[] properties)
    {
        foreach (string name in ArtistPropertyNames) if (Find(properties, name) != null) return true;
        return false;
    }

    private static bool IsArtistProperty(string name)
    {
        foreach (string candidate in ArtistPropertyNames) if (candidate == name) return true;
        return false;
    }

    private static bool IsRuntimeProperty(string name)
    {
        foreach (string candidate in RuntimePropertyNames) if (candidate == name) return true;
        return false;
    }

    private static bool IsRenderState(string name)
    {
        return name == "_SrcBlend" || name == "_DstBlend" || name == "_Cull" || name == "_ZWrite" ||
            name == "_ZTest" || name == "_ColorMask" || name == "_OffsetFactor" || name == "_OffsetUnits" ||
            name == "_QueueOffset" || name.StartsWith("_Stencil");
    }

    private static bool IsMarkedUnused(string displayName)
    {
        return displayName.Contains("未消费") || displayName.Contains("兼容保留") || displayName.Contains("不采样");
    }

    private static MaterialProperty Find(MaterialProperty[] properties, string name)
    {
        foreach (MaterialProperty property in properties) if (property.name == name) return property;
        return null;
    }

    private static string RuntimeLabel(string name)
    {
        switch (name)
        {
            case "_UseSceneLighting": return "运行时输入：场景光照开关";
            case "_FaceAxisXWS": return "运行时输入：面部局部 X 轴（WS）";
            case "_FaceAxisYWS": return "运行时输入：面部局部 Y 轴（WS）";
            case "_FaceAxisZWS": return "运行时输入：面部局部 Z 轴（WS）";
            case "_FaceShadowPointWS": return "运行时输入：面部阴影锚点（WS）";
            case "_DisplayTimeSeconds": return "运行时输入：展示时间（秒）";
            default: return name;
        }
    }

    private sealed class ArtistGroup
    {
        public readonly string Title;
        public readonly ArtistField[] Fields;
        public ArtistGroup(string title, ArtistField[] fields) { Title = title; Fields = fields; }
    }

    private sealed class ArtistField
    {
        public readonly string Name, Label, Tooltip;
        public ArtistField(string name, string label, string tooltip) { Name = name; Label = label; Tooltip = tooltip; }
    }
}