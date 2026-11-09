# 渲染管线与模块契约

代码位于 `unity/`。这是两个角色共用的一套 URP 角色渲染框架，角色差异通过材质 Profile、骨架轴向映射和 Feature 开关表达。

## 总览

```text
动画骨骼 / 主光 / 相机
        │
        ▼
ZZZCharacterInputs
  头部三轴、场景光照开关、展示时钟 → 角色材质槽
        │
        ├─ Surface      身体、服装、头发
        ├─ Face         脸、眉、脸内睫毛与眼线
        ├─ Eye          眼球、虹膜、透明覆盖
        ├─ Outline      视空间描边外壳
        └─ HairShadow   发影几何 + 脸部 Stencil 接收
        │
        ▼
角色线性 HDR 层
        │
        ▼
ZZZCharacterOutputFeature
  LogC LUT 调色 → 三尺度高亮 → 分段合成 → 最终输出
```

## 运行输入

`ZZZCharacterInputs` 在每帧渲染前向角色的每个材质槽写 MaterialPropertyBlock。写入的字段是 `_DisplayTimeSeconds`、`_UseSceneLighting`、`_FaceAxisXWS/YWS/ZWS` 和 `_HeadPositionWS`；`_HeadPositionWS` 当前没有 Shader 读取，作为预留字段。光向来自材质中的捕获值或 URP 主光，不经过这个组件。

- `faceAxisX/Y/Z` 把不同骨架的骨骼轴向映射到 Shader 使用的源头部基，支持镜像根。
- `lightingMode` 在“跟随 URP 主光”和“捕获帧光照”之间切换；生产使用前者。
- 没有有效输入时停止更新，不猜固定方向。
- 同一场景的多个角色各自绑定自己的输入，不共享全局 Shader 参数。

`ZZZCharacterCamera` 标记角色相机，可单独开关调色与泛光；`ZZZOutlineFollower` 让描边外壳跟随角色；`ZZZRenderPipelineBinding` 把 URP Renderer 与 Feature 接起来。

## Surface

用于身体、服装和头发。输入是主图、法线控制图、材质控制图、辅助控制图和区域色板。

```text
N.RG 重映射 + 重建 Z      → 切线空间法线
N.B                       → 色调偏置
M.R (.2/.4/.6/.8 分段)    → 五套色板选择
M.G                       → 金属度
M.B                       → 高光遮罩
Aux.R                     → Matcap 折射
Aux.G                     → 粗糙度
Aux.B                     → Matcap / 发光遮罩（由 _EmissionRemap 分配）
七段光照权重 + 半角高光    → 明暗与高光
视空间法线查 Matcap        → 反射叠加
```

主要参数：`_NormalStrength`、`_MetalStrength`、`_RoughnessStrength`、`_BandWidth`、`_SpecularStrength`、`_EmissionEnabled`、`_EmissionRemap`、`_TextureMipBias`、`_TextureVFlip`、`_MatcapEnabled`、`_MatcapArray`、`_MatcapParameters0-4`、`_MatcapOptions0-4`、`_MatcapUVTransform0-4`、`_MatcapTint0-4`、`_RegionSpecular`、`_RegionSpecular4`、`_SurfaceExposure`。

区域值由 `_MaterialControl.r` 提供，0.2/0.4/0.6/0.8 四个阈值选择五套色板。光照响应分成 dark、shadow、transition、mid、lit transition、lit、bright 七段；dark 段乘深色板，shadow 和 transition 乘浅色板，后四段使用固定常量色。同一个区域值还决定高光、发光和 Matcap 切片。

头发复用同一个 Surface 核心，差异在材质 Profile 和色板；目标侧没有单独的头发 Shader。

## Face

用于脸主槽、独立眉毛和脸内睫毛 / 眼线。

```text
动画后头部基 + 光向      → 相对角度
控制图 R                 → 明暗边界中心
控制图 G                 → 采样选择与带宽
角度镜像 UV              → 左右对称采样
顶点 COLOR.b 低两位      → 色板选择值
三色权重                 → 白色 / 浅色 / 暗色
主图 RGB × 色调 × 光色 + 环境项 → 最终颜色
```

关键点：

- 角度镜像与带宽门限不能合并成单一权重。
- 顶点编码先解码再插值，不能把不同色板的顶点直接混在一起。
- 脸部使用源式 `albedo × (0.96 × 色调 × 光色 + 环境)`。
- 鼻部乘色、法线补充、局部高光等对画面贡献很小的分支未纳入当前实现；删除项有对照记录。

## Eye

```text
顶点 COLOR.r → uint(code) → 16×16 查表地址 (code&15, 15-(code>>4))
             → 线性色表采样
             → RGB×2，Alpha 不乘 2
             → 幂响应与法线响应
覆盖 = 主图 Alpha × 插值色表 Alpha
输出 = (着色 RGB × 覆盖, 覆盖)
```

Pass 使用 `One / OneMinusSrcAlpha`、`ZWrite Off`、`Cull Back`、`ZTest LEqual`。源材质的独立 Alpha 因子与目标不同，完整 Blend 状态仍属已知缺口。

## Outline

- 从 UV1 的带符号 XY 重建切线空间平滑法线，再转到世界空间和视空间。
- 在视空间 XY 上按宽度扩张；宽度由投影深度分三段（0.00105 / 0.005 / 0.0035）并乘视口修正，`Cull Front` 绘制外壳。
- 片元把漫反射转 HSV，按金属度和区域压缩 V，再按光照响应合成区域描边色。
- 与角色共用骨架蒙皮；脸部需要额外同步 Morph 权重。
- 眼球与睫毛的描边槽可以单独关闭。

## HairShadow

- 使用源发影几何，保留裁剪空间偏移 `_ClipSpaceXOffset/YOffset`，再叠加按 3840×2160 参考画幅换算的像素偏移。
- `ColorMask 0`，只写 Stencil；脸部第二个 Pass 用 `Blend DstColor Zero`、`ZTest Equal`、Stencil Ref 132 / ReadMask 128 乘一次阴影色。
- 源码中的发影 Shader 没有光向输入；遮罩跟随动画头部。完整源影图 / Stencil 生产链仍未恢复。

## Output

`ZZZCharacterOutputFeature` 在角色层之后执行：

1. LogC 编码后查 32³ 条带 LUT：1024×32，蓝通道选切片，相邻切片插值。
2. 4-tap 下采样、6-tap 单轴模糊、9/16/20 tap 三尺度高亮图集。
3. 按 0.3/0.3/0.26/0.15 还原亮部；低值保持线性，高值走幂响应。
4. 把高亮加到调色结果上并饱和。

主要参数：`_VwwBrightThreshold`、`_VwwBrightGain`、`_VwwSegmentThreshold`、`_VwwSegmentExponent`、`_VwwSegmentPowScale`、`_VwwSegmentOffset`、`_VwwHighlightGain`、`_VwwHighlightCompositionStrength`。

输入应为单独的角色相机或 RenderTexture。代码没有按角色像素做 mask；如果相机把背景一起渲染进来，LUT 和亮部链会一并处理。

## Feature 开关

| 开关 | 作用 |
| --- | --- |
| `_TextureVFlip` | 适配 PNG 导入链的 V 方向 |
| `_MatcapEnabled` | 旁路 Matcap 分支 |
| `_EmissionEnabled` | 发光分支开关 |
| `_EmissionRemap` | 把 Aux.B 分配给 Matcap 或发光 |
| `_DistancePalette` | 眼部按视距调整色板端点 |
| `_PowerResponse` | 眼部亮度 / 法线幂响应 |
| `_RegionFromVertex` | 脸部描边区域来自顶点编码 |
| `_SceneAmbientMode` | 环境来源选择 Profile 或 SH |
| `_ResponseScale` | 眼部 / 脸部响应比例（0.96） |
| `_ArtLightingMode` | 美术光照模式：跟随、捕获或场景 |

## 材质与 Profile

仓库不附带材质、控制图、贴图和 LUT。需要自行准备：

- 主图（sRGB）与线性控制图；
- 角色骨架与 Renderer 绑定；
- 32³ LogC LUT；
- `ZZZ_Character_URP` / `ZZZ_Character_Renderer` Profile。

材质参数保存的是 sRGB 序列化颜色，在 Linear 工程上传时由引擎解码；方向与直接线性量使用 `Vector`，不能先 `.linear` 再写入 `Color`。
