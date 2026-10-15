# PPTMaker 工作约定

默认中文沟通，使用 Windows PowerShell、npm.cmd、npx.cmd。先读 README、相关源文件与 package.json，检查 Git 状态；使用锁定依赖，不重新初始化或顺带升级。

- 用户源稿、参考原件、主题、素材和各版成品保持完整；修改前检查现有变更，不覆盖其他 deck。参考原件只读，归档时复制。
- 公开 Git 包含通用工具、说明、官方 demo、TemplateMC/TemplateNKU 主题，以及经审阅的素材和示例 PDF/PPTX。私人资料、本机 Skills、依赖、缓存及其他成品不提交或上传。
- demo 的 slides.md 与 Counter.vue 保持 Slidev v53.0.0 官方内容，不改写成自制示例。新作品用 New 创建独立 deck，直接编辑其 slides.md。
- 初始仓库在 decks/ 下并列放置 demo、mc、nku，均可直接 Preview、Export、Check。这三个 ID 保留给内置示例，不设置单独的 templates/ 目录。
- 根目录保留入口和文档；Slidev 依赖、decks/、shared/、config/ 和 scripts/ 集中在 workspace/，路径使用相对引用。
- 不编造论文、数据、结果和引用；未知内容明确占位。默认 16:9，每页一个观点，溢出时重排或拆页。
- 学习参考时逐页观察，记录字体、配色、布局的页码依据；无依据写待确认。MC、NKU 的主题实现位于各自 theme/，专属样式不放到全局，更新需验证受影响作品。
- MC、NKU 通过 shared/ 复用中性页面骨架，配色和品牌素材留在各自 theme/；New 从所选示例的 manifest.starter 创建源稿，starter 必须位于该示例内。保留 TemplateNKU 原始校徽与建筑插图及其来源声明。
- 变更演示后预览并逐页核查图片、公式、字体、布局与技术内容；可编辑对象须实际检查，不凭后缀判断。
- 每版仅保留 PDF 与可编辑 PPTX；同版重导失败回滚，其他版本保留。截图、报告和测试副本只作临时验收，不积累归档。
- 代码修改后执行适当测试与公开文件检查，报告未验证项。当前不添加项目 LICENSE、不创建远程仓库或推送。

详见 [创作流程](docs/WORKFLOW.md) 与 [维护说明](docs/MAINTAINING.md)。
