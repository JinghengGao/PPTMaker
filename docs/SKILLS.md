# 项目 Skills 的来源与适配

本仓库把可公开审阅的项目 Skills 放在 .agents/skills/，随 Git 分发。它们是文本知识和流程，不包含模型 API、后台服务或额外的执行引擎。用户目录中的本机 Skills 不随仓库分发。

## 默认分工

| Skill | 作用与读取方式 |
| --- | --- |
| [pptmaker](../.agents/skills/pptmaker/SKILL.md) | 本仓库主流程：资料、逐页提纲、制作、修正、验收和版本化交付；制作本仓库演示时先读 |
| [slidev](../.agents/skills/slidev/SKILL.md) | 官方语法与功能参考；只按当前任务读取对应 references |
| [slidev-presenter-mode](../.agents/skills/slidev-presenter-mode/SKILL.md) | 社区讲稿与排练适配；需要讲稿、双屏或排练时读取 |

在本仓库中，上游 Skill 的独立初始化、pnpm、直接导出、部署等通用示例不能替代现有命令。以用户要求、AGENTS.md 和 PPTMaker 工作流为准；继续使用 npm.cmd、根 PPTMaker.ps1、workspace/decks/<id>/ 和已有导出事务。

## 固定来源

| 内容 | 上游与固定版本 | 本地处理 |
| --- | --- | --- |
| 官方 slidev Skill | [slidevjs/slidev，v53.0.0](https://github.com/slidevjs/slidev/tree/v53.0.0/skills/slidev)，提交 30a0a54c8739b4b395d9b336a6304cc8ebcc3947 | SKILL.md 与全部 references 原样保留；省略重复安装说明 README，保留 MIT 原文 |
| 社区 presenter Skill | [yoanbernabeu/slidev-skills](https://github.com/yoanbernabeu/slidev-skills/tree/db69c86909b5b18ceb5dad18ded20c8ef26d2929/skills/presentation/slidev-presenter-mode)，提交 db69c86909b5b18ceb5dad18ded20c8ef26d2929 | 从讲稿、双屏和排练建议改编；移除远程访问、录制和独立构建示例，启动/导出交给 PPTMaker；保留 MIT 原文 |
| pptmaker 与任务提示词 | 本仓库编写 | 项目整体许可证仍按根第三方声明处理，不替第三方内容更改许可 |

官方 Skill 与当前锁定的 @slidev/cli 53.0.0 对齐。[Slidev 官方 AI 指南](https://sli.dev/guide/work-with-ai)也提供了通用安装方式；本仓库已包含固定副本，首次使用不必再从网络安装 Skills，更不要用 latest 覆盖它们。

## Agent 如何使用

在仓库根目录或其子目录启动支持项目 Skills 的 Codex，项目中的 .agents/skills/ 可被发现；可使用 `$pptmaker` 明确选择主流程。[Codex 官方说明](https://developers.openai.com/codex/skills/)介绍了目录发现与按需加载。新安装或文件变更后，下个会话可用；未显示时重新打开 Agent 会话，并检查是否禁用了本地 Skill。同名全局 Skill 不会自动合并，使用本项目路径以免混淆。

其他 Agent 的发现目录和调用语法可能不同，本仓库不改写它们的全局配置。让 Agent 先读 AGENTS.md 和主 Skill，或在该产品支持的项目 Skill 目录中注册本仓库目录；通用启动提示词见 [PROMPTS.md](PROMPTS.md)。不要假定所有客户端都能自动读取 .agents/skills/。

首次制作前仍需 README 中的 Node、Python、npm 依赖和 Chromium 环境。Agent 需要本地文件、命令执行与浏览器能力；纯聊天窗口只有文本建议，不能因此声称已生成或验收成品。Skills 不授予额外权限，不自动发布仓库或上传参考材料。

## 维护

不自动跟随上游主分支。更新官方 Skill 时与 Slidev 版本一起评估，更新来源记录，检查所有相对链接、frontmatter 与许可证。社区适配继续与原始版本区分，避免引入重复初始化或第二套导出脚本。

修改主流程或提示词后，用临时干净副本走一次真实任务：读资料、写 brief、New、写 slides、预览、Export 和 Check。区分文件结构校验与 Agent 的真实行为测试；没有实际运行模型时，不把人工检查说明文件称为 Agent 行为验收。临时资料、截图、报告和成品不纳入 Git。
