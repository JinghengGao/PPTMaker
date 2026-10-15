# 创作流程

初始仓库的三套完整示例可直接使用 Preview、Export、Check：demo 为 Slidev 官方示例，template-mc、template-nku 为两套主题示例，源稿分别位于主题 examples/。无需先 New；这三个保留 ID 不用于创建自己的作品。

## 新演示

1. 用根入口 New 创建独立 deck，填写 brief.md 的受众、目标、主题、资料来源和版本。
2. 将官方 Starter 内容替换为自己的材料；图片放入对应 public/decks/<id>/，标清来源。
3. Preview 逐页核查。每页一个观点，内容过多时重排或拆页；不得编造论文、数据和引用。
4. Export 导出明确版本，Check 检查成品，人工打开 PDF/PPTX 逐页复核。QA.md 记录当前结论和未验证项。

每版保留 PDF 与可编辑 PPTX。同版重导成功后替换，其他版本保留；不积累截图、日志、输入快照和重导归档。

内置主题可用 TemplateMC、TemplateNKU（或 template-mc、template-nku）选择，默认仍为官方 default。New 优先读取本地主题 manifest.json 的 starter，复制对应示例的 assets/ 与 components/；没有 starter 时采用官方示例。starter 必须位于该主题内部，不能跳出目录。

## 从参考创建本地主题

参考资料按需放入根 references/，原件只读。归档时复制到独立目录；逐页渲染观察，记录字号、配色、网格、标题与图表的页码依据，未知属性写待确认。

在 research-ppt/templates/<id>/ 创建独立 Slidev Theme：

| 路径 | 内容 |
| --- | --- |
| package.json | 名称 slidev-theme-<id>，本地主题元数据 |
| manifest.json | id、name、version、source_reference、status、适用场景和验证日期 |
| STYLE-GUIDE.md | 带参考页码的字体、配色、布局及图表规则 |
| styles/index.css | 主题专属样式，优先限制在 .slidev-layout 下 |
| layouts/、components/ | 按需抽象的布局与组件 |
| examples/ | 典型版式源稿，截图仅临时验收 |

区分原稿实际布局与延伸设计；不把参考作者身份或论文图像当作默认素材，不打包受版权保护的字体。先验证典型页的预览和导出，再标记 validated。专属样式和布局不进入引擎全局目录，更新需验证既有作品。

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
