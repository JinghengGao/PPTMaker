# 项目 Skills 的来源与适配

本仓库把可公开审阅的项目 Skills 放在 .agents/skills/，随 Git 分发。它们是文本知识和流程，不包含模型 API、后台服务或额外的执行引擎。用户目录中的本机 Skills 不随仓库分发。

## 默认分工

| Skill | 作用与读取方式 |
| --- | --- |
| [pptmaker](../.agents/skills/pptmaker/SKILL.md) | 本仓库主流程：资料、逐页提纲、制作、修正、验收和版本化交付；制作本仓库演示时先读 |
| [slidev](../.agents/skills/slidev/SKILL.md) | 官方语法与功能参考；只按当前任务读取对应 references |
| [slidev-presenter-mode](../.agents/skills/slidev-presenter-mode/SKILL.md) | 社区讲稿与排练适配；需要讲稿、双屏或排练时读取 |

在本仓库中，上游 Skill 的独立初始化、pnpm、直接导出、部署等通用示例不能替代现有命令。以用户要求、AGENTS.md 和 PPTMaker 工作流为准；继续使用 npm.cmd、根 PPTMaker.ps1、workspace/decks/<id>/ 和已有导出事务。

## 规则放在哪里

| 位置 | 负责的内容 |
| --- | --- |
| [AGENTS.md](../AGENTS.md) | 仓库共同约束：资料保护、目录、公开范围、依赖及成品规则 |
| [pptmaker/SKILL.md](../.agents/skills/pptmaker/SKILL.md) | 制作任务的主流程、范围判断与专项参考的读取条件 |
| 官方 slidev Skill 与 references/ | 与锁定版本对齐的语法和功能；保持上游原文，项目例外写在主 Skill 或项目文档中 |
| presenter Skill | 讲稿、计时和本地排练的方法；启动、导出与验收交回主流程 |
| deck 的 STYLE-GUIDE.md、theme/ | 所选主题的布局、配色、字体及品牌资产；通用设计建议应在这些约束内使用 |
| [PROMPTS.md](PROMPTS.md) | 用户调用现有流程的任务示例，不另行定义制作规则 |
| 本文 | Skill 清单、固定来源、本地改编范围与维护方法 |

用户当前请求决定任务范围；用户只要求讲稿、局部修改或验收时，专项参考不能扩大任务。新增知识先判断是否属于现有 Skill：制作流程与通用设计由 pptmaker 调度，语法归官方参考，讲稿与排练归 presenter；只有具有独立用途的工作流才考虑新增 Skill。

主 SKILL.md 保留通用流程和必要约束。详细且只在部分任务中使用的知识放在对应 Skill 的 references/，从主文件说明何时读取；不预建空目录，也不为缩短文件机械拆分。引用路径相对所在文件解析，命令的执行目录按主流程约定。Skill 内的 references/ 是公开审阅的知识，区别于根目录被忽略的私人 references/。

详细规则在其负责位置维护，其他文件用链接引用；调用示例只保留必要摘要。引用官方或社区知识，不会让其初始化、确认、命令或归档规则自动成为本项目流程。

## 固定来源

| 内容 | 上游与固定版本 | 本地处理 |
| --- | --- | --- |
| 官方 slidev Skill | [slidevjs/slidev，v53.0.0](https://github.com/slidevjs/slidev/tree/v53.0.0/skills/slidev)，提交 30a0a54c8739b4b395d9b336a6304cc8ebcc3947 | SKILL.md 与全部 references 原样保留；省略重复安装说明 README，保留 MIT 原文 |
| 社区 presenter Skill | [yoanbernabeu/slidev-skills](https://github.com/yoanbernabeu/slidev-skills/tree/db69c86909b5b18ceb5dad18ded20c8ef26d2929/skills/presentation/slidev-presenter-mode)，提交 db69c86909b5b18ceb5dad18ded20c8ef26d2929 | 从讲稿、双屏和排练建议改编；移除远程访问、录制和独立构建示例，启动/导出交给 PPTMaker；保留 MIT 原文 |
| pptmaker 与任务提示词 | 本仓库编写 | 项目整体许可证仍按根第三方声明处理，不替第三方内容更改许可 |

官方 Skill 与当前锁定的 @slidev/cli 53.0.0 对齐。[Slidev 官方 AI 指南](https://sli.dev/guide/work-with-ai)也提供了通用安装方式；本仓库已包含固定副本，首次使用不必再从网络安装 Skills，更不要用 latest 覆盖它们。

## Agent 如何使用

在仓库根目录或其子目录启动支持项目 Skills 的 Codex，项目中的 .agents/skills/ 可被发现；可使用 `$pptmaker` 明确选择主流程。[OpenAI 官方说明](https://learn.chatgpt.com/docs/build-skills)介绍了目录发现与按需加载：先根据 name、description 和路径选择 Skill，再读取完整 SKILL.md，按需读取参考。参考文件不会因放入目录就自动应用，主 Skill 必须链接它并说明使用条件。

Codex 会自动检测新安装或修改的 Skill；更新未显示时再重启，并检查是否禁用了本地 Skill。当前对话已经读取过的文件修改后，要重新读取相关内容，不能把旧上下文当成最新版本。其他客户端的发现与刷新行为以其实际支持为准。同名 Skill 不会合并，可能同时出现在选择器中；用本项目路径确认来源。

其他 Agent 的发现目录和调用语法可能不同，本仓库不改写它们的全局配置。让 Agent 先读 AGENTS.md 和主 Skill，或在该产品支持的项目 Skill 目录中注册本仓库目录；通用启动提示词见 [PROMPTS.md](PROMPTS.md)。不要假定所有客户端都能自动读取 .agents/skills/。

首次制作前仍需 README 中的 Node、Python、npm 依赖和 Chromium 环境。Agent 需要本地文件、命令执行与浏览器能力；纯聊天窗口只有文本建议，不能因此声称已生成或验收成品。Skills 不授予额外权限，不自动发布仓库或上传参考材料。

## 维护

### 来源与更新

不自动跟随上游主分支，也不通过安装 latest 覆盖本地内容。原样引用与本地改编采用不同的维护方式：

- **原样引用**：按固定提交逐文件对照；官方 Slidev Skill 与工具链版本一起评估。工作区适配写在本项目说明中，避免修改官方副本后仍声称原样保留。
- **本地改编**：记录固定上游提交、原文件路径、对应本地文件，以及保留、改写和舍弃的内容。以后比较上游旧、新提交，选择需要的变化，再适配本地规则；不整目录覆盖。
- **本仓库编写**：直接用 Git 管理，按实际需求修改；与借鉴内容混合后，应更新来源说明，不继续把全部内容归为原创。

引入新来源时，在上表补充固定链接和文件映射；多对多映射可紧接上表单列，避免把完整来源记录复制到每个文件。改编文件顶部简述来源并链接这里；署名和许可证在对应目录或 [第三方声明](../THIRD_PARTY_NOTICES.md) 保留。未实际引入的资料不登记为项目依赖。

### 验证与公开范围

按改动影响选择验证范围，并在交付说明中区分完成了哪一层：

1. **文件与来源检查**：检查 frontmatter、相对链接、读取条件、规则冲突、固定来源及许可；原样副本与上游对照，确认新增知识未被 Git 忽略。
2. **实际任务验证**：调整制作流程、参考读取条件或设计方法后，让 Agent 在临时工作副本完成有代表性的任务。完整制作覆盖读资料、brief、New、写 slides、逐页预览、Export 和 Check；讲稿或局部修改按对应范围验证，观察是否扩大任务。纯链接或加载说明修正不要求重新生成演示。

结构检查不能证明 Agent 会选对 Skill，也不能证明设计效果改善；没有实际运行任务时明确记录未执行行为验证。后者以真实页面和导出结果判断，不以匹配说明文字代替。

仅公开已审阅的三套项目 Skills；新增独立 Skill 时同步审阅 .gitignore 白名单、本文、README 和第三方声明。现有 Skill 内新增参考文件也要检查 Git 差异，私人资料、本机配置、临时截图、报告和测试成品不纳入 Git。版本审阅与回滚使用 Git，无需额外管理器或历史副本目录。
