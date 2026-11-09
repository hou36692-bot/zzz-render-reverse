# Unity 源码说明

这是从研究工程中抽出的角色渲染框架源码，保留原始目录语义，去掉了 `.meta`、材质、贴图、场景和 Profile。

## 目录

```text
Shaders/
  ZZZCharacterSurface.shader        身体、服装、头发
  ZZZCharacterFace.shader           脸、眉、脸内睫毛与眼线
  ZZZCharacterEye.shader            眼球、虹膜、透明覆盖
  ZZZCharacterOutline.shader        视空间描边外壳（UV1 平滑法线）
  ZZZCharacterHairShadowMask.shader 发影几何 / 裁剪空间偏移 / Stencil 遮罩
  ZZZCharacterOutput.shader         输出合成
  Includes/
    ZZZSurface.hlsl / ZZZFace.hlsl / ZZZFaceMath.hlsl / ZZZEye.hlsl
    ZZZOutline.hlsl / ZZZHairShadow.hlsl / ZZZSceneLighting.hlsl
    ZZZCharacterOutput.hlsl / ZZZArtistControls.hlsl
Runtime/
  ZZZCharacterInputs.cs             头部轴、场景光照开关、时钟
  ZZZCharacterCamera.cs             角色相机标记与调色 / 泛光开关
  ZZZCharacterAuxiliaryFeature.cs   辅助通道
  ZZZCharacterOutputFeature.cs      LogC LUT 调色、三尺度高亮、合成
  ZZZOutlineFollower.cs             描边外壳跟随
  ZZZRenderPipelineBinding.cs       管线与 Renderer 绑定
Editor/
  ZZZCharacterShaderGUI.cs          材质 Inspector
```

## 依赖与限制

- Unity 6000.0.83f1，URP 17.0.4，Linear 色彩空间，RenderGraph。
- 依赖 URP 的 `_FORWARD_PLUS`、阴影和深度纹理变体，以及 Stencil 状态。
- 不附带材质、控制图、主图、LUT、角色模型和场景，不能单独打开运行。
- 材质需要自行创建并填入控制图；参数含义见 [../docs/pipeline.md](../docs/pipeline.md)。
- 不同骨架通过 `ZZZCharacterInputs.faceAxisX/Y/Z` 映射，不要求骨骼同名。
- 角色层建议使用 `R16G16B16A16_SFloat`、`sRGB=false` 的 RenderTexture；输出 Feature 在其后执行。
- 代码按研究版本公开，未做通用引擎版本的兼容层。

## 建议接入顺序

1. 建立 URP Renderer 与 RenderTexture，把角色层单独渲染。
2. 接入 `ZZZCharacterSurface`，先只用主图和基础色板跑通。
3. 加 `ZZZCharacterFace` 与头部轴输入，验证转灯响应。
4. 加 `ZZZCharacterEye`、`ZZZCharacterOutline`、`ZZZCharacterHairShadowMask`。
5. 最后接 `ZZZCharacterOutputFeature` 与 LUT。

每一步都先确认材质实际绑定、目标区域有响应、恢复后误差回到容差内，再进入下一步。
