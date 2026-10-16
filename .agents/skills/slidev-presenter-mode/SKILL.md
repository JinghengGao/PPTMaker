---
name: slidev-presenter-mode
description: "Prepare speaker notes and rehearse a Slidev presentation, including per-slide timing, transitions and local dual-screen presenter view. Use when a user asks for a talk track, 讲稿 or 排练; not for general deck generation or server deployment."
license: MIT
---

# Slidev 讲稿与排练

改编自 Yoan Bernabeu 的社区 Skill，保留讲稿、排练与双屏部分，适配 PPTMaker 的本地流程；并非上游原稿的完整副本。固定来源和改编范围见 [docs/SKILLS.md](../../../docs/SKILLS.md)，原许可见 [LICENSE](LICENSE)。

在 PPTMaker 仓库中，先遵守 [AGENTS.md](../../../AGENTS.md) 与 [pptmaker](../pptmaker/SKILL.md)，启动、导出和验收仍使用根 PPTMaker.ps1。其他 Slidev 项目可使用其已有启动命令，不自动初始化新工程。

## 把讲稿写给讲述者

先读当前源稿、受众与总时长。根据页面难度分配讲述时间，给开场、核心证据、局限和结尾留出合理空间；时间为排练估计，不宣称已经实测。

每页末尾用一个 HTML 注释写讲稿。说明这一页要讲清的观点、证据如何支撑它、需要解释的符号或前提，以及如何自然衔接下一页。不要逐字重复全部正文，不把未证实的新结论放入讲稿。

```markdown
<!--
预计用时：按该页内容与总时长分配。
要讲清的观点：概括本页的实际结论。
讲述顺序：指出页面中要看的图、数据或代码及必要解释。
需要说明的边界：保留依据中的前提与局限。
衔接下一页：用内容关系连接，不写空泛过渡口号。
-->
```

以上字段是写作提示，成稿时填入真实内容，删除不适用项。资料出处放在同一注释中；需要观众理解的关键限制与来源也应在页面可见。

## 在本地排练

用 Preview 启动目标 deck 后，观众页面为 http://localhost:<端口>/，演讲者页面为 http://localhost:<端口>/presenter。检查当前页、下一页和讲稿是否正确对应，再测试翻页与动画步骤。具体功能以当前 Slidev 版本为准。

根据实际排练反馈调整讲稿、节奏与页面密度；用户只要求讲稿时不重排视觉设计。图表和代码的解释应能在分配时间内讲完，不用加快语速弥补信息过载。

用户要求双屏展示时，把观众页面放在投影/共享窗口，演讲者页面保留在自己的屏幕。默认保持本地访问，不自动打开 --remote、外网共享、摄像头或录制。

## 交付

讲稿保存在原 slides.md 的注释中，不再维护一套重复讲稿。需要单独讲稿文件时按用户要求生成。区分“已补充讲稿”“已测试演讲者页面”和“已完成真实排练”，只报告实际完成的部分。
