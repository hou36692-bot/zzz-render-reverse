#ifndef ZZZ_FACE_MATH_INCLUDED
#define ZZZ_FACE_MATH_INCLUDED

// 脸与眼共用的无状态数学（源脸部PS 3969ce67 与眼部PS 720a454f 同族）。参数全部显式传入，不读材质CBUFFER。

// 输入是朝向主光的世界单位方向；先偏置并压平世界Y，再投影到源头部基。
// 返回角度/pi，约[-1,1]：符号决定镜像，绝对值决定明暗（0正面、±0.5侧面、±1背面）。
float ZZZFaceLightAngle(float3 lightDirectionWS, float3 axisXWS, float3 axisYWS, float3 axisZWS)
{
    float3 axisX = normalize(axisXWS);
    float3 axisY = normalize(axisYWS);
    float3 axisZ = normalize(axisZWS);
    float3 direction = normalize(lightDirectionWS);
    float bias = abs(dot(-axisX, direction)) * 0.5;
    direction.xz += bias * axisY.xz;
    direction *= rsqrt(max(dot(direction, direction), 1.175494351e-38));
    direction.y = 0.00001;
    direction *= rsqrt(max(dot(direction, direction), 1.175494351e-38));
    return atan2(dot(direction, axisY), dot(direction, axisZ)) * 0.318309873;
}

// 正角度时翻转U，使左右灯向共用一张边界图；V不变。
float2 ZZZFaceAngleUV(float angle, float2 uv)
{
    return float2(angle > 0.0 ? 1.0 - uv.x : uv.x, uv.y);
}

// 插值选择值.9/.7/.5/.3按.8/.6阈值选择端点，不在这里混色。
float3 ZZZFaceRegionColor(float region, float3 color0, float3 color1, float3 color2)
{
    float3 color = region < 0.8 ? color1 : color0;
    return region < 0.6 ? color2 : color;
}

float ZZZFaceRegionScalar(float region, float value0, float value1, float value2)
{
    float value = region < 0.8 ? value1 : value0;
    return region < 0.6 ? value2 : value;
}

// 控制图R决定边界中心，G与材质带宽决定过渡宽度；返回(白, 浅, 暗)三段权重。
// G的采样选择为开区间(.4,.95)，宽度gate为闭区间[.4,.95]，两者不能合并。
float3 ZZZFaceToneWeights(float boundaryR, float widthG, float angle, float bandwidth)
{
    float width = lerp(bandwidth, 0.025, saturate((widthG - 0.5) * 2.5));
    float widthGate = widthG >= 0.4 && widthG <= 0.95 ? 1.0 : 0.0;
    width = max(width * widthGate, 1e-5);
    float center = (boundaryR * 1.2 - 0.6) / (1.0 + 4.0 * width) + 0.6;
    float angleAbs = abs(angle);
    float3 weights;
    weights.x = saturate((center - width - angleAbs) / width);
    weights.z = saturate((angleAbs - center + width) / width);
    weights.y = 1.0 - weights.x - weights.z;
    return weights;
}

// 视距色板（源常量0.43725/0.33333）：近处趋向通道比例，约2.29单位以外保持原色板。
float3 ZZZFaceDistancePalette(float3 palette, float distanceToView)
{
    float3 biased = palette + 0.0000610351562;
    float mean = (biased.r + biased.g + biased.b) * 0.333330;
    float3 ratio = saturate(biased / max(mean, 1e-8));
    return lerp(ratio, biased, min(distanceToView * 0.437250, 1.0));
}

#endif
