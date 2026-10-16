# 创作流程

初始仓库的三套完整示例在 workspace/decks/ 下并列：demo 为 Slidev 官方示例，mc、nku 分别使用 TemplateMC、TemplateNKU 样式。三套均可直接 Preview、Export、Check；无需先 New。这三个保留 ID 不用于创建自己的作品。

## 新演示

1. 用根入口 New 创建独立 deck，填写 brief.md 的受众、目标、主题、资料来源和版本。
2. 将新建 deck 的示例内容替换为自己的材料；图片放入 workspace/public/decks/<id>/，以 /decks/<id>/文件名 引用，标清来源。
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

可直接复制的任务提示词统一维护在 [PROMPTS.md](PROMPTS.md)：新建演示、修改指定页、参考学习并创建主题、讲稿与排练、验收或继续任务。Agent 主流程在 [pptmaker Skill](../.agents/skills/pptmaker/SKILL.md)，上游来源与发现方式见 [SKILLS.md](SKILLS.md)。

先明确本轮交付范围：只做提纲、完整制作、局部修改或只验收。用户已经授权完整制作时，Agent 应持续推进到可检查的成品；关键事实或版本缺失时再集中询问，不能把每个步骤都变成确认节点。
