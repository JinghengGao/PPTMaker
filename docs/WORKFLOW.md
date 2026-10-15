# 创作流程

初始仓库的三套完整示例在 workspace/decks/ 下并列：demo 为 Slidev 官方示例，mc、nku 分别使用 TemplateMC、TemplateNKU 样式。三套均可直接 Preview、Export、Check；无需先 New。这三个保留 ID 不用于创建自己的作品。

## 新演示

1. 用根入口 New 创建独立 deck，填写 brief.md 的受众、目标、主题、资料来源和版本。
2. 将官方 Starter 内容替换为自己的材料；图片放入对应 public/decks/<id>/，标清来源。
3. Preview 逐页核查。每页一个观点，内容过多时重排或拆页；不得编造论文、数据和引用。
4. Export 导出明确版本，Check 检查成品，人工打开 PDF/PPTX 逐页复核。QA.md 记录当前结论和未验证项。

每版保留 PDF 与可编辑 PPTX。同版重导成功后替换，其他版本保留；不积累截图、日志、输入快照和重导归档。

用 -Theme mc 或 -Theme nku 选择样式，也接受 TemplateMC、TemplateNKU 名称；默认仍为官方 default。New 从来源示例 manifest.json 的 starter 复制源稿、assets/ 与 components/，并引用其 theme/。starter 必须位于来源示例内部，不能跳出目录。

## 从参考创建可复用示例

参考资料按需放入根 references/，原件只读。逐页观察并记录字号、配色、网格、标题与图表的页码依据，未知属性写待确认。

在 workspace/decks/<id>/ 按 mc、nku 的方式组织：

| 路径 | 内容 |
| --- | --- |
| slides.md、assets/ | 完整示例源稿与插图 |
| manifest.json | id、name、version、starter、来源与验证记录 |
| STYLE-GUIDE.md | 带参考页码的设计规则 |
| theme/package.json | 名称 slidev-theme-<id>，Slidev 本地主题元数据 |
| theme/styles/、theme/layouts/、theme/assets/ | 该示例专属的样式、布局与品牌素材 |
| exports/vX.Y.Z/ | 仅 PDF 与可编辑 PPTX |

区分原稿实际布局与延伸设计，不把参考作者身份或论文图像当作默认素材，不打包受版权保护的字体。先验证预览和导出，再标记 validated。中性骨架可以复用 shared/，专属配色不进入共享目录。

## AI 提示词

新建演示时可使用：

```text
先读 AGENTS.md 和 README.md。使用 [主题ID及版本]，基于 [本地资料] 制作 [主题]。
Deck ID：[ID]；受众：[受众]；时长与页数：[要求]；输出版本：[X.Y.Z]。
先填写 brief，不编造论文、数据和结果，缺失资料明确占位。
源稿与素材按 deck 隔离，逐页预览核查，导出 PDF 和可编辑 PPTX。
记录实际检查结果与限制，不修改其他作品。
```

创建主题时明确真实参考文件与新主题 ID，要求完整渲染、记录设计证据、实现独立 Theme，并与原稿逐页比对。修改已有演示时明确 deck、页码、目标和输出版本，不自动更换主题。
