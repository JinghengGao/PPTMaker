---
theme: default
title: PPTMaker 使用示例
info: 本演示只包含示例内容，不代表真实研究成果。
aspectRatio: 16/9
canvasWidth: 960
colorSchema: light
transition: none
wakeLock: false
fonts:
  sans: Microsoft YaHei
  local: [Microsoft YaHei, Arial]
  webfonts: []
  provider: none
drawings:
  enabled: false
---

# 从资料到可复现的科研演示

PPTMaker · AI 辅助工作区使用示例

阅读 → 编辑 → 预览 → 检查 → 导出

<div class="mt-12 text-sm opacity-60">示例内容 · 基于 Slidev 官方 default 主题</div>

---

# 每套演示拥有独立的源稿

1. 在任务书中写明受众、目标和资料来源。
2. 选择官方主题或已安装的本地主题。
3. 编辑 Markdown，按项目保存图片和数据。
4. 逐页预览，检查后导出一个明确版本。

<div class="mt-8 text-lg">未提供的研究结果应标为待补充，不得编造。</div>

---
layout: two-cols
---

# 图片与文字各有作用

本地 SVG 素材独立保存。

- 保持图片原始比例。
- 为实际论文图片记录来源。
- 复杂 SVG 在可编辑 PPTX 中仍可能是图片。

::right::

<img src="/decks/demo/sample.svg" alt="示例数据的三组柱形图" class="w-full mt-12" />

<p class="text-sm text-center">示意数据，仅用于检查图片路径与显示比例</p>

---

# 表格与公式也需要逐页检查

| 示例方案 | 示例分数 | 状态 |
| --- | ---: | --- |
| A | 60 | 演示数据 |
| B | 75 | 演示数据 |
| C | 90 | 演示数据 |

$$
\bar{x} = \frac{1}{n}\sum_{i=1}^{n}x_i
$$

<p class="text-sm opacity-60">这些数值不是实验结果。公式可正确显示，不意味着导出后可以原生编辑。</p>

---
layout: center
---

# 交付前检查三个文件

PDF 用于阅读，普通 PPTX 保持页面外观。

可编辑 PPTX 支持部分原生对象，仍需单独检查换行与图片。

源稿、版本快照和 QA 记录共同保留可维护原件。
